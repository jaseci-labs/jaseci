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

from ...type_system.diagnostics import DiagnosticSink, TypeDiagnostic
from ...type_system.symbol_table import EnhancedSymbolTable, SymbolTableManager
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

    def __init__(self, ir_in: uni.Module, prog: "JacProgram") -> None:
        """Initialize the type binder pass."""
        # Initialize type system components BEFORE calling super().__init__()
        # because super().__init__() immediately triggers the transform
        self.type_factory = TypeFactory()
        self.symbol_table_manager = SymbolTableManager(self.type_factory)
        self.diagnostic_sink = DiagnosticSink()

        # Track enhanced symbol tables for each scope
        self.enhanced_tables: Dict[str, EnhancedSymbolTable] = {}
        self.scope_stack: List[EnhancedSymbolTable] = []

        # Current enhanced symbol table
        self.current_enhanced_table: Optional[EnhancedSymbolTable] = None

        super().__init__(ir_in, prog)

    def before_pass(self) -> None:
        """Initialize type binding context before processing."""
        self.log_info("Starting type binding pass")

        # Register built-in types in the type factory
        self._register_builtin_types()

    def after_pass(self) -> None:
        """Finalize type binding and report any issues."""
        # Report any diagnostics collected during binding
        diagnostics = self.diagnostic_sink.get_diagnostics()

        for diagnostic in diagnostics:
            if diagnostic.severity.value == "error":
                self.log_error(str(diagnostic))
            elif diagnostic.severity.value == "warning":
                self.log_warning(str(diagnostic))
            else:
                self.log_info(str(diagnostic))

        # Print statistics
        stats = self.symbol_table_manager.get_global_statistics()
        self.log_info(f"Type binding completed: {stats}")

    def enter_module(self, node: uni.Module) -> None:
        """Create enhanced symbol table for module scope."""
        self.log_info(f"Binding types for module: {getattr(node, 'name', 'unnamed')}")

        if hasattr(node, "sym_tab") and node.sym_tab:
            # Create root enhanced symbol table
            enhanced_table = self.symbol_table_manager.create_root_table(node)
            self.enhanced_tables[node.sym_tab.scope_name] = enhanced_table
            self.current_enhanced_table = enhanced_table
            self.scope_stack.append(enhanced_table)

            # Bind built-in types to module scope
            self._bind_builtin_types_to_scope(enhanced_table)

    def exit_module(self, node: uni.Module) -> None:
        """Finalize module type binding."""
        self.log_info(
            f"Completed binding for module: {getattr(node, 'name', 'unnamed')}"
        )

        if self.scope_stack:
            self.scope_stack.pop()
            self.current_enhanced_table = (
                self.scope_stack[-1] if self.scope_stack else None
            )

    def enter_archetype(self, node: uni.Archetype) -> None:
        """Bind type information for archetype definitions."""
        if not hasattr(node, "sym_tab") or not node.sym_tab:
            return

        archetype_name = getattr(node.name, "value", str(node.name))
        self.log_info(f"Binding archetype: {archetype_name}")

        # Create enhanced symbol table for this archetype scope
        if self.current_enhanced_table:
            archetype_table = self.current_enhanced_table.create_child_table(
                node.sym_tab
            )
            self.enhanced_tables[node.sym_tab.scope_name] = archetype_table

            # Push new scope
            self.scope_stack.append(archetype_table)
            old_table = self.current_enhanced_table
            self.current_enhanced_table = archetype_table

            # Create and bind the archetype type
            archetype_type = self._create_archetype_type(node)
            if archetype_type:
                # Bind the archetype type to the parent scope (where it's accessible)
                old_table.define_symbol(
                    archetype_name,
                    archetype_type,
                    self._create_symbol_node(archetype_name, node.name),
                    inferred=False,
                )

    def exit_archetype(self, node: uni.Archetype) -> None:
        """Restore parent scope after archetype processing."""
        if not hasattr(node, "sym_tab") or not node.sym_tab:
            return

        # Pop scope
        if self.scope_stack:
            self.scope_stack.pop()
            self.current_enhanced_table = (
                self.scope_stack[-1] if self.scope_stack else None
            )

    def enter_ability(self, node: uni.Ability) -> None:
        """Bind type information for ability definitions."""
        if not hasattr(node, "sym_tab") or not node.sym_tab:
            return

        ability_name = node.py_resolve_name()
        self.log_info(f"Binding ability: {ability_name}")

        # Create enhanced symbol table for this ability scope
        if self.current_enhanced_table:
            ability_table = self.current_enhanced_table.create_child_table(node.sym_tab)
            self.enhanced_tables[node.sym_tab.scope_name] = ability_table

            # Push new scope
            self.scope_stack.append(ability_table)
            old_table = self.current_enhanced_table
            self.current_enhanced_table = ability_table

            # Create and bind the ability type
            ability_type = self._create_ability_type(node)
            if ability_type:
                # Bind the ability type to the parent scope
                old_table.define_symbol(
                    ability_name,
                    ability_type,
                    self._create_symbol_node(ability_name, node.name_ref),
                    inferred=False,
                )

    def exit_ability(self, node: uni.Ability) -> None:
        """Restore parent scope after ability processing."""
        if not hasattr(node, "sym_tab") or not node.sym_tab:
            return

        # Pop scope
        if self.scope_stack:
            self.scope_stack.pop()
            self.current_enhanced_table = (
                self.scope_stack[-1] if self.scope_stack else None
            )

    def exit_has_var(self, node: uni.HasVar) -> None:
        """Bind types for variable declarations (fields)."""
        if not self.current_enhanced_table:
            return

        var_name = getattr(node.name, "value", str(node.name))

        # Resolve type from annotation or infer
        var_type = self._resolve_variable_type(node)

        # Bind the variable to current scope
        self.current_enhanced_table.define_symbol(
            var_name,
            var_type,
            self._create_symbol_node(var_name, node.name),
            inferred=(node.type_tag is None),
        )

    def exit_param_var(self, node: uni.ParamVar) -> None:
        """Bind types for function/ability parameters."""
        if not self.current_enhanced_table:
            return

        param_name = getattr(node.name, "value", str(node.name))

        # Resolve parameter type from annotation or infer
        param_type = self._resolve_variable_type(node)

        # Bind the parameter to current scope
        self.current_enhanced_table.define_symbol(
            param_name,
            param_type,
            self._create_symbol_node(param_name, node.name),
            inferred=(node.type_tag is None),
        )

    def _register_builtin_types(self) -> None:
        """Register built-in types in the type factory."""
        # Built-in types are already registered in TypeFactory.__init__()
        # This method can be extended for additional built-ins if needed
        pass

    def _bind_builtin_types_to_scope(self, enhanced_table: EnhancedSymbolTable) -> None:
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
                # Create a symbol node for the builtin type
                symbol_node = self._create_symbol_node(type_name)

                enhanced_table.define_symbol(
                    type_name, builtin_type, symbol_node, inferred=False
                )
            except Exception as e:
                self.log_warning(f"Failed to bind builtin type {type_name}: {e}")

    def _create_archetype_type(self, node: uni.Archetype) -> Optional[TypeBase]:
        """Create a type for an archetype definition."""
        try:
            archetype_name = getattr(node.name, "value", str(node.name))

            if node.arch_type.name == Tok.KW_NODE:
                # Extract field types for the node
                fields = self._extract_field_types(node)
                # For now, create a basic type - will be enhanced in later commits
                node_type = self.type_factory.create_unknown_type()
                return node_type

            elif node.arch_type.name == Tok.KW_WALKER:
                # Extract state fields and abilities for the walker
                state_fields = self._extract_field_types(node)
                # For now, create a basic type - will be enhanced in later commits
                walker_type = self.type_factory.create_unknown_type()
                return walker_type

            elif node.arch_type.name == Tok.KW_EDGE:
                # Extract field types for the edge
                fields = self._extract_field_types(node)
                # For now, create a basic type - will be enhanced in later commits
                edge_type = self.type_factory.create_unknown_type()
                return edge_type

            else:
                # Generic archetype
                return self.type_factory.create_unknown_type()

        except Exception as e:
            self.diagnostic_sink.add_error(
                f"Failed to create archetype type: {e}", node
            )
            return None

    def _create_ability_type(self, node: uni.Ability) -> Optional[TypeBase]:
        """Create a type for an ability definition."""
        try:
            # Extract parameter types
            param_types = []
            if hasattr(node, "signature") and node.signature:
                if isinstance(node.signature, uni.FuncSignature):
                    param_types = self._extract_parameter_types(node.signature)
                # EventSignature doesn't have standard parameters, so skip for now

            # Extract return type
            return_type = self._extract_return_type(node)

            # For now, create a basic function-like type - will be enhanced in later commits
            ability_type = self.type_factory.create_unknown_type()
            return ability_type

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

        # No explicit return type - will be inferred later
        return self.type_factory.create_unknown_type()

    def _resolve_variable_type(self, var_node: uni.UniNode) -> TypeBase:
        """Resolve the type of a variable from its declaration."""
        # Check for explicit type annotation
        if hasattr(var_node, "type_tag") and var_node.type_tag:
            return self._resolve_type_annotation(var_node.type_tag)

        # Check for value to infer type from
        if hasattr(var_node, "value") and var_node.value:
            return self._infer_type_from_value(var_node.value)

        # No type information available - mark as unknown for inference
        return self.type_factory.create_unknown_type()

    def _resolve_type_annotation(self, type_tag: uni.UniNode) -> TypeBase:
        """Resolve a type annotation to a concrete type."""
        try:
            if isinstance(type_tag, uni.Name):
                # Simple type name
                type_name = getattr(type_tag, "value", str(type_tag))
                return self.type_factory.get_primitive_type(type_name)

            elif isinstance(type_tag, uni.IndexSlice):
                # Generic type like list[int], dict[str, int]
                return self._resolve_generic_type_annotation(type_tag)

            else:
                # Complex type annotation - for now, return unknown
                self.diagnostic_sink.add_warning(
                    f"Unsupported type annotation: {type(type_tag).__name__}", type_tag
                )
                return self.type_factory.create_unknown_type()

        except Exception as e:
            self.diagnostic_sink.add_error(
                f"Failed to resolve type annotation: {e}", type_tag
            )
            return self.type_factory.create_unknown_type()

    def _resolve_generic_type_annotation(self, index_slice: uni.IndexSlice) -> TypeBase:
        """Resolve generic type annotations like list[int], dict[str, int]."""
        try:
            if not hasattr(index_slice, "obj") or not hasattr(index_slice, "index"):
                return self.type_factory.create_unknown_type()

            # Get the base type name
            if isinstance(index_slice.obj, uni.Name):
                base_type_name = getattr(index_slice.obj, "value", "")

                if base_type_name == "list" and hasattr(index_slice.index, "items"):
                    # list[element_type]
                    if len(index_slice.index.items) == 1:
                        element_type = self._resolve_type_annotation(
                            index_slice.index.items[0]
                        )
                        return self.type_factory.create_list_type(element_type)

                elif base_type_name == "dict" and hasattr(index_slice.index, "items"):
                    # dict[key_type, value_type]
                    if len(index_slice.index.items) == 2:
                        key_type = self._resolve_type_annotation(
                            index_slice.index.items[0]
                        )
                        value_type = self._resolve_type_annotation(
                            index_slice.index.items[1]
                        )
                        return self.type_factory.create_dict_type(key_type, value_type)

                elif base_type_name == "set" and hasattr(index_slice.index, "items"):
                    # set[element_type]
                    if len(index_slice.index.items) == 1:
                        element_type = self._resolve_type_annotation(
                            index_slice.index.items[0]
                        )
                        return self.type_factory.create_set_type(element_type)

                elif base_type_name == "tuple" and hasattr(index_slice.index, "items"):
                    # tuple[type1, type2, ...]
                    element_types = [
                        self._resolve_type_annotation(item)
                        for item in index_slice.index.items
                    ]
                    return self.type_factory.create_tuple_type(element_types)

            return self.type_factory.create_unknown_type()

        except Exception as e:
            self.diagnostic_sink.add_error(
                f"Failed to resolve generic type annotation: {e}", index_slice
            )
            return self.type_factory.create_unknown_type()

    def _infer_type_from_value(self, value_node: uni.UniNode) -> TypeBase:
        """Infer type from an initial value expression."""
        try:
            # Basic literal type inference
            if isinstance(value_node, uni.Int):
                return self.type_factory.get_primitive_type("int")
            elif isinstance(value_node, uni.Float):
                return self.type_factory.get_primitive_type("float")
            elif isinstance(value_node, uni.String):
                return self.type_factory.get_primitive_type("str")
            elif isinstance(value_node, uni.Bool):
                return self.type_factory.get_primitive_type("bool")
            elif isinstance(value_node, uni.ListVal):
                # Basic list type inference - more sophisticated in later commits
                return self.type_factory.create_list_type()
            elif isinstance(value_node, uni.DictVal):
                # Basic dict type inference - more sophisticated in later commits
                return self.type_factory.create_dict_type()
            elif isinstance(value_node, uni.SetVal):
                # Basic set type inference - more sophisticated in later commits
                return self.type_factory.create_set_type()
            else:
                # Complex expression - defer to type evaluator in later passes
                return self.type_factory.create_unknown_type()

        except Exception as e:
            self.diagnostic_sink.add_warning(
                f"Failed to infer type from value: {e}", value_node
            )
            return self.type_factory.create_unknown_type()

    def _create_symbol_node(
        self, name: str, reference_node: Optional[uni.UniNode] = None
    ) -> uni.AstSymbolNode:
        """Create a proper AST symbol node for type system use."""
        if (
            reference_node
            and hasattr(reference_node, "loc")
            and isinstance(reference_node, uni.AstSymbolNode)
        ):
            # Create using reference node for proper location info
            return uni.Name.gen_stub_from_node(reference_node, name)
        else:
            # Fallback: create basic Name node
            from jaclang.compiler.unitree import Source
            from jaclang.compiler.constant import Tokens as Tok

            empty_source = Source("", "")
            return uni.Name(
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
