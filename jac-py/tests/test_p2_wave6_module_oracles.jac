"""Differential oracles for P2 wave-6 staged jac-py/Modules/ ports."""

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


test "jac-py pyctype_upper: cc vs staged jac agree on isupper(65)" {
    _staged_oracle(
        "pyctype_upper.c",
        "#include <stdio.h>\n"
        "int pyctype_isupper(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isupper(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isupper(65));\n" "}\n"
    );
}


test "jac-py pyctype_print: cc vs staged jac agree on isprint(65)" {
    _staged_oracle(
        "pyctype_print.c",
        "#include <stdio.h>\n"
        "int pyctype_isprint(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isprint(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isprint(65));\n" "}\n"
    );
}


test "jac-py pyctype_punct: cc vs staged jac agree on ispunct(33)" {
    _staged_oracle(
        "pyctype_punct.c",
        "#include <stdio.h>\n"
        "int pyctype_ispunct(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_ispunct(33));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_ispunct(33));\n" "}\n"
    );
}


test "jac-py math_pow2_check: cc vs staged jac agree on pow2(16)" {
    _staged_oracle(
        "math_pow2_check.c",
        "#include <stdio.h>\n"
        "int math_pow2_check(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", math_pow2_check(16));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_pow2_check(16));\n" "}\n"
    );
}
