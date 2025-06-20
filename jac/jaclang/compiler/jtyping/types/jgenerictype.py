from __future__ import annotations

from typing import Optional

from jaclang.compiler.jtyping.types.jclassmember import JClassMember
from jaclang.compiler.jtyping.types.jclasstype import JClassType
from jaclang.compiler.jtyping.types.jfuncargtype import JFuncArgument
from jaclang.compiler.jtyping.types.jfunctionttype import JFunctionType
from jaclang.compiler.jtyping.types.jtype import JType
from jaclang.compiler.jtyping.types.jtypevar import JTypeVar
from jaclang.compiler.jtyping.types.juniontype import JUnionType


class JGenericType(JType):
    """
    Represents a generic class type with concrete type arguments applied.

    This type wraps a `JClassType` that was originally defined with type variables,
    and substitutes those type variables with the provided concrete types.

    For example, given a generic class `List[T]`, a `JGenericType` with arguments `[int]`
    would represent `List[int]`. Internally, it builds a specialized version of the
    original class with updated member types and no remaining generics.

    Attributes:
        args (list[JType]): The concrete types used to specialize the base generic.
        base (JClassType): The resulting class type after type substitution.
    """

    def __init__(
        self, base: JClassType, args: list[JClassType | JGenericType | JUnionType]
    ) -> None:
        """
        Initialize a new generic type instance.

        Args:
            base (JClassType): The generic class definition (e.g., `List`).
            args (list[JType]): The type arguments to apply (e.g., `[int]`).
        """
        self.args: list[JClassType | JGenericType | JUnionType] = args
        self.base: JClassType = self.__specialize_base(base, args)
        name = f"{base.name}[{', '.join(arg.name for arg in args)}]"
        super().__init__(name=name, module=base.module)

    def is_instantiable(self) -> bool:
        """
        Determine if this generic type can be instantiated.

        Delegates to the underlying specialized base type.

        Returns:
            bool: True if instantiable, False otherwise.
        """
        return self.base.is_instantiable()

    def can_assign_from(self, other: JType) -> bool:
        """
        Check if a value of another type can be assigned to this generic type.

        Args:
            other (JType): The type being assigned.

        Returns:
            bool: True if assignable, False otherwise.
        """
        if not isinstance(other, JGenericType):
            return False
        if not self.base.can_assign_from(other.base):
            return False
        if len(self.args) != len(other.args):
            return False
        return all(a.can_assign_from(b) for a, b in zip(self.args, other.args))

    def supports_binary_op(self, op: str) -> bool:
        """
        Check if the given binary operator is supported on this type.

        Currently returns False for all operators.

        Args:
            op (str): The binary operator symbol (e.g., '+', '*').

        Returns:
            bool: Always False.
        """
        return False

    def __repr__(self) -> str:
        """
        Return a string representation of the generic type.

        Returns:
            str: The string form, e.g., "List[int]".
        """
        return f"{self.base.full_name}[{', '.join(str(arg) for arg in self.args)}]"

    def get_member(self, name: str) -> Optional[JClassMember]:
        """
        Retrieve a member by name from the specialized base type.

        Args:
            name (str): The member name.

        Returns:
            Optional[JClassMember]: The member, if found.
        """
        return self.base.get_member(name)

    def get_members(self) -> dict[str, JClassMember]:
        """
        Get all members (fields, methods, etc.) of the specialized type.

        Returns:
            dict[str, JClassMember]: A mapping of member names to their definitions.
        """
        return self.base.get_members()

    def __specialize_base(
        self, base: JClassType, args: list[JClassType | JGenericType | JUnionType]
    ) -> JClassType:
        """
        Specialize a generic class type by substituting its type variables with concrete types.

        This method instantiates a generic class (`JClassType`) using a list of resolved type arguments.
        It performs the following steps:

        1. Creates a mapping from the class's type variables to the provided type arguments.
        2. Recursively substitutes all type variables within the member types using this mapping.
        3. Constructs a new `JClassType` with updated members and no remaining generics.

        Args:
            base (JClassType): The generic class type to specialize.
            args (list[JType]): A list of concrete types to substitute in place of the class's type variables.

        Returns:
            JClassType: A new class type with type variables fully substituted.

        Note:
            - The returned type has an empty `generics` field, indicating full specialization.
            - `assignable_from` is reset and should be recomputed by the caller if needed.
        """
        from jaclang.compiler.jtyping.types.jclassinstance import JClassInstanceType

        typevar_map: dict[str, JClassType | JGenericType | JUnionType] = dict(
            zip(base.generics_vars.keys(), args)
        )

        def substitute_typevars(t: JType) -> JType:
            if isinstance(t, JTypeVar):
                return typevar_map.get(t.name, t)

            if isinstance(t, JClassInstanceType) and isinstance(t.class_type, JTypeVar):
                return typevar_map.get(t.class_type.name, t.class_type)

            if isinstance(t, JFunctionType):
                new_params = [
                    JFuncArgument(
                        name=param.name,
                        type=substitute_typevars(param.type),
                        is_optional=param.is_optional,
                    )
                    for param in t.parameters
                ]
                new_ret = substitute_typevars(t.return_type)
                return JFunctionType(new_params, new_ret)

            if isinstance(t, JGenericType):
                new_args: list[JGenericType | JClassType | JUnionType] = []
                for a in t.args:
                    a_new = substitute_typevars(a)
                    assert isinstance(a_new, (JGenericType, JClassType, JUnionType))
                    new_args.append(a_new)
                return JGenericType(t.base, new_args)

            return t

        instance_members = {
            name: JClassMember(
                name=m.name,
                type=substitute_typevars(m.type),
                kind=m.kind,
                visibility=m.visibility,
                is_method=m.is_method,
                decl=m.decl,
            )
            for name, m in base.instance_members.items()
        }

        class_members = {
            name: JClassMember(
                name=m.name,
                type=substitute_typevars(m.type),
                kind=m.kind,
                visibility=m.visibility,
                is_method=m.is_method,
                decl=m.decl,
            )
            for name, m in base.class_members.items()
        }

        return JClassType(
            name=base.name,
            full_name=base.full_name,
            module=base.module,
            is_abstract=base.is_abstract,
            instance_members=instance_members,
            class_members=class_members,
            assignable_from=[],  # Can be filled if inheritance chain is needed
            generics={},  # Specialization removes all generics
        )
