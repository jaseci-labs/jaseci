"""Every import shape that binds `Any` from typing must be refused (E1122).

Four statements, four refusals:
  - a lone `{ Any }` import
  - `Any` in the middle of a multi-name list
  - the `as` alias form, which the retired W1104 used to skip outright
  - `Any` among names that are themselves ambient

Line breaks inside the brace list are not a separate case: the formatter
canonicalizes them onto one line and the item list is the same either way.

The sibling names (`Optional`, `Callable`, `cast`, `TYPE_CHECKING`) are the
control: only `Any` is refused, the rest of typing stays importable.
"""

import from typing { Any }
import from typing { Optional, Any, cast }
import from typing { Any as Whatever }
import from typing { Callable, Any, TYPE_CHECKING }

def uses(x: Optional[int], cb: Callable[[], None]) {
    print(cast(int, x), cb, TYPE_CHECKING, Whatever);
}
