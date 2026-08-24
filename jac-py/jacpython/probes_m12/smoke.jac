# M12 smoke: does guest print() reach stdout through exec_code?
import from host_oracle { host_compile_marshal }
import from pyc_first { exec_code, unmarshal }
import from objects { PyObj, PyStr, PyError, is_error }

::py::
SRC = '''
def walk(tag, exc):
    tb = exc.__traceback__
    n = 0
    while tb is not None:
        name = tb.tb_frame.f_code.co_name
        print("%s frame[%d]=%s line=%d" % (tag, n, name, tb.tb_lineno))
        tb = tb.tb_next
        n += 1

def drive(coro):
    try:
        fut = coro.send(None)
    except StopIteration as e:
        return e.value
    raise AssertionError("coroutine suspended on %r" % (fut,))

async def leaf():
    raise TypeError("smoke")

async def agen():
    await leaf()
    yield 0

a = agen()
try:
    drive(a.asend(None))
    print("SMOKE BUG")
except TypeError as e:
    print("SMOKE caught:", e)
    walk("SMOKE", e)
print("SMOKE done")
'''
::py::

with entry {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(SRC, "<m12-smoke>", "exec")), [], ns
    );
    if is_error(outcome) {
        exc = (outcome as PyError).exception;
        print("WRAPPER-ERROR:", exc.type_name, exc.message);
    }
}
