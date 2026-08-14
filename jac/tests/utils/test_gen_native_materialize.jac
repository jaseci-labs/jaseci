"""Pins what the seal-time materializer generator may and may not emit.

`jaclang/compiler/native_materialize.jac` is generated inside the seal and is
gitignored, so no scoped `jac check` on a pull request ever compiles it -- only
the full seal in `build-jac` does. That is how a generator emitting a call it
could not type-check reached `main` green and turned the seal red on every
platform leg.

These tests exercise the emitters directly, with no native compile, so the
shape of the generated crossing is gated at PR speed instead of at seal time.

The load-bearing case is a `dict` whose key is not one of `_SCALARS`. Only a
scalar key has a CPython constructor the crossing can call; a `type` key does
not, because the native side holds a class-name pointer rather than a Python
class object. The emitter used to fall back to `PyLong_FromLongLong` on any
non-scalar key, which fabricated a Python int out of whatever the key was. A
shape the crossing cannot carry faithfully must come across as `None` -- the
same answer a dead or foreign field gets -- and never as a fabricated value.
"""

import jaclang.utils.gen_native_materialize as gm;


test "a dict keyed by a non-scalar crosses as None, not a fabricated int" {
    g = gm._MatGen();
    out: list[str] = [];
    g.emit_value(
        "nd.__sub_node_tab", "dict[type, list[UniNode]] | None", out, "    ", "0"
    );
    body = "\n".join(out);
    assert "PyLong_FromLongLong" not in body;
    assert "PyDict_New" not in body;
    assert "_py_none()" in body;
}


test "the dropped shape is recorded rather than emitted silently" {
    g = gm._MatGen();
    out: list[str] = [];
    g.emit_value("nd.tab", "dict[type, list[UniNode]]", out, "    ", "0");
    assert any(["unmaterializable dict key" in w for w in g.warnings]);
}


test "a scalar-keyed dict still carries both key and value" {
    g = gm._MatGen();
    out: list[str] = [];
    g.emit_value("nd.tab", "dict[str, int]", out, "    ", "0");
    body = "\n".join(out);
    assert "PyDict_New()" in body;
    assert "_py_str(dk_0d)" in body;
    assert "PyLong_FromLongLong(dv_0d)" in body;
}


test "an int-keyed dict still mints its key through PyLong_FromLongLong" {
    g = gm._MatGen();
    out: list[str] = [];
    g.emit_value("nd.tab", "dict[int, str]", out, "    ", "0");
    body = "\n".join(out);
    assert "PyLong_FromLongLong(dk_0d)" in body;
    assert "_py_str(dv_0d)" in body;
}
