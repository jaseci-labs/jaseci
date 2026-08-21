"""Differential oracles for P2 wave-5 staged jac-py/Modules/ ports."""

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


test "jac-py pyctype_xdigit: cc vs staged jac agree on isxdigit(65)" {
    _staged_oracle(
        "pyctype_xdigit.c",
        "#include <stdio.h>\n"
        "int pyctype_isxdigit(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isxdigit(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isxdigit(65));\n" "}\n"
    );
}


test "jac-py pyctype_alnum: cc vs staged jac agree on isalnum(97)" {
    _staged_oracle(
        "pyctype_alnum.c",
        "#include <stdio.h>\n"
        "int pyctype_isalnum(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isalnum(97));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isalnum(97));\n" "}\n"
    );
}


test "jac-py pyctype_lower: cc vs staged jac agree on islower(97)" {
    _staged_oracle(
        "pyctype_lower.c",
        "#include <stdio.h>\n"
        "int pyctype_islower(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_islower(97));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_islower(97));\n" "}\n"
    );
}


test "jac-py math_isqrt_small: cc vs staged jac agree on isqrt(16)" {
    _staged_oracle(
        "math_isqrt_small.c",
        "#include <stdio.h>\n"
        "unsigned long math_isqrt_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_isqrt_small(16));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_isqrt_small(16));\n" "}\n"
    );
}
