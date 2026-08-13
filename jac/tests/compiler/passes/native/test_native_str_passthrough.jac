"""str() pass-through keeps owned string payloads alive under native lowering.

Pins the #8109 use-after-free: NativeBuiltinEmitter.emit_str returned a bare
alias of its argument, the call machinery then released the owned argument
temp, and the enclosing expression read a freed buffer (empirically: every
join result wrapped in str() came back empty). The alias now retains, so
these round-trips must return real payloads.
"""

import ctypes;
import from tests.compiler.passes.native.test_native_bytes_struct {
    compile_native,
    get_sfunc
}

test "str() of an owned join result keeps its payload" {
    (eng, _ir) = compile_native("str_passthrough.jac");
    f = get_sfunc(eng, "join_ident", ctypes.c_char_p, ctypes.c_char_p);
    assert f("add_venv to path") == b"add_venv to path";
    assert f("abc") == b"abc";
}

test "len(str(join)) reads the stamped length, not a freed header" {
    (eng, _ir) = compile_native("str_passthrough.jac");
    f = get_sfunc(eng, "join_sep_len", ctypes.c_int64, ctypes.c_char_p);
    assert f("abc") == 5;
}

test "str() of an owned slice keeps its payload" {
    (eng, _ir) = compile_native("str_passthrough.jac");
    f = get_sfunc(eng, "str_of_owned_slice", ctypes.c_char_p, ctypes.c_char_p);
    assert f("xhello") == b"hello";
}
