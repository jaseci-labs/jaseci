"""
Type evaluator for analyzing expressions and statements.

Core engine for type checking in Jac.

Pyright Reference:
- analyzer/typeEvaluator.ts: Main type evaluation engine (1.2MB file)
- analyzer/typeEvaluatorTypes.ts: TypeEvaluator interface (lines 631-880)
- Lines 631-880: Complete TypeEvaluator interface definition
- Key methods: getType, getTypeOfExpression, assignType, etc.
"""

from typing import Dict, List, Optional, TYPE_CHECKING, Union

import jaclang.compiler.unitree as uni

from .diagnostics import DiagnosticSink, TypeDiagnostic
from .symbol_table import EnhancedSymbolTable, SymbolTableManager
from .type_factory import TypeFactory
from .types import TypeBase, TypeCategory

if TYPE_CHECKING:
    pass


class EvaluationContext:
    """Context for type evaluation including current scope and constraints."""

    def __init__(
        self,
        symbol_table: EnhancedSymbolTable,
        type_factory: TypeFactory,
        parent_context: Optional["EvaluationContext"] = None,
    ) -> None:
        """Initialize evaluation context."""
        self.symbol_table = symbol_table
        self.type_factory = type_factory
        self.parent_context = parent_context
        self.type_constraints: Dict[str, List[TypeBase]] = {}
        self.inferred_types: Dict[str, TypeBase] = {}

    def add_type_constraint(self, symbol_name: str, constraint: TypeBase) -> None:
        """Add a type constraint for a symbol."""
        if symbol_name not in self.type_constraints:
            self.type_constraints[symbol_name] = []
        self.type_constraints[symbol_name].append(constraint)

    def get_constraints_for_symbol(self, symbol_name: str) -> List[TypeBase]:
        """Get all type constraints for a symbol."""
        constraints = self.type_constraints.get(symbol_name, [])
        if self.parent_context:
            constraints.extend(
                self.parent_context.get_constraints_for_symbol(symbol_name)
            )
        return constraints

    def set_inferred_type(self, symbol_name: str, inferred_type: TypeBase) -> None:
        """Set an inferred type for a symbol."""
        self.inferred_types[symbol_name] = inferred_type

    def get_inferred_type(self, symbol_name: str) -> Optional[TypeBase]:
        """Get the inferred type for a symbol."""
        if symbol_name in self.inferred_types:
            return self.inferred_types[symbol_name]
        if self.parent_context:
            return self.parent_context.get_inferred_type(symbol_name)
        return None


class TypeEvaluator:
    """
    Main type evaluator that walks the AST and computes types.

    Inspired by Pyright's TypeEvaluator architecture.
    """

    def __init__(
        self, symbol_table_manager: SymbolTableManager, type_factory: TypeFactory
    ) -> None:
        """Initialize the type evaluator."""
        self.symbol_table_manager = symbol_table_manager
        self.type_factory = type_factory
        self.diagnostic_sink = DiagnosticSink()
        self.current_context: Optional[EvaluationContext] = None
        self.expression_type_cache: Dict[int, TypeBase] = {}

    def create_context(
        self,
        symbol_table: EnhancedSymbolTable,
        parent_context: Optional[EvaluationContext] = None,
    ) -> EvaluationContext:
        """Create a new evaluation context."""
        return EvaluationContext(symbol_table, self.type_factory, parent_context)

    def push_context(self, context: EvaluationContext) -> None:
        """Push a new evaluation context."""
        context.parent_context = self.current_context
        self.current_context = context

    def pop_context(self) -> Optional[EvaluationContext]:
        """Pop the current evaluation context."""
        if self.current_context:
            old_context = self.current_context
            self.current_context = old_context.parent_context
            return old_context
        return None

    def get_type_of_expression(self, node: uni.UniNode) -> TypeBase:
        """Get the type of an expression node."""
        # Check cache first
        node_id = id(node)
        if node_id in self.expression_type_cache:
            return self.expression_type_cache[node_id]

        # Evaluate the expression type
        result_type = self._evaluate_expression_type(node)

        # Cache the result
        self.expression_type_cache[node_id] = result_type
        return result_type

    def _evaluate_expression_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate expression type of the given node."""
        match type(node):
            case uni.Name:
                return self._evaluate_name_type(node)
            case uni.BinaryExpr:
                return self._evaluate_binary_expr_type(node)
            case uni.UnaryExpr:
                return self._evaluate_unary_expr_type(node)
            case uni.Literal:
                return self._evaluate_literal_type(node)
            case uni.ListVal:
                return self._evaluate_list_literal_type(node)
            case uni.DictVal:
                return self._evaluate_dict_literal_type(node)
            case uni.SetVal:
                return self._evaluate_set_literal_type(node)
            case uni.TupleVal:
                return self._evaluate_tuple_literal_type(node)
            case uni.FuncCall:
                return self._evaluate_function_call_type(node)
            case uni.IndexSlice:
                return self._evaluate_index_slice_type(node)
            case uni.AtomTrailer:
                return self._evaluate_atom_trailer_type(node)
            case _:
                # Unknown expression type - return unknown
                self._add_diagnostic(
                    TypeDiagnostic.create_error(
                        f"Unsupported expression type: {type(node).__name__}", node
                    )
                )
                return self.type_factory.create_unknown_type()

    def _evaluate_name_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of a name/identifier."""
        if not self.current_context:
            return self.type_factory.create_unknown_type()

        # Cast to Name type for attribute access
        name_node = node  # type: ignore
        if not hasattr(name_node, "value"):
            return self.type_factory.create_unknown_type()

        # Look up the symbol in the current context
        symbol = self.current_context.symbol_table.lookup_symbol(
            name_node.value, deep=True
        )
        if symbol:
            # Check if we have an inferred type that's more specific
            inferred_type = self.current_context.get_inferred_type(name_node.value)
            if inferred_type:
                return inferred_type
            return symbol.symbol_type

        # Check if it's a builtin type
        builtin_type = self.type_factory.get_primitive_type(name_node.value)
        if builtin_type.category != TypeCategory.UNKNOWN:
            return builtin_type

        # Symbol not found - add diagnostic and return unknown
        self._add_diagnostic(
            TypeDiagnostic.create_error(f"Undefined symbol: {name_node.value}", node)
        )
        return self.type_factory.create_unknown_type()

    def _evaluate_literal_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of a literal value."""
        match type(node):
            case uni.Int:
                return self.type_factory.get_primitive_type("int")
            case uni.Float:
                return self.type_factory.get_primitive_type("float")
            case uni.String:
                return self.type_factory.get_primitive_type("str")
            case uni.Bool:
                return self.type_factory.get_primitive_type("bool")
            case uni.Null:
                # Null could be any type - return special null type or unknown
                return self.type_factory.create_unknown_type()
            case _:
                return self.type_factory.create_unknown_type()

    def _evaluate_binary_expr_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of a binary expression."""
        # Cast to access attributes
        binary_node = node  # type: ignore
        if not (hasattr(binary_node, "left") and hasattr(binary_node, "right")):
            return self.type_factory.create_unknown_type()

        left_type = self.get_type_of_expression(binary_node.left)
        right_type = self.get_type_of_expression(binary_node.right)

        # Handle arithmetic operations
        if (
            hasattr(binary_node, "op")
            and hasattr(binary_node.op, "name")
            and binary_node.op.name
            in [
                "PLUS",
                "MINUS",
                "STAR",
                "FSLASH",
                "MOD",
            ]
        ):
            return self._evaluate_arithmetic_binary_op(
                left_type, binary_node.op, right_type, node
            )

        # Handle comparison operations
        if (
            hasattr(binary_node, "op")
            and hasattr(binary_node.op, "name")
            and binary_node.op.name in ["EE", "NE", "LT", "LE", "GT", "GE"]
        ):
            return self._evaluate_comparison_binary_op(
                left_type, binary_node.op, right_type, node
            )

        # Handle logical operations
        if (
            hasattr(binary_node, "op")
            and hasattr(binary_node.op, "name")
            and binary_node.op.name in ["AND", "OR"]
        ):
            return self._evaluate_logical_binary_op(
                left_type, binary_node.op, right_type, node
            )

        # Default: return unknown for unsupported operations
        return self.type_factory.create_unknown_type()

    def _evaluate_arithmetic_binary_op(
        self,
        left_type: TypeBase,
        op: Union[uni.Token, uni.DisconnectOp, uni.ConnectOp],
        right_type: TypeBase,
        node: uni.UniNode,
    ) -> TypeBase:
        """Evaluate arithmetic binary operations."""
        # String concatenation
        if (
            left_type.category == TypeCategory.PRIMITIVE
            and left_type.get_display_name() == "str"
            and hasattr(op, "name")
            and op.name == "PLUS"
        ):
            return left_type  # String + anything = string

        # Numeric operations
        if (
            left_type.category == TypeCategory.PRIMITIVE
            and right_type.category == TypeCategory.PRIMITIVE
        ):
            left_name = left_type.get_display_name()
            right_name = right_type.get_display_name()

            if left_name in ["int", "float"] and right_name in ["int", "float"]:
                # If either operand is float, result is float
                if left_name == "float" or right_name == "float":
                    return self.type_factory.get_primitive_type("float")
                else:
                    return self.type_factory.get_primitive_type("int")

        # Type mismatch
        op_name = getattr(op, "name", str(op))
        self._add_diagnostic(
            TypeDiagnostic.create_error(
                f"Unsupported operand types for {op_name}: "
                f"{left_type.get_display_name()} and {right_type.get_display_name()}",
                node,
            )
        )
        return self.type_factory.create_unknown_type()

    def _evaluate_comparison_binary_op(
        self,
        left_type: TypeBase,
        op: Union[uni.Token, uni.DisconnectOp, uni.ConnectOp],
        right_type: TypeBase,
        node: uni.UniNode,
    ) -> TypeBase:
        """Evaluate comparison binary operations."""
        # Comparison operations always return bool
        return self.type_factory.get_primitive_type("bool")

    def _evaluate_logical_binary_op(
        self,
        left_type: TypeBase,
        op: Union[uni.Token, uni.DisconnectOp, uni.ConnectOp],
        right_type: TypeBase,
        node: uni.UniNode,
    ) -> TypeBase:
        """Evaluate logical binary operations."""
        # Logical operations return bool
        return self.type_factory.get_primitive_type("bool")

    def _evaluate_unary_expr_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of a unary expression."""
        if not hasattr(node, "operand"):
            return self.type_factory.create_unknown_type()

        operand_type = self.get_type_of_expression(node.operand)

        if hasattr(node, "op") and hasattr(node.op, "name"):
            if node.op.name == "NOT":
                return self.type_factory.get_primitive_type("bool")
            elif (
                node.op.name in ["PLUS", "MINUS"]
                and operand_type.category == TypeCategory.PRIMITIVE
            ):
                # Unary plus/minus preserve numeric types
                type_name = operand_type.get_display_name()
                if type_name in ["int", "float"]:
                    return operand_type

        return self.type_factory.create_unknown_type()

    def _evaluate_list_literal_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of a list literal."""
        if not hasattr(node, "values") or not node.values:
            # Empty list - return generic list
            return self.type_factory.create_list_type()

        # Evaluate element types
        element_types = [self.get_type_of_expression(elem) for elem in node.values]

        # Try to find a common type
        common_type = self._find_common_type(element_types)
        return self.type_factory.create_list_type(common_type)

    def _evaluate_dict_literal_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of a dictionary literal."""
        if not hasattr(node, "kv_pairs") or not node.kv_pairs:
            # Empty dict - return generic dict
            return self.type_factory.create_dict_type()

        # Evaluate key and value types
        key_types = []
        value_types = []

        for kv_pair in node.kv_pairs:
            if hasattr(kv_pair, "key") and hasattr(kv_pair, "value"):
                key_types.append(self.get_type_of_expression(kv_pair.key))
                value_types.append(self.get_type_of_expression(kv_pair.value))

        if key_types and value_types:
            common_key_type = self._find_common_type(key_types)
            common_value_type = self._find_common_type(value_types)
            return self.type_factory.create_dict_type(
                common_key_type, common_value_type
            )

        return self.type_factory.create_dict_type()

    def _evaluate_set_literal_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of a set literal."""
        if not hasattr(node, "values") or not node.values:
            # Empty set - return generic set
            return self.type_factory.create_set_type()

        # Evaluate element types
        element_types = [self.get_type_of_expression(elem) for elem in node.values]

        # Find common element type
        common_type = self._find_common_type(element_types)
        return self.type_factory.create_set_type(common_type)

    def _evaluate_tuple_literal_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of a tuple literal."""
        if not hasattr(node, "values"):
            return self.type_factory.create_tuple_type()

        # Evaluate each element type (tuples preserve individual element types)
        element_types = [self.get_type_of_expression(elem) for elem in node.values]
        return self.type_factory.create_tuple_type(element_types)

    def _evaluate_function_call_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of a function call."""
        # This is a placeholder for now - function call type checking is complex
        # and will be implemented in later commits
        return self.type_factory.create_unknown_type()

    def _evaluate_index_slice_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of an index/slice operation."""
        # This is a placeholder for now - indexing type checking will be
        # implemented in later commits
        return self.type_factory.create_unknown_type()

    def _evaluate_atom_trailer_type(self, node: uni.UniNode) -> TypeBase:
        """Evaluate the type of an atom trailer (attribute access)."""
        # This is a placeholder for now - attribute access type checking
        # will be implemented in later commits
        return self.type_factory.create_unknown_type()

    def _find_common_type(self, types: List[TypeBase]) -> TypeBase:
        """Find a common type for a list of types."""
        if not types:
            return self.type_factory.create_unknown_type()

        if len(types) == 1:
            return types[0]

        # For now, use a simple approach - if all types are the same, return that type
        # Otherwise, try to find a compatible type or return the first type
        first_type = types[0]
        if all(t.is_same_type(first_type) for t in types):
            return first_type

        # Check for numeric type promotion (int -> float)
        if all(t.category == TypeCategory.PRIMITIVE for t in types):
            type_names = [t.get_display_name() for t in types]
            if all(name in ["int", "float"] for name in type_names):
                if "float" in type_names:
                    return self.type_factory.get_primitive_type("float")
                else:
                    return self.type_factory.get_primitive_type("int")

        # For now, create a union type (placeholder - will be improved in later commits)
        return self.type_factory.create_union_type(types)

    def _add_diagnostic(self, diagnostic: TypeDiagnostic) -> None:
        """Add a diagnostic message."""
        self.diagnostic_sink.add_diagnostic(diagnostic)

    def get_diagnostics(self) -> List[TypeDiagnostic]:
        """Return all accumulated diagnostics."""
        return self.diagnostic_sink.get_diagnostics()

    def clear_diagnostics(self) -> None:
        """Clear all accumulated diagnostics."""
        self.diagnostic_sink.clear()

    def clear_cache(self) -> None:
        """Clear the expression type cache."""
        self.expression_type_cache.clear()

    def get_cache_statistics(self) -> Dict[str, int]:
        """Get statistics about the type evaluator cache."""
        return {
            "cached_expressions": len(self.expression_type_cache),
            "total_diagnostics": len(self.diagnostic_sink.get_diagnostics()),
        }
