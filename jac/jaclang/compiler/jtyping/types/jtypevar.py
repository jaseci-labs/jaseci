from typing import Optional
import jaclang.compiler.unitree as uni
from jaclang.compiler.jtyping.types.jtype import JType
from jaclang.compiler.jtyping.types.jclassmember import JClassMember


class JTypeVar(JType):
    """
    Represents a type variable in the Jac type system, used in generic type definitions.

    A `JTypeVar` acts as a placeholder for a concrete type and is resolved during
    type inference or unification. Once resolved, it points to a `JClassType`.

    Attributes:
        name (str): The name of the type variable.
        resolved (Optional[JClassType]): The concrete type this variable has been unified to, if any.
    """

    _id_counter = 0

    def __init__(self, name: str) -> None:
        """
        Initialize a new type variable.

        Args:
            name (str): The name of the type variable (e.g., 'T').
        """
        from jaclang.compiler.jtyping.types.jclassinstance import JClassType
        self.module = None
        self.name = name
        self.resolved: Optional[JClassType] = None  # After unification

    def __repr__(self) -> str:
        """
        Return a string representation of the type variable.

        If the type variable has been resolved, show its binding.
        Otherwise, show it as a free type variable.

        Returns:
            str: The string representation.
        """
        if self.resolved:
            return f"{self.name}={self.resolved}"
        return f"TypeVar[{self.name}]"

    def is_instantiable(self) -> bool:
        """
        Indicates whether the type can be directly instantiated at runtime.

        A type variable cannot be instantiated directly, hence always returns False.

        Returns:
            bool: False
        """
        return False

    def get_members(self) -> dict[str, JClassMember]:
        """
        Returns the accessible members of the type.

        If the type variable has been resolved, delegates to the resolved type's members.
        Otherwise, returns an empty dict.

        Returns:
            dict[str, JClassMember]: Mapping of member names to their definitions.
        """
        if self.resolved:
            return self.resolved.get_members()
        else:
            return {}

    def supports_binary_op(self, op: str) -> bool:
        """
        Checks whether a binary operator is supported by this type.

        Always returns False unless resolved to a concrete type.

        Args:
            op (str): The operator symbol (e.g., '+', '*', '==').

        Returns:
            bool: False (default behavior for unresolved type vars).
        """
        return False

    def can_assign_from(self, other: JType) -> bool:
        """
        Determines if this type can accept an assignment from another type.

        If resolved, delegates the check to the resolved type.
        Otherwise, uses default `JType` logic (usually false).

        Args:
            other (JType): The type being assigned.

        Returns:
            bool: True if assignable, False otherwise.
        """
        if self.resolved:
            return self.resolved.can_assign_from(other)
        else:
            return super().can_assign_from(other)

    @property
    def full_name(self) -> str:
        """
        Returns the fully qualified name of the type.

        If resolved, uses the resolved type's full name.
        Otherwise, returns a string representation of the type variable.

        Returns:
            str: The full name or type variable display.
        """
        if self.resolved:
            return self.resolved.full_name
        else:
            return str(self)
