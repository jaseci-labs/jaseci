"""Deferred side-effect rewrites: buffered emits, hoisted returns, eager flush boundary."""
import os;
import tempfile;
import from tests.support {
    graphmend_break_kinds as _break_kinds,
    graphmend_compile_path as _compile_path,
    graphmend_pysrc as _pysrc
}
import from jaclang.jac0core.jaclib {
    __jac_log_emit__,
    __jac_log_flush_hook__,
    __jac_log_register__,
    __jac_se_emit__,
    __jac_se_region_open__
}
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.main.graphmend.ast_edit {
    append_stmt,
    gen_name,
    insert_before
}

glob _LOG_SEEN: list = [];

"""Record a replayed log message (flush-hook probe)."""
def _record_log(msg: str) {
    _LOG_SEEN.append(msg);
}

"""Raise from inside a replayed log call (flush-hook probe)."""
def _raise_log(msg: str) {
    raise RuntimeError("logger down");
}

glob _EAGER_LOG_SEEN: list = [];

"""Record a message emitted through the slot registry (eager-path probe)."""
def _record_eager(msg: str) {
    _EAGER_LOG_SEEN.append(msg);
}

glob _NESTED_SEEN: list = [];

"""Record a replayed call from either buffer (nested-region probe)."""
def _record_nested(msg: str) {
    _NESTED_SEEN.append(msg);
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
    # structurally; this guards `jac run model.py` under the default auto mode.
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

test "a deferred logger call emits immediately when no region is open" {
    # A [Defer] rewrite must be behavior-preserving on the eager path: with no
    # compiled region open there is nothing to defer to, so the slot call goes
    # straight through, exactly as __jac_se_emit__ does at depth 0. Buffering it
    # would hold the message until some unrelated region exits, or drop it.
    slot = __jac_log_register__(_record_eager);
    __jac_log_emit__(slot, ("eager", ), {});
    assert _EAGER_LOG_SEEN == ["eager"] , (
        f"eager logger call was buffered instead of emitted: {_EAGER_LOG_SEEN}"
    );
    # Inside an open region (what the injected forward pre-hook does) the same
    # call must still buffer and replay on the flush hook.
    __jac_se_region_open__(None, None);
    __jac_log_emit__(slot, ("deferred", ), {});
    assert _EAGER_LOG_SEEN == ["eager"] , (
        f"call inside an open region was not deferred: {_EAGER_LOG_SEEN}"
    );
    __jac_log_flush_hook__(None, None, None);
    assert _EAGER_LOG_SEEN == ["eager", "deferred"] , (
        f"deferred call was not replayed: {_EAGER_LOG_SEEN}"
    );
}

test "a raising log call cannot replay stale entries on the next pass" {
    # The flush hook snapshots and clears the buffer BEFORE replaying, so a
    # log call that raises drops the batch instead of re-emitting it later.
    ok_slot = __jac_log_register__(_record_log);
    boom_slot = __jac_log_register__(_raise_log);
    __jac_se_region_open__(None, None);
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

test "a nested region exit leaves the enclosing region's buffers intact" {
    # Nested compiled modules share one context-local depth counter. The inner
    # module's post-hook drops the depth to 1, not 0: draining there would run
    # the outer region's buffered calls mid-trace, which is what deferral
    # exists to prevent, and dynamo replays them again on a recompile.
    slot = __jac_log_register__(_record_nested);
    __jac_se_region_open__(None, None);
    __jac_se_emit__(_record_nested, ("outer-se", ), {});
    __jac_log_emit__(slot, ("outer-log", ), {});
    __jac_se_region_open__(None, None);
    __jac_log_flush_hook__(None, None, None);
    assert _NESTED_SEEN == [] , (
        f"inner region exit drained the outer buffers: {_NESTED_SEEN}"
    );
    __jac_log_flush_hook__(None, None, None);
    assert _NESTED_SEEN == ["outer-se", "outer-log"] , (
        f"outer region exit did not replay: {_NESTED_SEEN}"
    );
    # Drained exactly once: the snapshot-and-clear happens on the outer exit.
    __jac_log_flush_hook__(None, None, None);
    assert _NESTED_SEEN == ["outer-se", "outer-log"] , (
        f"entries replayed twice: {_NESTED_SEEN}"
    );
}

glob GLOB_TAIL_SRC = "import torch;\n\nglob m = torch.relu;\n";

"""Compile a .jac source string and return its module node."""
def _compile_mod(src: str) -> uni.Module {
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.program { JacProgram }
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "glob_mod.jac");
        with open(path, "w") as fh {
            fh.write(src);
        }
        return JacProgram().compile(
            file_path=path, options=CompileOptions(type_check=False)
        );
    }
}

test "insert_before climbs out of a module-level glob to the module body" {
    # The anchor assignment lives in a GlobalVars, whose assignments list has
    # no statement slot; the insert must land on the module body before the
    # glob statement, not be dropped.
    mod = _compile_mod(GLOB_TAIL_SRC);
    gv = mod.get_all_sub_nodes(uni.GlobalVars)[0];
    anchor = gv.assignments[0];
    nm = gen_name(anchor, "__gm_probe__", False);
    stmt = uni.ExprStmt(expr=nm, in_fstring=False, kid=[nm]);
    assert insert_before(anchor, stmt);
    assert stmt in mod.body;
    assert mod.body.index(stmt) == mod.body.index(gv) - 1;
    assert mod.kid.index(stmt) == mod.kid.index(gv) - 1;
    assert stmt.parent is mod;
}

test "append_stmt lands after a trailing module-level glob" {
    mod = _compile_mod(GLOB_TAIL_SRC);
    gv = mod.get_all_sub_nodes(uni.GlobalVars)[0];
    nm = gen_name(gv, "__gm_probe__", False);
    stmt = uni.ExprStmt(expr=nm, in_fstring=False, kid=[nm]);
    assert append_stmt(mod, stmt);
    assert mod.body[-1] is stmt;
    assert mod.kid.index(stmt) == mod.kid.index(gv) + 1;
    assert stmt.parent is mod;
}

test "a jac glob call-site wrap gets the forward hook registrations" {
    # `glob m = torch.compile(...)` puts the assignment inside a GlobalVars,
    # whose `assignments` list is the only thing emitted. Without hooks the
    # region never opens, so every [Defer] rewrite in the module is a runtime
    # no-op and the graph break it was meant to close survives.
    src = _pysrc("region_wrap_cls.jac", True);
    assert "if hasattr(compiled_net, 'register_forward_pre_hook'):" in src;
    assert "compiled_net.register_forward_pre_hook(__jac_se_region_open__)" in src;
    assert (
        "compiled_net.register_forward_hook(__jac_log_flush_hook__, always_call=True)"
        in src
    );
}

glob _THREAD_SEEN: list = [],
     _THREAD_SLOT: list = [];

"""Record a deferred call with the thread that actually ran it."""
def _record_thread(tag: str) {
    import threading;
    _THREAD_SEEN.append((tag, threading.get_ident()));
}

test "two threads in deferred regions never replay each other's calls" {
    # A threaded server interleaves requests; each thread's open region must
    # buffer and flush only its own calls, never a concurrent thread's.
    import threading;
    if not _THREAD_SLOT {
        _THREAD_SLOT.append(__jac_log_register__(_record_thread));
    }
    _THREAD_SEEN.clear();
    started = threading.Event();
    peer_emitted = threading.Event();
    flushed = threading.Event();
    idents: dict = {};
    def _first {
        idents["first"] = threading.get_ident();
        __jac_se_region_open__(None, None);
        __jac_se_emit__(_record_thread, ("first-se", ), {});
        __jac_log_emit__(_THREAD_SLOT[0], ("first-log", ), {});
        started.set();
        peer_emitted.wait(30);
        __jac_log_flush_hook__(None, None, None);
        flushed.set();
    }
    def _second {
        idents["second"] = threading.get_ident();
        started.wait(30);
        __jac_se_region_open__(None, None);
        __jac_se_emit__(_record_thread, ("second-se", ), {});
        __jac_log_emit__(_THREAD_SLOT[0], ("second-log", ), {});
        peer_emitted.set();
        flushed.wait(30);
        __jac_log_flush_hook__(None, None, None);
    }
    t1 = threading.Thread(target=_first);
    t2 = threading.Thread(target=_second);
    t1.start();
    t2.start();
    t1.join(60);
    t2.join(60);
    assert not t1.is_alive() and not t2.is_alive() , "workers deadlocked";
    assert len(_THREAD_SEEN) == 4 , (
        f"expected each thread to flush its own two calls, saw {_THREAD_SEEN}"
    );
    by_tag = {tag: ident for (tag, ident) in _THREAD_SEEN};
    assert by_tag.get("first-se") == idents["first"] , (
        f"first thread's deferred emit replayed elsewhere: {_THREAD_SEEN}"
    );
    assert by_tag.get("first-log") == idents["first"] , (
        f"first thread's deferred log replayed elsewhere: {_THREAD_SEEN}"
    );
    assert by_tag.get("second-se") == idents["second"] , (
        f"second thread's deferred emit replayed elsewhere: {_THREAD_SEEN}"
    );
    assert by_tag.get("second-log") == idents["second"] , (
        f"second thread's deferred log replayed elsewhere: {_THREAD_SEEN}"
    );
    _THREAD_SEEN.clear();
    __jac_se_emit__(_record_thread, ("main-eager", ), {});
    assert _THREAD_SEEN == [("main-eager", threading.get_ident())] , (
        "worker-thread region state leaked into the main thread"
    );
}
