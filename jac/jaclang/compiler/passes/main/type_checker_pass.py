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

from typing import Any, Dict, List, Optional, TYPE_CHECKING

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import UniPass

from ...type_system.diagnostics import TypeErrorCodes
from ...type_system.symbol_table import EnhancedSymbolTable, SymbolTableManager
from ...type_system.type_evaluator import EvaluationContext, TypeEvaluator
from ...type_system.type_factory import TypeFactory
from ...type_system.types import TypeBase

if TYPE_CHECKING:
    from jaclang.compiler.program import JacProgram


class TypeCheckerPass(UniPass):
    """Main type checking pass that integrates with the compilation pipeline."""

    def __init__(self, ir_in: uni.Module, prog: "JacProgram") -> None:
        """Initialize the type checker pass."""
        super().__init__(ir_in, prog)

        # Initialize type system components
        self.type_factory = TypeFactory()
        self.symbol_table_manager = SymbolTableManager(self.type_factory)
        self.type_evaluator = TypeEvaluator(
            self.symbol_table_manager, self.type_factory
        )

        # Track enhanced symbol tables for each scope
        self.enhanced_tables: Dict[str, EnhancedSymbolTable] = {}
        self.context_stack: List[EvaluationContext] = []

        # Track current enhanced symbol table
        self.current_enhanced_table: Optional[EnhancedSymbolTable] = None

    def before_pass(self) -> None:
        """Initialize type checking context before processing."""
        self.log_info("Starting type checking pass")

        # Create root enhanced symbol table for the module
        if hasattr(self.ir_in, "sym_tab") and self.ir_in.sym_tab:
            root_table = self.symbol_table_manager.create_root_table(self.ir_in)
            self.enhanced_tables[self.ir_in.sym_tab.scope_name] = root_table
            self.current_enhanced_table = root_table

            # Create initial evaluation context
            initial_context = self.type_evaluator.create_context(root_table)
            self.type_evaluator.push_context(initial_context)
            self.context_stack.append(initial_context)

    def after_pass(self) -> None:
        """Finalize type checking and report results."""
        # Collect all diagnostics
        diagnostics = self.type_evaluator.get_diagnostics()

        # Report errors and warnings
        for diagnostic in diagnostics:
            if diagnostic.severity.value == "error":
                self.log_error(str(diagnostic))
            elif diagnostic.severity.value == "warning":
                self.log_warning(str(diagnostic))
            else:
                self.log_info(str(diagnostic))

        # Print statistics
        stats = self.type_evaluator.get_cache_statistics()
        self.log_info(f"Type checking completed: {stats}")

        # Validate all symbol tables
        validation_errors = self.symbol_table_manager.validate_all_tables()
        for error in validation_errors:
            self.log_warning(f"Symbol validation: {error}")

    def enter_module(self, node: uni.Module) -> None:
        """Enter module scope and set up type checking context."""
        self.log_info(f"Entering module: {getattr(node, 'name', 'unnamed')}")

        # Module context is already set up in before_pass
        if hasattr(node, "sym_tab") and node.sym_tab:
            # Register built-in types in the module scope
            self._register_builtin_types()

    def exit_module(self, node: uni.Module) -> None:
        """Exit module scope and finalize type checking."""
        self.log_info(f"Exiting module: {getattr(node, 'name', 'unnamed')}")

        # Pop the initial context
        if self.context_stack:
            self.type_evaluator.pop_context()
            self.context_stack.pop()

    def enter_archetype(self, node: uni.Archetype) -> None:
        """Enter archetype scope and create enhanced symbol table."""
        if not hasattr(node, "sym_tab") or not node.sym_tab:
            return

        # Create enhanced symbol table for this archetype
        if self.current_enhanced_table:
            archetype_table = self.current_enhanced_table.create_child_table(
                node.sym_tab
            )
            self.enhanced_tables[node.sym_tab.scope_name] = archetype_table

            # Create and push new evaluation context
            archetype_context = self.type_evaluator.create_context(
                archetype_table, self.context_stack[-1] if self.context_stack else None
            )
            self.type_evaluator.push_context(archetype_context)
            self.context_stack.append(archetype_context)

            # Update current table
            self.current_enhanced_table = archetype_table

            # Define archetype type
            self._define_archetype_type(node)

    def exit_archetype(self, node: uni.Archetype) -> None:
        """Exit archetype scope and restore parent context."""
        if not hasattr(node, "sym_tab") or not node.sym_tab:
            return

        # Pop evaluation context
        if self.context_stack:
            self.type_evaluator.pop_context()
            self.context_stack.pop()

        # Restore parent enhanced table
        if self.current_enhanced_table and self.current_enhanced_table.parent_table:
            self.current_enhanced_table = self.current_enhanced_table.parent_table

    def enter_ability(self, node: uni.Ability) -> None:
        """Enter ability scope and create enhanced symbol table."""
        if not hasattr(node, "sym_tab") or not node.sym_tab:
            return

        # Create enhanced symbol table for this ability
        if self.current_enhanced_table:
            ability_table = self.current_enhanced_table.create_child_table(node.sym_tab)
            self.enhanced_tables[node.sym_tab.scope_name] = ability_table

            # Create and push new evaluation context
            ability_context = self.type_evaluator.create_context(
                ability_table, self.context_stack[-1] if self.context_stack else None
            )
            self.type_evaluator.push_context(ability_context)
            self.context_stack.append(ability_context)

            # Update current table
            self.current_enhanced_table = ability_table

            # Define function/method type
            self._define_ability_type(node)

    def exit_ability(self, node: uni.Ability) -> None:
        """Exit ability scope and restore parent context."""
        if not hasattr(node, "sym_tab") or not node.sym_tab:
            return

        # Pop evaluation context
        if self.context_stack:
            self.type_evaluator.pop_context()
            self.context_stack.pop()

        # Restore parent enhanced table
        if self.current_enhanced_table and self.current_enhanced_table.parent_table:
            self.current_enhanced_table = self.current_enhanced_table.parent_table

    def exit_assignment(self, node: uni.Assignment) -> None:
        """Type check assignment statements."""
        if not hasattr(node, "target") or not hasattr(node, "value"):
            return

        try:
            # Get types of target and value
            target_type = self._get_assignment_target_type(node.target)
            if node.value is None:
                return
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
                    # Successful assignment - update symbol type if needed
                    self._update_symbol_type_from_assignment(node.target, value_type)

        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error checking assignment: {str(e)}", node
            )

    def exit_binary_expr(self, node: uni.BinaryExpr) -> None:
        """Type check binary expressions."""
        try:
            # The TypeEvaluator already handles binary expression type checking
            # We just need to ensure it gets evaluated
            result_type = self.type_evaluator.get_type_of_expression(node)

            # Store the computed type in the node for later use
            if hasattr(node, "expr_type"):
                node.expr_type = result_type.get_display_name()

        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error checking binary expression: {str(e)}", node
            )

    def exit_unary_expr(self, node: uni.UnaryExpr) -> None:
        """Type check unary expressions."""
        try:
            # The TypeEvaluator handles unary expression type checking
            result_type = self.type_evaluator.get_type_of_expression(node)

            # Store the computed type in the node
            if hasattr(node, "expr_type"):
                node.expr_type = result_type.get_display_name()

        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error checking unary expression: {str(e)}", node
            )

    def exit_name(self, node: uni.Name) -> None:
        """Type check name references."""
        try:
            # Check if the name can be resolved
            result_type = self.type_evaluator.get_type_of_expression(node)

            # Store the resolved type
            if hasattr(node, "expr_type"):
                node.expr_type = result_type.get_display_name()

        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error resolving name '{getattr(node, 'value', 'unknown')}': {str(e)}",
                node,
            )

    def exit_func_call(self, node: uni.FuncCall) -> None:
        """Type check function calls."""
        try:
            # Basic function call type checking
            # More sophisticated checking will be implemented in later commits
            result_type = self.type_evaluator.get_type_of_expression(node)

            if hasattr(node, "expr_type"):
                node.expr_type = result_type.get_display_name()

        except Exception as e:
            self.type_evaluator.diagnostic_sink.add_error(
                f"Error checking function call: {str(e)}", node
            )

    def _register_builtin_types(self) -> None:
        """Register built-in types in the current symbol table."""
        if not self.current_enhanced_table:
            return

        builtin_types = ["int", "float", "str", "bool", "list", "dict", "set", "tuple"]

        for type_name in builtin_types:
            try:
                # Create a declaration node for the builtin type
                type_node = self._create_symbol_node(type_name)
                builtin_type = self.type_factory.get_primitive_type(type_name)

                self.current_enhanced_table.define_symbol(
                    type_name, builtin_type, type_node
                )
            except Exception as e:
                self.log_warning(f"Failed to register builtin type {type_name}: {e}")

    def _define_archetype_type(self, node: uni.Archetype) -> None:
        """Define the type for an archetype."""
        if not self.current_enhanced_table or not hasattr(node, "name"):
            return

        try:
            # For now, create a basic archetype type
            # More sophisticated archetype types will be implemented in later commits
            archetype_name = getattr(node.name, "value", str(node.name))

            # Create a placeholder type for the archetype
            # This will be enhanced with Jac-specific archetype types in Phase 3
            archetype_type = self.type_factory.create_unknown_type()

            # Create symbol node
            symbol_node = self._create_symbol_node(archetype_name)

            # Define in parent scope (not current scope)
            if self.current_enhanced_table.parent_table:
                self.current_enhanced_table.parent_table.define_symbol(
                    archetype_name, archetype_type, symbol_node
                )

        except Exception as e:
            self.log_warning(f"Failed to define archetype type: {e}")

    def _define_ability_type(self, node: uni.Ability) -> None:
        """Define the type for an ability (function/method)."""
        if not self.current_enhanced_table or not hasattr(node, "name"):
            return

        try:
            # For now, create a basic function type
            # More sophisticated function types will be implemented in later commits
            ability_name = getattr(node.name, "value", str(node.name))

            # Create a placeholder function type
            function_type = self.type_factory.create_unknown_type()

            # Create symbol node
            symbol_node = self._create_symbol_node(ability_name)

            # Define in parent scope
            if self.current_enhanced_table.parent_table:
                self.current_enhanced_table.parent_table.define_symbol(
                    ability_name, function_type, symbol_node
                )

        except Exception as e:
            self.log_warning(f"Failed to define ability type: {e}")

    def _get_assignment_target_type(self, target: Any) -> Optional[TypeBase]:
        """Get the type of an assignment target."""
        try:
            if hasattr(target, "__iter__") and not isinstance(target, str):
                # Multiple assignment targets
                # For now, just handle the first one
                if target and len(target) > 0:
                    return self._get_single_target_type(target[0])
            else:
                return self._get_single_target_type(target)

        except Exception as e:
            self.log_warning(f"Error getting assignment target type: {e}")

        return None

    def _get_single_target_type(self, target: Any) -> Optional[TypeBase]:
        """Get the type of a single assignment target."""
        try:
            # If target is a name, look up its current type
            if hasattr(target, "value") and isinstance(target.value, str):
                if self.current_enhanced_table:
                    symbol = self.current_enhanced_table.lookup_symbol(target.value)
                    if symbol:
                        return symbol.symbol_type

                # If not found, infer from context or return unknown
                return self.type_factory.create_unknown_type()

            # For other target types, evaluate their type
            return self.type_evaluator.get_type_of_expression(target)

        except Exception:
            return self.type_factory.create_unknown_type()

    def _update_symbol_type_from_assignment(
        self, target: Any, value_type: TypeBase
    ) -> None:
        """Update symbol type based on assignment."""
        try:
            if hasattr(target, "__iter__") and not isinstance(target, str):
                # Multiple targets
                for single_target in target:
                    self._update_single_symbol_type(single_target, value_type)
            else:
                self._update_single_symbol_type(target, value_type)

        except Exception as e:
            self.log_warning(f"Error updating symbol type: {e}")

    def _update_single_symbol_type(self, target: Any, value_type: TypeBase) -> None:
        """Update a single symbol's type from assignment."""
        try:
            if (
                hasattr(target, "value")
                and isinstance(target.value, str)
                and self.current_enhanced_table
            ):
                # Try to update existing symbol or create new one
                success = self.current_enhanced_table.update_symbol_type(
                    target.value, value_type, inferred=True
                )

                if not success:
                    # Symbol doesn't exist yet, create it
                    symbol_node = self._create_symbol_node(target.value)
                    self.current_enhanced_table.define_symbol(
                        target.value, value_type, symbol_node, inferred=True
                    )

        except Exception as e:
            self.log_warning(f"Error updating single symbol type: {e}")

    def _create_symbol_node(self, name: str) -> uni.AstSymbolNode:
        """Create a proper AST symbol node for type system use."""
        # Use the current context to get a reference node for location information
        ref_node = (
            self.cur_node if hasattr(self, "cur_node") and self.cur_node else None
        )

        if (
            ref_node
            and hasattr(ref_node, "loc")
            and isinstance(ref_node, uni.AstSymbolNode)
        ):
            # Create a proper Name node using the gen_stub_from_node method
            name_node = uni.Name.gen_stub_from_node(ref_node, name)
            return name_node
        else:
            # Fallback: create a basic Name node with minimal location info
            # This shouldn't happen in normal operation but provides safety
            from jaclang.compiler.unitree import Source

            empty_source = Source("", "")
            name_node = uni.Name(
                orig_src=empty_source,
                name=Tok.NAME.value,
                value=name,
                line=0,
                end_line=0,
                col_start=0,
                col_end=len(name),
                pos_start=0,
                pos_end=len(name),
            )
            return name_node
