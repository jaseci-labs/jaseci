# Guest<->host coroutine bridge pins (asyncio interop lane).
#
# Each fixture drives guest Python coroutines/async-generators through the real
# host asyncio event loop: to_host presents a native PyGenerator(t="coroutine")
# as a REAL host awaitable (send/throw/close/__await__, collections.abc.Coroutine
# registered so asyncio.iscoroutine accepts it) whose every drive marshals into
# frame resumption -- never drained. Covers: asyncio.run/gather/TaskGroup over
# guest coroutines, exception fidelity in both directions (guest raise surfaces
# at asyncio.run with its original instance; host-raised errors stay catchable
# by guest except clauses), task.cancel() landing CancelledError inside the
# guest frame, type(_coro).__name__ reporting `coroutine`, and async-for over a
# guest async generator from host code.

import from objects { PyObj, PyStr, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<coro_bridge>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

# Run a host-side async scenario against every `_coro*` binding of the guest
# namespace. The scenario defines `main()` and must return its verdict; this
# helper runs it under the host loop and reports [ok, result-or-error-text].
def run_async(scenario_body: str, guest_src: str) -> list[any] {
    import asyncio;
    ns = vm_exec(guest_src);
    g: dict[str, any] = {"asyncio": asyncio};
    for k in ns {
        if k.startswith("_coro") {
            g[k] = to_host(ns[k]);
        }
    }
    scenario = scenario_body + "\n_result_ = asyncio.run(main())\n";
    try {
        exec(scenario, g);
    } except BaseException as e {
        return [False, type(e).__name__ + ": " + str(e)];
    }
    return [True, str(g["_result_"])];
}

test "asyncio.run awaits a guest coroutine to its return value" {
    r = run_async(
        "async def main():\n"
        "    return await _coro\n",
        "async def _coro():\n"
        "    return 42\n"
        "_coro = _coro()\n"
    );
    assert r[0], str(r[1]);
    assert str(r[1]) == "42", str(r[1]);
}

test "gather over guest coroutines with sleep(0)" {
    r = run_async(
        "async def main():\n"
        "    return await asyncio.gather(_coro, _coro1)\n",
        "import asyncio\n"
        "async def mk():\n"
        "    await asyncio.sleep(0)\n"
        "    return 7\n"
        "_coro = mk()\n"
        "_coro1 = mk()\n"
    );
    assert r[0], str(r[1]);
    assert str(r[1]) == "[7, 7]", str(r[1]);
}

test "task group over guest coroutines" {
    r = run_async(
        "async def main():\n"
        "    async with asyncio.TaskGroup() as tg:\n"
        "        t1 = tg.create_task(_coro1)\n"
        "        t2 = tg.create_task(_coro2)\n"
        "    return t1.result() + t2.result()\n",
        "import asyncio\n"
        "async def mk():\n"
        "    await asyncio.sleep(0)\n"
        "    return 20\n"
        "_coro1 = mk()\n"
        "_coro2 = mk()\n"
    );
    assert r[0], str(r[1]);
    assert str(r[1]) == "40", str(r[1]);
}

test "guest exception propagates out of asyncio.run" {
    r = run_async(
        "async def main():\n"
        "    return await _coro\n",
        "async def _coro():\n"
        "    raise ValueError('boom')\n"
        "_coro = _coro()\n"
    );
    assert not r[0];
    assert "ValueError: boom" == str(r[1]), str(r[1]);
}

test "host-thrown exception enters the suspended guest frame and is catchable" {
    # Drive the guest coroutine to its first suspension, then inject a host
    # exception via throw(); the guest's own except clause recovers and its
    # return value surfaces as StopIteration.value -- CPython's exact contract.
    r = run_async(
        "async def main():\n"
        "    yielded = _coro.send(None)\n"
        "    assert yielded is not None\n"
        "    try:\n"
        "        _coro.throw(RuntimeError('injected'))\n"
        "    except StopIteration as e:\n"
        "        return 'guest-caught:' + str(e.value)\n"
        "    except RuntimeError as e:\n"
        "        return 'escaped:' + str(e)\n"
        "    return 'no-exc'\n",
        "import asyncio\n"
        "async def _coro():\n"
        "    try:\n"
        "        await asyncio.sleep(100)\n"
        "    except RuntimeError:\n"
        "        return 'caught-in-guest'\n"
        "    return 'done'\n"
        "_coro = _coro()\n"
    );
    assert r[0], str(r[1]);
    assert str(r[1]) == "guest-caught:caught-in-guest", str(r[1]);
}

test "task.cancel raises CancelledError inside the guest frame" {
    # The guest observes the cancellation explicitly and re-raises; the task
    # still ends Cancelled for the awaiting host side.
    r = run_async(
        "async def main():\n"
        "    task = asyncio.create_task(_coro)\n"
        "    await asyncio.sleep(0)\n"
        "    task.cancel()\n"
        "    try:\n"
        "        await task\n"
        "    except asyncio.CancelledError:\n"
        "        return 'cancelled'\n"
        "    return 'not-cancelled'\n",
        "import asyncio\n"
        "async def _coro():\n"
        "    try:\n"
        "        await asyncio.sleep(100)\n"
        "    except asyncio.CancelledError:\n"
        "        raise\n"
        "    return 'done'\n"
        "_coro = _coro()\n"
    );
    assert r[0], str(r[1]);
    assert str(r[1]) == "cancelled", str(r[1]);
}

test "cancel without guest handling surfaces CancelledError at await" {
    r = run_async(
        "async def main():\n"
        "    task = asyncio.create_task(_coro)\n"
        "    await asyncio.sleep(0)\n"
        "    task.cancel()\n"
        "    try:\n"
        "        await task\n"
        "    except asyncio.CancelledError:\n"
        "        return 'cancelled'\n"
        "    return 'not-cancelled'\n",
        "import asyncio\n"
        "async def _coro():\n"
        "    await asyncio.sleep(100)\n"
        "    return 'done'\n"
        "_coro = _coro()\n"
    );
    assert r[0], str(r[1]);
    assert str(r[1]) == "cancelled", str(r[1]);
}

test "bridged coroutine presents the CPython coroutine surface" {
    r = run_async(
        "async def main():\n"
        "    names_ok = type(_coro).__name__ == 'coroutine'\n"
        "    methods_ok = all(\n"
        "        hasattr(_coro, m)\n"
        "        for m in ('send', 'throw', 'close', '__await__')\n"
        "    )\n"
        "    return names_ok and methods_ok and bool(await _coro)\n",
        "async def _coro():\n"
        "    return 1\n"
        "_coro = _coro()\n"
    );
    assert r[0], str(r[1]);
    assert str(r[1]) == "True", str(r[1]);
}

test "async for over a guest async generator from host" {
    r = run_async(
        "async def main():\n"
        "    out = []\n"
        "    async for x in _coro:\n"
        "        out.append(x)\n"
        "    return out\n",
        "async def _coro():\n"
        "    yield 1\n"
        "    yield 2\n"
        "    yield 3\n"
        "_coro = _coro()\n"
    );
    assert r[0], str(r[1]);
    assert str(r[1]) == "[1, 2, 3]", str(r[1]);
}

test "guest async-for drives its own async generator" {
    ns = vm_exec(
        "async def agen():\n"
        "    yield 1\n"
        "    yield 2\n"
        "async def main():\n"
        "    out = []\n"
        "    async for x in agen():\n"
        "        out.append(x)\n"
        "    return out\n"
        "_coro = main()\n"
    );
    import asyncio;
    result = None;
    err_txt = "";
    try {
        result = asyncio.run(to_host(ns["_coro"]));
    } except BaseException as e {
        err_txt = type(e).__name__ + ": " + str(e);
    }
    assert str(result) == "[1, 2]", "failed: " + err_txt;
}

test "in-body await inside a guest async generator suspends to the host loop" {
    r = run_async(
        "async def main():\n"
        "    out = []\n"
        "    async for x in _coro1:\n"
        "        out.append(x)\n"
        "    return out\n",
        "import asyncio\n"
        "async def agen():\n"
        "    yield 1\n"
        "    await asyncio.sleep(0)\n"
        "    yield 2\n"
        "_coro1 = agen()\n"
    );
    assert r[0], str(r[1]);
    assert str(r[1]) == "[1, 2]", str(r[1]);
}
