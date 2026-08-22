"""Differential oracles for P2 wave-7 staged jac-py/Modules/ ports."""

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


test "jac-py pyctype_graph: cc vs staged jac agree on isgraph(65)" {
    _staged_oracle(
        "pyctype_graph.c",
        "#include <stdio.h>\n"
        "int pyctype_isgraph(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isgraph(65));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isgraph(65));\n" "}\n"
    );
}


test "jac-py pyctype_cntrl: cc vs staged jac agree on iscntrl(7)" {
    _staged_oracle(
        "pyctype_cntrl.c",
        "#include <stdio.h>\n"
        "int pyctype_iscntrl(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_iscntrl(7));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_iscntrl(7));\n" "}\n"
    );
}


test "jac-py pyctype_blank: cc vs staged jac agree on isblank(9)" {
    _staged_oracle(
        "pyctype_blank.c",
        "#include <stdio.h>\n"
        "int pyctype_isblank(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isblank(9));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(pyctype_isblank(9));\n" "}\n"
    );
}


test "jac-py math_ilog2_small: cc vs staged jac agree on ilog2(16)" {
    _staged_oracle(
        "math_ilog2_small.c",
        "#include <stdio.h>\n"
        "int math_ilog2_small(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", math_ilog2_small(16));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n" "    print(math_ilog2_small(16));\n" "}\n"
    );
}

