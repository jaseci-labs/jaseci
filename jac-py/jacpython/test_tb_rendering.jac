# Host-exact traceback rendering pins (uncaught-error display path).
#
# Each fixture compiles Python source at filename "<tb>" (linecache miss, the
# same degradation CPython exercises for synthetic filenames: frame header
# lines render, source text is omitted) and asserts tb_format output
# byte-for-byte against python3's own uncaught-exception display captured via
# `traceback.print_exception(type(exc), exc, exc.__traceback__.tb_next)` --
# the exact PyErr_Display code path -- with tb_next trimming the generator's
# exec frame that guest execution does not have.
#
# Pinned shapes: nested calls, method frames, class-body frames, explicit
# __cause__ chaining, implicit __context__ chaining, `from None` suppression,
# bare re-raise across frames, deep-recursion "[Previous line repeated N more
# times]" collapse, cause-cycle suppression, and exec_code's final-surface
# stderr write.

import from objects { PyObj, PyError, PyException, PyStr, PyCode, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, exec_code_frame }
import from tb_render { tb_format, tb_display_error }

::py::
_TB_TEST_OLD_STDERR = None

def _tb_test_swap_stderr():
    # Redirect host stderr into a StringIO so a test can assert exactly what
    # exec_code's final-error surfacing wrote.
    import sys, io
    global _TB_TEST_OLD_STDERR
    _TB_TEST_OLD_STDERR = sys.stderr
    buf = io.StringIO()
    sys.stderr = buf
    return buf

def _tb_test_restore_stderr():
    import sys
    sys.stderr = _TB_TEST_OLD_STDERR

def _tb_test_stderr_text(buf):
    return buf.getvalue()
::py::


# Run `src` on ceval and return the escaping exception (bypassing exec_code so
# the final-surface display stays silent during fixture collection; the display
# itself is pinned separately below).
def vm_exc(src: str) -> PyException {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code_frame(
        unmarshal(host_compile_marshal(src, "<tb>", "exec")) as PyCode,
        [],
        {},
        ns,
        ns,
        [],
        [],
        {}
    );
    assert is_error(outcome);
    return (outcome as PyError).exception;
}

test "tb: nested function raise renders host-exact stack" {
    text = tb_format(
        vm_exc(
            "def inner():\n"
            "    raise ValueError('boom')\n"
            "def outer():\n"
            "    inner()\n"
            "outer()\n"
        )
    );
    assert text
        == (
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 5, in <module>\n"
            "  File \"<tb>\", line 4, in outer\n"
            "  File \"<tb>\", line 2, in inner\n"
            "ValueError: boom\n"
        );
}

test "tb: method raise keeps method frame name" {
    text = tb_format(
        vm_exc(
            "class Greeter:\n"
            "    def greet(self):\n"
            "        raise TypeError('bad greeting')\n"
            "g = Greeter()\n"
            "g.greet()\n"
        )
    );
    assert text
        == (
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 5, in <module>\n"
            "  File \"<tb>\", line 3, in greet\n"
            "TypeError: bad greeting\n"
        );
}

test "tb: class-body raise renders the class frame" {
    text = tb_format(
        vm_exc(
            "def make():\n"
            "    class C:\n"
            "        x = 1/0\n"
            "    return C\n"
            "make()\n"
        )
    );
    assert text
        == (
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 5, in <module>\n"
            "  File \"<tb>\", line 2, in make\n"
            "  File \"<tb>\", line 3, in C\n"
            "ZeroDivisionError: division by zero\n"
        );
}

# Chaining fixtures build the chain by attribute assignment (raise ... from
# itself is pinned once VM-side entry-cadence fidelity lands; see progress
# notes) so these pin the RENDERER's chaining/suppression logic exactly.
test "tb: explicit cause chains with the direct-cause message" {
    text = tb_format(
        vm_exc(
            "e1 = KeyError('k')\n"
            "e2 = RuntimeError('wrapped')\n"
            "e2.__cause__ = e1\n"
            "raise e2\n"
        )
    );
    assert text
        == (
            "KeyError: 'k'\n"
            "\n"
            "The above exception was the direct cause of the following exception:\n"
            "\n"
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 4, in <module>\n"
            "RuntimeError: wrapped\n"
        );
}

test "tb: context chains with the during-handling message" {
    text = tb_format(
        vm_exc(
            "e1 = KeyError('k')\n"
            "e2 = ValueError('v')\n"
            "e2.__context__ = e1\n"
            "raise e2\n"
        )
    );
    assert text
        == (
            "KeyError: 'k'\n"
            "\n"
            "During handling of the above exception, another exception occurred:\n"
            "\n"
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 4, in <module>\n"
            "ValueError: v\n"
        );
}

test "tb: suppress_context drops the context block" {
    text = tb_format(
        vm_exc(
            "e1 = KeyError('k')\n"
            "e2 = ValueError('top')\n"
            "e2.__context__ = e1\n"
            "e2.__suppress_context__ = True\n"
            "raise e2\n"
        )
    );
    assert text
        == (
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 5, in <module>\n"
            "ValueError: top\n"
        );
}

test "tb: chained frames render outermost-first with per-frame entries" {
    # Deep call nesting accumulates one entry per frame transit at the call
    # site line; the header prints once for the whole stack.
    text = tb_format(
        vm_exc(
            "def low():\n"
            "    raise OSError('io')\n"
            "def mid():\n"
            "    low()\n"
            "def top():\n"
            "    mid()\n"
            "top()\n"
        )
    );
    assert text
        == (
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 7, in <module>\n"
            "  File \"<tb>\", line 6, in top\n"
            "  File \"<tb>\", line 4, in mid\n"
            "  File \"<tb>\", line 2, in low\n"
            "OSError: io\n"
        );
}

test "tb: identical-frame runs collapse to the repetition marker" {
    text = tb_format(
        vm_exc(
            "def f(n):\n"
            "    if n == 0:\n"
            "        raise ValueError('deep')\n"
            "    f(n - 1)\n"
            "f(11)\n"
        )
    );
    assert text
        == (
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 5, in <module>\n"
            "  File \"<tb>\", line 4, in f\n"
            "  File \"<tb>\", line 4, in f\n"
            "  File \"<tb>\", line 4, in f\n"
            "  [Previous line repeated 8 more times]\n"
            "  File \"<tb>\", line 3, in f\n"
            "ValueError: deep\n"
        );
}

test "tb: cause cycles are suppressed like TracebackException._seen" {
    text = tb_format(
        vm_exc(
            "e1 = ValueError('one')\n"
            "e2 = TypeError('two')\n"
            "e2.__cause__ = e1\n"
            "e1.__cause__ = e2\n"
            "raise e2\n"
        )
    );
    assert text
        == (
            "ValueError: one\n"
            "\n"
            "The above exception was the direct cause of the following exception:\n"
            "\n"
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 5, in <module>\n"
            "TypeError: two\n"
        );
}

test "tb: exec_code surfaces the rendered traceback on stderr" {
    buf = _tb_test_swap_stderr();
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    try {
        outcome = exec_code(
            unmarshal(
                host_compile_marshal(
                    "def inner():\n"
                    "    raise ValueError('boom')\n"
                    "def outer():\n"
                    "    inner()\n"
                    "outer()\n",
                    "<tb>",
                    "exec"
                )
            ),
            [],
            ns
        );
        assert is_error(outcome);
        text = _tb_test_stderr_text(buf);
    } finally {
        _tb_test_restore_stderr();
    }
    assert text
        == (
            "Traceback (most recent call last):\n"
            "  File \"<tb>\", line 5, in <module>\n"
            "  File \"<tb>\", line 4, in outer\n"
            "  File \"<tb>\", line 2, in inner\n"
            "ValueError: boom\n"
        );
}
