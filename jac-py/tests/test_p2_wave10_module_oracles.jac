"""Differential oracles for P2 wave-10 staged jac-py/Modules/ ports."""

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

test "jac-py math_gcd_iter: cc vs staged jac agree on gcd(12,18)" {
    _staged_oracle(
        "math_gcd_iter.c",
        "#include <stdio.h>\n"
        "unsigned long math_gcd_iter(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_gcd_iter(12, 18));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(math_gcd_iter(12, 18));\n" "}\n"
    );
}


test "jac-py math_lcm_u: cc vs staged jac agree on lcm(4,6)" {
    _staged_oracle(
        "math_lcm_u.c",
        "#include <stdio.h>\n"
        "unsigned long math_lcm_u(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_lcm_u(4, 6));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(math_lcm_u(4, 6));\n" "}\n"
    );
}


test "jac-py pystr_startswith_c: cc vs staged jac agree on startswith abc" {
    _staged_oracle(
        "pystr_startswith_c.c",
        "#include <stdio.h>\n"
        "int pystr_startswith_c(const char *s, const char *prefix);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_startswith_c("abcdef", "abc"));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(pystr_startswith_c("abcdef", "abc"));\n" "}\n"
    );
}


test "jac-py pystr_endswith_c: cc vs staged jac agree on endswith def" {
    _staged_oracle(
        "pystr_endswith_c.c",
        "#include <stdio.h>\n"
        "int pystr_endswith_c(const char *s, const char *suffix);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_endswith_c("abcdef", "def"));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(pystr_endswith_c("abcdef", "def"));\n" "}\n"
    );
}

