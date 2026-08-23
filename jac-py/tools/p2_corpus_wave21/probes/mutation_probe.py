"""Ground-truth lazy-iterator mutation probes for wave 21 (run with python3).

Create iterators over a list, mutate the list after creation, and print
what each iterator actually yields. The same probes run through the jac
leaf gate must produce identical output.
"""
import itertools


def take(it, n):
    out = []
    for _ in range(n):
        try:
            out.append(next(it))
        except StopIteration:
            break
    return out


def drain(it):
    return take(it, 50)


# Probe 1: chain over a list mutated after creation
lst = [1, 2, 3]
ch = itertools.chain(lst, ["tail"])
lst.append(4)
lst[0] = 99
print("chain:", drain(ch))

# Probe 2: islice(start=1) over a list mutated after creation
lst2 = [10, 20, 30, 40]
isl = itertools.islice(lst2, 1, None)
lst2.append(50)
lst2[1] = -20
print("islice:", drain(isl))

# Probe 3: zip_longest over two lists, left one mutated after creation
la = [1, 2, 3]
lb = ["a", "b"]
zl = itertools.zip_longest(la, lb, fillvalue="FILL")
la.append(4)
la[0] = -1
print("zip_longest:", drain(zl))

# Probe 4: islice step>1 clamp at stop
print("islice_step:", list(itertools.islice(range(100), 2, 10, 3)))

# Probe 5: groupby head-runs peel per outer next()
keys = [1, 1, 2, 2, 2, 3]
groups = [(k, len(list(g))) for k, g in itertools.groupby(keys)]
print("groupby:", groups)

# Probe 6: batched short tail, strict vs lenient
print("batched:", [list(b) for b in itertools.batched([1, 2, 3, 4, 5], 2)])
try:
    list(itertools.batched([1, 2, 3, 4, 5], 2, strict=True))
except ValueError as e:
    print("batched_strict: ValueError:", e)

# Probe 7: takewhile/dropwhile sticky flips
seq = [1, 2, 3, 1, 2]
print("takewhile:", list(itertools.takewhile(lambda x: x < 3, seq)))
print("dropwhile:", list(itertools.dropwhile(lambda x: x < 3, seq)))

# Probe 8: date/timedelta kernel ground truths
from datetime import date, timedelta

for ordinal in (1, 365, 366, 730, 1461, 36524, 36525, 146097, 719162,
                738889, 3652059):
    d = date.fromordinal(ordinal)
    print("ord_to_ymd:", ordinal, d.year, d.month, d.day,
          "weekday", d.weekday(), "roundtrip", d.toordinal())
print("is_leap:", [(y, (date(y, 3, 1) - date(y, 2, 28)).days == 2)
                   for y in (1900, 2000, 2023, 2024, 2100)])
print("iso_week1_monday:", [date.fromisocalendar(y, 1, 1).toordinal()
                            for y in (1, 4, 5, 100, 400, 2021, 2026)])
td = timedelta(days=-3, seconds=-7200, microseconds=-123456)
print("timedelta_norm:", td.days, td.seconds, td.microseconds)
