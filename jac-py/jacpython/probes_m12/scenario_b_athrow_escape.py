# M12 scenario B: athrow(ValueError) escaping the async gen to the awaiting
# caller. Nothing in the gen catches; the caller sees the exception with the
# gen's frame on the chain, and the gen is left closed.


def walk(tag, exc):
    tb = exc.__traceback__
    n = 0
    while tb is not None:
        name = tb.tb_frame.f_code.co_name
        print("%s frame[%d]=%s line=%d" % (tag, n, name, tb.tb_lineno))
        tb = tb.tb_next
        n += 1


async def _run(aw):
    return await aw


def drive(aw):
    # Drive an agen/coroutine step (asend/athrow/__anext__ result) to
    # completion through one await; nothing here suspends on real futures.
    try:
        fut = _run(aw).send(None)
    except StopIteration as e:
        return e.value
    raise AssertionError("suspended on %r" % (fut,))


async def agen():
    try:
        yield 1
    finally:
        print("B finally ran")


a = agen()
print("B first:", drive(a.asend(None)))
try:
    drive(a.athrow(ValueError("escape")))
    print("B BUG: no raise")
except ValueError as e:
    print("B escaped:", e)
    walk("B", e)
try:
    drive(a.asend(None))
    print("B BUG: expected StopAsyncIteration")
except StopAsyncIteration:
    print("B post-exhausted")
print("B done")
