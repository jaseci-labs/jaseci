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
from .type_evaluator import TypeEvaluator
from .type_factory import TypeFactory
from .types import TypeBase, TypeCategory, TypeFlags
from .union_types import UnionType, create_union_type, get_union_subtypes, is_union_type
from .function_types import (
    FunctionType,
    FunctionParameter,
    OverloadedFunctionType,
    ParameterKind,
    create_function_type,
    create_simple_function_type,
    is_function_type,
    is_callable_type,
)

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
    # Union types
    "UnionType",
    "create_union_type",
    "get_union_subtypes",
    "is_union_type",
    # Function types
    "FunctionType",
    "FunctionParameter",
    "OverloadedFunctionType",
    "ParameterKind",
    "create_function_type",
    "create_simple_function_type",
    "is_function_type",
    "is_callable_type",
    # Type factory
    "TypeFactory",
    # Type evaluator
    "TypeEvaluator",
    # Diagnostics
    "TypeDiagnostic",
    "DiagnosticSink",
    "DiagnosticSeverity",
    "TypeErrorCodes",
]
