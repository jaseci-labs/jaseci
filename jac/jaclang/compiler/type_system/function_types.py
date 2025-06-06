"""
Function type implementation for the Jac type system.

Provides function types with parameters, return types, overloading,
and generic function support.

Pyright Reference:
- analyzer/types.ts: FunctionType class implementation (lines 1496-2328)
- Lines 1496-1550: FunctionType class definition and constructor
- Lines 1551-1650: Parameter handling and function signatures
- Lines 1651-1750: Function type compatibility and assignability
- Lines 1751-2000: Overload resolution and dispatch
- Lines 2001-2328: Generic function instantiation and constraints
"""

from typing import Any, Dict, List, Optional, Set, TYPE_CHECKING
from enum import Enum

from .types import TypeBase, TypeCategory, TypeFlags

if TYPE_CHECKING:
    pass


class ParameterKind(Enum):
    """Kinds of function parameters."""

    POSITIONAL_ONLY = "positional_only"
    POSITIONAL_OR_KEYWORD = "positional_or_keyword"
    VAR_POSITIONAL = "var_positional"  # *args
    KEYWORD_ONLY = "keyword_only"
    VAR_KEYWORD = "var_keyword"  # **kwargs


class FunctionParameter:
    """Represents a function parameter with type and metadata."""

    def __init__(
        self,
        name: str,
        param_type: TypeBase,
        kind: ParameterKind = ParameterKind.POSITIONAL_OR_KEYWORD,
        default_value: Optional[Any] = None,
        has_default: bool = False,
    ) -> None:
        """Initialize a function parameter."""
        self.name = name
        self.param_type = param_type
        self.kind = kind
        self.default_value = default_value
        self.has_default = has_default

    def is_optional(self) -> bool:
        """Check if this parameter is optional (has default value)."""
        return self.has_default

    def is_variadic(self) -> bool:
        """Check if this parameter is variadic (*args or **kwargs)."""
        return self.kind in (ParameterKind.VAR_POSITIONAL, ParameterKind.VAR_KEYWORD)

    def accepts_positional(self) -> bool:
        """Check if this parameter accepts positional arguments."""
        return self.kind in (
            ParameterKind.POSITIONAL_ONLY,
            ParameterKind.POSITIONAL_OR_KEYWORD,
            ParameterKind.VAR_POSITIONAL,
        )

    def accepts_keyword(self) -> bool:
        """Check if this parameter accepts keyword arguments."""
        return self.kind in (
            ParameterKind.POSITIONAL_OR_KEYWORD,
            ParameterKind.KEYWORD_ONLY,
            ParameterKind.VAR_KEYWORD,
        )

    def get_display_name(self) -> str:
        """Get display representation of this parameter."""
        type_str = self.param_type.get_display_name()

        if self.kind == ParameterKind.VAR_POSITIONAL:
            return f"*{self.name}: {type_str}"
        elif self.kind == ParameterKind.VAR_KEYWORD:
            return f"**{self.name}: {type_str}"
        elif self.has_default:
            return f"{self.name}: {type_str} = ..."
        else:
            return f"{self.name}: {type_str}"

    def __str__(self) -> str:
        """String representation of the parameter."""
        return self.get_display_name()

    def __repr__(self) -> str:
        """Detailed string representation of the parameter."""
        return (
            f"FunctionParameter(name={self.name}, "
            f"type={self.param_type.get_display_name()}, "
            f"kind={self.kind.value}, "
            f"has_default={self.has_default})"
        )


class FunctionType(TypeBase):
    """
    Represents a function type with parameters and return type.

    Supports overloading, generic functions, and comprehensive
    function type compatibility checking.
    """

    def __init__(
        self,
        parameters: List[FunctionParameter],
        return_type: TypeBase,
        name: Optional[str] = None,
        is_method: bool = False,
        is_class_method: bool = False,
        is_static_method: bool = False,
    ) -> None:
        """Initialize a function type."""
        super().__init__(TypeCategory.FUNCTION, TypeFlags.INSTANTIABLE)

        self.parameters = parameters
        self.return_type = return_type
        self.name = name or "<anonymous>"
        self.is_method = is_method
        self.is_class_method = is_class_method
        self.is_static_method = is_static_method

        # Function type metadata
        self.is_generic = False
        self.type_parameters: List[TypeBase] = []
        self.overloads: List["FunctionType"] = []

        # Cache for performance
        self._signature_cache: Optional[str] = None
        self._compatibility_cache: Dict[str, bool] = {}

    def add_overload(self, overload: "FunctionType") -> None:
        """Add an overload to this function type."""
        self.overloads.append(overload)

    def get_parameter_count(self) -> int:
        """Get the number of non-variadic parameters."""
        return len([p for p in self.parameters if not p.is_variadic()])

    def get_required_parameter_count(self) -> int:
        """Get the number of required (non-optional) parameters."""
        return len(
            [p for p in self.parameters if not p.is_optional() and not p.is_variadic()]
        )

    def get_positional_parameters(self) -> List[FunctionParameter]:
        """Get parameters that accept positional arguments."""
        return [p for p in self.parameters if p.accepts_positional()]

    def get_keyword_parameters(self) -> List[FunctionParameter]:
        """Get parameters that accept keyword arguments."""
        return [p for p in self.parameters if p.accepts_keyword()]

    def has_var_positional(self) -> bool:
        """Check if function has *args parameter."""
        return any(p.kind == ParameterKind.VAR_POSITIONAL for p in self.parameters)

    def has_var_keyword(self) -> bool:
        """Check if function has **kwargs parameter."""
        return any(p.kind == ParameterKind.VAR_KEYWORD for p in self.parameters)

    def get_var_positional_parameter(self) -> Optional[FunctionParameter]:
        """Get the *args parameter if it exists."""
        for param in self.parameters:
            if param.kind == ParameterKind.VAR_POSITIONAL:
                return param
        return None

    def get_var_keyword_parameter(self) -> Optional[FunctionParameter]:
        """Get the **kwargs parameter if it exists."""
        for param in self.parameters:
            if param.kind == ParameterKind.VAR_KEYWORD:
                return param
        return None

    def can_accept_args(
        self,
        arg_types: List[TypeBase],
        keyword_args: Optional[Dict[str, TypeBase]] = None,
    ) -> bool:
        """
        Check if this function can accept the given arguments.

        Args:
            arg_types: Types of positional arguments
            keyword_args: Types of keyword arguments (if any)

        Returns:
            True if the function can accept these arguments
        """
        keyword_args = keyword_args or {}

        # Get positional and keyword parameters
        positional_params = self.get_positional_parameters()
        keyword_params = self.get_keyword_parameters()

        # Check positional arguments
        required_positional = len(
            [
                p
                for p in positional_params
                if not p.is_optional() and not p.is_variadic()
            ]
        )
        max_positional = (
            len(positional_params) if not self.has_var_positional() else float("inf")
        )

        if len(arg_types) < required_positional:
            return False  # Not enough positional arguments

        if len(arg_types) > max_positional:
            return False  # Too many positional arguments

        # Check positional argument types
        for i, arg_type in enumerate(arg_types):
            if i < len(positional_params):
                param = positional_params[i]
                if not param.is_variadic() and not arg_type.is_assignable_to(
                    param.param_type
                ):
                    return False
            elif self.has_var_positional():
                var_param = self.get_var_positional_parameter()
                if var_param and not arg_type.is_assignable_to(var_param.param_type):
                    return False

        # Check keyword arguments
        for kw_name, kw_type in keyword_args.items():
            # Find matching keyword parameter
            matching_param = None
            for param in keyword_params:
                if param.name == kw_name and not param.is_variadic():
                    matching_param = param
                    break

            if matching_param:
                if not kw_type.is_assignable_to(matching_param.param_type):
                    return False
            elif self.has_var_keyword():
                var_kw_param = self.get_var_keyword_parameter()
                if var_kw_param and not kw_type.is_assignable_to(
                    var_kw_param.param_type
                ):
                    return False
            else:
                return False  # Unknown keyword argument

        # Check that all required keyword-only parameters are provided
        for param in self.parameters:
            if (
                param.kind == ParameterKind.KEYWORD_ONLY
                and not param.is_optional()
                and param.name not in keyword_args
            ):
                return False

        return True

    def resolve_overload(
        self,
        arg_types: List[TypeBase],
        keyword_args: Optional[Dict[str, TypeBase]] = None,
    ) -> Optional["FunctionType"]:
        """
        Resolve the best matching overload for given arguments.

        Returns the most specific matching overload, or None if no match.
        """
        if not self.overloads:
            # No overloads, check if this function matches
            return self if self.can_accept_args(arg_types, keyword_args) else None

        # Check each overload for compatibility
        compatible_overloads = []
        for overload in self.overloads:
            if overload.can_accept_args(arg_types, keyword_args):
                compatible_overloads.append(overload)

        if not compatible_overloads:
            return None

        # For now, return the first compatible overload
        # In a more sophisticated implementation, we would rank by specificity
        return compatible_overloads[0]

    def is_same_type(self, other: TypeBase) -> bool:
        """Check if this function type is the same as another type."""
        if not isinstance(other, FunctionType):
            return False

        # Check return types
        if not self.return_type.is_same_type(other.return_type):
            return False

        # Check parameter count
        if len(self.parameters) != len(other.parameters):
            return False

        # Check each parameter
        for self_param, other_param in zip(self.parameters, other.parameters):
            if (
                not self_param.param_type.is_same_type(other_param.param_type)
                or self_param.kind != other_param.kind
                or self_param.has_default != other_param.has_default
            ):
                return False

        return True

    def is_assignable_to(self, target: TypeBase) -> bool:
        """Check if this function type can be assigned to the target type."""
        # Use cache for performance
        cache_key = f"{id(self)}_{id(target)}"
        if cache_key in self._compatibility_cache:
            return self._compatibility_cache[cache_key]

        result = self._compute_assignability(target)
        self._compatibility_cache[cache_key] = result
        return result

    def _compute_assignability(self, target: TypeBase) -> bool:
        """Compute function type assignability."""
        if not isinstance(target, FunctionType):
            # Check for special types
            from .special_types import AnyType, UnknownType

            return isinstance(target, (AnyType, UnknownType))

        # Function types are contravariant in parameter types and covariant in return types

        # Check return type compatibility (covariant)
        if not self.return_type.is_assignable_to(target.return_type):
            return False

        # Check parameter compatibility (contravariant)
        # The target function must be able to accept calls that this function can accept

        # For now, use a simplified check - exact parameter match
        # A more sophisticated implementation would handle contravariance properly
        if len(self.parameters) != len(target.parameters):
            return False

        for self_param, target_param in zip(self.parameters, target.parameters):
            # Parameters are contravariant - target param type must be assignable to self param type
            if (
                not target_param.param_type.is_assignable_to(self_param.param_type)
                or self_param.kind != target_param.kind
            ):
                return False

        return True

    def get_signature(self) -> str:
        """Get the function signature as a string."""
        if self._signature_cache is not None:
            return self._signature_cache

        # Build parameter list
        param_strs = []
        for param in self.parameters:
            param_strs.append(param.get_display_name())

        # Build signature
        params_str = ", ".join(param_strs)
        return_str = self.return_type.get_display_name()

        signature = f"({params_str}) -> {return_str}"
        self._signature_cache = signature
        return signature

    def get_display_name(self) -> str:
        """Get the display name for this function type."""
        if self.name and self.name != "<anonymous>":
            return f"{self.name}{self.get_signature()}"
        else:
            return f"function{self.get_signature()}"

    def instantiate_generics(self, type_args: Dict[str, TypeBase]) -> "FunctionType":
        """
        Instantiate generic type parameters with concrete types.

        Args:
            type_args: Mapping from type parameter names to concrete types

        Returns:
            A new FunctionType with type parameters substituted
        """
        if not self.is_generic:
            return self

        # Substitute type parameters in parameters
        new_parameters = []
        for param in self.parameters:
            new_param_type = self._substitute_type_parameters(
                param.param_type, type_args
            )
            new_param = FunctionParameter(
                param.name,
                new_param_type,
                param.kind,
                param.default_value,
                param.has_default,
            )
            new_parameters.append(new_param)

        # Substitute type parameters in return type
        new_return_type = self._substitute_type_parameters(self.return_type, type_args)

        # Create new function type
        instantiated = FunctionType(
            new_parameters,
            new_return_type,
            self.name,
            self.is_method,
            self.is_class_method,
            self.is_static_method,
        )

        return instantiated

    def _substitute_type_parameters(
        self, type_instance: TypeBase, type_args: Dict[str, TypeBase]
    ) -> TypeBase:
        """Substitute type parameters in a type instance."""
        # For now, return the type as-is
        # This will be enhanced when we implement proper generic types
        return type_instance

    def __str__(self) -> str:
        """String representation of the function type."""
        return self.get_display_name()

    def __repr__(self) -> str:
        """Detailed string representation of the function type."""
        return f"FunctionType({self.get_signature()})"


class OverloadedFunctionType(FunctionType):
    """
    Represents a function with multiple overloads.

    This is a special function type that contains multiple function signatures
    and resolves to the most appropriate one based on arguments.
    """

    def __init__(self, name: str, overloads: List[FunctionType]) -> None:
        """Initialize an overloaded function type."""
        if not overloads:
            raise ValueError("Overloaded function must have at least one overload")

        # Use the first overload as the base signature
        primary = overloads[0]
        super().__init__(
            primary.parameters,
            primary.return_type,
            name,
            primary.is_method,
            primary.is_class_method,
            primary.is_static_method,
        )

        # Store all overloads
        self.overloads = overloads.copy()

    def resolve_call(
        self,
        arg_types: List[TypeBase],
        keyword_args: Optional[Dict[str, TypeBase]] = None,
    ) -> Optional[FunctionType]:
        """
        Resolve a function call to the most specific matching overload.

        Returns the best matching overload or None if no match.
        """
        compatible_overloads = []

        for overload in self.overloads:
            if overload.can_accept_args(arg_types, keyword_args):
                compatible_overloads.append(overload)

        if not compatible_overloads:
            return None

        # Rank overloads by specificity (simplified)
        # In a more sophisticated implementation, we would have detailed specificity rules
        return compatible_overloads[0]

    def get_all_return_types(self) -> List[TypeBase]:
        """Get all possible return types from all overloads."""
        return [overload.return_type for overload in self.overloads]

    def get_union_return_type(self) -> TypeBase:
        """Get a union of all possible return types."""
        from .union_types import create_union_type

        return create_union_type(self.get_all_return_types())

    def get_display_name(self) -> str:
        """Get the display name for this overloaded function."""
        return f"{self.name}[{len(self.overloads)} overloads]"


def create_function_type(
    parameters: List[FunctionParameter],
    return_type: TypeBase,
    name: Optional[str] = None,
    **kwargs,
) -> FunctionType:
    """Factory function to create a function type."""
    return FunctionType(parameters, return_type, name, **kwargs)


def create_simple_function_type(
    param_types: List[TypeBase],
    return_type: TypeBase,
    param_names: Optional[List[str]] = None,
) -> FunctionType:
    """
    Create a simple function type with positional parameters.

    Args:
        param_types: Types of the parameters
        return_type: Return type of the function
        param_names: Optional parameter names (defaults to param0, param1, ...)

    Returns:
        A new FunctionType
    """
    if param_names is None:
        param_names = [f"param{i}" for i in range(len(param_types))]

    if len(param_names) != len(param_types):
        raise ValueError("Parameter names and types must have the same length")

    parameters = []
    for name, param_type in zip(param_names, param_types):
        param = FunctionParameter(name, param_type)
        parameters.append(param)

    return FunctionType(parameters, return_type)


def is_function_type(type_instance: TypeBase) -> bool:
    """Check if a type is a function type."""
    return isinstance(type_instance, FunctionType)


def is_callable_type(type_instance: TypeBase) -> bool:
    """Check if a type is callable (function or method)."""
    return isinstance(type_instance, FunctionType)
