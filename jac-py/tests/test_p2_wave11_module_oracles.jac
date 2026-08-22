"""Differential oracles for P2 wave-11 staged jac-py/Modules/ ports."""

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

test "jac-py math_pow_mod: cc vs staged jac agree on powmod(2,10,1000)" {
    _staged_oracle(
        "math_pow_mod.c",
        "#include <stdio.h>\n"
        "unsigned long math_pow_mod(unsigned long base, unsigned long exp, unsigned long mod);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_pow_mod(2, 10, 1000));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(math_pow_mod(2, 10, 1000));\n" "}\n"
    );
}


test "jac-py math_popcount_u: cc vs staged jac agree on popcount(15)" {
    _staged_oracle(
        "math_popcount_u.c",
        "#include <stdio.h>\n"
        "unsigned long math_popcount_u(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_popcount_u(15));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(math_popcount_u(15));\n" "}\n"
    );
}


test "jac-py pystr_contains_c: cc vs staged jac agree on contains cd" {
    _staged_oracle(
        "pystr_contains_c.c",
        "#include <stdio.h>\n"
        "int pystr_contains_c(const char *hay, const char *needle);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_contains_c("abcdef", "cd"));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(pystr_contains_c("abcdef", "cd"));\n" "}\n"
    );
}


test "jac-py pystr_cmp_c: cc vs staged jac agree on cmp abc abd" {
    _staged_oracle(
        "pystr_cmp_c.c",
        "#include <stdio.h>\n"
        "int pystr_cmp_c(const char *a, const char *b);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pystr_cmp_c("abc", "abd"));\n"
        "    return 0;\n"
"}\n",
        "with entry {\n" "    print(pystr_cmp_c("abc", "abd"));\n" "}\n"
    );
}

