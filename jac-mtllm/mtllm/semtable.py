"""Registry Utilities.

This module contains classes and functions for managing the registry of
semantic information.
"""

from __future__ import annotations

from typing import Optional

import jaclang.compiler.unitree as uni


class SemInfo:
    """Semantic information class."""

    def __init__(
        self,
        node: uni.UniNode,
        name: str,
        type_str: Optional[str] = None,
        semstr: str = "",
    ) -> None:
        """Initialize the class."""
        self.node_type = type(node)
        self.name = name
        self.type = type_str
        self.semstr = semstr

        if hasattr(node, "doc") and node.doc:
            self.docstr = node.doc.value.strip("\"'")
        else:
            self.docstr = ""
        self.semstr = semstr or self.docstr

    def __repr__(self) -> str:
        """Return the string representation of the class."""
        return f"{self.semstr} ({self.type}) ({self.name})"

    def get_children(
        self, sem_registry: SemRegistry, filter: Optional[type[uni.UniNode]] = None
    ) -> list[SemInfo]:
        """Get the children of the SemInfo."""
        scope, _ = sem_registry.lookup(name=self.name)
        self_scope = str(scope) + f".{self.name}({self.type})"
        _, children = sem_registry.lookup(scope=SemScope.get_scope_from_str(self_scope))
        if filter and children and isinstance(children, list):
            return [i for i in children if i.node_type == filter]
        return children if children and isinstance(children, list) else []


class SemScope:
    """Scope class."""

    def __init__(
        self, scope: str, type: str, parent: Optional[SemScope] = None
    ) -> None:
        """Initialize the class."""
        self.parent = parent
        self.type = type
        self.scope = scope

    def __str__(self) -> str:
        """Return the string representation of the class."""
        if self.parent:
            return f"{self.parent}.{self.scope}({self.type})"
        else:
            return f"{self.scope}({self.type})"

    def __repr__(self) -> str:
        """Return the string representation of the class."""
        return self.__str__()

    @staticmethod
    def get_scope_from_str(scope_str: str) -> Optional[SemScope]:
        """Get scope from string."""
        scope_list = scope_str.split(".")
        parent = None
        for scope in scope_list:
            start, end = scope.find("("), -1
            scope_name, scope_type = scope[:start], scope[start + 1 : end]
            parent = SemScope(scope_name, scope_type, parent)
        return parent

    @property
    def as_type_str(self) -> Optional[str]:
        """Return the type string representation of the SemScope."""
        if self.type not in ["class", "node", "object"]:
            return None
        type_str = self.scope
        node = self.parent
        while node and node.parent:
            if node.type not in ["class", "node", "object"]:
                return type_str
            type_str = f"{node.scope}.{type_str}"
            node = node.parent
        return type_str

    def get_scope_trace(self) -> list[dict[str, str]]:
        """Get the scope trace as a list of dict."""
        list_of_scopes = [{"scope": self.scope, "type": self.type}]
        if self.parent:
            parent_trace = self.parent.get_scope_trace()
            for scope in parent_trace:
                list_of_scopes.append(scope)
        return list_of_scopes


class SemRegistry:
    """Registry class for semantic information."""

    def __init__(self, program_head: uni.ProgramModule, by_scope: SemScope) -> None:
        """Initialize the registry with the program head and current scope."""
        self.program_head: uni.ProgramModule = program_head
        self.by_scope: SemScope = by_scope

    def _find_node_datatype(self, node: uni.UniNode) -> str | None:
        """Find the data type of the node."""
        if isinstance(node, uni.AstTypedVarNode) and node.type_tag:
            type_expr = node.type_tag.tag.unparse()
            return type_expr
        if isinstance(node, uni.Enum):
            return str("Enum")
        if isinstance(node, uni.Archetype):
            return str(node.sym_category)
        if isinstance(node, uni.Ability) and isinstance(
            node.signature, uni.FuncSignature
        ):
            ret = "function("
            params = []
            if node.signature.params:
                for param in node.signature.params.items:
                    params.append(
                        param.name.value
                        + ":"
                        + (self._find_node_datatype(param) or "Any")
                    )
            ret += ", ".join(params)
            return_str = "Any"
            if (
                isinstance(node.signature, uni.FuncSignature)
                and node.signature.return_type
            ):
                return_str = (
                    self._find_node_datatype(node.signature.return_type) or "Any"
                )
            ret += ") -> " + return_str
            return ret
        return None

    def lookup(
        self,
        scope: Optional[SemScope] = None,
        name: Optional[str] = None,
        _type: Optional[str] = None,
    ) -> tuple[Optional[SemScope], Optional[SemInfo | list[SemInfo]]]:
        """Lookup semantic information in the registry.

        - If 'scope' is provided, look up by scope.
        - If 'name' is provided, look up by name.
        - If '_type' is provided, filter by type.
        Returns (SemScope, SemInfo or list[SemInfo]) or (None, None) if not found.
        """
        mods = self.program_head.hub
        mod = None
        scope_obj = None
        # Find the relevant module and scope object
        scope_stack = (
            scope.get_scope_trace() if scope else self.by_scope.get_scope_trace()
        )
        expected_mod = scope_stack[-1]["scope"] if scope_stack else None
        for m in mods.values():
            if m.name == expected_mod:
                mod = m
                break
        if not mod:
            return None, None
        found_scope = mod
        scope_stack.pop(-1)

        if len(scope_stack) == 0:
            scope_obj = mod
            symbol_table = mod
        else:
            while len(scope_stack) > 0:
                found_scope = found_scope.find_scope(name=scope_stack[-1]["scope"])
                if found_scope and len(scope_stack) == 1:
                    scope_obj = found_scope
                    break
                scope_stack.pop(-1)

            if not scope_obj:
                return None, None  # Module or scope not found
            symbol_table = scope_obj.get_parent()

        if not symbol_table:
            return None, None  # Symbol table not found

        sem_scope: Optional[SemScope] = None

        # Lookup by scope
        if scope:
            symbol = symbol_table.lookup(scope.scope)
            if not symbol:
                return None, None
            # Get the AST node for semantic scope information
            decl_node = symbol.decl.name_of
            if not isinstance(decl_node, uni.UniNode):
                return None, None

            # Get the semantic scope that contains this node, not the node's own scope
            if decl_node.parent:
                sem_scope = get_sem_scope(decl_node.parent)
            else:
                sem_scope = get_sem_scope(decl_node)

            # Get the symbol table that contains the symbol's members
            scope_node = symbol.fetch_sym_tab
            if scope_node is None:
                # Try to find the scope node by name
                scope_node = symbol.parent_tab.find_scope(symbol.sym_name)
                if not scope_node or not hasattr(scope_node, "names_in_scope"):
                    # If we can't find the proper scope, fall back to original behavior
                    scope_node = symbol.parent_tab

            # Create SemInfo objects for all symbols in the scope
            sem_info_list = []
            for sym in scope_node.names_in_scope.values():
                node_of_sym = sym.decl.name_of
                node_type = self._find_node_datatype(node_of_sym) or "Any"
                if not _type or node_type == _type:
                    sem_info_list.append(
                        SemInfo(
                            node_of_sym,
                            sym.sym_name,
                            node_type,
                            "",
                        )
                    )
            return sem_scope, sem_info_list

        # Lookup by name
        if name:
            symbol = symbol_table.lookup(name)
            if not symbol:
                return None, None
            node = symbol.decl.name_of
            node_type = self._find_node_datatype(node) or "Any"
            if not isinstance(node, uni.UniNode):
                return None, None

            # Get the containing scope, not the symbol's own scope
            if node.parent:
                sem_scope = get_sem_scope(node.parent)
            else:
                # If the node has no parent, use the node itself (likely a module)
                sem_scope = get_sem_scope(node)
            sem_info = SemInfo(node, name, node_type, "")
            if _type and sem_info.type != _type:
                return None, None
            return sem_scope, sem_info

        # Lookup by type only (return all matching symbols in the table)
        if _type:
            sem_info_list = []
            # We'll store the parent scope - this should be the same for all symbols in this table
            sem_scope = None

            # First, determine the containing scope from the symbol_table's parent
            if symbol_table.parent_scope:
                parent_node = symbol_table.parent_scope
                # If the parent_scope is a valid node, get its scope
                if isinstance(parent_node, uni.UniNode):
                    sem_scope = get_sem_scope(parent_node)

            for sym in symbol_table.names_in_scope.values():
                parent_scope = sym.parent_tab
                node_of_sym = sym.decl.name_of
                node_type = self._find_node_datatype(node_of_sym) or "Any"
                if (
                    isinstance(parent_scope, uni.UniNode)
                    and str(parent_scope.get_type()) == _type
                ):
                    # If we couldn't get the scope from the parent, use the declaration node as fallback
                    if not sem_scope:
                        decl_node = sym.decl.name_of
                        if isinstance(decl_node, uni.UniNode):
                            # Get the parent's scope, not the symbol's own scope
                            if decl_node.parent:
                                sem_scope = get_sem_scope(decl_node.parent)
                            else:
                                sem_scope = get_sem_scope(decl_node)
                    sem_info_list.append(
                        SemInfo(node_of_sym, sym.sym_name, node_type, "")
                    )

            if sem_info_list:
                return sem_scope, sem_info_list
            else:
                return None, None

        return None, None

    @property
    def module_scope(self) -> SemScope:
        """Get the module scope."""
        scope = self.by_scope
        while scope.parent:
            scope = scope.parent
        return scope

    def pp(self) -> str:
        """Pretty print the registry."""
        ret_str = f"Scope: {self.by_scope}\n"
        mods = self.program_head.hub
        for m in mods.values():
            scope_obj = m.find_scope(self.by_scope.scope)
            if scope_obj:
                symbol_table = scope_obj.get_parent()
                if symbol_table and hasattr(symbol_table, "names_in_scope"):
                    for v in symbol_table.names_in_scope.values():
                        node = v.parent_tab
                        ret_str += f"  {v.sym_name} {str(node.get_type()) if hasattr(node, 'get_type') else ''}\n"
        return ret_str


def get_sem_scope(node: uni.UniNode) -> SemScope:
    """Get scope of the node."""
    a = (
        node.name
        if isinstance(node, uni.Module)
        else (
            node.name.value
            if isinstance(node, (uni.Enum, uni.Archetype))
            else node.name_ref.sym_name if isinstance(node, uni.Ability) else ""
        )
    )
    if isinstance(node, uni.Module):
        return SemScope(a, "Module", None)
    elif isinstance(node, (uni.Enum, uni.Archetype, uni.Ability)):
        node_type = (
            node.__class__.__name__
            if isinstance(node, uni.Enum)
            else ("Ability" if isinstance(node, uni.Ability) else node.arch_type.value)
        )
        if node.parent:
            return SemScope(
                a,
                node_type,
                get_sem_scope(node.parent),
            )
    else:
        if node.parent:
            return get_sem_scope(node.parent)
    return SemScope("", "", None)
