# EXEC builtin namespace-population pins (lane fix/exec-ns-population).
#
# Surface under test: ceval's native exec() builtin (bltinmodule.c
# builtin_exec_impl). Executing a code object must bind its top-level names
# (def/class/assignment) into the LIVE namespace dict passed to exec --
# CPython routes module-level MAKE_FUNCTION + STORE_NAME through the frame's
# f_locals/f_globals.
#
# Ground truth recorded from host python3.14.7:
#   - exec(code, ns) leaves 'name' bound in ns for every top-level binding
#   - exec returns None
#   - re-exec over an occupied name overwrites (last wins)
#   - exec(code, g, l) binds into l; module-level LOAD_GLOBAL still reads g
#   - bare exec(code) at module top level binds into the module globals

import from objects {
    PyObj,
    PyCode,
    PyError,
    PyStr,
    is_error,
}
import from product_compile { compile_source }
import from pyc_first { exec_code }


def product_exec(source: str, filename: str = "<execns>") -> PyObj {
    return compile_source(source, filename, "exec", 0);
}

# Compile + run `source` as a module on ceval; returns the outcome error or
# None-shaped success sentinel.
def run_module(source: str) -> PyObj {
    comp = product_exec(source);
    assert not is_error(comp), f"compile failed: {(comp as PyError).exception.message}";
    return exec_code(comp as PyCode, [], {"__name__": PyStr(t="str", val="__main__")});
}

def fail_msg(outcome: PyObj) -> str {
    return (outcome as PyError).exception.message;
}

test "execns: exec def binds function into fresh dict" {
    outcome = run_module(
        "ns = {}\n"
        "code = compile('def unpack_400():\\n    return 400\\n', '<s>', 'exec')\n"
        "ret = exec(code, ns)\n"
        "assert ret == None, f'exec returned {ret!r}'\n"
        "assert 'unpack_400' in ns, 'def not bound into ns'\n"
        "assert ns['unpack_400']() == 400, 'exec-defined fn broken'\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "execns: exec class and assignment bind into fresh dict" {
    outcome = run_module(
        "ns = {}\n"
        "src = 'class Spam:\\n    x = 1\\nY = [2]\\nZ = 3\\n'\n"
        "exec(compile(src, '<s>', 'exec'), ns)\n"
        "assert 'Spam' in ns and 'Y' in ns and 'Z' in ns\n"
        "assert ns['Spam'].x == 1 and ns['Y'] == [2] and ns['Z'] == 3\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "execns: exec overwrite collides last-wins" {
    outcome = run_module(
        "ns = {'v': 'old'}\n"
        "exec(compile('v = \"new\"\\n', '<s>', 'exec'), ns)\n"
        "assert ns['v'] == 'new', 'collision did not overwrite'\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "execns: exec with separate locals binds there not globals" {
    outcome = run_module(
        "g = {'base': 10}\n"
        "loc: dict = {}\n"
        "exec(compile('w = base + 5\\n', '<s>', 'exec'), g, loc)\n"
        "assert loc.get('w') == 15, f'locals missing w: {loc!r}'\n"
        "leak = [k for k in g if k == 'w']\n"
        "assert len(leak) == 0, 'w leaked into globals'\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "execns: bare exec at module level binds into module globals" {
    outcome = run_module(
        "code = compile('def made_by_exec():\\n    return 7\\n', '<s>', 'exec')\n"
        "exec(code)\n"
        "assert made_by_exec() == 7, 'bare exec did not bind module global'\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "execns: exec raises through and ns stays partially live" {
    # The executed code's bindings before the raise are already visible to the
    # caller -- STORE_NAME writes are not transactional (matches CPython).
    outcome = run_module(
        "ns = {}\n"
        "src = 'a = 1\\nraise ValueError(\"x\")\\nb = 2\\n'\n"
        "caught = False\n"
        "try:\n"
        "    exec(compile(src, '<s>', 'exec'), ns)\n"
        "except ValueError:\n"
        "    caught = True\n"
        "assert caught, 'exec error did not propagate'\n"
        "assert ns.get('a') == 1, 'binding before raise lost'\n"
        "late = [k for k in ns if k == 'b']\n"
        "assert len(late) == 0, 'binding after raise landed'\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}
