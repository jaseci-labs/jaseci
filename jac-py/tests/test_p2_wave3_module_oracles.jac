"""Differential oracles for P2 wave-3 staged jac-py/Modules/ ports."""

import os;
import from tests.support { JAC_ROOT }
import from tests.compiler.c2jac.lift_oracle { assert_staged_jac_matches_c }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MODULES: str = os.path.join(REPO_ROOT, "jac-py", "Modules");


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


test "jac-py math_count_bits: cc vs staged jac agree on popcount(0x0f0f)" {
    _staged_oracle(
        "math_count_bits.c",
        "#include <stdio.h>\n"
        "unsigned long math_count_set_bits(unsigned long n);\n"
        "int main(void) {\n"
        "    printf(\"%lu\\n\", math_count_set_bits(0x0f0ful));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(math_count_set_bits(0x0f0f));\n"
        "}\n"
    );
}

test "jac-py math_lcm_long: cc vs staged jac agree on lcm(12, 18)" {
    _staged_oracle(
        "math_lcm_long.c",
        "#include <stdio.h>\n"
        "long math_lcm_long(long a, long b);\n"
        "int main(void) {\n"
        "    printf(\"%ld\\n\", math_lcm_long(12, 18));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(math_lcm_long(12, 18));\n"
        "}\n"
    );
}

test "jac-py strhex_byte: cc vs staged jac agree on pack(0xab)" {
    _staged_oracle(
        "strhex_byte.c",
        "#include <stdio.h>\n"
        "unsigned int strhex_pack_byte(unsigned char value);\n"
        "int main(void) {\n"
        "    printf(\"%u\\n\", strhex_pack_byte(0xab));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(strhex_pack_byte(0xab));\n"
        "}\n"
    );
}

test "jac-py pyctype_digit: cc vs staged jac agree on isdigit(57)" {
    _staged_oracle(
        "pyctype_digit.c",
        "#include <stdio.h>\n"
        "int pyctype_isdigit(unsigned char c);\n"
        "int main(void) {\n"
        "    printf(\"%d\\n\", pyctype_isdigit(57));\n"
        "    return 0;\n"
        "}\n",
        "with entry {\n"
        "    print(pyctype_isdigit(57));\n"
        "}\n"
    );
}
