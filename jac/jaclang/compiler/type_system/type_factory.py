"""
Factory for creating and managing type instances.

Provides centralized type creation and caching.

Pyright Reference:
- Type creation utilities inspired by analyzer/typeUtils.ts
- Centralized type management concepts from Pyright's type system
- Caching and deduplication strategies for performance
"""

from typing import Dict, List, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from .function_types import FunctionType, FunctionParameter, OverloadedFunctionType

from .primitive_types import (
    BoolType,
    DictType,
    FloatType,
    IntType,
    ListType,
    SetType,
    StrType,
    TupleType,
)
from .special_types import AnyType, NeverType, UnknownType
from .types import TypeBase


class TypeFactory:
    """Factory for creating and caching type instances."""

    def __init__(self) -> None:
        """Initialize the type factory with primitive types and caching."""
        self._type_cache: Dict[str, TypeBase] = {}
        self._primitive_types = self._create_primitive_types()
        self._collection_cache: Dict[str, TypeBase] = {}

    def _create_primitive_types(self) -> Dict[str, TypeBase]:
        """Create the built-in primitive types."""
        return {
            "int": IntType(),
            "float": FloatType(),
            "str": StrType(),
            "bool": BoolType(),
            "any": AnyType(),
            "unknown": UnknownType(),
            "never": NeverType(),
        }

    def get_primitive_type(self, name: str) -> TypeBase:
        """Get a primitive type by name."""
        if name in self._primitive_types:
            return self._primitive_types[name]
        # Return unknown for unrecognized primitive types
        return self._primitive_types["unknown"]

    def create_list_type(self, element_type: Optional[TypeBase] = None) -> ListType:
        """Create a list type with optional element type."""
        if element_type is None:
            cache_key = "list"
        else:
            cache_key = f"list[{element_type.get_display_name()}]"

        if cache_key in self._collection_cache:
            cached_type = self._collection_cache[cache_key]
            assert isinstance(cached_type, ListType)
            return cached_type

        list_type = ListType(element_type)
        self._collection_cache[cache_key] = list_type
        return list_type

    def create_dict_type(
        self, key_type: Optional[TypeBase] = None, value_type: Optional[TypeBase] = None
    ) -> DictType:
        """Create a dictionary type with optional key and value types."""
        if key_type is None and value_type is None:
            cache_key = "dict"
        elif key_type is not None and value_type is not None:
            cache_key = (
                f"dict[{key_type.get_display_name()}, {value_type.get_display_name()}]"
            )
        else:
            # Partial specification - don't cache for now
            return DictType(key_type, value_type)

        if cache_key in self._collection_cache:
            cached_type = self._collection_cache[cache_key]
            assert isinstance(cached_type, DictType)
            return cached_type

        dict_type = DictType(key_type, value_type)
        self._collection_cache[cache_key] = dict_type
        return dict_type

    def create_set_type(self, element_type: Optional[TypeBase] = None) -> SetType:
        """Create a set type with optional element type."""
        if element_type is None:
            cache_key = "set"
        else:
            cache_key = f"set[{element_type.get_display_name()}]"

        if cache_key in self._collection_cache:
            cached_type = self._collection_cache[cache_key]
            assert isinstance(cached_type, SetType)
            return cached_type

        set_type = SetType(element_type)
        self._collection_cache[cache_key] = set_type
        return set_type

    def create_tuple_type(
        self, element_types: Optional[List[TypeBase]] = None
    ) -> TupleType:
        """Create a tuple type with specific element types."""
        if element_types is None or len(element_types) == 0:
            cache_key = "tuple[()]"
        else:
            element_names = [t.get_display_name() for t in element_types]
            cache_key = f"tuple[{', '.join(element_names)}]"

        if cache_key in self._collection_cache:
            cached_type = self._collection_cache[cache_key]
            assert isinstance(cached_type, TupleType)
            return cached_type

        tuple_type = TupleType(element_types)
        self._collection_cache[cache_key] = tuple_type
        return tuple_type

    def create_union_type(self, types: List[TypeBase]) -> TypeBase:
        """
        Create a union type from a list of types with deduplication and normalization.

        Returns a single type if the union reduces to one type.
        """
        from .union_types import create_union_type

        return create_union_type(types)

    def normalize_type(self, type_instance: TypeBase) -> TypeBase:
        """
        Normalize a type by applying standard transformations.

        This includes simplification and canonicalization.
        """
        # Basic normalization - can be extended in future commits
        return type_instance

    def get_type_by_name(self, type_name: str) -> Optional[TypeBase]:
        """Get a type by its string name."""
        # Check primitive types first
        if type_name in self._primitive_types:
            return self._primitive_types[type_name]

        # Check cached types
        if type_name in self._type_cache:
            return self._type_cache[type_name]

        # Parse generic types like list[int], dict[str, int], etc.
        parsed_type = self._parse_generic_type_name(type_name)
        if parsed_type:
            return parsed_type

        return None

    def _parse_generic_type_name(self, type_name: str) -> Optional[TypeBase]:
        """Parse generic type names like 'list[int]', 'dict[str, int]', etc."""
        if "[" not in type_name or "]" not in type_name:
            return None

        # Extract base type and parameters
        base_type = type_name[: type_name.index("[")]
        params_str = type_name[type_name.index("[") + 1 : type_name.rindex("]")]

        # Parse parameters
        if not params_str:
            params = []
        else:
            # Simple parameter parsing - split by comma and trim
            params = [p.strip() for p in params_str.split(",")]

        # Create appropriate collection type
        if base_type == "list":
            if len(params) == 0:
                return self.create_list_type()
            elif len(params) == 1:
                element_type = self.get_type_by_name(params[0])
                if element_type:
                    return self.create_list_type(element_type)
        elif base_type == "dict":
            if len(params) == 0:
                return self.create_dict_type()
            elif len(params) == 2:
                key_type = self.get_type_by_name(params[0])
                value_type = self.get_type_by_name(params[1])
                if key_type and value_type:
                    return self.create_dict_type(key_type, value_type)
        elif base_type == "set":
            if len(params) == 0:
                return self.create_set_type()
            elif len(params) == 1:
                element_type = self.get_type_by_name(params[0])
                if element_type:
                    return self.create_set_type(element_type)
        elif base_type == "tuple":
            if len(params) == 0:
                return self.create_tuple_type()
            else:
                element_types = []
                for param in params:
                    element_type = self.get_type_by_name(param)
                    if element_type:
                        element_types.append(element_type)
                    else:
                        return None  # Failed to resolve all parameter types
                return self.create_tuple_type(element_types)

        return None

    def register_type(self, name: str, type_instance: TypeBase) -> None:
        """Register a type in the cache with a given name."""
        self._type_cache[name] = type_instance

    def clear_cache(self) -> None:
        """Clear all cached types except primitive types."""
        self._collection_cache.clear()
        self._type_cache.clear()

    def get_cache_stats(self) -> Dict[str, int]:
        """Get statistics about cached types."""
        return {
            "primitive_types": len(self._primitive_types),
            "collection_cache": len(self._collection_cache),
            "type_cache": len(self._type_cache),
            "total_cached": len(self._primitive_types)
            + len(self._collection_cache)
            + len(self._type_cache),
        }

    def create_unknown_type(self) -> UnknownType:
        """Create an unknown type instance."""
        unknown_type = self.get_primitive_type("unknown")
        assert isinstance(unknown_type, UnknownType)
        return unknown_type

    def create_any_type(self) -> AnyType:
        """Create an any type instance."""
        any_type = self.get_primitive_type("any")
        assert isinstance(any_type, AnyType)
        return any_type

    def create_never_type(self) -> NeverType:
        """Create a never type instance."""
        never_type = self.get_primitive_type("never")
        assert isinstance(never_type, NeverType)
        return never_type

    def create_function_type(
        self,
        parameters: List["FunctionParameter"],
        return_type: TypeBase,
        name: Optional[str] = None,
        **kwargs,
    ) -> "FunctionType":
        """Create a function type with parameters and return type."""
        from .function_types import FunctionType

        return FunctionType(parameters, return_type, name, **kwargs)

    def create_simple_function_type(
        self,
        param_types: List[TypeBase],
        return_type: TypeBase,
        param_names: Optional[List[str]] = None,
    ) -> "FunctionType":
        """Create a simple function type with positional parameters."""
        from .function_types import create_simple_function_type

        return create_simple_function_type(param_types, return_type, param_names)

    def create_overloaded_function_type(
        self, name: str, overloads: List["FunctionType"]
    ) -> "OverloadedFunctionType":
        """Create an overloaded function type with multiple signatures."""
        from .function_types import OverloadedFunctionType

        return OverloadedFunctionType(name, overloads)
