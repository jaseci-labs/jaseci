# M12 scenario F: full tb frame-name+lineno inventory for a raise that climbs
# out of an async gen through two awaited frames (agen -> mid -> leaf).
# This is the reference shape every other scenario's walk is read against.


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


async def leaf():
    raise TypeError("f-boom")


async def mid():
    await leaf()


async def agen():
    await mid()
    yield 0


a = agen()
try:
    drive(a.asend(None))
    print("F BUG: no raise")
except TypeError as e:
    print("F caught:", e)
    walk("F", e)
print("F done")
