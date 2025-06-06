"""
Core type system for Jac language type checker.

Inspired by Pyright's type system architecture.

Pyright Reference:
- analyzer/types.ts: Core type system (TypeBase, TypeCategory, ClassType, etc.)
- Lines 27-51: TypeCategory enum definition
- Lines 52-68: TypeFlags enum definition
- Lines 70-141: TypeBase interface and methods
"""

from abc import ABC, abstractmethod
from enum import Enum
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    pass


class TypeCategory(Enum):
    """Categories of types in the Jac type system."""

    UNKNOWN = "unknown"
    ANY = "any"
    NEVER = "never"
    PRIMITIVE = "primitive"
    NODE = "node"
    EDGE = "edge"
    WALKER = "walker"
    ABILITY = "ability"
    ARCHETYPE = "archetype"
    UNION = "union"
    FUNCTION = "function"
    GENERIC = "generic"
    TYPE_VAR = "type_var"


class TypeFlags(Enum):
    """Flags for type instances."""

    NONE = 0
    INSTANTIABLE = 1 << 0
    INSTANCE = 1 << 1
    AMBIGUOUS = 1 << 2
    INSTANTIABLE_INSTANCE = (1 << 0) | (1 << 1)  # Combined flag for convenience


class TypeBase(ABC):
    """Base class for all types in the Jac type system."""

    def __init__(
        self, category: TypeCategory, flags: TypeFlags = TypeFlags.NONE
    ) -> None:
        """Initialize a type with category and flags."""
        self.category = category
        self.flags = flags

    @abstractmethod
    def is_same_type(self, other: "TypeBase") -> bool:
        """Check if this type is the same as another type."""
        pass

    @abstractmethod
    def is_assignable_to(self, target: "TypeBase") -> bool:
        """Check if this type can be assigned to the target type."""
        pass

    @abstractmethod
    def get_display_name(self) -> str:
        """Get the display name for this type."""
        pass

    def __str__(self) -> str:
        """String representation of the type."""
        return self.get_display_name()

    def __repr__(self) -> str:
        """Return detailed string representation of the type."""
        return f"{self.__class__.__name__}(category={self.category.value}, flags={self.flags.value})"
