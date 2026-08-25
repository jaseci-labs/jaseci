"""Compiler pass bases and the seed-tier analysis passes.

The classes exported here are the pass infrastructure (Transform/UniPass
bases, diagnostics values) plus the bootstrap-critical passes the jac0
tier compiles; the full-compiler pass packages live in the subpackages
(main/, ecmascript/, native/, tool/) pending their move to backends/ and
tools/ (#8681).
"""

from jaclang.compiler.backends.py.jcir_bc_gen_pass import JcirBytecodeGenPass
from jaclang.compiler.backends.py.jcir_gen_pass import JcirGenPass
from jaclang.compiler.backends.py.module_codegen_pass import ModuleCodegenPass
from jaclang.compiler.passes.ast_gen import BaseAstGenPass
from jaclang.compiler.passes.ast_validation_pass import ASTValidationPass
from jaclang.compiler.passes.boundary_analysis_pass import BoundaryAnalysisPass
from jaclang.compiler.passes.decl_impl_match_pass import DeclImplMatchPass
from jaclang.compiler.passes.endpoint_effect_pass import EndpointEffectPass
from jaclang.compiler.passes.semantic_analysis_pass import SemanticAnalysisPass
from jaclang.compiler.passes.sym_tab_build_pass import SymTabBuildPass
from jaclang.compiler.passes.transform import (
    Alert,
    BaseTransform,
    DiagnosticPolicy,
    Transform,
)
from jaclang.compiler.passes.uni_pass import UniPass
from jaclang.compiler.placement.placement_solver import PlacementApplyPass

__all__ = [
    "Alert",
    "ASTValidationPass",
    "BaseAstGenPass",
    "BaseTransform",
    "BoundaryAnalysisPass",
    "DeclImplMatchPass",
    "DiagnosticPolicy",
    "EndpointEffectPass",
    "JcirBytecodeGenPass",
    "JcirGenPass",
    "ModuleCodegenPass",
    "PlacementApplyPass",
    "SemanticAnalysisPass",
    "SymTabBuildPass",
    "Transform",
    "UniPass",
]
