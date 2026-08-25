"""Subscripting a class object consults its metaclass before generic specialization.
A class is an instance of its metaclass, so `Foo[x]` runs `type(Foo).__getitem__`.
"""

import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="metasub.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "an enum member is reachable by name" {
    src = "import from enum { StrEnum }\n"
        + "class Tokens(StrEnum) {\n"
        + "    A = 'a';\n"
        + "    B = 'b';\n"
        + "}\n"
        + "def probe -> Tokens {\n"
        + "    return Tokens['A'];\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"enum lookup by name rejected: {errs}";
}

test "a metaclass subscript is dispatched from the class object" {
    src = "class Meta(type) {\n"
        + "    def __getitem__(cls: Meta, key: str) -> int {\n"
        + "        return len(key);\n"
        + "    }\n"
        + "}\n"
        + "class Foo(metaclass=Meta) {}\n"
        + "def probe -> int {\n"
        + "    return Foo['abc'];\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"metaclass subscript not dispatched: {errs}";
}

test "the metaclass receiver binds the class it was reached through" {
    src = "import from enum { Enum }\n"
        + "class Color(Enum) {\n"
        + "    RED = 1;\n"
        + "}\n"
        + "class Shade(Enum) {\n"
        + "    DARK = 1;\n"
        + "}\n"
        + "def probe -> Shade {\n"
        + "    return Shade['DARK'];\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"receiver type vars unsolved on metaclass method: {errs}";
}

test "generic specialization still wins where no metaclass subscript exists" {
    src = "def probe -> list[int] {\n"
        + "    empty: list[int] = [];\n"
        + "    return empty;\n"
        + "}\n"
        + "def keyed -> dict[str, int] {\n"
        + "    return {'a': 1};\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"builtin generic specialization broke: {errs}";
}

test "a user generic class still specializes through subscript" {
    src = "obj Box[T] {\n"
        + "    has item: T;\n"
        + "}\n"
        + "def probe -> Box[int] {\n"
        + "    return Box[int](item=3);\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"user generic specialization broke: {errs}";
}

test "a generic class with a real metaclass still specializes" {
    src = "import from abc { ABC }\n"
        + "obj Node[T](ABC) {\n"
        + "    has item: T;\n"
        + "}\n"
        + "def probe -> Node[int] {\n"
        + "    return Node[int](item=1);\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"metaclass lookup hijacked generic specialization: {errs}";
}
