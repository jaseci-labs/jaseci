# M12 scenario E: yield-from-equivalent delegation chain with throw.
# outer() awaits sub() and re-throws whatever arrives at its own yield into
# the delegate via athrow, so one logical throw crosses three frames:
# main -> outer -> sub -> back out through outer -> main.


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


async def sub():
    try:
        yield 1
        yield 2
    except ValueError as e:
        print("E sub saw:", e)
        walk("E-sub", e)
        raise


async def outer():
    s = sub()
    x = await anext(s)
    try:
        yield ("outer-yield", x)
    except ValueError as e:
        print("E outer saw:", e)
        walk("E-outer", e)
        await s.athrow(e)


o = outer()
print("E got:", drive(o.asend(None)))
try:
    drive(o.athrow(ValueError("arrives")))
    print("E BUG: no raise")
except ValueError as e:
    print("E escaped:", e)
    walk("E-main", e)
print("E done")
