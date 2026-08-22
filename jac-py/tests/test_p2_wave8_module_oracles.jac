"""Differential oracles for P2 wave-8 staged jac-py/Modules/ ports."""

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

test "jac-py math_ctz_small: cc vs staged jac agree on ctz(8)" {
    _staged_oracle(
        "math_ctz_small.c",
        "#include <stdio.h>\n"
        "int math_ctz_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", math_ctz_small(8));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_ctz_small(8));\n" "}\n"
    );
}


test "jac-py math_clz32_small: cc vs staged jac agree on clz32(1)" {
    _staged_oracle(
        "math_clz32_small.c",
        "#include <stdio.h>\n"
        "int math_clz32_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", math_clz32_small(1));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_clz32_small(1));\n" "}\n"
    );
}


test "jac-py math_abs_diff: cc vs staged jac agree on abs_diff(10,7)" {
    _staged_oracle(
        "math_abs_diff.c",
        "#include <stdio.h>\n"
        "unsigned long math_abs_diff(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_abs_diff(10, 7));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_abs_diff(10, 7));\n" "}\n"
    );
}


test "jac-py math_min_u: cc vs staged jac agree on min_u(3,9)" {
    _staged_oracle(
        "math_min_u.c",
        "#include <stdio.h>\n"
        "unsigned long math_min_u(unsigned long a, unsigned long b);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_min_u(3, 9));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_min_u(3, 9));\n" "}\n"
    );
}

