# M12 scenario C: async-for over an agen that raises mid-iteration.
# The KeyError must propagate out of the async-for into the enclosing frame.


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
    raise KeyError("mid")


async def main():
    got = []
    try:
        async for v in agen():
            got.append(v)
    except KeyError as e:
        print("C caught:", e)
        walk("C", e)
    print("C got:", got)


drive(main())
print("C done")
