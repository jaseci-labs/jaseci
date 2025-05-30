"""Test type check modules."""

import ast as ast3
from difflib import unified_diff

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes.main import CompilerMode
from jaclang.compiler.passes.tool import JacFormatPass
from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCaseMicroSuite


class JTypeCheckSanityTests(TestCaseMicroSuite):
    """Test pass module."""

    TargetPass = JacFormatPass

    def micro_suite_test(self, filename: str) -> None:
        """Parse micro jac file."""
        code_gen_pure = JacProgram().compile(
            self.fixture_abs_path(filename),
            mode=CompilerMode.TYPECHECK
        )
        self.assertIsInstance(code_gen_pure, uni.Module)
       


JTypeCheckSanityTests.self_attach_micro_tests()
