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
from .type_factory import TypeFactory
from .types import TypeBase, TypeCategory

if TYPE_CHECKING:
    pass


class TypeEvaluator:
    """
    Main type evaluator that walks the AST and computes types.

    Inspired by Pyright's TypeEvaluator architecture.
    """

    def __init__(self, type_factory: TypeFactory) -> None:
        """Initialize the type evaluator."""
        self.type_factory = type_factory
        self.diagnostic_sink = DiagnosticSink()
        self.scope_stack: List[uni.UniScopeNode] = []
        self.expression_type_cache: Dict[int, TypeBase] = {}

    def enter_scope(self, node: uni.UniScopeNode) -> None:
        """Enter a new scope."""
        self.scope_stack.append(node)

    def exit_scope(self) -> None:
        """Exit a scope."""
        if self.scope_stack:
            self.scope_stack.pop()

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
        if isinstance(node, uni.Name):
            return self._evaluate_name_type(node)
        elif isinstance(node, uni.BinaryExpr):
            return self._evaluate_binary_expr_type(node)
        elif isinstance(node, uni.UnaryExpr):
            return self._evaluate_unary_expr_type(node)
        elif isinstance(node, uni.Literal):
            return self._evaluate_literal_type(node)
        elif isinstance(node, uni.ListVal):
            return self._evaluate_list_literal_type(node)
        elif isinstance(node, uni.DictVal):
            return self._evaluate_dict_literal_type(node)
        elif isinstance(node, uni.SetVal):
            return self._evaluate_set_literal_type(node)
        elif isinstance(node, uni.TupleVal):
            return self._evaluate_tuple_literal_type(node)
        elif isinstance(node, uni.FuncCall):
            return self._evaluate_function_call_type(node)
        elif isinstance(node, uni.IndexSlice):
            return self._evaluate_index_slice_type(node)
        elif isinstance(node, uni.AtomTrailer):
            return self._evaluate_atom_trailer_type(node)
        else:
            # Unknown expression type - return unknown
            self._add_diagnostic(
                TypeDiagnostic.create_error(
                    f"Unsupported expression type: {type(node).__name__}", node
                )
            )
            return self.type_factory.create_unknown_type()

    def _evaluate_name_type(self, node: uni.Name) -> TypeBase:
        """Evaluate the type of a name/identifier."""
        if not self.scope_stack:
            return self.type_factory.create_unknown_type()

        current_scope = self.scope_stack[-1]
        symbol = current_scope.lookup(node.value, deep=True)
        if symbol and symbol.typ:
            return symbol.typ

        # Check if it's a builtin type
        builtin_type = self.type_factory.get_primitive_type(node.value)
        if builtin_type.category != TypeCategory.UNKNOWN:
            return builtin_type

        # Symbol not found - add diagnostic and return unknown
        self._add_diagnostic(
            TypeDiagnostic.create_error(f"Undefined symbol: {node.value}", node)
        )
        return self.type_factory.create_unknown_type()

    def _evaluate_literal_type(self, node: uni.Literal) -> TypeBase:
        """Evaluate the type of a literal value."""
        if isinstance(node, uni.Int):
            return self.type_factory.get_primitive_type("int")
        elif isinstance(node, uni.Float):
            return self.type_factory.get_primitive_type("float")
        elif isinstance(node, uni.String):
            return self.type_factory.get_primitive_type("str")
        elif isinstance(node, uni.Bool):
            return self.type_factory.get_primitive_type("bool")
        elif isinstance(node, uni.Null):
            return self.type_factory.create_unknown_type()
        else:
            return self.type_factory.create_unknown_type()

    def _evaluate_binary_expr_type(self, node: uni.BinaryExpr) -> TypeBase:
        """Evaluate the type of a binary expression."""
        left_type = self.get_type_of_expression(node.left)
        right_type = self.get_type_of_expression(node.right)

        op_name = node.op.name
        # Handle arithmetic operations
        if op_name in ["PLUS", "MINUS", "STAR", "FSLASH", "MOD"]:
            return self._evaluate_arithmetic_binary_op(
                left_type, node.op, right_type, node
            )
        # Handle comparison operations
        elif op_name in ["EE", "NE", "LT", "LE", "GT", "GE"]:
            return self._evaluate_comparison_binary_op(
                left_type, node.op, right_type, node
            )
        # Handle logical operations
        elif op_name in ["AND", "OR"]:
            return self._evaluate_logical_binary_op(
                left_type, node.op, right_type, node
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

    def _evaluate_unary_expr_type(self, node: uni.UnaryExpr) -> TypeBase:
        """Evaluate the type of a unary expression."""
        operand_type = self.get_type_of_expression(node.operand)

        if hasattr(node.op, "name"):
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

    def _evaluate_list_literal_type(self, node: uni.ListVal) -> TypeBase:
        """Evaluate the type of a list literal."""
        if not node.values:
            # Empty list - return generic list
            return self.type_factory.create_list_type()

        # Evaluate element types
        element_types = [self.get_type_of_expression(elem) for elem in node.values]

        # Try to find a common type
        common_type = self._find_common_type(element_types)
        return self.type_factory.create_list_type(common_type)

    def _evaluate_dict_literal_type(self, node: uni.DictVal) -> TypeBase:
        """Evaluate the type of a dictionary literal."""
        if not node.kv_pairs:
            # Empty dict - return generic dict
            return self.type_factory.create_dict_type()

        # Evaluate key and value types
        key_types, value_types = [], []
        for kv_pair in node.kv_pairs:
            if kv_pair.key:
                key_types.append(self.get_type_of_expression(kv_pair.key))
            value_types.append(self.get_type_of_expression(kv_pair.value))

        if key_types and value_types:
            common_key_type = self._find_common_type(key_types)
            common_value_type = self._find_common_type(value_types)
            return self.type_factory.create_dict_type(
                common_key_type, common_value_type
            )

        return self.type_factory.create_dict_type()

    def _evaluate_set_literal_type(self, node: uni.SetVal) -> TypeBase:
        """Evaluate the type of a set literal."""
        if not node.values:
            # Empty set - return generic set
            return self.type_factory.create_set_type()

        # Evaluate element types
        element_types = [self.get_type_of_expression(elem) for elem in node.values]

        # Find common element type
        common_type = self._find_common_type(element_types)
        return self.type_factory.create_set_type(common_type)

    def _evaluate_tuple_literal_type(self, node: uni.TupleVal) -> TypeBase:
        """Evaluate the type of a tuple literal."""
        # Evaluate each element type (tuples preserve individual element types)
        element_types = [self.get_type_of_expression(elem) for elem in node.values]
        return self.type_factory.create_tuple_type(element_types)

    def _evaluate_function_call_type(self, node: uni.FuncCall) -> TypeBase:
        """Evaluate the type of a function call."""
        return self.type_factory.create_unknown_type()

    def _evaluate_index_slice_type(self, node: uni.IndexSlice) -> TypeBase:
        """Evaluate the type of an index/slice operation."""
        return self.type_factory.create_unknown_type()

    def _evaluate_atom_trailer_type(self, node: uni.AtomTrailer) -> TypeBase:
        """Evaluate the type of an atom trailer (attribute access)."""
        return self.type_factory.create_unknown_type()

    def _find_common_type(self, types: List[TypeBase]) -> TypeBase:
        """Find a common type for a list of types."""
        if not types:
            return self.type_factory.create_unknown_type()
        if len(types) == 1:
            return types[0]

        first_type = types[0]
        if all(t.is_same_type(first_type) for t in types):
            return first_type

        if all(t.category == TypeCategory.PRIMITIVE for t in types):
            type_names = {t.get_display_name() for t in types}
            if type_names.issubset({"int", "float"}):
                return self.type_factory.get_primitive_type("float")

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
