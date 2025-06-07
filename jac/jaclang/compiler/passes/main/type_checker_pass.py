"""
Type checker pass for comprehensive type analysis.

Integrates with existing compilation pipeline.

Pyright Reference:
- analyzer/checker.ts: Main type checker walker (lines 1-7685)
- Lines 150-200: Checker class initialization and setup
- Lines 300-500: Visit methods for different AST node types
- analyzer/typeEvaluator.ts: Core type evaluation methods
- This pass combines walking (like Checker) with evaluation (like TypeEvaluator)
"""

from __future__ import annotations

from typing import Dict, List, Optional, Sequence, TYPE_CHECKING, Union

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import UniPass

from ...type_system.diagnostics import TypeErrorCodes
from ...type_system.type_evaluator import TypeEvaluator
from ...type_system.type_factory import TypeFactory
from ...type_system.types import TypeBase

if TYPE_CHECKING:
    from jaclang.compiler.program import JacProgram


class TypeCheckerPass(UniPass):
    """Main type checking pass that integrates with the compilation pipeline."""

    def before_pass(self) -> None:
        """Initialize type checking context before processing."""
        self.log_info("Starting type checking pass")
        self.type_factory = TypeFactory()
        self.type_evaluator = TypeEvaluator(self.type_factory)

    def after_pass(self) -> None:
        """Finalize type checking and report results."""
        diagnostics = self.type_evaluator.get_diagnostics()

        for diagnostic in diagnostics:
            if diagnostic.severity.value == "error":
                self.log_error(str(diagnostic))
            elif diagnostic.severity.value == "warning":
                self.log_warning(str(diagnostic))
            else:
                self.log_info(str(diagnostic))

        stats = self.type_evaluator.get_cache_statistics()
        self.log_info(f"Type checking completed: {stats}")

    def enter_scope(self, node: uni.UniScopeNode) -> None:
        """Enter a new scope."""
        self.type_evaluator.enter_scope(node)

    def exit_scope(self) -> None:
        """Exit a scope."""
        self.type_evaluator.exit_scope()

    def enter_module(self, node: uni.Module) -> None:
        """Enter module scope and set up type checking context."""
        if node.sym_tab:
            self.enter_scope(node.sym_tab)

    def exit_module(self, node: uni.Module) -> None:
        """Exit module scope and finalize type checking."""
        if node.sym_tab:
            self.exit_scope()

    def enter_archetype(self, node: uni.Archetype) -> None:
        """Enter archetype scope and create enhanced symbol table."""
        if node.sym_tab:
            self.enter_scope(node.sym_tab)

    def exit_archetype(self, node: uni.Archetype) -> None:
        """Exit archetype scope and restore parent context."""
        if node.sym_tab:
            self.exit_scope()

    def enter_ability(self, node: uni.Ability) -> None:
        """Enter ability scope and create enhanced symbol table."""
        if node.sym_tab:
            self.enter_scope(node.sym_tab)

    def exit_ability(self, node: uni.Ability) -> None:
        """Exit ability scope and restore parent context."""
        if node.sym_tab:
            self.exit_scope()

    def exit_assignment(self, node: uni.Assignment) -> None:
        """Type check assignment statements."""
        if not node.value:
            return
        try:
            # Get types of target and value
            target_type = self._get_assignment_target_type(node.target)
            value_type = self.type_evaluator.get_type_of_expression(node.value)

            # Check assignment compatibility
            if target_type and value_type:
                if not value_type.is_assignable_to(target_type):
                    self.type_evaluator.diagnostic_sink.add_error(
                        f"Cannot assign {value_type.get_display_name()} "
                        f"to {target_type.get_display_name()}",
                        node,
                        TypeErrorCodes.INCOMPATIBLE_ASSIGNMENT,
                    )
                else:
                    self._update_symbol_type_from_assignment(node.target, value_type)
        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error checking assignment: {str(e)}", node
            )

    def exit_binary_expr(self, node: uni.BinaryExpr) -> None:
        """Type check binary expressions."""
        try:
            self.type_evaluator.get_type_of_expression(node)
        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error checking binary expression: {str(e)}", node
            )

    def exit_unary_expr(self, node: uni.UnaryExpr) -> None:
        """Type check unary expressions."""
        try:
            self.type_evaluator.get_type_of_expression(node)
        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error checking unary expression: {str(e)}", node
            )

    def exit_name(self, node: uni.Name) -> None:
        """Type check name references."""
        try:
            self.type_evaluator.get_type_of_expression(node)
        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error resolving name '{getattr(node, 'value', 'unknown')}': {str(e)}",
                node,
            )

    def exit_func_call(self, node: uni.FuncCall) -> None:
        """Type check function calls."""
        try:
            self.type_evaluator.get_type_of_expression(node)
        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error checking function call: {str(e)}", node
            )

    def _get_assignment_target_type(
        self, target: Union[Sequence[uni.UniNode], uni.UniNode]
    ) -> Optional[TypeBase]:
        """Get the type of an assignment target."""
        if isinstance(target, list):
            if target:
                return self._get_single_target_type(target[0])
        elif isinstance(target, uni.UniNode):
            return self._get_single_target_type(target)
        return None

    def _get_single_target_type(self, target: uni.UniNode) -> Optional[TypeBase]:
        """Get the type of a single assignment target."""
        if isinstance(target, uni.Name):
            if self.type_evaluator.scope_stack:
                scope = self.type_evaluator.scope_stack[-1]
                sym = scope.lookup(target.value)
                if sym and sym.typ:
                    return sym.typ
            return self.type_factory.create_unknown_type()
        return self.type_evaluator.get_type_of_expression(target)

    def _update_symbol_type_from_assignment(
        self, target: Union[Sequence[uni.UniNode], uni.UniNode], value_type: TypeBase
    ) -> None:
        """Update symbol type based on assignment."""
        if isinstance(target, list):
            for single_target in target:
                self._update_single_symbol_type(single_target, value_type)
        elif isinstance(target, uni.UniNode):
            self._update_single_symbol_type(target, value_type)

    def _update_single_symbol_type(
        self, target: uni.UniNode, value_type: TypeBase
    ) -> None:
        """Update a single symbol's type from assignment."""
        if isinstance(target, uni.Name) and self.type_evaluator.scope_stack:
            scope = self.type_evaluator.scope_stack[-1]
            sym = scope.lookup(target.value)
            if sym:
                sym.typ = value_type
                sym.is_type_inferred = True
