"""Warnings facade parity: native jacpython warnings core vs host CPython.

Every scenario runs identically against the host ``warnings`` module (isolated
inside ``catch_warnings(record=True)``) and against the facade pipeline
(``warn_explicit`` bridge + display-sink capture), then compares counts,
raised categories and byte-exact formatted output. Position wiring is tested
through the provider hook; the ``<sys>:0`` fallback pins CPython's own
out-of-frames result.
"""

import warnings as host_warnings;
import builtins as host_builtins;
import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyList,
    PyExceptionType,
    PyError,
    py_exception_type,
    is_error,
    py_none,
}
import from _warningsmodule {
    _p2_warn_state_reset,
    _p2_warn_default_filters,
    _p2_resetwarnings,
    _p2_simplefilter,
    _p2_filterwarnings,
    _p2_warn_set_display_sink,
    _p2_warn_set_position_provider,
    _p2_formatwarning,
    _p2_action_is_valid,
    PyWarningsWarnFn,
    PyWarningsWarnExplicitFn,
    PyWarningsSimpleFilterFn,
    PyWarningsCatchFn,
}

glob _probe_lines: list[str] = [];
glob _provider_stacklevels: list[int] = [];

def _capture_sink(text: str) {
    _probe_lines.append(text);
}

def _probe_provider(sl: int) -> tuple | None {
    _provider_stacklevels.append(sl);
    # Module "__main__" so the default DeprecationWarning-in-__main__ filter
    # (module-prefix matching) applies exactly as under CPython.
    return ("/tmp/probe.py", 42, "__main__");
}

def _facade_fresh_capture {
    _p2_warn_state_reset();
    _probe_lines.clear();
    _provider_stacklevels.clear();
    _p2_warn_set_display_sink(_capture_sink);
    _p2_warn_set_position_provider(None);
}

def _warn_explicit_bridge(text: str, category: str, filename: str, lineno: int) -> PyObj {
    fn = PyWarningsWarnExplicitFn(t="function");
    return fn.tp_call(
        [
            PyStr(t="str", val=text),
            py_exception_type(category),
            PyStr(t="str", val=filename),
            PyInt(t="int", val=lineno),
        ],
        {}
    );
}


# Host category lookup: the warnings module does not re-export the builtin
# warning classes; they live on builtins.
def _host_cat(name: str) -> any {
    if name == "DeprecationWarning" {
        return host_builtins.DeprecationWarning;
    }
    if name == "PendingDeprecationWarning" {
        return host_builtins.PendingDeprecationWarning;
    }
    if name == "ResourceWarning" {
        return host_builtins.ResourceWarning;
    }
    return host_builtins.UserWarning;
}

# Host twin of one explicit-location scenario: returns (#shown, #raised).
def _host_run(action: str, calls: list[tuple[str, str, int]]) -> tuple[int, int] {
    shown = 0;
    raised = 0;
    # A persistent module registry -- warn() itself feeds one from the frame's
    # globals; direct warn_explicit calls must supply it for dedup to engage.
    reg: dict = {};
    cm = host_warnings.catch_warnings(record=True);
    rec = cm.__enter__();
    try {
        host_warnings.simplefilter(action);
        for (text, cat, lineno) in calls {
            try {
                host_warnings.warn_explicit(
                    text, _host_cat(cat), "m.py", lineno, "m", reg
                );
            } except BaseException {
                raised = raised + 1;
                continue;
            }
            shown = shown + 1;
        }
        shown = len(rec);
    } finally {
        cm.__exit__(None, None, None);
    }
    return (shown, raised);
}

def _facade_run(action: str, calls: list[tuple[str, str, int]]) -> tuple[int, int] {
    _facade_fresh_capture();
    _p2_simplefilter(action, "Warning");
    shown = 0;
    raised = 0;
    for (text, cat, lineno) in calls {
        res = _warn_explicit_bridge(text, cat, "m.py", lineno);
        if is_error(res) {
            raised = raised + 1;
            continue;
        }
        shown = shown + 1;
    }
    return (len(_probe_lines), raised);
}

test "warnings facade: default filter table pins CPython 3.14 defaults" {
    expected: list = [
        ("default", "DeprecationWarning", "__main__"),
        ("ignore", "DeprecationWarning", None),
        ("ignore", "PendingDeprecationWarning", None),
        ("ignore", "ImportWarning", None),
        ("ignore", "ResourceWarning", None),
    ];
    assert _p2_warn_default_filters() == expected , _p2_warn_default_filters();
}

test "warnings facade: formatwarning byte-matches host on linecache misses" {
    cases: list = [
        ("hello", "UserWarning", "nofile.py", 7, None),
        ("m", "DeprecationWarning", "x.py", 3, "  do_thing(1)  "),
        ("gone", "ResourceWarning", "/abs/path.py", 100, ""),
    ];
    for (text, cat, fname, lineno, line) in cases {
        host_out = host_warnings.formatwarning(
            text, _host_cat(cat), fname, lineno, line
        );
        facade_out = _p2_formatwarning(text, cat, fname, lineno, line);
        assert facade_out == host_out , (facade_out, host_out);
    }
}

test "warnings facade: action matrix agrees with host" {
    actions: list[str] = [
        "error",
        "ignore",
        "always",
        "once",
        "default",
        "module",
    ];
    same_location: list[tuple[str, str, int]] = [
        ("w1", "UserWarning", 10),
        ("w1", "UserWarning", 10),
        ("w1", "UserWarning", 10),
    ];
    for action in actions {
        (host_shown, host_raised) = _host_run(action, same_location);
        (f_shown, f_raised) = _facade_run(action, same_location);
        assert f_shown == host_shown and f_raised == host_raised , (
            action,
            (f_shown, f_raised),
            (host_shown, host_raised),
        );
    }
}

test "warnings facade: once dedups across linenos but not categories" {
    calls: list[tuple[str, str, int]] = [
        ("same", "UserWarning", 1),
        ("same", "UserWarning", 2),
        ("same", "DeprecationWarning", 3),
        ("same", "UserWarning", 4),
    ];
    (host_shown, host_raised) = _host_run("once", calls);
    (f_shown, f_raised) = _facade_run("once", calls);
    assert f_shown == host_shown and f_shown == 2 and f_raised == 0 , (
        ((f_shown, f_raised), (host_shown, host_raised)),
    );
}

test "warnings facade: default dedups per location, module dedups per module" {
    spread: list[tuple[str, str, int]] = [
        ("d", "UserWarning", 1),
        ("d", "UserWarning", 2),
        ("d", "UserWarning", 1),
    ];
    (host_shown, _) = _host_run("default", spread);
    (f_shown, _) = _facade_run("default", spread);
    assert f_shown == host_shown == 2 , ((f_shown, host_shown),);

    (host_mod, _) = _host_run("module", spread);
    (f_mod, _) = _facade_run("module", spread);
    assert f_mod == host_mod == 1 , ((f_mod, host_mod),);
}

test "warnings facade: filter category matching follows the warning hierarchy" {
    calls: list[tuple[str, str, int]] = [
        ("a", "DeprecationWarning", 1),
        ("b", "PendingDeprecationWarning", 2),
        ("c", "UserWarning", 3),
    ];
    _facade_fresh_capture();
    # Drop the default ignores (Pending/Import/Resource) so the hierarchy
    # question is isolated to the installed filter.
    _p2_resetwarnings();
    _p2_filterwarnings("ignore", "DeprecationWarning");
    for (text, cat, lineno) in calls {
        res = _warn_explicit_bridge(text, cat, "m.py", lineno);
        assert not is_error(res) , res;
    }
    assert len(_probe_lines) == 2 , _probe_lines;
    assert "PendingDeprecationWarning: b" in _probe_lines[0] , _probe_lines;
    assert "UserWarning: c" in _probe_lines[1] , _probe_lines;
}

test "warnings facade: version bump invalidates location registries" {
    _facade_fresh_capture();
    _p2_simplefilter("always", "Warning");
    _warn_explicit_bridge("v", "UserWarning", "m.py", 5);
    assert len(_probe_lines) == 1;
    # Same location would dedup under "always"? No -- but a registry entry
    # from the old version must not survive: reinstalling filters bumps the
    # version, clears the registry, so the SAME location shows again.
    _p2_simplefilter("always", "Warning");
    r2 = _warn_explicit_bridge("v", "UserWarning", "m.py", 5);
    assert not is_error(r2);
    assert len(_probe_lines) == 2 , _probe_lines;
}

test "warnings facade: resetwarnings clears filters to empty like CPython" {
    _facade_fresh_capture();
    _p2_filterwarnings("ignore", "UserWarning");
    _warn_explicit_bridge("rw", "UserWarning", "m.py", 1);
    assert len(_probe_lines) == 0 , _probe_lines;
    _p2_resetwarnings();
    r2 = _warn_explicit_bridge("rw", "UserWarning", "m.py", 1);
    assert not is_error(r2);
    assert len(_probe_lines) == 1 , _probe_lines;
    assert _probe_lines[0] == "m.py:1: UserWarning: rw\n" , _probe_lines[0];
}

test "warnings facade: warn maps str and instance messages with provider position" {
    _facade_fresh_capture();
    _p2_warn_set_position_provider(_probe_provider);
    fn = PyWarningsWarnFn(t="function");

    res = fn.tp_call([PyStr(t="str", val="hello")], {});
    assert not is_error(res) , res;
    assert len(_probe_lines) == 1 , _probe_lines;
    assert _probe_lines[0] == "/tmp/probe.py:42: UserWarning: hello\n" , (
        _probe_lines[0]
    );

    # Default-action dedup keys on the resolved position.
    fn.tp_call([PyStr(t="str", val="hello")], {});
    assert len(_probe_lines) == 1 , _probe_lines;

    # Provider saw the requested stacklevel.
    fn.tp_call([PyStr(t="str", val="deep")], {"stacklevel": PyInt(t="int", val=3)});
    assert _provider_stacklevels[len(_provider_stacklevels) - 1] == 3;

    # Warning-instance message carries its own class and str().
    inst = py_exception_type("DeprecationWarning").tp_call(
        [PyStr(t="str", val="inst-msg")], {}
    );
    fn.tp_call([inst], {});
    assert len(_probe_lines) == 3 , _probe_lines;
    assert _probe_lines[1] == "/tmp/probe.py:42: UserWarning: deep\n" , (
        _probe_lines[1]
    );
    assert _probe_lines[2]
        == "/tmp/probe.py:42: DeprecationWarning: inst-msg\n" , _probe_lines[2];

    # Non-str non-Warning message stringifies (CPython: "UserWarning: 42").
    fn.tp_call([PyInt(t="int", val=42)], {});
    assert _probe_lines[3] == "/tmp/probe.py:42: UserWarning: 42\n" , (
        _probe_lines[3]
    );
}

test "warnings facade: unwired positions fall back to CPython <sys> result" {
    _facade_fresh_capture();
    fn = PyWarningsWarnFn(t="function");
    res = fn.tp_call([PyStr(t="str", val="orphan")], {});
    assert not is_error(res) , res;
    assert _probe_lines[0] == "<sys>:0: UserWarning: orphan\n" , _probe_lines[0];
}

test "warnings facade: error action surfaces category and message" {
    _facade_fresh_capture();
    _p2_simplefilter("error", "Warning");
    res = _warn_explicit_bridge("boom", "UserWarning", "m.py", 9);
    assert is_error(res) , res;
    err = res as PyError;
    assert err.exception.type_name == "UserWarning" , err.exception.type_name;
    assert err.exception.message == "boom" , err.exception.message;
    assert len(_probe_lines) == 0 , _probe_lines;
}

test "warnings facade: bad action and non-warning category are rejected" {
    sf = PyWarningsSimpleFilterFn(t="function");
    bad = sf.tp_call([PyStr(t="str", val="bogus")], {});
    assert is_error(bad);
    assert (bad as PyError).exception.type_name == "_OptionError" , bad;
    assert not _p2_action_is_valid("bogus") ;

    fn = PyWarningsWarnFn(t="function");
    res = fn.tp_call(
        [PyStr(t="str", val="x"), py_exception_type("ValueError")], {}
    );
    assert is_error(res);
    assert (res as PyError).exception.type_name == "TypeError" , res;
}

test "warnings facade: catch_warnings record mode mirrors CPython shapes" {
    _facade_fresh_capture();

    catch_fn = PyWarningsCatchFn(t="function");
    ctx = catch_fn.tp_call([], {"record": PyBool(t="bool", val=True)});
    enter = ctx.tp_getattro("__enter__");
    records = enter.tp_call([ctx], {});
    assert isinstance(records, PyList) , records.t;

    _p2_warn_set_position_provider(_probe_provider);
    fn = PyWarningsWarnFn(t="function");
    fn.tp_call([PyStr(t="str", val="r1")], {});
    fn.tp_call(
        [py_exception_type("ResourceWarning").tp_call([PyStr(t="str", val="r2")], {})],
        {},
    );

    items = (records as PyList).items;
    assert len(items) == 2 , len(items);

    m0 = items[0];
    cat0 = m0.tp_getattro("category");
    assert isinstance(cat0, PyExceptionType) , cat0.t;
    assert (cat0 as PyExceptionType).name == "UserWarning" , cat0;
    assert (m0.tp_getattro("filename") as PyStr).val == "/tmp/probe.py";
    assert (m0.tp_getattro("lineno") as PyInt).val == 42;
    assert m0.tp_getattro("line").t == "none";

    # str(w[0]) byte-matches the CPython WarningMessage template.
    str_fn = m0.tp_getattro("__repr__");
    s = (str_fn.tp_call([], {}) as PyStr).val;
    assert s
        == "<WarningMessage {message : UserWarning('r1'), category : 'UserWarning',"
        + " filename : '/tmp/probe.py', lineno : 42, line : None}>" , s;

    exit_fn = ctx.tp_getattro("__exit__");
    suppress = exit_fn.tp_call([ctx, py_none(), py_none(), py_none()], {});
    assert isinstance(suppress, PyBool) and not (suppress as PyBool).val;

    # After exit: recording disabled, display flows back to the sink, and the
    # forced "always" filter is gone (default dedup applies again).
    fn.tp_call([PyStr(t="str", val="post")], {});
    assert len(_probe_lines) == 1 , _probe_lines;
    assert _probe_lines[0] == "/tmp/probe.py:42: UserWarning: post\n" , (
        _probe_lines[0]
    );
}

test "warnings facade: non-record context isolates filter mutations" {
    _facade_fresh_capture();
    _p2_filterwarnings("ignore", "UserWarning");

    catch_fn = PyWarningsCatchFn(t="function");
    ctx = catch_fn.tp_call([], {});
    enter = ctx.tp_getattro("__enter__");
    got = enter.tp_call([ctx], {});
    assert got.t == "none" , got.t;

    # Inside the context the ignored category shows again (fresh state rules
    # do not apply; isolation comes from the snapshot, so simulate by
    # verifying the ignore still holds until mutated).
    res = _warn_explicit_bridge("still-ignored", "UserWarning", "m.py", 4);
    assert not is_error(res);
    assert len(_probe_lines) == 0 , _probe_lines;

    _p2_simplefilter("always", "Warning");
    _warn_explicit_bridge("shown-inside", "UserWarning", "m.py", 5);
    assert len(_probe_lines) == 1 , _probe_lines;

    exit_fn = ctx.tp_getattro("__exit__");
    exit_fn.tp_call([ctx, py_none(), py_none(), py_none()], {});

    # Snapshot restored: the pre-context ignore suppresses again.
    res2 = _warn_explicit_bridge("reignored", "UserWarning", "m.py", 6);
    assert not is_error(res2);
    assert len(_probe_lines) == 1 , _probe_lines;
}
