# VM-crash trio regression pins (fix/vm-crash-trio).
#
# Each pin replays a VM-CRASH class from the wp4/mech-overflow triage and
# asserts the CPython-oracle outcome (probed against python3.14):
#   1. '%'-modulo on a str SUBCLASS resolves the user __mod__ slot
#      (test_modulo_of_string_subclasses; crashed via the bug-3 NameError
#      firing inside the assert-report path).
#   2. Non-BMP identifiers are valid (PEP 3131): surrogate-pair \uXXXX escapes
#      in string literals combine to one astral code point (JSON escape
#      contract used by tools/convert_suite.py), and astral identifiers run.
#   3. host_exception's registry arm resolves registered_exc_base instead of
#      raising NameError when a native exception (whose args carry another
#      exception) converts to its host form at runtime.
import from layer_p2_libtest { p2_libtest_run_snippet }

def expect_ok(name: str, src: str) {
    (ok, detail) = p2_libtest_run_snippet(src);
    assert ok , name + " RUN<" + detail + ">";
    assert detail == "ok" , name + " GOT<" + detail + ">";
}

test "vm_crash_trio: str subclass __mod__ slot" {
    expect_ok(
        "modulo_subclass",
        "def _t():\n"
        "\n"
        "    class MyString(str):\n"
        "\n"
        "        def __mod__(self, value):\n"
        "            return 42\n"
        "    assert MyString() % 3 == 42\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "vm_crash_trio: surrogate pair escape combines to astral char" {
    expect_ok(
        "surrogate_pair_escape",
        "def _t():\n"
        "    s = '\udb40\udd00'\n"
        "    assert len(s) == 1, ('len', len(s))\n"
        "    assert ord(s) == 0xE0100, ('ord', hex(ord(s)))\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "vm_crash_trio: non-bmp identifier via escaped source" {
    expect_ok(
        "non_bmp_identifier",
        "def _t():\n"
        "\n"
        "    class T:\n"
        "        x󠄀 = 4\n"
        "    assert getattr(T, 'x󠄀') == 4\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "vm_crash_trio: exception args carrying exceptions convert to host" {
    # The exact shape that fired NameError: registered_exc_base -- DClass(a)
    # carries an exception instance inside args; type()/isinstance on it walks
    # host_exception -> _jac_instantiate_registered_exception.
    expect_ok(
        "exc_args_to_host",
        "def _t():\n"
        "\n"
        "    class AClass(Exception):\n"
        "        pass\n"
        "    a = AClass('inner')\n"
        "    try:\n"
        "        raise ValueError(a)\n"
        "    except ValueError as v:\n"
        "        assert type(v).__name__ == 'ValueError'\n"
        "        assert isinstance(v.args[0], AClass)\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}
