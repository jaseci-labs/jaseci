import json
import os
from pathlib import Path

from jaclang.compiler.jtyping import (
    JClassInstanceType,
    JClassMember,
    JClassType,
    JFuncArgument,
    JFunctionType,
    JType,
    JUnionType,
)
from jaclang.compiler.jtyping.types.jclassmember import MemberKind, Visibility


BUILTIN_PATH = Path(os.path.dirname(__file__)) / "builtins.json"


class JTypeRegistry:
    """
    Global registry for all user-defined and built-in types in the Jac type system.

    Types are indexed by their fully qualified name (e.g., 'builtins.int', 'mymod.MyClass').
    """

    def __init__(self) -> None:
        self._types: dict[str, JType] = {}
        self.__load_builtin_types()

    def register(self, type_obj: JClassType) -> None:
        """
        Register a type in the global registry.

        Args:
            type_obj (JType): The type to register.
        """
        self._types[type_obj.full_name] = type_obj

    def get(self, full_name: str) -> JType | None:
        """
        Retrieve a type by its fully qualified name.

        Args:
            full_name (str): The full name (e.g., 'builtins.str').

        Returns:
            JType | None: The registered type, or None if not found.
        """
        return self._types.get(full_name)

    def get_full_name(self, type_obj: JType) -> str:
        """
        Compute the fully qualified name for a type.

        Args:
            type_obj (JType): The type whose name to compute.

        Returns:
            str: Fully qualified name like 'builtins.int'.
        """
        mod = type_obj.module.name if type_obj.module else "unknown"
        return f"{mod}.{type_obj.name}"

    def all_types(self) -> list[JType]:
        """
        Retrieve all types currently registered in the type registry.

        Returns:
            list[JType]: A list of all registered types.
        """
        return list(self._types.values())

    def __load_builtin_types(self) -> None:
        """
        Load and register built-in types and their methods into the type registry.

        This method performs the following steps:
        1. Reads a JSON file defined by `BUILTIN_PATH`, allowing for comments (lines starting with `//`).
        2. Parses the cleaned JSON content to extract built-in type definitions.
        3. Registers each built-in type as a `JClassType`, setting its name, full name, and `assignable_from` list.
        4. For each built-in type, it also registers methods (if any) by:
        - Resolving method signatures using `__make_callable_type`.
        - Creating `JClassMember` instances for each method.
        - Adding them to the type's `instance_members`.

        This ensures that both types and their associated callable methods are available for type checking.

        Raises:
            AssertionError: If a registered type is not an instance of `JClassType`.
        """
        with open(BUILTIN_PATH, "r") as file:
            # Remove comments (//) and collect cleaned lines
            lines = (line.split("//")[0].strip() for line in file)
            json_str = "\n".join(line for line in lines if line)

            # Parse the cleaned JSON
            builtin_types = json.loads("".join(json_str))

            # Register class types
            for type_name, type_info in builtin_types.items():
                class_type = JClassType(
                    name=type_name,
                    full_name=type_name,
                    module=None,
                    is_abstract=False,
                    instance_members={},
                    class_members={},
                    assignable_from=type_info.get("assignable_from", []),
                )
                self.register(class_type)

            # Register methods for each class type
            for type_name, type_info in builtin_types.items():
                full_name = type_name
                type_obj = self.get(full_name)
                assert isinstance(type_obj, JClassType)

                for method_name, sig in type_info.get("methods", {}).items():
                    args = sig.get("args", [])
                    ret = sig.get("return", "None")

                    method_type = self.__make_callable_type(args, ret)
                    type_obj.instance_members[method_name] = JClassMember(
                        name=method_name,
                        type=method_type,
                        kind=MemberKind.INSTANCE,
                        visibility=Visibility.PUBLIC,
                        is_method=True,
                        decl=None,
                    )

    def __make_callable_type(
        self, arg_types: list[list[str] | str], return_type: str
    ) -> JFunctionType:
        """
        Construct a `JFunctionType` object based on argument types and a return type.

        This function takes a list of argument types (each can be a string representing a single type,
        or a list of strings representing a union type) and a return type string. It resolves the
        types using the internal `_types` dictionary, which maps type names to `JClassType` or similar
        objects. Union types are handled by constructing a `JUnionType`.

        Args:
            arg_types (list[list[str] | str]):
                A list of argument type specifications. Each item can either be:
                - A single string (e.g., "int")
                - A list of strings (e.g., ["int", "float"]) representing a union type

            return_type (str):
                The name of the return type, which must exist in the `_types` mapping.

        Returns:
            JFunctionType:
                A function type object composed of typed arguments and the resolved return type.
        """
        # Resolve the arg type from builtins json
        resolved_types: list[JType] = []
        for arg in arg_types:
            if isinstance(arg, list):
                union_types: list[JClassType | JClassInstanceType] = []
                for t in arg:
                    resolved_type = self._types[t]
                    assert isinstance(resolved_type, JClassType)
                    union_types.append(JClassInstanceType(resolved_type))
                resolved_types.append(JUnionType(union_types))
            else:
                resolved_type = self._types[arg]
                assert isinstance(resolved_type, JClassType)
                resolved_types.append(JClassInstanceType(resolved_type))

        # Create function arguments based on their types
        resolved_args: list[JFuncArgument] = [
            JFuncArgument(name=f"arg{i}", type=typ)
            for i, typ in enumerate(resolved_types)
        ]

        return JFunctionType(
            parameters=resolved_args, return_type=self._types[return_type]
        )
