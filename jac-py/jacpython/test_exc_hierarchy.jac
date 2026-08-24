# Guest-visible builtin exception hierarchy: parity pins against CPython 3.14.
#
# Every rule below was probed side-by-side against CPython before pinning
# (construction semantics, per-type __str__ smart forms, name-hierarchy
# matching across native/host-proxied type shapes). The VM exposes builtin
# exceptions in two shapes -- native PyExceptionType markers and host-proxied
# classes -- so these pins deliberately mix both paths.
#
# Pins run as guest-side asserts: a wrong str form or field fails with the
# actual value carried in the AssertionError message (checked by err_msg).

import from objects { PyObj, PyStr, PyError, PyException, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

def _fresh_ns -> dict[str, PyObj] {
    return {"__name__": PyStr(t="str", val="__main__")};
}

def vm_try(src: str) -> PyObj {
    return exec_code(
        unmarshal(host_compile_marshal(src, "<exc_hierarchy>", "exec")),
        [],
        _fresh_ns()
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

# Eval `src` expecting clean completion.
def vm_ok(src: str) {
    outcome = vm_try(src);
    if is_error(outcome) {
        assert False, err_type(outcome) + ": " + err_msg(outcome);
    }
}

# Eval `src` expecting clean completion; a guest failure surfaces with its
# type + message (guest asserts carry the actual value in their message).
def vm_ok(src: str) {
    outcome = vm_try(src);
    assert not is_error(outcome), err_type(outcome) + ": " + err_msg(outcome);
}

test "hierarchy: every builtin exception name resolves" {
    names = [
        "BaseException", "Exception", "ArithmeticError", "FloatingPointError",
        "OverflowError", "ZeroDivisionError", "AssertionError", "AttributeError",
        "BufferError", "EOFError", "ExceptionGroup", "ImportError",
        "ModuleNotFoundError", "LookupError", "IndexError", "KeyError",
        "MemoryError", "NameError", "UnboundLocalError", "OSError",
        "BlockingIOError", "ChildProcessError", "ConnectionError",
        "BrokenPipeError", "ConnectionAbortedError", "ConnectionRefusedError",
        "ConnectionResetError", "FileExistsError", "FileNotFoundError",
        "InterruptedError", "IsADirectoryError", "NotADirectoryError",
        "PermissionError", "ProcessLookupError", "TimeoutError",
        "ReferenceError", "RuntimeError", "NotImplementedError",
        "RecursionError", "StopAsyncIteration", "StopIteration", "SyntaxError",
        "IndentationError", "TabError", "SystemError", "TypeError",
        "ValueError", "UnicodeError", "UnicodeDecodeError",
        "UnicodeEncodeError", "UnicodeTranslateError", "Warning",
        "BytesWarning", "DeprecationWarning", "EncodingWarning",
        "FutureWarning", "ImportWarning", "PendingDeprecationWarning",
        "ResourceWarning", "RuntimeWarning", "SyntaxWarning",
        "UnicodeWarning", "UserWarning", "GeneratorExit",
        "KeyboardInterrupt", "SystemExit",
    ];
    missing: list[str] = [];
    for n in names {
        if is_error(vm_try(n + "\n")) {
            missing.append(n);
        }
    }
    assert len(missing) == 0, "missing builtins: " + ", ".join(missing);
}

test "oserror: native 3-arg form sets errno/strerror/filename" {
    vm_ok(
        "e = OSError(2, 'No such file', 'f.py')\n"
        "assert e.errno == 2\n"
        "assert e.strerror == 'No such file'\n"
        "assert e.filename == 'f.py'\n"
        "assert e.filename2 is None\n"
        "assert e.args == (2, 'No such file')\n"
    );
}

test "oserror: 5-arg form ignores winerror off-Windows, keeps filename2" {
    vm_ok(
        "e = OSError(2, 'm', 'old', None, 'new')\n"
        "assert e.filename == 'old'\n"
        "assert e.filename2 == 'new'\n"
    );
}

test "oserror: single-int form keeps errno only" {
    vm_ok("e = OSError(5)\nassert e.args == (5,) and e.errno == 5\n");
}

test "oserror: subclass construction follows OSError semantics" {
    vm_ok(
        "e = FileNotFoundError(2, 'No such file or directory')\n"
        "assert e.errno == 2 and e.args == (2, 'No such file or directory')\n"
    );
}

test "str: oserror two-arg smart form is byte-exact" {
    vm_ok(
        "try:\n"
        "    raise OSError(2, 'No such file or directory')\n"
        "except OSError as e:\n"
        "    assert str(e) == '[Errno 2] No such file or directory', str(e)\n"
    );
}

test "str: oserror filename form appends repr'd path" {
    vm_ok(
        "try:\n"
        "    raise FileNotFoundError(2, 'No such file or directory', 'x')\n"
        "except OSError as e:\n"
        "    assert str(e) == \"[Errno 2] No such file or directory: 'x'\", str(e)\n"
    );
}

test "str: oserror two-file form joins old -> new" {
    vm_ok(
        "e = OSError(2, 'm', 'old', None, 'new')\n"
        "assert str(e) == \"[Errno 2] m: 'old' -> 'new'\", str(e)\n"
    );
}

test "str: host-raised os errors keep errno and smart form" {
    vm_ok(
        "try:\n"
        "    open('/nonexistent_dir_xyz/f')\n"
        "except FileNotFoundError as e:\n"
        "    assert e.errno == 2\n"
        "    assert str(e).startswith('[Errno 2]'), str(e)\n"
        "    assert 'nonexistent_dir_xyz' in str(e)\n"
    );
}

test "str: keyerror renders repr of the key" {
    vm_ok(
        "try:\n"
        "    raise KeyError('k')\n"
        "except KeyError as e:\n"
        "    assert str(e) == \"'k'\", str(e)\n"
        "try:\n"
        "    {}['k']\n"
        "except KeyError as e:\n"
        "    assert str(e) == \"'k'\", str(e)\n"
    );
}

test "str: syntaxerror appends location suffix" {
    vm_ok(
        "e = SyntaxError('bad', ('f.py', 3, 5, 'code\\n'))\n"
        "assert str(e) == 'bad (f.py, line 3)', str(e)\n"
        "assert e.msg == 'bad' and e.lineno == 3 and e.offset == 5\n"
        "assert e.text == 'code\\n'\n"
    );
}

test "str: unicode decode form is byte-exact" {
    vm_ok(
        "try:\n"
        "    raise UnicodeDecodeError('utf-8', b'a\\xffb', 1, 2,"
        " 'invalid start byte')\n"
        "except UnicodeDecodeError as e:\n"
        "    assert e.encoding == 'utf-8' and e.start == 1 and e.end == 2\n"
        "    assert str(e) == \"'utf-8' codec can't decode byte 0xff in position 1:"
        " invalid start byte\", str(e)\n"
    );
}

test "str: unicode encode form escapes the code point" {
    vm_ok(
        "try:\n"
        "    raise UnicodeEncodeError('ascii', 'a\\u20acb', 1, 2,"
        " 'ordinal not in range')\n"
        "except UnicodeEncodeError as e:\n"
        "    expected = (\"'ascii' codec can't encode character \" + chr(92) +\n"
        "        \"u20ac in position 1: ordinal not in range\")\n"
        "    assert str(e) == expected, str(e)\n"
    );
}

test "importerror: name/path kwargs become attributes, args stay clean" {
    vm_ok(
        "try:\n"
        "    raise ImportError('nope', name='json', path='/x')\n"
        "except ImportError as e:\n"
        "    assert e.name == 'json' and e.path == '/x'\n"
        "    assert e.args == ('nope',)\n"
    );
}

test "importerror: positional second arg binds to name" {
    vm_ok(
        "e = ImportError('m', 'json')\n"
        "assert e.name == 'json' and e.path is None\n"
        "assert e.args == ('m', 'json')\n"
    );
}

test "matching: subclasses catch through parent branches" {
    vm_ok(
        "try:\n    raise FileNotFoundError(2, 'x')\nexcept OSError as e:\n    pass\n"
        "try:\n    raise TabError('t')\nexcept SyntaxError:\n    pass\n"
        "try:\n    raise ModuleNotFoundError('m', name='z')\nexcept ImportError as e:\n"
        "    assert type(e).__name__ == 'ModuleNotFoundError'\n"
        "    assert e.name == 'z'\n"
    );
}

test "matching: baseexception catches what exception must not" {
    vm_ok(
        "try:\n    raise KeyboardInterrupt('k')\nexcept Exception:\n    got = False\n"
        "except BaseException:\n    got = True\n"
        "assert got\n"
    );
    vm_ok(
        "caught = False\n"
        "try:\n    raise GeneratorExit()\nexcept Exception:\n    caught = True\n"
        "except BaseException:\n    pass\n"
        "assert not caught\n"
    );
}

test "matching: tuple targets walk every branch" {
    vm_ok(
        "try:\n    raise TimeoutError('t')\nexcept (ValueError, OSError) as e:\n"
        "    assert type(e).__name__ == 'TimeoutError'\n"
    );
}

test "issubclass/isinstance: cross the native/proxy type split" {
    vm_ok(
        "assert issubclass(FileNotFoundError, OSError)\n"
        "assert issubclass(ZeroDivisionError, ArithmeticError)\n"
        "assert issubclass(Warning, Exception)\n"
        "assert issubclass(UnicodeDecodeError, ValueError)\n"
        "assert isinstance(UserWarning('w'), Warning)\n"
        "assert isinstance(KeyError('k'), LookupError)\n"
        "assert not issubclass(OSError, ValueError)\n"
    );
}

test "user subclass of a builtin matches its ancestor target" {
    vm_ok(
        "class MyErr(KeyError):\n    pass\n"
        "try:\n    raise MyErr('missing')\nexcept KeyError as e:\n"
        "    assert str(e) == \"'missing'\", str(e)\n"
    );
}

test "warnings: warning classes construct and match today" {
    vm_ok(
        "try:\n    raise UserWarning('w')\nexcept Warning as e:\n"
        "    assert type(e).__name__ == 'UserWarning'\n"
    );
}

test "repr: trimmed args keep host-exact forms" {
    vm_ok(
        "assert repr(FileNotFoundError(2, 'm', 'f')) == \"FileNotFoundError(2, 'm')\"\n"
        "assert repr(TypeError(1, 2)) == 'TypeError(1, 2)'\n"
    );
}

test "stopiteration: generator return value rides .value" {
    vm_ok(
        "def g():\n    yield 1\n    return 42\n"
        "it = g()\nnext(it)\n"
        "try:\n    next(it)\nexcept StopIteration as e:\n    assert e.value == 42\n"
    );
}
