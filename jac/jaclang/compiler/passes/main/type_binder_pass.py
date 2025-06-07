"""
Type binder pass that associates types with symbols.

Extends existing symbol table functionality with comprehensive type information.

Pyright Reference:
- analyzer/binder.ts: Core symbol binding implementation (lines 1-4418)
- Lines 195-280: Binder class and initialization
- Lines 400-600: visitClass and visitFunction methods
- Lines 3500-3650: _bindNameToScope and symbol creation methods
- This pass extends Binder concepts with type information
"""

from typing import Dict, List, Optional, TYPE_CHECKING

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import UniPass

from ...type_system.diagnostics import DiagnosticSink
from ...type_system.type_factory import TypeFactory
from ...type_system.types import TypeBase

if TYPE_CHECKING:
    from jaclang.compiler.program import JacProgram


class TypeBinderPass(UniPass):
    """
    Binds type information to symbols in the symbol table.

    Integrates with existing SymTabBuildPass to enhance symbol tables
    with comprehensive type information.
    """

    def before_pass(self) -> None:
        """Initialize type binding context before processing."""
        self.log_info("Starting type binding pass")
        self.type_factory = TypeFactory()
        self.diagnostic_sink = DiagnosticSink()
        self.scope_stack: List[uni.UniScopeNode] = []
        self._register_builtin_types()

    def after_pass(self) -> None:
        """Finalize type binding and report any issues."""
        diagnostics = self.diagnostic_sink.get_diagnostics()

        for diagnostic in diagnostics:
            if diagnostic.severity.value == "error":
                self.log_error(str(diagnostic))
            elif diagnostic.severity.value == "warning":
                self.log_warning(str(diagnostic))
            else:
                self.log_info(str(diagnostic))
        self.log_info("Type binding completed.")

    def enter_scope(self, node: uni.UniScopeNode) -> None:
        """Enter a new scope."""
        self.scope_stack.append(node)

    def exit_scope(self) -> None:
        """Exit a scope."""
        if self.scope_stack:
            self.scope_stack.pop()

    def enter_module(self, node: uni.Module) -> None:
        """Create enhanced symbol table for module scope."""
        if node.sym_tab:
            self.enter_scope(node.sym_tab)
            self._bind_builtin_types_to_scope(node.sym_tab)

    def exit_module(self, node: uni.Module) -> None:
        """Finalize module type binding."""
        if node.sym_tab:
            self.exit_scope()

    def enter_archetype(self, node: uni.Archetype) -> None:
        """Bind type information for archetype definitions."""
        if not node.sym_tab:
            return
        self.enter_scope(node.sym_tab)
        archetype_type = self._create_archetype_type(node)
        if archetype_type and node.sym_tab.parent_scope:
            sym = node.sym_tab.parent_scope.def_insert(node, typ=archetype_type)
            if sym:
                sym.is_type_inferred = False

    def exit_archetype(self, node: uni.Archetype) -> None:
        """Restore parent scope after archetype processing."""
        if node.sym_tab:
            self.exit_scope()

    def enter_ability(self, node: uni.Ability) -> None:
        """Bind type information for ability definitions."""
        if not node.sym_tab:
            return
        self.enter_scope(node.sym_tab)
        ability_type = self._create_ability_type(node)
        if ability_type and node.sym_tab.parent_scope:
            sym = node.sym_tab.parent_scope.def_insert(node=node, typ=ability_type)
            if sym:
                sym.is_type_inferred = False

    def exit_ability(self, node: uni.Ability) -> None:
        """Restore parent scope after ability processing."""
        if node.sym_tab:
            self.exit_scope()

    def exit_has_var(self, node: uni.HasVar) -> None:
        """Bind types for variable declarations (fields)."""
        if not self.scope_stack:
            return
        current_scope = self.scope_stack[-1]
        var_type = self._resolve_variable_type(node)
        sym = current_scope.def_insert(node=node, typ=var_type)
        if sym:
            sym.is_type_inferred = node.type_tag is None

    def exit_param_var(self, node: uni.ParamVar) -> None:
        """Bind types for function/ability parameters."""
        if not self.scope_stack:
            return
        current_scope = self.scope_stack[-1]
        param_type = self._resolve_variable_type(node)
        sym = current_scope.def_insert(node=node, typ=param_type)
        if sym:
            sym.is_type_inferred = node.type_tag is None

    def _register_builtin_types(self) -> None:
        """Register built-in types in the type factory."""
        pass

    def _bind_builtin_types_to_scope(self, current_scope: uni.UniScopeNode) -> None:
        """Bind built-in types to the given scope."""
        builtin_types = [
            "int",
            "float",
            "str",
            "bool",
            "list",
            "dict",
            "set",
            "tuple",
            "any",
            "unknown",
        ]
        for type_name in builtin_types:
            try:
                builtin_type = self.type_factory.get_primitive_type(type_name)
                symbol_node = self._create_symbol_node(
                    type_name, reference_node=current_scope
                )
                sym = current_scope.def_insert(node=symbol_node, typ=builtin_type)
                if sym:
                    sym.is_type_inferred = False
            except Exception as e:
                self.log_warning(f"Failed to bind builtin type {type_name}: {e}")

    def _create_archetype_type(self, node: uni.Archetype) -> Optional[TypeBase]:
        """Create a type for an archetype definition."""
        try:
            if node.arch_type.name == Tok.KW_NODE:
                return self.type_factory.create_unknown_type()
            elif node.arch_type.name == Tok.KW_WALKER:
                return self.type_factory.create_unknown_type()
            elif node.arch_type.name == Tok.KW_EDGE:
                return self.type_factory.create_unknown_type()
            else:
                return self.type_factory.create_unknown_type()
        except Exception as e:
            self.diagnostic_sink.add_error(
                f"Failed to create archetype type: {e}", node
            )
            return None

    def _create_ability_type(self, node: uni.Ability) -> Optional[TypeBase]:
        """Create a type for an ability definition."""
        try:
            return self.type_factory.create_unknown_type()
        except Exception as e:
            self.diagnostic_sink.add_error(f"Failed to create ability type: {e}", node)
            return None

    def _extract_field_types(self, node: uni.Archetype) -> Dict[str, TypeBase]:
        """Extract field types from archetype definition."""
        fields = {}
        if hasattr(node, "body") and node.body:
            for member in node.body.statements:
                if isinstance(member, uni.HasVar):
                    field_name = getattr(member.name, "value", str(member.name))
                    field_type = self._resolve_variable_type(member)
                    fields[field_name] = field_type
        return fields

    def _extract_parameter_types(self, signature: uni.FuncSignature) -> List[TypeBase]:
        """Extract parameter types from function signature."""
        param_types = []
        if hasattr(signature, "params") and signature.params:
            for param in signature.params:
                if isinstance(param, uni.ParamVar):
                    param_type = self._resolve_variable_type(param)
                    param_types.append(param_type)
        return param_types

    def _extract_return_type(self, node: uni.Ability) -> Optional[TypeBase]:
        """Extract return type from ability definition."""
        if (
            hasattr(node, "signature")
            and node.signature
            and hasattr(node.signature, "return_type")
            and node.signature.return_type
        ):
            return self._resolve_type_annotation(node.signature.return_type)
        return self.type_factory.create_unknown_type()

    def _resolve_variable_type(self, var_node: uni.AstTypedVarNode) -> TypeBase:
        """Resolve the type of a variable from its declaration."""
        if var_node.type_tag:
            return self._resolve_type_annotation(var_node.type_tag.tag)
        if hasattr(var_node, "value") and var_node.value:
            return self._infer_type_from_value(var_node.value)
        return self.type_factory.create_unknown_type()

    def _resolve_type_annotation(self, type_node: uni.Expr) -> TypeBase:
        """Resolve a type annotation to a concrete type."""
        try:
            if isinstance(type_node, uni.AtomTrailer) and isinstance(
                type_node.right, uni.IndexSlice
            ):
                return self._resolve_generic_type_annotation(type_node)
            elif isinstance(type_node, uni.Name):
                type_name = getattr(type_node, "value", str(type_node))
                type_val = self.type_factory.get_primitive_type(type_name)
                if type_val.get_display_name() == "unknown" and self.scope_stack:
                    sym = self.scope_stack[-1].lookup(type_name)
                    if sym and sym.typ:
                        return sym.typ
                return type_val
            else:
                self.diagnostic_sink.add_warning(
                    f"Unsupported type annotation: {type(type_node).__name__}",
                    type_node,
                )
                return self.type_factory.create_unknown_type()
        except Exception as e:
            self.diagnostic_sink.add_error(
                f"Failed to resolve type annotation: {e}", type_node
            )
            return self.type_factory.create_unknown_type()

    def _resolve_generic_type_annotation(self, trailer: uni.AtomTrailer) -> TypeBase:
        """Resolve generic type annotations like list[int], dict[str, int]."""
        try:
            base_type_name = ""
            if isinstance(trailer.target, uni.Name):
                base_type_name = trailer.target.value

            params = (
                trailer.right.kid if isinstance(trailer.right, uni.IndexSlice) else []
            )
            params = [p for p in params if isinstance(p, uni.Expr)]

            if base_type_name == "list":
                if len(params) == 1:
                    element_type = self._resolve_type_annotation(params[0])
                    return self.type_factory.create_list_type(element_type)
            elif base_type_name == "dict":
                if len(params) == 2:
                    key_type = self._resolve_type_annotation(params[0])
                    value_type = self._resolve_type_annotation(params[1])
                    return self.type_factory.create_dict_type(key_type, value_type)
            elif base_type_name == "set":
                if len(params) == 1:
                    element_type = self._resolve_type_annotation(params[0])
                    return self.type_factory.create_set_type(element_type)
            elif base_type_name == "tuple":
                element_types = [self._resolve_type_annotation(p) for p in params]
                return self.type_factory.create_tuple_type(element_types)

            return self.type_factory.create_unknown_type()
        except Exception as e:
            self.diagnostic_sink.add_error(
                f"Failed to resolve generic type annotation: {e}", trailer
            )
            return self.type_factory.create_unknown_type()

    def _infer_type_from_value(self, value_node: uni.Expr) -> TypeBase:
        """Infer type from an initial value expression."""
        try:
            if isinstance(value_node, uni.Int):
                return self.type_factory.get_primitive_type("int")
            elif isinstance(value_node, uni.Float):
                return self.type_factory.get_primitive_type("float")
            elif isinstance(value_node, uni.String):
                return self.type_factory.get_primitive_type("str")
            elif isinstance(value_node, uni.Bool):
                return self.type_factory.get_primitive_type("bool")
            elif isinstance(value_node, uni.ListVal):
                return self.type_factory.create_list_type()
            elif isinstance(value_node, uni.DictVal):
                return self.type_factory.create_dict_type()
            elif isinstance(value_node, uni.SetVal):
                return self.type_factory.create_set_type()
            else:
                return self.type_factory.create_unknown_type()
        except Exception as e:
            self.diagnostic_sink.add_warning(
                f"Failed to infer type from value: {e}", value_node
            )
            return self.type_factory.create_unknown_type()

    def _create_symbol_node(
        self, name: str, reference_node: uni.UniNode
    ) -> uni.AstSymbolNode:
        """Create a proper AST symbol node for type system use."""
        ret = uni.Name.gen_stub_from_node(reference_node, name)
        ret.parent = reference_node
        return ret
