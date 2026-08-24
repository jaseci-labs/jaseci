# M12 scenario D: StopAsyncIteration propagation paths.
# D1: exhausted anext raises StopAsyncIteration into the awaiting caller.
# D2: StopAsyncIteration raised inside an agen BODY must convert to
#     RuntimeError ("async generator raised StopAsyncIteration").


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
    yield 1


a = agen()
print("D first:", drive(a.asend(None)))
try:
    drive(a.asend(None))
    print("D BUG: expected StopAsyncIteration")
except StopAsyncIteration as e:
    print("D stopasync caught:", repr(e))
    walk("D", e)


async def bad():
    raise StopAsyncIteration("from body")
    yield 1


b = bad()
try:
    drive(b.asend(None))
    print("D2 BUG: no error")
except RuntimeError as e:
    print("D2 runtimeerror:", e)
    walk("D2", e)
except BaseException as e:
    print("D2 WRONG-TYPE:", type(e).__name__, e)
    walk("D2-wrong", e)
print("D done")
