"""Differential oracles for P2 wave-4 staged jac-py/Modules/ ports."""

import os;
import from tests.support { JAC_ROOT }
import from tests.compiler.c2jac.lift_oracle { assert_staged_jac_matches_c }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MODULES: str = os.path.join(REPO_ROOT, "jac-py", "Modules");


def _staged_oracle(c_name: str, driver: str, jac_entry: str) {
    base = os.path.splitext(c_name)[0];
    c_path = os.path.join(MODULES, c_name);
    jac_path = os.path.join(MODULES, f"{base}.jac");
    assert_staged_jac_matches_c(
        c_path, jac_path, driver, jac_entry, include_dirs=[MODULES]
    );
}


test "jac-py pystricmp: cc vs staged jac agree on ABC vs abc" {
    _staged_oracle(
        "pystricmp.c",
        "#include <stdio.h>\n"
        "int PyOS_mystricmp(const char *s1, const char *s2);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", PyOS_mystricmp(\"ABC\", \"abc\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(PyOS_mystricmp(\"ABC\", \"abc\"));\n" "}\n"
    );
}


test "jac-py pystricmp: cc vs staged jac agree on empty strings" {
    _staged_oracle(
        "pystricmp.c",
        "#include <stdio.h>\n"
        "int PyOS_mystricmp(const char *s1, const char *s2);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", PyOS_mystricmp(\"\", \"\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(PyOS_mystricmp(\"\", \"\"));\n" "}\n"
    );
}


test "jac-py pystricmp: cc vs staged jac agree on prefix mismatch" {
    _staged_oracle(
        "pystricmp.c",
        "#include <stdio.h>\n"
        "int PyOS_mystricmp(const char *s1, const char *s2);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", PyOS_mystricmp(\"ab\", \"abc\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(PyOS_mystricmp(\"ab\", \"abc\"));\n" "}\n"
    );
}


test "jac-py pyctype_space: cc vs staged jac agree on isspace(32)" {
    _staged_oracle(
        "pyctype_space.c",
        "#include <stdio.h>\n"
        "int pyctype_isspace(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isspace(32));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isspace(32));\n" "}\n"
    );
}


test "jac-py pyctype_alpha: cc vs staged jac agree on isalpha(65)" {
    _staged_oracle(
        "pyctype_alpha.c",
        "#include <stdio.h>\n"
        "int pyctype_isalpha(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isalpha(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isalpha(65));\n" "}\n"
    );
}


test "jac-py math_factorial_small: cc vs staged jac agree on fact(5)" {
    _staged_oracle(
        "math_factorial_small.c",
        "#include <stdio.h>\n"
        "unsigned long math_factorial_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_factorial_small(5));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_factorial_small(5));\n" "}\n"
    );
}
