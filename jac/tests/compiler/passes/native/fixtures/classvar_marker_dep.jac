"""A dependency whose only compile-time import is `ClassVar`.

`ClassVar[T]` names where a slot lives, not a value the program computes, so
the native lane erases it exactly as it erases `TypeAlias`. Before `ClassVar`
joined the compile-time vocabulary the import in front of this declaration was
enough to refuse the module at placement, and no consumer could link it.

`KIND` is declared and not read: a class-level slot is not part of the
instance layout the backend emits against, so reading one off the class is a
separate gap (waived in `test_type_system_seal_census` as
`TypeBase.category.__get__`). What is measured here is that declaring one no
longer costs the module its place in a native unit.
"""

import from typing { ClassVar }


obj Tagged {
    with entry {
        KIND: ClassVar[int] = 7;
    }

    has value: int = 0;

    def doubled -> int {
        return self.value * 2;
    }
}


def make_tagged(value: int) -> Tagged {
    return Tagged(value=value);
}
