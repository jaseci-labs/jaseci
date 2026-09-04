"""A named gateway port is a contract, the same as on the plain serve path.

`serve()` dispatches microservice projects to the gateway and returns before
the plain path's port handling ever runs, so these two paths had to be pinned
separately: a project carrying [scale.microservices.routes] walked off a
pinned port and announced the port it had asked for rather than the one it
bound (jac#8387). Nothing covered that path, which is why it survived review.
"""

import os;
import re;
import shutil;
import signal;
import socket;
import subprocess;
import tempfile;
import threading;
import time;
import from pathlib { Path }

import from jaclang.scale.runtime.context.util { jac_executable }
import from jaclang.scale.tests.support { get_free_port }


glob _FIXTURES: Path = Path(__file__).parent.parent
         / "fixtures"
         / "microservice_port";


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


"""Drain a pipe into `sink` so the child never blocks on a full buffer."""
def _pump(stream: any, sink: list) {
    try {
        for line in iter(stream.readline, '') {
            sink.append(line);
        }
    } except Exception {}
}


"""Stop the process group, so the gateway's spawned services go with it."""
def _kill_tree(proc: any) {
    try {
        os.killpg(os.getpgid(proc.pid), int(signal.SIGTERM));
    } except Exception {}
    try {
        proc.`wait(timeout=10);
    } except Exception {
        try {
            os.killpg(os.getpgid(proc.pid), int(signal.SIGKILL));
        } except Exception {}
    }
}


"""Serve, wait for the gateway banner, and connect to the port it announced.

The connect has to happen while the process is still alive. Reading the banner
off a finished run only proves what was printed, and item 2 of #8387 is a claim
about what is reachable, not about what was printed. Returns
`(announced_port, reachable, output)`, with `announced_port` 0 if no banner
arrived before the deadline.
"""
def _serve_and_probe(args: list[str], cwd: str, timeout: int = 300) -> tuple {
    proc = subprocess.Popen(
        [jac_executable(), "run", "--serve"] + args,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        cwd=cwd,
        start_new_session=True
    );
    lines: list = [];
    pump = threading.Thread(target=_pump, args=(proc.stdout, lines), daemon=True);
    pump.start();
    announced = 0;
    deadline = time.time() + timeout;
    while time.time() < deadline {
        for line in list(lines) {
            found = re.search(r"Gateway: http://[\d.]+:(\d+)", line);
            if found {
                announced = int(found.group(1));
                break;
            }
        }
        if announced or proc.poll() is not None {
            break;
        }
        time.sleep(0.5);
    }
    reachable = False;
    if announced {
        probe = socket.socket();
        probe.settimeout(5);
        reachable = probe.connect_ex(("127.0.0.1", announced)) == 0;
        probe.close();
    }
    _kill_tree(proc);
    pump.join(timeout=5);
    return (announced, reachable, "".join(lines));
}


"""A copy of the fixture whose config asks for `port` as the gateway port.

A config `gateway_port` is deliberately not pinned, so the gateway relocates off
it when it is taken. That is the only way to make the relocation case
deterministic without assuming some fixed port is free on the runner.
"""
def _fixture_wanting(port: int) -> str {
    dst = tempfile.mkdtemp(prefix="jac_gateway_port_");
    for name in ["main.jac", "echo_service.jac"] {
        shutil.copy(str(_FIXTURES / name), os.path.join(dst, name));
    }
    with open(os.path.join(dst, "jac.toml"), "w") as handle {
        handle.write(
            '[project]\n'
            'name = "microservice-port-fixture"\n'
            'entry-point = "main.jac"\n'
            '\n'
            '[scale.microservices]\n'
            f'gateway_port = {port}\n'
            '\n'
            '[scale.microservices.routes]\n'
            'echo_service = "/echo"\n'
        );
    }
    return dst;
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


test "the gateway announces a port that is actually listening" {
    # Item 2 of #8387 is a positive claim: the address on the banner is one you
    # can reach. Forcing a relocation is what makes it discriminating. Before
    # the fix the banner named the port that was *wanted*, which here is the one
    # the holder still owns, so asserting "announced is not the held port, and
    # something answers on it" fails on main and passes here.
    wanted = get_free_port();
    holder = socket.socket();
    holder.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    holder.bind(("0.0.0.0", wanted));
    holder.listen(5);
    workdir = _fixture_wanting(wanted);
    try {
        (announced, reachable, output) = _serve_and_probe([], workdir);
        assert announced , (
            f"the gateway announced no address at all: {output[-400:]!r}"
        );
        assert announced != wanted , (
            f"the gateway announced {announced}, which the holder still owns, so "
            f"the banner reported a request rather than a bind: {output[-400:]!r}"
        );
        assert reachable , (
            f"nothing answered on the announced port {announced}, so the banner "
            f"is not an address anyone can use: {output[-400:]!r}"
        );
    } finally {
        holder.close();
        shutil.rmtree(workdir, ignore_errors=True);
    }
}


test "a free named port is bound and served, not refused" {
    # The other half of the contract. Naming a port opts into failure only when
    # that port is taken; a free one has to come up on exactly that number. This
    # is also the check that handing the bind a retry budget of 0 did not break
    # the ordinary path.
    free = get_free_port();
    (announced, reachable, output) = _serve_and_probe(
        ["--port", str(free)], str(_FIXTURES)
    );
    assert announced == free , (
        f"a free named port must be bound as asked: wanted {free}, announced "
        f"{announced}: {output[-400:]!r}"
    );
    assert reachable , (
        f"the gateway announced {announced} but nothing answered there: "
        f"{output[-400:]!r}"
    );
}
