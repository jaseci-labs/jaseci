"""Execute a differential fixture exclusively through Jac's bytecode backend."""

import os
import sys

from jaclang.compiler.frontend.codeinfo import set_effective_default_codespace
from jaclang.runtime.runtime import JacRuntime


def main() -> None:
    source = os.path.abspath(sys.argv[1])
    sys.argv = [source, *sys.argv[2:]]
    set_effective_default_codespace("server")
    JacRuntime.jac_import(
        target=os.path.basename(source)[:-4],
        base_path=os.path.dirname(source),
        override_name="__main__",
    )
    errors = JacRuntime.get_program().errors_had
    if errors:
        for error in errors:
            print(error.pretty_print(), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
