"""
Primitive type implementations for the Jac type system.

Includes basic types like int, float, str, bool and collections.

Pyright Reference:
- Built-in type creation from analyzer/typeEvaluator.ts
- Primitive type handling in analyzer/types.ts
- Collection type implementations for List, Dict, Set equivalents
"""

from typing import List, Optional, TYPE_CHECKING

from .types import TypeBase, TypeCategory, TypeFlags

if TYPE_CHECKING:
    pass


class PrimitiveType(TypeBase):
    """Base class for primitive types like int, float, str, bool."""

    def __init__(self, name: str, default_value: object | None = None) -> None:
        """Initialize a primitive type."""
        super().__init__(TypeCategory.PRIMITIVE, TypeFlags.INSTANTIABLE_INSTANCE)
        self.name = name
        self.default_value = default_value

    def is_same_type(self, other: TypeBase) -> bool:
        """Check if this type is the same as another type."""
        return isinstance(other, PrimitiveType) and self.name == other.name

    def is_assignable_to(self, target: TypeBase) -> bool:
        """Check if this type can be assigned to the target type."""
        # Same type assignment
        if self.is_same_type(target):
            return True

        # Check for special types (handled in special_types.py)
        from .special_types import AnyType, UnknownType

        if isinstance(target, (AnyType, UnknownType)):
            return True

        # Numeric type compatibility (int can be assigned to float)
        if isinstance(self, IntType) and isinstance(target, FloatType):
            return True

        return False

    def get_display_name(self) -> str:
        """Return the display name for this type."""
        return self.name

    def __str__(self) -> str:
        """Return string representation of the type."""
        return self.name


class IntType(PrimitiveType):
    """Integer type."""

    def __init__(self) -> None:
        """Initialize integer type."""
        super().__init__("int", 0)


class FloatType(PrimitiveType):
    """Float type."""

    def __init__(self) -> None:
        """Initialize float type."""
        super().__init__("float", 0.0)


class StrType(PrimitiveType):
    """String type."""

    def __init__(self) -> None:
        """Initialize string type."""
        super().__init__("str", "")


class BoolType(PrimitiveType):
    """Boolean type."""

    def __init__(self) -> None:
        """Initialize boolean type."""
        super().__init__("bool", False)


class CollectionType(TypeBase):
    """Base class for collection types like list, dict, set."""

    def __init__(
        self, name: str, element_types: Optional[List[TypeBase]] = None
    ) -> None:
        """Initialize a collection type with optional element types."""
        super().__init__(TypeCategory.PRIMITIVE, TypeFlags.INSTANTIABLE_INSTANCE)
        self.name = name
        self.element_types = element_types or []

    def is_same_type(self, other: TypeBase) -> bool:
        """Check if this type is the same as another type."""
        if not isinstance(other, CollectionType) or self.name != other.name:
            return False

        # Check element types
        if len(self.element_types) != len(other.element_types):
            return False

        return all(
            a.is_same_type(b) for a, b in zip(self.element_types, other.element_types)
        )

    def is_assignable_to(self, target: TypeBase) -> bool:
        """Check if this type can be assigned to the target type."""
        # Same collection type with compatible element types
        if isinstance(target, CollectionType) and self.name == target.name:
            if not self.element_types and not target.element_types:
                return True
            if len(self.element_types) == len(target.element_types):
                return all(
                    a.is_assignable_to(b)
                    for a, b in zip(self.element_types, target.element_types)
                )

        # Check for special types
        from .special_types import AnyType, UnknownType

        if isinstance(target, (AnyType, UnknownType)):
            return True

        return False

    def get_display_name(self) -> str:
        """Return the display name for this type."""
        if not self.element_types:
            return self.name

        if self.name == "dict" and len(self.element_types) == 2:
            return f"dict[{self.element_types[0].get_display_name()}, {self.element_types[1].get_display_name()}]"
        elif len(self.element_types) == 1:
            return f"{self.name}[{self.element_types[0].get_display_name()}]"
        else:
            element_names = ", ".join(t.get_display_name() for t in self.element_types)
            return f"{self.name}[{element_names}]"


class ListType(CollectionType):
    """List type with optional element type."""

    def __init__(self, element_type: Optional[TypeBase] = None) -> None:
        """Initialize list type with optional element type."""
        element_types = [element_type] if element_type else []
        super().__init__("list", element_types)

    @property
    def element_type(self) -> Optional[TypeBase]:
        """Get the element type of the list."""
        return self.element_types[0] if self.element_types else None


class DictType(CollectionType):
    """Dictionary type with optional key and value types."""

    def __init__(
        self, key_type: Optional[TypeBase] = None, value_type: Optional[TypeBase] = None
    ) -> None:
        """Initialize dictionary type with optional key and value types."""
        element_types = []
        if key_type and value_type:
            element_types = [key_type, value_type]
        super().__init__("dict", element_types)

    @property
    def key_type(self) -> Optional[TypeBase]:
        """Get the key type of the dictionary."""
        return self.element_types[0] if len(self.element_types) >= 1 else None

    @property
    def value_type(self) -> Optional[TypeBase]:
        """Get the value type of the dictionary."""
        return self.element_types[1] if len(self.element_types) >= 2 else None


class SetType(CollectionType):
    """Set type with optional element type."""

    def __init__(self, element_type: Optional[TypeBase] = None) -> None:
        """Initialize set type with optional element type."""
        element_types = [element_type] if element_type else []
        super().__init__("set", element_types)

    @property
    def element_type(self) -> Optional[TypeBase]:
        """Get the element type of the set."""
        return self.element_types[0] if self.element_types else None


class TupleType(CollectionType):
    """Tuple type with specific element types."""

    def __init__(self, element_types: Optional[List[TypeBase]] = None) -> None:
        """Initialize tuple type with specific element types."""
        super().__init__("tuple", element_types or [])

    def is_assignable_to(self, target: TypeBase) -> bool:
        """Check if this tuple type can be assigned to the target type."""
        # Tuple assignment requires exact element type matching
        if isinstance(target, TupleType):
            if len(self.element_types) != len(target.element_types):
                return False
            return all(
                a.is_assignable_to(b)
                for a, b in zip(self.element_types, target.element_types)
            )

        return super().is_assignable_to(target)

    def get_display_name(self) -> str:
        """Get the display name for this tuple type."""
        if not self.element_types:
            return "tuple[()]"

        element_names = ", ".join(t.get_display_name() for t in self.element_types)
        return f"tuple[{element_names}]"
