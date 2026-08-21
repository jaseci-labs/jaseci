"""Run the in-checkout jaclang on the bundled pbs CPython (build bootstrap).

`zig build` fetches python-build-standalone (bootstrap/fetch_pbs.zig, the one
step that runs before any Python exists) and then drives every other build
step through this shim, so the build tooling is Jac (`jaclang.payload`) and
needs no prior jac binary:

    <pbs-python> -I jacboot.py payload <subcommand> [args...]   # jaclang.payload.cli
    <pbs-python> -I jacboot.py jac <jac-cli-args...>             # the jac CLI itself

`-I` keeps the interpreter isolated from the ambient environment; the checkout
root is put on sys.path explicitly and the lazy `.jac` finder installed, which
is all importing the compiler from source takes (jaclang has no third-party
runtime dependencies).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
JAC_ROOT = os.path.dirname(HERE)


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in ("payload", "jac"):
        sys.stderr.write(
            "usage: jacboot.py payload <subcommand> [args...] | jac <args...>\n"
        )
        return 2
    sys.path.insert(0, JAC_ROOT)
    # The build must not be rerouted to a dev-source tree or a project venv:
    # this checkout IS the source being built.
    os.environ["JAC_NO_DEV_SOURCE"] = "1"
    import _jac_finder

    _jac_finder.install()
    mode = sys.argv[1]
    if mode == "payload":
        from jaclang.payload.cli import main as payload_main

        return int(payload_main(sys.argv[2:]) or 0)
    sys.argv = ["jac"] + sys.argv[2:]
    from jaclang.jac0core.cli_boot import start_cli

    start_cli()
    return 0


if __name__ == "__main__":
    sys.exit(main())
