"""Differential oracles for P2 wave-2 staged jac-py/Modules/ ports."""

import os;
import from tests.support { JAC_ROOT }
import from tests.compiler.c2jac.lift_oracle {
    assert_lift_matches_c,
    assert_staged_jac_matches_c
}

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MODULES: str = os.path.join(REPO_ROOT, "jac-py", "Modules");


def _oracle(c_name: str, driver: str, jac_entry: str) -> None {
    c_path = os.path.join(MODULES, c_name);
    assert_lift_matches_c(
        c_path,
        driver,
        jac_entry,
        include_dirs=[MODULES]
    );
}


def _staged_oracle(c_name: str, driver: str, jac_entry: str) -> None {
    base = os.path.splitext(c_name)[0];
    c_path = os.path.join(MODULES, c_name);
    jac_path = os.path.join(MODULES, f"{base}.jac");
    assert_staged_jac_matches_c(
        c_path,
        jac_path,
        driver,
        jac_entry,
        include_dirs=[MODULES]
    );
}


test "jac-py _stat: cc vs staged jac agree on S_IMODE" {
    _staged_oracle(
        "_stat.c",
        "#include <stdio.h>\n"
        "unsigned long stat_S_IMODE(long omode);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", (int)stat_S_IMODE(0x81a4));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(stat_S_IMODE(0x81a4));\n"
        "}\n"
    );
}

test "jac-py _stat: cc vs staged jac agree on S_IFMT" {
    _staged_oracle(
        "_stat.c",
        "#include <stdio.h>\n"
        "unsigned long stat_S_IFMT(long omode);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", (int)stat_S_IFMT(0x81a4));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(stat_S_IFMT(0x81a4));\n"
        "}\n"
    );
}

test "jac-py _opcode: cc vs staged jac agree on is_valid(84)" {
    _staged_oracle(
        "_opcode.c",
        "#include <stdio.h>\n"
        "int opcode_is_valid(int opcode);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", opcode_is_valid(84));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(opcode_is_valid(84));\n"
        "}\n"
    );
}

test "jac-py _opcode: cc vs staged jac agree on has_arg(84)" {
    _staged_oracle(
        "_opcode.c",
        "#include <stdio.h>\n"
        "int opcode_has_arg(int opcode);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", opcode_has_arg(84));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(opcode_has_arg(84));\n"
        "}\n"
    );
}

test "jac-py math_gcd: cc vs lifted jac agree on gcd(48, 18)" {
    _oracle(
        "math_gcd.c",
        "#include <stdio.h>\n"
        "long math_gcd_long(long a, long b);\n"
        "int main(void) {\n"
        "    printf(\"%ld\\n\", math_gcd_long(48, 18));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(math_gcd_long(48, 18));\n"
        "}\n"
    );
}

test "jac-py pystrnicmp: cc vs lifted jac agree on prefix compare" {
    _oracle(
        "pystrnicmp.c",
        "#include <stdio.h>\n"
        "int PyOS_mystrnicmp(const char *s1, const char *s2, long size);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", PyOS_mystrnicmp(\"AbC\", \"abd\", 3));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(PyOS_mystrnicmp(\"AbC\", \"abd\", 3));\n"
        "}\n"
    );
}
