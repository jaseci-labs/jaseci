"""
Union type implementation for the Jac type system.

Provides union types with proper semantics including flattening, normalization,
and type narrowing capabilities.

Pyright Reference:
- analyzer/types.ts: UnionType class implementation (lines 2581-2720)
- Lines 2581-2620: UnionType class definition and constructor
- Lines 2621-2670: Union flattening and normalization methods
- Lines 2671-2720: Assignability and comparison logic
- Key concepts: subtype management, type narrowing, union simplification
"""

from typing import List, Optional, Set, TYPE_CHECKING

from .types import TypeBase, TypeCategory, TypeFlags

if TYPE_CHECKING:
    pass


class UnionType(TypeBase):
    """
    Represents a union of multiple types.

    A union type can hold values of any of its constituent types.
    Supports proper semantics including flattening, normalization,
    and type narrowing.
    """

    def __init__(self, subtypes: List[TypeBase]) -> None:
        """Initialize a union type with proper normalization."""
        super().__init__(TypeCategory.UNION, TypeFlags.INSTANTIABLE_INSTANCE)

        # Flatten and normalize the union
        self.subtypes = self._normalize_subtypes(subtypes)

        # Cache for performance optimization
        self._assignability_cache: dict[str, bool] = {}
        self._subtype_cache: dict[str, bool] = {}

    def _normalize_subtypes(self, subtypes: List[TypeBase]) -> List[TypeBase]:
        """Normalize union subtypes by flattening and removing duplicates."""
        if not subtypes:
            return []

        # Step 1: Flatten nested unions
        flattened = self._flatten_unions(subtypes)

        # Step 2: Remove duplicate types
        deduplicated = self._remove_duplicates(flattened)

        # Step 3: Remove subtypes that are assignable to other types in the union
        simplified = self._remove_redundant_subtypes(deduplicated)

        # Step 4: Handle special type combinations
        final = self._handle_special_combinations(simplified)

        return final

    def _flatten_unions(self, subtypes: List[TypeBase]) -> List[TypeBase]:
        """Flatten nested union types into a single list."""
        flattened = []

        for subtype in subtypes:
            if isinstance(subtype, UnionType):
                # Recursively flatten nested unions
                flattened.extend(subtype.subtypes)
            else:
                flattened.append(subtype)

        return flattened

    def _remove_duplicates(self, subtypes: List[TypeBase]) -> List[TypeBase]:
        """Remove duplicate types from the union."""
        unique_types: List[TypeBase] = []

        for subtype in subtypes:
            # Check if this type is already in the list
            if not any(subtype.is_same_type(existing) for existing in unique_types):
                unique_types.append(subtype)

        return unique_types

    def _remove_redundant_subtypes(self, subtypes: List[TypeBase]) -> List[TypeBase]:
        """Remove subtypes that are assignable to other types in the union."""
        if len(subtypes) <= 1:
            return subtypes

        # For now, be conservative and only remove truly identical types
        # More sophisticated redundancy removal can be added later when we have
        # proper inheritance hierarchies
        from .primitive_types import PrimitiveType

        non_redundant: List[TypeBase] = []

        for candidate in subtypes:
            # Check if this candidate is assignable to any other type in the union
            is_redundant = False

            for other in subtypes:
                if (
                    candidate is not other
                    and candidate.is_assignable_to(other)
                    and
                    # Only remove if it's the exact same type or clear inheritance
                    # Don't remove primitive type compatibility (like int -> float)
                    not (
                        isinstance(candidate, PrimitiveType)
                        and isinstance(other, PrimitiveType)
                    )
                ):
                    # This candidate is redundant (it's a subtype of another)
                    is_redundant = True
                    break

            if not is_redundant:
                non_redundant.append(candidate)

        return non_redundant

    def _handle_special_combinations(self, subtypes: List[TypeBase]) -> List[TypeBase]:
        """Handle special type combinations and simplifications."""
        if len(subtypes) <= 1:
            return subtypes

        # Check for Any type - if present, the entire union becomes Any
        from .special_types import AnyType, NeverType, UnknownType

        for subtype in subtypes:
            if isinstance(subtype, AnyType):
                return [subtype]  # Any absorbs all other types

        # Remove Never types (they don't contribute to the union)
        filtered = [t for t in subtypes if not isinstance(t, NeverType)]

        # If all types were Never, return Never
        if not filtered and subtypes:
            return [subtypes[0]]  # Return a Never type

        return filtered if filtered else subtypes

    def is_same_type(self, other: TypeBase) -> bool:
        """Check if this union type is the same as another type."""
        if not isinstance(other, UnionType):
            # A union is the same as a non-union only if the union has exactly one subtype
            # that is the same as the other type
            return len(self.subtypes) == 1 and self.subtypes[0].is_same_type(other)

        # Both are union types - check if they have the same subtypes
        if len(self.subtypes) != len(other.subtypes):
            return False

        # Check if all subtypes in this union exist in the other union
        for subtype in self.subtypes:
            if not any(
                subtype.is_same_type(other_subtype) for other_subtype in other.subtypes
            ):
                return False

        return True

    def is_assignable_to(self, target: TypeBase) -> bool:
        """Check if this union type can be assigned to the target type."""
        # Use cache for performance
        cache_key = f"{id(self)}_{id(target)}"
        if cache_key in self._assignability_cache:
            return self._assignability_cache[cache_key]

        result = self._compute_assignability(target)
        self._assignability_cache[cache_key] = result
        return result

    def _compute_assignability(self, target: TypeBase) -> bool:
        """Compute assignability without caching."""
        if isinstance(target, UnionType):
            # Union to union: every subtype of this union must be assignable
            # to at least one subtype of the target union
            return all(
                any(
                    subtype.is_assignable_to(target_subtype)
                    for target_subtype in target.subtypes
                )
                for subtype in self.subtypes
            )
        else:
            # Union to non-union: every subtype must be assignable to the target
            return all(subtype.is_assignable_to(target) for subtype in self.subtypes)

    def can_accept_assignment_from(self, source: TypeBase) -> bool:
        """Check if this union can accept assignment from the source type."""
        if isinstance(source, UnionType):
            # Union from union: every subtype of the source must be assignable
            # to at least one subtype of this union
            return all(
                any(
                    source_subtype.is_assignable_to(target_subtype)
                    for target_subtype in self.subtypes
                )
                for source_subtype in source.subtypes
            )
        else:
            # Non-union to union: source must be assignable to at least one subtype
            return any(source.is_assignable_to(subtype) for subtype in self.subtypes)

    def narrow_type_with_condition(
        self, condition_type: TypeBase, is_positive: bool = True
    ) -> TypeBase:
        """
        Narrow this union type based on a type condition.

        Args:
            condition_type: The type to narrow with
            is_positive: True for positive narrowing (is instanceof),
                        False for negative narrowing (is not instanceof)

        Returns:
            A narrowed type (possibly another union or single type)
        """
        if is_positive:
            # Positive narrowing: keep only subtypes that are assignable to condition_type
            compatible_types = [
                subtype
                for subtype in self.subtypes
                if subtype.is_assignable_to(condition_type)
                or condition_type.is_assignable_to(subtype)
            ]
        else:
            # Negative narrowing: keep only subtypes that are NOT assignable to condition_type
            compatible_types = [
                subtype
                for subtype in self.subtypes
                if not subtype.is_assignable_to(condition_type)
                and not condition_type.is_assignable_to(subtype)
            ]

        if not compatible_types:
            # Narrowing results in no compatible types - return Never
            from .special_types import NeverType

            return NeverType()
        elif len(compatible_types) == 1:
            # Narrowing results in a single type
            return compatible_types[0]
        else:
            # Narrowing results in a smaller union
            return UnionType(compatible_types)

    def contains_type(self, type_to_check: TypeBase) -> bool:
        """Check if this union contains a specific type."""
        return any(subtype.is_same_type(type_to_check) for subtype in self.subtypes)

    def contains_assignable_type(self, type_to_check: TypeBase) -> bool:
        """Check if this union contains a type assignable to the given type."""
        return any(subtype.is_assignable_to(type_to_check) for subtype in self.subtypes)

    def get_common_base_type(self) -> Optional[TypeBase]:
        """
        Get the most specific common base type of all subtypes.

        Returns None if no common base type exists.
        """
        if not self.subtypes:
            return None

        if len(self.subtypes) == 1:
            return self.subtypes[0]

        # For now, return None - this can be enhanced with inheritance hierarchy
        # analysis in later commits
        return None

    def get_primitive_subtypes(self) -> List[TypeBase]:
        """Get only the primitive type subtypes from this union."""
        from .primitive_types import PrimitiveType

        return [
            subtype for subtype in self.subtypes if isinstance(subtype, PrimitiveType)
        ]

    def get_non_primitive_subtypes(self) -> List[TypeBase]:
        """Get only the non-primitive type subtypes from this union."""
        from .primitive_types import PrimitiveType

        return [
            subtype
            for subtype in self.subtypes
            if not isinstance(subtype, PrimitiveType)
        ]

    def is_optional_type(self) -> bool:
        """
        Check if this is an optional type (union with None/null).

        Returns True if the union contains exactly two types,
        one of which represents None/null.
        """
        if len(self.subtypes) != 2:
            return False

        # Check if one of the subtypes represents None/null
        # This can be enhanced when we add proper None/null types
        return False

    def get_non_none_type(self) -> Optional[TypeBase]:
        """
        If this is an optional type, return the non-None type.
        Otherwise return None.
        """
        if not self.is_optional_type():
            return None

        # Implementation will be enhanced when we add proper None/null types
        return None

    def get_display_name(self) -> str:
        """Get the display name for this union type."""
        if not self.subtypes:
            return "never"  # Empty union is never

        if len(self.subtypes) == 1:
            return self.subtypes[0].get_display_name()

        # Sort display names for consistent output
        subtype_names = sorted(subtype.get_display_name() for subtype in self.subtypes)
        return " | ".join(subtype_names)

    def __str__(self) -> str:
        """String representation of the union type."""
        return self.get_display_name()

    def __repr__(self) -> str:
        """Detailed string representation of the union type."""
        return f"UnionType({[repr(subtype) for subtype in self.subtypes]})"

    def __len__(self) -> int:
        """Return the number of subtypes in this union."""
        return len(self.subtypes)

    def __iter__(self):
        """Allow iteration over the subtypes."""
        return iter(self.subtypes)

    def __contains__(self, type_to_check: TypeBase) -> bool:
        """Check if a type is contained in this union using 'in' operator."""
        return self.contains_type(type_to_check)


def create_union_type(types: List[TypeBase]) -> TypeBase:
    """
    Factory function to create a union type with proper normalization.

    If the normalized union has only one type, returns that type directly.
    If the union is empty, returns Never type.
    """
    if not types:
        from .special_types import NeverType

        return NeverType()

    union = UnionType(types)

    # If normalization resulted in a single type, return it directly
    if len(union.subtypes) == 1:
        return union.subtypes[0]

    return union


def is_union_type(type_instance: TypeBase) -> bool:
    """Check if a type is a union type."""
    return isinstance(type_instance, UnionType)


def get_union_subtypes(type_instance: TypeBase) -> List[TypeBase]:
    """Get the subtypes of a union, or a single-item list for non-unions."""
    if isinstance(type_instance, UnionType):
        return type_instance.subtypes.copy()
    else:
        return [type_instance]
