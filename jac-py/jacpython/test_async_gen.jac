# Async-generator runtime pins (audit items 1 + 4).
#
# Calling an async-generator function builds a LAZY PyGenerator tagged
# "async_generator" (CO_ASYNC_GENERATOR); its frame only advances through the
# __anext__/asend/athrow/aclose awaitables, which the SEND loop drives exactly
# like native coroutines. CALL_INTRINSIC_1 arg 4 wraps every yield in an
# opaque PyAsyncGenWrappedValue that the drivers unwrap. Every rule below was
# probed side-by-side against CPython 3.14 before pinning.
#
# Idiom: host_compile_marshal -> unmarshal -> exec_code runs each snippet on
# ceval. Success cases drive a coroutine manually and return a
# (label, detail) string pair through `res`; error cases surface as the
# exec_code error object and are pinned via type_name/message.

import from host_oracle { host_compile_marshal }
import from pyc_first { exec_code, unmarshal }
import from objects { PyObj, PyStr, PyTuple, PyError, PyException, is_error }

# Eval/exec `src` on ceval; fails the test if the snippet raises.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<async_gen>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

# Eval/exec `src` and return the raw outcome so a test can pin the raised
# exception itself.
def vm_try(src: str) -> PyObj {
    return exec_code(
        unmarshal(host_compile_marshal(src, "<async_gen>", "exec")),
        [],
        {"__name__": PyStr(t="str", val="__main__")}
    );
}

def err_type(outcome: PyObj) -> str {
    assert isinstance(outcome, PyError);
    return ((outcome as PyError).exception as PyException).type_name;
}

def err_msg(outcome: PyObj) -> str {
    assert isinstance(outcome, PyError);
    return ((outcome as PyError).exception as PyException).message;
}

# Wrap `body` (the indented inside of `async def main():`) in the manual
# coroutine-drive harness; the body's return value lands in global `ret`.
def drive_src(body: list[str]) -> str {
    lines: list[str] = ["async def main():"];
    for line in body {
        lines.append("    " + line);
    }
    # Drive: resume with None until StopIteration carries the return value.
    lines.append("c = main()");
    lines.append("ret = None");
    lines.append("try:");
    lines.append("    while True:");
    lines.append("        c.send(None)");
    lines.append("except StopIteration as e:");
    lines.append("    ret = e.value");
    out: list[str] = [];
    for line in lines {
        out.append(line + "\n");
    }
    return "".join(out);
}

# The `(label, detail)` string pair a driven case leaves in global `ret`.
def case_result(ns: dict[str, PyObj]) -> tuple[str, str] {
    pair = ns["ret"];
    assert isinstance(pair, PyTuple);
    items = (pair as PyTuple).items;
    assert len(items) == 2;
    return ((items[0] as PyStr).val, (items[1] as PyStr).val);
}

test "agen: calling builds a lazy async_generator; async-for drains it" {
    ns = vm_exec(drive_src([
        "async def agen():",
        "    yield 1",
        "    yield 2",
        "out = []",
        "async for x in agen():",
        "    out.append(x)",
        "g = agen()",
        "return (type(g).__name__, ','.join(str(x) for x in out))",
    ]));
    (label, detail) = case_result(ns);
    assert label == "async_generator";
    assert detail == "1,2";
}

test "agen: asend resumes with values and exhaustion raises StopAsyncIteration" {
    ns = vm_exec(drive_src([
        "async def agen():",
        "    yield 1",
        "    yield 2",
        "g = agen()",
        "first = await g.asend(None)",
        "second = await g.asend(5)",
        "try:",
        "    await g.__anext__()",
        "    raise AssertionError('no StopAsyncIteration')",
        "except StopAsyncIteration:",
        "    return ('asend', str(first) + ',' + str(second))",
    ]));
    (label, detail) = case_result(ns);
    assert label == "asend";
    assert detail == "1,2";
}

test "agen: asend non-None on a just-started generator is a TypeError" {
    outcome = vm_try(drive_src([
        "async def agen():",
        "    yield 1",
        "g = agen()",
        "await g.asend(5)",
    ]));
    assert err_type(outcome) == "TypeError";
    assert err_msg(outcome) == "can't send non-None value to a just-started async generator";
}

test "agen: athrow caught-and-returned raises StopAsyncIteration" {
    ns = vm_exec(drive_src([
        "async def agen():",
        "    try:",
        "        yield 1",
        "    except ValueError:",
        "        return",
        "g = agen()",
        "await g.__anext__()",
        "try:",
        "    await g.athrow(ValueError())",
        "    raise AssertionError('no StopAsyncIteration')",
        "except StopAsyncIteration:",
        "    return ('athrow-return', 'StopAsyncIteration')",
    ]));
    (label, detail) = case_result(ns);
    assert label == "athrow-return";
    assert detail == "StopAsyncIteration";
}

test "agen: athrow caught-and-yielded surfaces the next yield" {
    ns = vm_exec(drive_src([
        "async def agen():",
        "    try:",
        "        yield 1",
        "    except ValueError:",
        "        yield 7",
        "g = agen()",
        "await g.__anext__()",
        "v = await g.athrow(ValueError())",
        "return ('athrow-yield', str(v))",
    ]));
    (label, detail) = case_result(ns);
    assert label == "athrow-yield";
    assert detail == "7";
}

test "agen: athrow into an exhausted generator completes silently (3.14)" {
    ns = vm_exec(drive_src([
        "async def agen():",
        "    yield 1",
        "g = agen()",
        "await g.asend(None)",
        "try:",
        "    await g.asend(None)",
        "except StopAsyncIteration:",
        "    pass",
        "r = await g.athrow(ValueError())",
        "return ('silent', repr(r))",
    ]));
    (label, detail) = case_result(ns);
    assert label == "silent";
    assert detail == "None";
}

test "agen: aclose runs finally handlers and is idempotent" {
    ns = vm_exec(drive_src([
        "ran = []",
        "async def agen():",
        "    try:",
        "        yield 1",
        "        yield 2",
        "    finally:",
        "        ran.append('cleanup')",
        "g = agen()",
        "first = await g.__anext__()",
        "c1 = await g.aclose()",
        "c2 = await g.aclose()",
        "return ('aclose', str(first) + '|' + repr(c1) + '|' + repr(c2) + '|' + ','.join(ran))",
    ]));
    (label, detail) = case_result(ns);
    assert label == "aclose";
    assert detail == "1|None|None|cleanup";
}

test "agen: yielding after GeneratorExit during aclose is a RuntimeError" {
    outcome = vm_try(drive_src([
        "async def agen():",
        "    try:",
        "        yield 1",
        "    except GeneratorExit:",
        "        yield 2",
        "g = agen()",
        "await g.__anext__()",
        "await g.aclose()",
    ]));
    assert err_type(outcome) == "RuntimeError";
    assert err_msg(outcome) == "async generator ignored GeneratorExit";
}

test "agen: nested async generators compose through async-for" {
    ns = vm_exec(drive_src([
        "async def inner():",
        "    yield 'i1'",
        "    yield 'i2'",
        "async def outer():",
        "    async for x in inner():",
        "        yield x",
        "acc = []",
        "async for x in outer():",
        "    acc.append(x)",
        "return ('nested', ','.join(acc))",
    ]));
    (label, detail) = case_result(ns);
    assert label == "nested";
    assert detail == "i1,i2";
}

test "agen: await inside an async generator delegates via SEND" {
    ns = vm_exec(drive_src([
        "async def helper():",
        "    return 'h'",
        "async def agen():",
        "    r = await helper()",
        "    yield r",
        "acc = []",
        "async for x in agen():",
        "    acc.append(x)",
        "return ('await-in-gen', ','.join(acc))",
    ]));
    (label, detail) = case_result(ns);
    assert label == "await-in-gen";
    assert detail == "h";
}

test "agen: sync iteration surface is absent (next / for / await)" {
    outcome = vm_try(drive_src([
        "async def agen():",
        "    yield 1",
        "g = agen()",
        "next(g)",
    ]));
    assert err_type(outcome) == "TypeError";

    outcome = vm_try(drive_src([
        "async def agen():",
        "    yield 1",
        "g = agen()",
        "for x in g:",
        "    pass",
    ]));
    assert err_type(outcome) == "TypeError";
    assert err_msg(outcome) == "'async_generator' object is not iterable";

    outcome = vm_try(drive_src([
        "async def agen():",
        "    yield 1",
        "g = agen()",
        "await g",
    ]));
    assert err_type(outcome) == "TypeError";
    assert err_msg(outcome) == "object async_generator can't be used in 'await' expression";
}

test "agen: StopAsyncIteration escaping the body becomes RuntimeError (PEP 479)" {
    outcome = vm_try(drive_src([
        "async def agen():",
        "    raise StopAsyncIteration",
        "    yield 1",
        "g = agen()",
        "await g.__anext__()",
    ]));
    assert err_type(outcome) == "RuntimeError";
    assert err_msg(outcome) == "async generator raised StopAsyncIteration";
}

test "agen: fresh aclose closes without driving the frame" {
    ns = vm_exec(drive_src([
        "ran = []",
        "async def agen():",
        "    ran.append('driven')",
        "    yield 1",
        "g = agen()",
        "r = await g.aclose()",
        "try:",
        "    await g.__anext__()",
        "    raise AssertionError('no StopAsyncIteration after close')",
        "except StopAsyncIteration:",
        "    return ('fresh-close', repr(r) + '|' + ','.join(ran))",
    ]));
    (label, detail) = case_result(ns);
    assert label == "fresh-close";
    assert detail == "None|";
}

test "agen: ag_running mirrors gi_running; ag_frame.clear exhausts" {
    ns = vm_exec(drive_src([
        "async def agen():",
        "    yield 1",
        "g = agen()",
        "before = g.ag_running",
        "has_frame = hasattr(g, 'ag_frame')",
        "await g.__anext__()",
        "after = g.ag_running",
        "g.ag_frame.clear()",
        "try:",
        "    await g.asend(None)",
        "    raise AssertionError('no StopAsyncIteration after clear')",
        "except StopAsyncIteration:",
        "    pass",
        "return ('surface', str(before) + '|' + str(has_frame) + '|' + str(after) + '|cleared')",
    ]));
    (label, detail) = case_result(ns);
    assert label == "surface";
    assert detail == "False|True|False|cleared";
}
