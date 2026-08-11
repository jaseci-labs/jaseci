"""GraphMend deferred side-effect transformation tests.

print/logger calls are rewritten into appends on a PROCESS-GLOBAL buffer
(`__jac_se_emit__`), and the buffer is flushed after all compute (the return
value is hoisted into a temp so the flush is a trailing eager epilogue). This
keeps the forward pass a single contiguous FX graph while preserving the calls.

The buffer is global rather than function-local so it outlives a frame that
exits by raising: the `@__jac_se_guard__` boundary decorator, which sits ABOVE
`@torch.compile` and is therefore eager, drains it on that path. Assertions run
against the generated Python source, plus the detection tag table where source
alone cannot distinguish "not detected" from "detected but declined"."""
import ast;
import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.jaclib {
    __jac_log_emit__,
    __jac_log_flush_hook__,
    __jac_log_register__
}
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob _LOG_SEEN: list = [];

"""Record a replayed log message (flush-hook probe)."""
def _record_log(msg: str) {
    _LOG_SEEN.append(msg);
}

"""Raise from inside a replayed log call (flush-hook probe)."""
def _raise_log(msg: str) {
    raise RuntimeError("logger down");
}

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "graphmend"
     );

"""Compile a source file and return its generated Python source."""
def _compile_path(path: str, gm: bool) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=path, options=CompileOptions(graphmend=gm, type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

"""Compile a checked-in .jac fixture and return its generated Python source."""
def _pysrc(name: str, gm: bool) -> str {
    return _compile_path(os.path.join(FIXTURES, name), gm);
}

"""Compile a fixture with graphmend on and list the detection tags recorded."""
def _break_kinds(name: str) -> list {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=True, type_check=False)
    );
    return [k.value for k in prog.graphmend_breaks.values()];
}

"""A Python-source model with a print between tensor ops.

Written to a temp file at test time rather than checked in as a .py fixture:
the repository does not accept new Python files, and the point of the fixture
is only that GraphMend ingests .py source, which a generated file exercises
just as well."""
glob PY_SIDE_EFFECT_SRC = '''
import torch


@torch.compile()
def f(x):
    x = torch.relu(x)
    print(x)
    return torch.sin(x) * 2.0
''';

"""Compile the generated .py model above and return its Python lowering."""
def _py_fixture_src(gm: bool) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "py_side_effect.py");
        with open(path, "w") as fh {
            fh.write(PY_SIDE_EFFECT_SRC);
        }
        return _compile_path(path, gm);
    }
}

glob PY_LOCAL_LOGGER_SRC = '''
import torch


class Net(torch.nn.Module):
    def forward(self, x, local_logger):
        x = torch.relu(x)
        local_logger.warning("GM-LOCAL")
        return torch.sin(x) * 2.0


model = torch.compile(Net())
''';

"""Compile the local-receiver forward model and return its Python lowering."""
def _py_local_logger_src(gm: bool) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "py_local_logger.py");
        with open(path, "w") as fh {
            fh.write(PY_LOCAL_LOGGER_SRC);
        }
        return _compile_path(path, gm);
    }
}

test "print is buffered and flushed via the runtime helper" {
    src = _pysrc("side_effect.jac", True);
    # The mutable positional arg is snapshotted: hoisted to a temp and cloned (if
    # a tensor) at the call site so a later in-place mutation cannot corrupt the
    # deferred value.
    assert "__gm_se_arg_0 = x" in src;
    assert (
        "__jac_se_emit__(print, "
        "(__gm_se_arg_0.clone() if hasattr(__gm_se_arg_0, 'clone') "
        "else __gm_se_arg_0,), {})"
    )
        in src;
    assert "__jac_se_flush__()" in src;
    assert (
        "from jaclang.jac0core.jaclib import "
        "__jac_se_emit__, __jac_se_flush__, __jac_se_guard__"
    )
        in src;
    assert _break_kinds("side_effect.jac") == ["side_effect"];
}

test "a compiled function gets the eager boundary guard" {
    src = _pysrc("side_effect.jac", True);
    # The guard must sit ABOVE @torch.compile: prepended, it wraps the compiled
    # callable from outside, so its try/finally is never traced. Placed inside
    # the compiled region an untraceable finally makes Dynamo abandon the frame.
    assert "@__jac_se_guard__" in src;
    assert src.index("@__jac_se_guard__") < src.index("@torch.compile");
}

test "return value is hoisted so the flush follows all compute" {
    src = _pysrc("side_effect.jac", True);
    # compute assigned to a temp, then flush, then return the temp
    assert "__gm_ret_0 = torch.sin(x) * 2.0" in src;
    assert src.index("__gm_ret_0 = ") < src.index("__jac_se_flush__()");
    assert src.index("__jac_se_flush__()") < src.index("return __gm_ret_0");
}

test "the buffer is flushed before every return" {
    src = _pysrc("side_effect_early_return.jac", True);
    # two exit paths, each preceded by its own flush; both return temps hoisted
    assert src.count("__jac_se_flush__()") == 2;
    assert src.count("return __gm_ret_") == 2;
}

test "logger call is buffered the same way as print" {
    src = _pysrc("side_effect_logger.jac", True);
    assert "__jac_se_emit__(log.warning, ('deprecated path',), {})" in src;
    assert "__jac_se_flush__()" in src;
}

test "a buffered call's keyword arguments are preserved" {
    src = _pysrc("logger_kwargs.jac", True);
    assert (
        "__jac_se_emit__(logger.warning, ('deprecated',), {'stacklevel': 2})" in src
    );
}

test "a non-literal keyword value is snapshotted like a positional" {
    src = _pysrc("side_effect_kwarg.jac", True);
    assert "__gm_se_arg_0 = y" in src;
    assert (
        "{'extra': __gm_se_arg_0.clone() if hasattr(__gm_se_arg_0, 'clone') "
        "else __gm_se_arg_0}"
    )
        in src;
}

test "an unpacked argument declines instead of being dropped" {
    # Detection still tags both; the decline belongs to the transform.
    src = _pysrc("side_effect_unpack.jac", True);
    assert "__jac_se_emit__" not in src;
    assert "print('head', *extra)" in src;
    assert "logger.warning('deprecated', **opts)" in src;
    assert _break_kinds("side_effect_unpack.jac") == ["side_effect", "side_effect"];
}

test "a receiver that does not bind to a logger is left untouched" {
    # A parameter receiver has no logger-proving binding, so the call is not
    # tagged at all: no module-scope slot, no buffer, the break stays.
    src = _py_local_logger_src(True);
    assert "__jac_log_register__" not in src;
    assert "__jac_se_emit__" not in src;
    assert "local_logger.warning('GM-LOCAL')" in src;
}

test "a logging-named method on a non-logger receiver is not tagged" {
    # The receiver base must bind to a logger (a logging module import or a
    # getLogger/get_logger assignment); an arbitrary module declines.
    src = _pysrc("se_foreign_warn.jac", True);
    assert "__jac_se_emit__" not in src;
    assert "myutils.warn_user(y)" in src;
    assert _break_kinds("se_foreign_warn.jac") == [];
}

test "a user-defined name matching a logging pattern is not tagged" {
    # `warn_and_scale` contains the `warn` pattern, but the name resolves to a
    # local function; rewriting it would defer arbitrary user compute.
    src = _pysrc("user_defined_warn.jac", True);
    assert "__jac_se_emit__" not in src;
    assert "y = warn_and_scale(x)" in src;
    assert _break_kinds("user_defined_warn.jac") == [];
}

test "py source: print side effect is buffered and flushed" {
    # The .py front-end (PyastBuildPass) produces UniIR whose nodes unparse
    # differently from .jac-origin nodes, so the rewrite must operate
    # structurally; this guards `jac run model.py --graphmend`.
    src = _py_fixture_src(True);
    assert "__gm_se_arg_0 = x" in src;
    assert "__jac_se_emit__(print, " in src;
    assert "__jac_se_flush__()" in src;
    src = _py_fixture_src(False);
    assert "__jac_se_emit__" not in src;
    assert "print(x)" in src;
}

test "no buffering when graphmend disabled" {
    src = _pysrc("side_effect.jac", False);
    assert "__jac_se_emit__" not in src;
    assert "__jac_se_guard__" not in src;
    assert "print(x)" in src;
}

test "a raising log call cannot replay stale entries on the next pass" {
    # The flush hook snapshots and clears the buffer BEFORE replaying, so a
    # log call that raises drops the batch instead of re-emitting it later.
    ok_slot = __jac_log_register__(_record_log);
    boom_slot = __jac_log_register__(_raise_log);
    __jac_log_emit__(boom_slot, ("first", ), {});
    __jac_log_emit__(ok_slot, ("second", ), {});
    raised = None;
    try {
        __jac_log_flush_hook__(None, None, None);
    } except RuntimeError as e {
        raised = e;
    }
    assert raised is not None;
    __jac_log_emit__(ok_slot, ("third", ), {});
    __jac_log_flush_hook__(None, None, None);
    assert _LOG_SEEN == ["third"] , f"stale entries replayed: {_LOG_SEEN}";
}
