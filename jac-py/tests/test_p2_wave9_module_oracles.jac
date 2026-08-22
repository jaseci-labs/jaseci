"""Differential oracles for P2 wave-9 staged jac-py/Modules/ ports."""

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


test "jac-py math_max_u: cc vs staged jac agree on max_u(3,9)" {
    _staged_oracle(
        "math_max_u.c",
        "#include <stdio.h>\n"
        "unsigned long math_max_u(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_max_u(3, 9));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_max_u(3, 9));\n" "}\n"
    );
}


test "jac-py pystr_len_c: cc vs staged jac agree on len(abc)" {
    _staged_oracle(
        "pystr_len_c.c",
        "#include <stdio.h>\n"
        "unsigned long pystr_len_c(const char *s);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", pystr_len_c(\"abc\"));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pystr_len_c(\"abc\"));\n" "}\n"
    );
}


test "jac-py pystr_find_char: cc vs staged jac agree on find(b)" {
    _staged_oracle(
        "pystr_find_char.c",
        "#include <stdio.h>\n"
        "int pystr_find_char(const char *s, int ch);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_find_char(\"abc\", 'b'));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pystr_find_char(\"abc\", 98));\n" "}\n"
    );
}


test "jac-py pystr_count_char: cc vs staged jac agree on count(a)" {
    _staged_oracle(
        "pystr_count_char.c",
        "#include <stdio.h>\n"
        "unsigned long pystr_count_char(const char *s, int ch);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", pystr_count_char(\"abaca\", 'a'));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pystr_count_char(\"abaca\", 97));\n" "}\n"
    );
}
