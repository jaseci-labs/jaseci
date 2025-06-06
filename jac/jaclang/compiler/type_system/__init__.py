"""
Type system package for Jac language type checker.

Provides comprehensive static type checking for Jac programs.

Inspired by Microsoft's Pyright type checker architecture.
"""

from .diagnostics import (
    DiagnosticSeverity,
    DiagnosticSink,
    TypeDiagnostic,
    TypeErrorCodes,
)
from .primitive_types import (
    BoolType,
    CollectionType,
    DictType,
    FloatType,
    IntType,
    ListType,
    PrimitiveType,
    SetType,
    StrType,
    TupleType,
)
from .special_types import AnyType, NeverType, UnknownType
from .symbol_table import EnhancedSymbolTable, SymbolTableManager, TypedSymbol
from .type_evaluator import EvaluationContext, TypeEvaluator
from .type_factory import TypeFactory
from .types import TypeBase, TypeCategory, TypeFlags

__all__ = [
    # Core types
    "TypeBase",
    "TypeCategory",
    "TypeFlags",
    # Primitive types
    "PrimitiveType",
    "IntType",
    "FloatType",
    "StrType",
    "BoolType",
    # Collection types
    "CollectionType",
    "ListType",
    "DictType",
    "SetType",
    "TupleType",
    # Special types
    "AnyType",
    "UnknownType",
    "NeverType",
    # Type factory
    "TypeFactory",
    # Enhanced symbol tables
    "TypedSymbol",
    "EnhancedSymbolTable",
    "SymbolTableManager",
    # Type evaluator
    "TypeEvaluator",
    "EvaluationContext",
    # Diagnostics
    "TypeDiagnostic",
    "DiagnosticSink",
    "DiagnosticSeverity",
    "TypeErrorCodes",
]
