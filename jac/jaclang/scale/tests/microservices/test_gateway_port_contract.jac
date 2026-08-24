"""A named gateway port is a contract, the same as on the plain serve path.

`serve()` dispatches microservice projects to the gateway and returns before
the plain path's port handling ever runs, so these two paths had to be pinned
separately: a project carrying [scale.microservices.routes] walked off a
pinned port and announced the port it had asked for rather than the one it
bound (jac#8387). Nothing covered that path, which is why it survived review.
"""

import os;
import socket;
import subprocess;
import from pathlib { Path }

import from jaclang.scale.runtime.context.util { jac_executable }


glob _FIXTURES: Path = Path(__file__).parent.parent
         / "fixtures"
         / "microservice_port";


"""A port nothing is listening on."""
def _free_port -> int {
    probe = socket.socket();
    probe.bind(("127.0.0.1", 0));
    chosen = probe.getsockname()[1];
    probe.close();
    return chosen;
}


"""Run the fixture through the gateway path and return `(returncode, output)`."""
def _serve(args: list[str], timeout: int = 420) -> tuple {
    proc = subprocess.Popen(
        [jac_executable(), "run", "--serve"] + args,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        cwd=str(_FIXTURES)
    );
    try {
        (output, _unused) = proc.communicate(timeout=timeout);
        return (proc.returncode, output);
    } except subprocess.TimeoutExpired {
        proc.kill();
        (output, _unused) = proc.communicate();
        return (None, output);
    } finally {
        if proc.poll() is None {
            proc.kill();
        }
    }
}


test "a gateway refuses a pinned port instead of walking off it" {
    holder = socket.socket();
    holder.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    holder.bind(("0.0.0.0", 0));
    taken = holder.getsockname()[1];
    holder.listen(5);
    try {
        # Generous: a cold run compiles the whole toolchain before it ever
        # reaches the bind, and a timeout here reads as "did not refuse".
        (code, output) = _serve(["--port", str(taken)]);
        assert code is not None and code != 0 , (
            "a microservice project asked for a port something else holds must "
            f"exit non-zero rather than relocating, got {code}: {output[-400:]!r}"
        );
        assert str(taken) in output , (
            f"the failure must name the port that was asked for: {output[-400:]!r}"
        );
    } finally {
        holder.close();
    }
}


test "a gateway announces the port it bound, not the one it wanted" {
    holder = socket.socket();
    holder.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    holder.bind(("0.0.0.0", 0));
    taken = holder.getsockname()[1];
    holder.listen(5);
    try {
        # No --port, so the default may relocate. Whatever it lands on, the
        # banner has to name that one: a banner printed before the bind can
        # only report a request, and a request is not an address anyone can
        # reach (jac#8387 item 2).
        (_code, output) = _serve([], timeout=240);
        assert f"Gateway: http://0.0.0.0:{taken}" not in output , (
            "the gateway announced a port it could not have bound, which is "
            f"the banner reporting a request: {output[-400:]!r}"
        );
    } finally {
        holder.close();
    }
}


test "an unnamed port still relocates rather than failing" {
    # The other half of the contract. Naming a port opts into failure; not
    # naming one must keep the old forgiving behaviour, or every developer
    # running two projects at once is broken.
    probe = socket.socket();
    probe.bind(("0.0.0.0", 0));
    free = probe.getsockname()[1];
    probe.close();
    (code, output) = _serve(["--port", str(free)], timeout=60);
    assert code != 0 or "is already in use" not in output , (
        f"a free named port must not be refused: {output[-300:]!r}"
    );
}
