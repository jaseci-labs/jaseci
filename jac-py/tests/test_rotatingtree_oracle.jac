"""Differential oracle for jac-py/Modules/rotatingtree staged port.

Reuses the c2jac lift oracle harness: system cc on the pinned C source vs
jac run on freshly lifted Jac must agree on RotatingTree_RandomBits(3).
"""

import os;
import from tests.support { JAC_ROOT }
import from tests.compiler.c2jac.lift_oracle { assert_lift_matches_c }

glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     ROTATINGTREE_C: str = os.path.join(
         REPO_ROOT, "jac-py", "Modules", "rotatingtree.c"
     ),
     _DRIVER: str = "#include <stdio.h>\n"
     "int RotatingTree_RandomBits(int bits);\n"
     "int main(void) {\n"
     "    printf(\"%d\\n\", RotatingTree_RandomBits(3));\n"
     "    return 0;\n"
     "}\n",
     _ENTRY: str = "with entry {\n"
     "    print(RotatingTree_RandomBits(3));\n"
     "}\n";


test "jac-py rotatingtree: cc vs lifted jac agree on RotatingTree_RandomBits(3)" {
    assert_lift_matches_c(
        ROTATINGTREE_C,
        _DRIVER,
        _ENTRY,
        include_dirs=[os.path.dirname(ROTATINGTREE_C)]
    );
}
