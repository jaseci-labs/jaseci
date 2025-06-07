"""
Special type implementations for the Jac type system.

Includes AnyType, UnknownType, and NeverType.

Pyright Reference:
- AnyType class from analyzer/types.ts (lines 2426-2477)
- UnknownType class from analyzer/types.ts (lines 350-380)
- NeverType class from analyzer/types.ts (lines 2381-2424)
- Built-in type creation from analyzer/typeEvaluator.ts
"""

from typing import TYPE_CHECKING

from .types import TypeBase, TypeCategory, TypeFlags

if TYPE_CHECKING:
    pass


class AnyType(TypeBase):
    """
    Represents the 'any' type which can be assigned to/from any other type.

    Equivalent to TypeScript's 'any' type.

    Pyright Reference: analyzer/types.ts lines 2426-2477
    """

    def __init__(self) -> None:
        """Initialize the any type."""
        super().__init__(TypeCategory.ANY, TypeFlags.INSTANTIABLE)

    def is_same_type(self, other: TypeBase) -> bool:
        """Any type is only the same as another any type."""
        return isinstance(other, AnyType)

    def is_assignable_to(self, target: TypeBase) -> bool:
        """Any type can be assigned to any target type."""
        return True

    def get_display_name(self) -> str:
        """Get the display name for this type."""
        return "any"


class UnknownType(TypeBase):
    """
    Represents the 'unknown' type which is the top type in the type hierarchy.

    All types can be assigned to unknown, but unknown can only be assigned to any and unknown.

    Pyright Reference: analyzer/types.ts lines 350-380
    """

    def __init__(self) -> None:
        """Initialize the unknown type."""
        super().__init__(TypeCategory.UNKNOWN, TypeFlags.INSTANTIABLE)

    def is_same_type(self, other: TypeBase) -> bool:
        """Unknown type is only the same as another unknown type."""
        return isinstance(other, UnknownType)

    def is_assignable_to(self, target: TypeBase) -> bool:
        """Unknown can only be assigned to any or unknown types."""
        return isinstance(target, (AnyType, UnknownType))

    def get_display_name(self) -> str:
        """Get the display name for this type."""
        return "unknown"


class NeverType(TypeBase):
    """
    Represents the 'never' type which is the bottom type in the type hierarchy.

    Never can be assigned to any type, but no type can be assigned to never.

    Pyright Reference: analyzer/types.ts lines 2381-2424
    """

    def __init__(self) -> None:
        """Initialize the never type."""
        super().__init__(TypeCategory.NEVER, TypeFlags.NONE)

    def is_same_type(self, other: TypeBase) -> bool:
        """Never type is only the same as another never type."""
        return isinstance(other, NeverType)

    def is_assignable_to(self, target: TypeBase) -> bool:
        """Never can be assigned to any type (bottom type)."""
        return True

    def get_display_name(self) -> str:
        """Get the display name for this type."""
        return "never"
