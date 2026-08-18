"""Every import shape that binds a deprecated typing alias must be refused (E1123).

The aliases are the PEP 585 twins of builtins jac already subscripts directly:
`List`/`Dict`/`Tuple`/`Set`/`FrozenSet`/`Type` say nothing `list`/`dict`/`tuple`/
`set`/`frozenset`/`type` do not, so like `Any` before them they are refused at
the import rather than tolerated as a second spelling.

Five statements, six refusals:
  - a lone `{ List }` import
  - `Dict` in the middle of a multi-name list
  - the `as` alias form, which binds the deprecated name just as surely
  - `Set` and `FrozenSet` together in one list (two refusals from one statement)
  - `Type`, the one whose builtin twin is not a container

The sibling names (`Optional`, `Callable`, `cast`) are the control: only the
deprecated aliases are refused, the rest of typing stays importable.
"""

import from typing { List }
import from typing { Optional, Dict, cast }
import from typing { Tuple as Pair }
import from typing { Set, FrozenSet }
import from typing { Callable, Type }

def uses(
    a: List[int],
    b: Dict[str, int],
    c: Pair[int, int],
    d: Set[int],
    e: FrozenSet[int],
    f: Type[int],
    g: Optional[int],
    cb: Callable[[], None]
) {
    print(a, b, c, d, e, f, cast(int, g), cb);
}
