"""
Enhanced symbol table with comprehensive type information.

Extends the existing symbol table infrastructure.

Pyright Reference:
- analyzer/binder.ts: Symbol binding and scope creation (lines 1-4418)
- analyzer/symbol.ts: Symbol class definition (lines 1-312)
- analyzer/scope.ts: Scope management (lines 1-231)
- Key classes: Binder, Symbol, Scope with type information tracking
"""

from typing import Dict, List, Optional, TYPE_CHECKING

import jaclang.compiler.unitree as uni

from .type_factory import TypeFactory
from .types import TypeBase

if TYPE_CHECKING:
    pass


class TypedSymbol:
    """Symbol with associated type information."""

    def __init__(
        self,
        name: str,
        symbol_type: TypeBase,
        declaration_node: uni.AstSymbolNode,
        scope_id: str,
    ) -> None:
        """Initialize a typed symbol with type metadata."""
        self.name = name
        self.symbol_type = symbol_type
        self.declaration_node = declaration_node
        self.scope_id = scope_id
        self.is_type_inferred = False
        self.type_constraints: List[TypeBase] = []
        self.definition_locations: List[uni.AstSymbolNode] = [declaration_node]
        self.use_locations: List[uni.AstSymbolNode] = []

    def add_type_constraint(self, constraint_type: TypeBase) -> None:
        """Add a type constraint to this symbol."""
        if not any(
            constraint_type.is_same_type(existing) for existing in self.type_constraints
        ):
            self.type_constraints.append(constraint_type)

    def add_definition(self, definition_node: uni.AstSymbolNode) -> None:
        """Add another definition location for this symbol."""
        self.definition_locations.append(definition_node)

    def add_use(self, use_node: uni.AstSymbolNode) -> None:
        """Add a use location for this symbol."""
        self.use_locations.append(use_node)

    def update_type(self, new_type: TypeBase, inferred: bool = False) -> None:
        """Update the type of this symbol."""
        self.symbol_type = new_type
        if inferred:
            self.is_type_inferred = True

    def is_compatible_with(self, other_type: TypeBase) -> bool:
        """Check if this symbol's type is compatible with another type."""
        return self.symbol_type.is_assignable_to(other_type)

    def get_display_info(self) -> str:
        """Return display information for this symbol."""
        type_info = (
            f"{self.symbol_type.get_display_name()}"
            f"{'(inferred)' if self.is_type_inferred else ''}"
        )
        constraint_info = (
            f" | constraints: {[c.get_display_name() for c in self.type_constraints]}"
            if self.type_constraints
            else ""
        )
        return f"{self.name}: {type_info}{constraint_info}"

    def __str__(self) -> str:
        """Return string representation of the typed symbol."""
        return f"TypedSymbol({self.name}: {self.symbol_type.get_display_name()})"

    def __repr__(self) -> str:
        """Detailed string representation of the typed symbol."""
        return (
            f"TypedSymbol(name={self.name}, "
            f"type={self.symbol_type.get_display_name()}, "
            f"inferred={self.is_type_inferred}, "
            f"scope={self.scope_id})"
        )


class EnhancedSymbolTable:
    """Enhanced symbol table with type checking capabilities."""

    def __init__(self, scope_node: uni.UniScopeNode, type_factory: TypeFactory) -> None:
        """Initialize enhanced symbol table."""
        self.scope_node = scope_node
        self.type_factory = type_factory
        self.symbols: Dict[str, TypedSymbol] = {}
        self.parent_table: Optional["EnhancedSymbolTable"] = None
        self.child_tables: List["EnhancedSymbolTable"] = []
        self.scope_id = getattr(scope_node, "scope_name", "unknown")

    def define_symbol(
        self,
        name: str,
        symbol_type: TypeBase,
        declaration_node: uni.AstSymbolNode,
        inferred: bool = False,
    ) -> TypedSymbol:
        """Define a new symbol with type information."""
        if name in self.symbols:
            # Symbol already exists, add this as another definition
            existing_symbol = self.symbols[name]
            existing_symbol.add_definition(declaration_node)
            # Update type if this is a more specific type
            if symbol_type.is_assignable_to(existing_symbol.symbol_type):
                existing_symbol.update_type(symbol_type, inferred)
            return existing_symbol
        else:
            # Create new typed symbol
            typed_symbol = TypedSymbol(
                name, symbol_type, declaration_node, self.scope_id
            )
            typed_symbol.is_type_inferred = inferred
            self.symbols[name] = typed_symbol
            return typed_symbol

    def lookup_symbol(self, name: str, deep: bool = True) -> Optional[TypedSymbol]:
        """Look up a symbol, searching parent scopes if necessary."""
        # Check current scope
        if name in self.symbols:
            return self.symbols[name]

        # Check parent scopes if deep lookup is enabled
        if deep and self.parent_table:
            return self.parent_table.lookup_symbol(name, deep)

        return None

    def update_symbol_type(
        self, name: str, new_type: TypeBase, inferred: bool = False
    ) -> bool:
        """Update the type of an existing symbol."""
        if name in self.symbols:
            self.symbols[name].update_type(new_type, inferred)
            return True
        return False

    def add_symbol_constraint(self, name: str, constraint_type: TypeBase) -> bool:
        """Add a type constraint to an existing symbol."""
        if name in self.symbols:
            self.symbols[name].add_type_constraint(constraint_type)
            return True
        return False

    def add_symbol_use(self, name: str, use_node: uni.AstSymbolNode) -> bool:
        """Add a use location for a symbol."""
        symbol = self.lookup_symbol(name)
        if symbol:
            symbol.add_use(use_node)
            return True
        return False

    def link_parent_table(self, parent_table: "EnhancedSymbolTable") -> None:
        """Link this table to a parent table."""
        self.parent_table = parent_table
        parent_table.child_tables.append(self)

    def create_child_table(
        self, child_scope_node: uni.UniScopeNode
    ) -> "EnhancedSymbolTable":
        """Create and link a child symbol table."""
        child_table = EnhancedSymbolTable(child_scope_node, self.type_factory)
        child_table.link_parent_table(self)
        return child_table

    def get_all_symbols(
        self, include_inherited: bool = False
    ) -> Dict[str, TypedSymbol]:
        """Get all symbols in this scope, optionally including inherited symbols."""
        all_symbols = self.symbols.copy()

        if include_inherited and self.parent_table:
            parent_symbols = self.parent_table.get_all_symbols(include_inherited=True)
            # Add parent symbols that aren't overridden in this scope
            for symbol_name, symbol in parent_symbols.items():
                if symbol_name not in all_symbols:
                    all_symbols[symbol_name] = symbol

        return all_symbols

    def get_symbols_by_type(self, symbol_type: TypeBase) -> List[TypedSymbol]:
        """Get all symbols that have a specific type."""
        return [
            symbol
            for symbol in self.symbols.values()
            if symbol.symbol_type.is_same_type(symbol_type)
        ]

    def get_symbols_compatible_with(self, target_type: TypeBase) -> List[TypedSymbol]:
        """Get all symbols that are compatible with a target type."""
        return [
            symbol
            for symbol in self.symbols.values()
            if symbol.is_compatible_with(target_type)
        ]

    def validate_symbol_usage(self) -> List[str]:
        """Validate symbol usage and return list of errors."""
        errors = []

        for symbol in self.symbols.values():
            # Check for unused symbols (excluding special symbols)
            if (
                not symbol.use_locations
                and not symbol.name.startswith("_")
                and symbol.name not in ["self", "super"]
            ):
                errors.append(f"Unused symbol: {symbol.name}")

            # Check for symbols with no inferred type (if needed)
            if (
                symbol.is_type_inferred
                and symbol.symbol_type.category.value == "unknown"
            ):
                errors.append(f"Could not infer type for symbol: {symbol.name}")

        return errors

    def get_scope_statistics(self) -> Dict[str, int]:
        """Get statistics about this symbol table."""
        total_symbols = len(self.symbols)
        inferred_types = sum(1 for s in self.symbols.values() if s.is_type_inferred)
        constrained_symbols = sum(
            1 for s in self.symbols.values() if s.type_constraints
        )

        return {
            "total_symbols": total_symbols,
            "inferred_types": inferred_types,
            "constrained_symbols": constrained_symbols,
            "child_tables": len(self.child_tables),
        }

    def debug_print(self, indent: int = 0) -> None:
        """Print debug information about this symbol table."""
        prefix = "  " * indent
        print(f"{prefix}EnhancedSymbolTable({self.scope_id}):")

        for _, symbol in self.symbols.items():
            print(f"{prefix}  {symbol.get_display_info()}")

        for child in self.child_tables:
            child.debug_print(indent + 1)

    def __str__(self) -> str:
        """Return string representation of the enhanced symbol table."""
        return f"EnhancedSymbolTable({self.scope_id}, {len(self.symbols)} symbols)"

    def __repr__(self) -> str:
        """Detailed string representation of the enhanced symbol table."""
        return (
            f"EnhancedSymbolTable(scope_id={self.scope_id}, "
            f"symbols={list(self.symbols.keys())}, "
            f"parent={'Yes' if self.parent_table else 'No'}, "
            f"children={len(self.child_tables)})"
        )


class SymbolTableManager:
    """Manager for enhanced symbol tables across the compilation unit."""

    def __init__(self, type_factory: TypeFactory) -> None:
        """Initialize the symbol table manager."""
        self.type_factory = type_factory
        self.root_table: Optional[EnhancedSymbolTable] = None
        self.all_tables: List[EnhancedSymbolTable] = []
        self.symbol_cache: Dict[str, TypedSymbol] = {}

    def create_root_table(self, module_node: uni.Module) -> EnhancedSymbolTable:
        """Create the root symbol table for a module."""
        self.root_table = EnhancedSymbolTable(module_node, self.type_factory)
        self.all_tables.append(self.root_table)
        return self.root_table

    def create_table_for_scope(
        self, scope_node: uni.UniScopeNode, parent_table: EnhancedSymbolTable
    ) -> EnhancedSymbolTable:
        """Create a new symbol table for a scope."""
        new_table = parent_table.create_child_table(scope_node)
        self.all_tables.append(new_table)
        return new_table

    def find_symbol_globally(self, name: str) -> Optional[TypedSymbol]:
        """Find a symbol across all symbol tables."""
        # Check cache first
        if name in self.symbol_cache:
            return self.symbol_cache[name]

        # Search all tables
        for table in self.all_tables:
            symbol = table.lookup_symbol(name, deep=False)
            if symbol:
                self.symbol_cache[name] = symbol
                return symbol

        return None

    def clear_cache(self) -> None:
        """Clear the symbol cache."""
        self.symbol_cache.clear()

    def get_global_statistics(self) -> Dict[str, int]:
        """Get global statistics about all symbol tables."""
        total_tables = len(self.all_tables)
        total_symbols = sum(len(table.symbols) for table in self.all_tables)
        total_inferred = sum(
            sum(1 for s in table.symbols.values() if s.is_type_inferred)
            for table in self.all_tables
        )

        return {
            "total_tables": total_tables,
            "total_symbols": total_symbols,
            "total_inferred": total_inferred,
            "cached_symbols": len(self.symbol_cache),
        }

    def validate_all_tables(self) -> List[str]:
        """Validate all symbol tables and return list of errors."""
        all_errors = []
        for table in self.all_tables:
            errors = table.validate_symbol_usage()
            all_errors.extend([f"{table.scope_id}: {error}" for error in errors])
        return all_errors
