# M12 scenario A: athrow(ValueError) into a suspended async gen, caught
# INSIDE the gen. After the except block the gen resumes and yields 99,
# then exhausts with StopAsyncIteration.


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
        yield 2
    except ValueError as e:
        print("A inner-caught:", e)
        walk("A-inner", e)
    yield 99


a = agen()
print("A first:", drive(a.asend(None)))
print("A threw:", drive(a.athrow(ValueError("boom"))))
try:
    drive(a.asend(None))
    print("A BUG: expected StopAsyncIteration")
except StopAsyncIteration:
    print("A exhausted")
print("A done")
