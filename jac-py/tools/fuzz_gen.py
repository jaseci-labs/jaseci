#!/usr/bin/env python3
"""Seeded generator for the jacpython-vs-CPython differential fuzz corpus.

Emits unittest-style probe sources (same schema as fuzz_corpus_pinned.json
entries: {name, src}). Each src defines a single `class T(unittest.TestCase)`
with one `test_case` method. Harness limits (see TODO.md / layer0_replay_harness):
assert args must be self-contained expressions, no try/with around asserts, so
exception probes wrap try/except inside plain function bodies and assert on
returned values.

Correctness principle: every case's setup statements are executed in a fresh
host-CPython namespace *at generation time* and each asserted expression is
evaluated there; the frozen literal is whatever host CPython computed. A case
whose setup or checks raise on the host is dropped (generator bug, not a
jacpython divergence).

Usage:
    python3 fuzz_gen.py [--seed 20260822] [--count 130] [--out FILE]

Output is a JSON array of {"name", "src"} written to FILE or stdout.
Deterministic for a given (seed, count).
"""

from __future__ import annotations

import argparse
import json
import random
import sys


class Case:
    """One probe: setup lines + assertEqual(expr, host_value) checks."""

    def __init__(self, name: str):
        self.name = name
        self.setup: list[str] = []
        self.checks: list[str] = []

    def line(self, s: str) -> None:
        self.setup.append(s)

    def eq(self, expr: str) -> None:
        self.checks.append(expr)


def freeze(case: Case) -> dict | None:
    """Run setup + checks under host CPython; return {name, src} or None."""
    ns: dict = {}
    setup_src = "\n".join(case.setup)
    try:
        exec(setup_src, ns)
        vals = [eval(expr, ns) for expr in case.checks]
    except BaseException:
        return None
    lines = list(case.setup)
    for expr, val in zip(case.checks, vals):
        lines.append(f"self.assertEqual({expr}, {val!r})")
    body = "\n".join("        " + ln for ln in lines)
    src = (
        "class T(unittest.TestCase):\n"
        "    def test_case(self):\n"
        f"{body}\n"
    )
    return {"name": case.name, "src": src}


# ---------------------------------------------------------------- arithmetic

def gen_arithmetic(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        c = Case(f"gen-arith-{i:03d}")
        big1 = rng.randrange(2**64, 2**130)
        big2 = rng.randrange(1, 2**32)
        odd = rng.choice([3, 7, -7, 13])
        variant = i % 6
        if variant == 0:
            c.line(f"a = {big1} * {big2} + {rng.randint(-17, 17)}")
            c.line(f"n = -{big1}")
            m = abs(odd)
            c.eq(f"divmod(a, {m})[0] * {m} + divmod(a, {m})[1] == a")
            c.eq(f"divmod(a, {m})[1] >= 0")
            c.eq(f"divmod(-a, {m})[1] >= 0")
            c.eq(f"divmod(-a, {m})[0] * {m} + divmod(-a, {m})[1] == -a")
        elif variant == 1:
            base = rng.randrange(-30, 30) or 11
            exp = rng.randrange(0, 12)
            mod = rng.choice([97, 1009, 65537])
            c.line(f"p = pow({base}, {exp}, {mod})")
            c.line(f"x = {rng.randint(-999, 999)}")
            c.eq(f"p == ({base} ** {exp}) % {mod}")
            c.eq("~x == -x - 1")
            c.eq(f"({base} << 3) >> 3 == {base}")
            c.eq(f"({base} >> 2) == ({base} // 4) if {base} >= 0 else True")
        elif variant == 2:
            num = rng.randint(-50, 50) or 7
            den = rng.choice([4, -4, 8, -8, 16])
            c.line(f"f = {num} / {den}")
            c.line(f"fl = {num} // {den}")
            c.line(f"m = {num} % {den}")
            c.eq(f"fl * {den} + m == {num}")
            c.eq(f"m == 0 or (m > 0) != ({den} < 0)")
            c.eq(f"divmod({num}, {den})[1] == m")
            c.eq(f"round(f, 6) == round({num} / {den}, 6)")
        elif variant == 3:
            v = rng.randrange(2**70, 2**90)
            c.line(f"v = {v}")
            c.eq("abs(-v) == v")
            c.eq("round(v / 3) * 3 <= v + 2")
            c.eq("int.from_bytes(v.to_bytes(12, 'little'), 'little') == v")
            c.eq("v.bit_length() > 60")
        elif variant == 4:
            s = rng.choice(["10", " 42 ", "0x1f", "0o17", "0b101", "-99"])
            c.line(f"a = int({s!r}, 0)")
            c.eq(f"a == int({s!r}, 0)")
            c.eq("[bool(a > 0)] == [True]")
            c.eq("complex(3, -4).real == 3")
            c.eq("complex(3, -4).imag == -4")
            c.eq("abs(complex(3, -4)) == 5.0")
        else:
            a = rng.randrange(2**40, 2**60)
            b = rng.randrange(2**40, 2**60)
            c.line(f"a = {a}")
            c.line(f"b = {b}")
            c.eq("(a ^ b) ^ b == a")
            c.eq("(a | b) >= max(a, b)")
            c.eq("(a & b) <= min(a, b)")
            c.eq("hash(a) == hash(int(repr(a)))")
            c.eq("hash(-a) == hash(int(repr(-a)))")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# --------------------------------------------------------------- comparisons

def gen_comparisons(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        c = Case(f"gen-cmp-{i:03d}")
        variant = i % 4
        if variant == 0:
            a, b, k = (rng.randint(-20, 20) for _ in range(3))
            c.eq(f"{a} < {b} <= {k} == (({a} < {b}) and ({b} <= {k}))")
            c.eq(f"{a} != {b} == (not {a} == {b})")
            c.eq("1 < 2 == 2 < 3")
            c.eq("3 > 2 > 1 == 1")
        elif variant == 1:
            c.eq("float('nan') == float('nan')")
            c.eq("float('nan') != float('nan')")
            c.eq("float('inf') > 10 ** 400")
            c.eq("-float('inf') < -10 ** 400")
            c.eq("float('-0.0') == 0")
        elif variant == 2:
            k = rng.choice([2**53 - 1, 2**53, 2**53 + 1, -(2**53)])
            c.line(f"a = {k}")
            c.line("b = float(a)")
            c.eq("a == b")
            c.eq("(a != b) == (not a == b)")
            c.eq("isinstance(b, float)")
            c.eq("int(b) == a" if float(k) == k else "True")
        else:
            c.line("class R():")
            c.line("    def __init__(me, v): me.v = v")
            c.line("    def __eq__(me, o): return me.v == getattr(o, 'v', None)")
            c.line("    def __lt__(me, o): return me.v < o.v")
            c.line("    def __le__(me, o): return me.v <= o.v")
            c.line("xs = [R(3), R(1), R(2)]")
            c.eq("sorted([x.v for x in xs]) == [1, 2, 3]")
            c.eq("R(1) == R(1)")
            c.eq("R(1) == 1")
            c.eq("max(xs, key=lambda x: x.v).v == 3")
            c.eq("min(xs, key=lambda x: x.v).v == 1")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# --------------------------------------------------------------------- dicts

def gen_dicts(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        keys = rng.sample(range(1, 200), 5)
        c = Case(f"gen-dict-{i:03d}")
        variant = i % 4
        if variant == 0:
            c.line("d = {}")
            c.line("d[True] = 't'")
            c.line("d[1] = 'one'")
            c.line(f"d[{keys[0]}] = 'k0'")
            c.eq("len(d) == len(list(d))")
            c.eq("d[True] == 'one'")
            c.eq(f"d[{keys[0]}] == 'k0'")
            c.eq("list(d)[-1] == " + str(keys[0]))
        elif variant == 1:
            c.line(f"d = dict.fromkeys([{', '.join(map(str, keys))}], 0)")
            c.line(f"d.setdefault({keys[1]}, 99)")
            c.line(f"d.setdefault({keys[1]}, 77)")
            c.eq(f"d[{keys[1]}] == 99")
            c.line(f"d.update({{{keys[2]}: 5}})")
            c.eq(f"d[{keys[2]}] == 5")
            c.line(f"k = d.pop({keys[3]})")
            c.eq(f"k not in d")
            c.eq(f"d.get({keys[4]}, 'dflt') == 'dflt'")
        elif variant == 2:
            pairs = ", ".join(f"{chr(97 + j)!r}: {keys[j]}" for j in range(5))
            c.line(f"d = {{{pairs}}}")
            c.line("ks = list(d.keys())")
            c.line(f"del d[{chr(97 + 2)!r}]")
            c.eq(f"list(d.keys()) == {[chr(97 + j) for j in range(5) if j != 2]!r}")
            c.line(f"d[{keys[2]!r}] = {keys[2]}")
            c.eq(f"list(d.keys())[-1] == {keys[2]!r}")
            c.eq(f"sum(d.values()) == {sum(keys)}")
        else:
            d1 = ", ".join(f"{chr(97 + j)!r}: {keys[j]}" for j in range(3))
            d2 = ", ".join(f"{chr(98 + j)!r}: {keys[j + 2]}" for j in range(3))
            c.line(f"d1 = {{{d1}}}")
            c.line(f"d2 = {{{d2}}}")
            c.line("view = d1.keys() | d2.keys()")
            c.eq("len(view) == 4")
            c.eq("(view & d1.keys()) == d1.keys()")
            merged_keys = ["a", "c"] + [chr(98 + j) for j in range(3)]
            c.eq(f"(d1 | d2) == {{'a': {keys[0]}, 'b': {keys[2]}, "
                 f"'c': {keys[2]}, 'd': {keys[3]}}}")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# --------------------------------------------------------------------- sets

def gen_sets(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        a = sorted(rng.sample(range(0, 40), rng.randint(3, 6)))
        b = sorted(rng.sample(range(0, 40), rng.randint(3, 6)))
        la, lb = ", ".join(map(str, a)), ", ".join(map(str, b))
        c = Case(f"gen-set-{i:03d}")
        c.line(f"A = set([{la}])")
        c.line(f"B = set([{lb}])")
        c.eq(f"sorted(A & B) == {sorted(set(a) & set(b))!r}")
        c.eq(f"sorted(A | B) == {sorted(set(a) | set(b))!r}")
        c.eq(f"sorted(A ^ B) == {sorted(set(a) ^ set(b))!r}")
        c.eq(f"sorted(A - B) == {sorted(set(a) - set(b))!r}")
        c.eq("(A <= A) == True".replace(" == True", ""))
        c.eq(f"A.isdisjoint(B) == {not bool(set(a) & set(b))}")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# -------------------------------------------------------------------- lists

def gen_lists(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        xs = [rng.randint(-50, 50) for _ in range(8)]
        c = Case(f"gen-list-{i:03d}")
        variant = i % 4
        if variant == 0:
            c.line(f"L = {xs!r}")
            c.eq(f"sorted(L) == {sorted(xs)!r}")
            c.eq(f"L.count({xs[3]}) == {xs.count(xs[3])}")
            c.eq(f"L.index({xs[3]}) == {xs.index(xs[3])}")
            c.eq("sorted(L, key=lambda x: (x < 0, abs(x))) == "
                 + repr(sorted(xs, key=lambda x: (x < 0, abs(x)))))
        elif variant == 1:
            lo, hi = sorted(rng.sample(range(-2, 11), 2))
            step = rng.choice([1, 2, 3])
            sl = xs[lo:hi:step]
            c.line(f"L = {xs!r}")
            c.eq(f"L[{lo}:{hi}:{step}] == {sl!r}")
            c.line(f"M = L[:]")
            if sl:
                c.line(f"L[{lo}:{hi}:{step}] = [0] * {len(sl)}")
                c.eq(f"len(L) >= {len(sl)}")
            c.line(f"del M[{lo}:{hi}]")
            c.eq(f"M == {(xs[:lo] + xs[hi:])!r}")
        elif variant == 2:
            c.line(f"a, *b, c = {xs!r}")
            c.eq(f"b == {xs[1:-1]!r}")
            c.eq(f"c == {xs[-1]}")
            c.line("p, q = q, p = 1, 2")
            c.eq("q == 2")
            c.line("*mids, = b")
            c.eq(f"mids == {xs[1:-1]!r}")
        else:
            head = xs[:5]
            removed = xs[2] if xs[2] in head else head[0]
            c.line(f"L = {head!r}")
            c.line(f"L.remove({removed})")
            c.eq(f"{removed} not in L")
            ins = rng.randint(-9, 9)
            c.line(f"L.insert(0, {ins})")
            c.eq(f"L[0] == {ins}")
            c.line("L.extend([])")
            c.eq(f"len(L) == {len(head)}")
            c.line("rev = list(L)")
            c.line("rev.reverse()")
            c.eq("rev[::-1] == L")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# ------------------------------------------------------------------ strings

def gen_strings(rng: random.Random, n: int) -> list[dict]:
    out = []
    words = ["alpha", "beta", "gamma", "delta"]
    for i in range(n):
        w1, w2 = rng.sample(words, 2)
        num = rng.randint(-12345, 12345)
        f = round(rng.uniform(-99, 99), 4)
        c = Case(f"gen-str-{i:03d}")
        variant = i % 5
        if variant == 0:
            pad = rng.choice(["ljust", "rjust"])
            width = rng.randint(8, 14)
            s = f"{w1}-{w2}"
            c.line(f"s = {s!r}")
            c.eq(f"s.upper() == {s.upper()!r}")
            c.eq(f"s.split('-') == {[w1, w2]!r}")
            c.eq(f"'-'.join(s.split('-')) == s")
            c.eq(f"s.replace({w1!r}, 'X') == {s.replace(w1, 'X')!r}")
            c.eq(f"'{w1}'.{pad}({width}).strip() == {w1!r}")
            c.eq(f"s.find({w2!r}) == {s.find(w2)}")
        elif variant == 1:
            c.line(f"v = {num}")
            c.line(f"f = {f!r}")
            c.eq("'%d' % v == str(v)")
            c.eq("'%x' % 255 == 'ff'")
            c.eq(f"'%s|%' + '' if False else ('%s|%s' % ({w1!r}, v)) == {w1 + '|' + str(num)!r}")
            c.eq(f"'{{}}={{}}'.format({w1!r}, v) == {w1 + '=' + str(num)!r}")
            c.eq(f"'{{nm}}!'.format_map({{'nm': {w2!r}}}) == {w2 + '!'!r}")
        elif variant == 2:
            c.line("tbl = str.maketrans('abc', 'xyz', 'd')")
            c.eq("'abcd'.translate(tbl) == 'xyz'")
            c.eq("'\\t'.expandtabs(8) == ' ' * 8")
            c.eq("ord('\\u00e9') == 233")
            c.eq("chr(20013) == '\\u4e2d'")
            c.eq(f"{w1!r}.encode('utf-8').decode() == {w1!r}")
            c.eq(f"bytes({w1!r}, 'ascii').isascii()")
        elif variant == 3:
            parts = rng.sample(words, 3)
            joined = "".join(parts)
            w = "".join(parts)
            c.line(f"w = {w!r}")
            c.eq(f"w.capitalize()[0] == {joined[0].upper()!r}")
            c.eq(f"w[1:-1] == {joined[1:-1]!r}")
            c.eq(f"w.startswith({parts[0]!r})")
            c.eq(f"w.endswith({parts[2]!r})")
            c.eq(f"w.title() == {''.join(p.capitalize() for p in parts)!r}")
            c.eq(f"'*'.join(w) == {'*'.join(joined)!r}")
        else:
            sp = f"  {w1}  "
            c.line(f"sp = {sp!r}")
            c.eq("'%c' % 65 == 'A'")
            c.eq("'aB'.swapcase() == 'Ab'")
            c.eq(f"sp.strip() == {w1!r}")
            c.eq("sp.lstrip().rstrip() == sp.strip()")
            c.eq("'ab'.partition('b')[0] == 'a'")
            c.eq("'a-b-c'.rsplit('-', 1) == ['a-b', 'c']")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# ------------------------------------------------------------------- bytes

def gen_bytes(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        vals = [rng.randint(0, 255) for _ in range(6)]
        c = Case(f"gen-bytes-{i:03d}")
        c.line(f"B = bytes([{', '.join(map(str, vals))}])")
        c.eq(f"B[1:3] == bytes([{vals[1]}, {vals[2]}])")
        c.eq(f"B + B[-1:] == bytes({vals + [vals[-1]]!r})")
        c.eq(f"list(B[:3]) == {vals[:3]!r}")
        c.eq("bytes.maketrans(b'ab', b'XY') is not None or True")
        c.eq("b'abc'.translate(bytes.maketrans(b'ab', b'XY'), delete=b'c') == b'XY'")
        c.eq(f"B.hex()[:2] == {format(vals[0], '02x')!r}")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# --------------------------------------------------------------- exceptions

def gen_exceptions(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        c = Case(f"gen-exc-{i:03d}")
        variant = i % 5
        if variant == 0:
            c.line("order = []")
            c.line("def probe():")
            c.line("    order.append('try')")
            c.line("    try:")
            c.line("        raise KeyError('k')")
            c.line("    except LookupError:")
            c.line("        order.append('lookup')")
            c.line("    finally:")
            c.line("        order.append('fin')")
            c.line("    return 'done'")
            c.eq("probe() == 'done'")
            c.eq("order == ['try', 'lookup', 'fin']")
        elif variant == 1:
            c.line("log = []")
            c.line("def fin_on_return():")
            c.line("    try:")
            c.line("        return 'try'")
            c.line("    finally:")
            c.line("        log.append('finally')")
            c.eq("fin_on_return() == 'try'")
            c.eq("log == ['finally']")
            c.line("def nested():")
            c.line("    log = []")
            c.line("    try:")
            c.line("        try:")
            c.line("            raise IndexError")
            c.line("        finally:")
            c.line("            log.append('inner')")
            c.line("    except IndexError:")
            c.line("        log.append('outer')")
            c.line("    return log")
            c.eq("nested() == ['inner', 'outer']")
        elif variant == 2:
            c.line("def reraise():")
            c.line("    caught = None")
            c.line("    try:")
            c.line("        try:")
            c.line("            raise TypeError('orig')")
            c.line("        except TypeError as e:")
            c.line("            caught = type(e).__name__")
            c.line("            raise")
            c.line("    except TypeError as e2:")
            c.line("        return (caught, str(e2))")
            c.eq("reraise() == ('TypeError', 'orig')")
            c.line("def nm():")
            c.line("    try:")
            c.line("        undefined_xyzzy_42")
            c.line("    except NameError:")
            c.line("        return 'ne'")
            c.eq("nm() == 'ne'")
        elif variant == 3:
            c.line("class MyErr(Exception): pass")
            c.line("class SubErr(MyErr): pass")
            c.line("hits = []")
            c.line("def pick():")
            c.line("    try:")
            c.line("        raise SubErr('sub')")
            c.line("    except (KeyError, ValueError):")
            c.line("        hits.append('kv')")
            c.line("    except (SubErr, MyErr):")
            c.line("        hits.append('mine')")
            c.line("    return 'ok'")
            c.eq("pick() == 'ok'")
            c.eq("hits == ['mine']")
            c.eq("issubclass(SubErr, MyErr)")
        else:
            c.line("chain = []")
            c.line("def low():")
            c.line("    raise ValueError('low')")
            c.line("def high():")
            c.line("    try:")
            c.line("        low()")
            c.line("    except ValueError as e:")
            c.line("        raise RuntimeError('high') from e")
            c.line("try_holder = []")
            c.line("def run_high():")
            c.line("    try:")
            c.line("        high()")
            c.line("    except RuntimeError as e:")
            c.line("        return (str(e), type(e.__cause__).__name__)")
            c.eq("run_high() == ('high', 'ValueError')")
            c.line("def ctx_probe():")
            c.line("    try:")
            c.line("        try:")
            c.line("            1 / 0")
            c.line("        except ZeroDivisionError:")
            c.line("            raise KeyError('ctx')")
            c.line("    except KeyError as e2:")
            c.line("        return type(e2.__context__).__name__")
            c.eq("ctx_probe() == 'ZeroDivisionError'")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# --------------------------------------------------------------- generators

def gen_generators(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        c = Case(f"gen-gen-{i:03d}")
        variant = i % 5
        if variant == 0:
            k = rng.randint(2, 6)
            c.line("def g():")
            c.line(f"    for j in range({k}):")
            c.line("        x = yield j * j")
            c.line("        if x == 'halt':")
            c.line("            return 'stopped'")
            c.line("    return 'done'")
            c.line("it = g()")
            c.eq("next(it) == 0")
            c.eq(f"[it.send('go') for _ in range({k - 1})] == "
                 + repr([j * j for j in range(1, k)]))
            c.eq("it.close() == None".replace(" == None", " is None"))
        elif variant == 1:
            c.line("log = []")
            c.line("def inner():")
            c.line("    try:")
            c.line("        yield 1")
            c.line("        yield 2")
            c.line("    finally:")
            c.line("        log.append('ifin')")
            c.line("def outer():")
            c.line("    yield from inner()")
            c.line("    yield 3")
            c.line("it = outer()")
            c.eq("[next(it), next(it), next(it)] == [1, 2, 3]")
            c.line("def drain():")
            c.line("    try:")
            c.line("        next(it)")
            c.line("    except StopIteration:")
            c.line("        log.append('stop')")
            c.eq("drain() is None")
            c.eq("log == ['ifin', 'stop']")
        elif variant == 2:
            c.line("def g():")
            c.line("    try:")
            c.line("        yield 'a'")
            c.line("        yield 'b'")
            c.line("    except ValueError as e:")
            c.line("        yield 'caught:' + str(e)")
            c.line("        yield 'after'")
            c.line("it = g()")
            c.eq("next(it) == 'a'")
            c.eq("it.throw(ValueError('boom')) == 'caught:boom'")
            c.eq("next(it) == 'after'")
        elif variant == 3:
            c.line("def countdown(t):")
            c.line("    while t > 0:")
            c.line("        got = yield t")
            c.line("        t = (got if isinstance(got, int) else t) - 1")
            c.line("    return 'zero'")
            c.line("it = countdown(3)")
            c.line("seq = []")
            c.line("seq.append(next(it))")
            c.line("while len(seq) < 3:")
            c.line("    seq.append(it.send(seq[-1]))")
            c.line("def finish():")
            c.line("    try:")
            c.line("        it.send(seq[-1])")
            c.line("    except StopIteration as e:")
            c.line("        seq.append(e.value)")
            c.line("finish()")
            c.eq("seq == [3, 2, 1, 'zero']")
        else:
            c.line("def g():")
            c.line("    yield 10")
            c.line("    return")
            c.line("    yield 20")
            c.line("it = g()")
            c.eq("next(it) == 10")
            c.line("def stop_check():")
            c.line("    try:")
            c.line("        next(it)")
            c.line("        return False")
            c.line("    except StopIteration:")
            c.line("        return True")
            c.eq("stop_check()")
            c.line("closed = g()")
            c.eq("closed.close() is None")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# ------------------------------------------------------------ comprehensions

def gen_comprehensions(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        lim = rng.randint(3, 8)
        mult = rng.choice([2, 3, 5])
        c = Case(f"gen-comp-{i:03d}")
        variant = i % 4
        if variant == 0:
            c.line(f"sq = [x * {mult} for x in range({lim})]")
            c.eq(f"sq == {[x * mult for x in range(lim)]!r}")
            c.line("[leak for leak in [7]]")
            c.eq("'leak' in dir()")
        elif variant == 1:
            c.line(f"dc = {{k: k * {mult} for k in range({lim}) if k % 2 == 0}}")
            c.eq(f"dc == {{{', '.join(f'{k}: {k * mult}' for k in range(lim) if k % 2 == 0)}}}")
            c.eq(f"{{k % 3 for k in range({lim * 2})}} == {{0, 1, 2}}")
            c.eq(f"sum(k for k in range({lim}) if k != 0) == {sum(range(1, lim))}")
        elif variant == 2:
            flat = [(r * lim + c2) for r in range(3) for c2 in range(3)]
            c.line(f"mat = [[r * {lim} + cc for cc in range(3)] for r in range(3)]")
            c.line("flat = [cell for row in mat for cell in row]")
            c.eq(f"flat == {flat!r}")
            c.eq(f"[mat[r][r] for r in range(3)] == {[(r * lim + r) for r in range(3)]!r}")
            c.eq("all(isinstance(row, list) for row in mat)")
        else:
            c.line("words = ['ab', 'cde', 'f']")
            c.line("lens = {w: len(w) for w in words}")
            c.eq("lens['cde'] == 3")
            c.eq("len(list((a, b) for a in 'xy' for b in '12')) == 4")
            c.eq("sum(sum(row) for row in [[1, 2], [3, 4]]) == 10")
            c.eq("[w.upper() for w in words if len(w) > 1] == ['AB', 'CDE']")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# ----------------------------------------------------------------- closures

def gen_closures(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        start = rng.randint(-10, 10)
        step = rng.randint(1, 5)
        c = Case(f"gen-closure-{i:03d}")
        variant = i % 3
        if variant == 0:
            c.line("def make():")
            c.line(f"    count = {start}")
            c.line("    def bump():")
            c.line("        nonlocal count")
            c.line(f"        count += {step}")
            c.line("        return count")
            c.line("    return bump")
            c.line("b = make()")
            c.eq(f"[b() for _ in range(3)] == {[start + step * k for k in range(1, 4)]!r}")
            c.line("b2 = make()")
            c.eq(f"b2() == {start + step}")
            c.eq(f"b() == {start + step * 4}")
        elif variant == 1:
            c.line(f"def f(a, b={start}, *, k={step}, **rest):")
            c.line("    return (a, b, k, sorted(rest.items()))")
            c.eq("f(1)[0] == 1")
            c.eq(f"f(1)[1] == {start}")
            c.eq("f(1, k=9)[2] == 9")
            c.eq("f(*[10, 20], **{'k': 30, 'extra': 1})[0] == 10")
            c.eq("dict(f(*[10], **{'extra': 1})[3]).get('extra') == 1")
        else:
            c.line(f"fs = [lambda x=x: x + {step} for x in range(3)]")
            c.eq(f"[fn() for fn in fs] == {[x + step for x in range(3)]!r}")
            c.line("gs = [lambda: x for x in range(3)]")
            c.eq("len({g() for g in gs}) == 1")
            c.line("def outer():")
            c.line("    acc = []")
            c.line("    def add(v):")
            c.line("        acc.append(v)")
            c.line("    return add, acc")
            c.line("add_fn, acc_list = outer()")
            c.line(f"[add_fn(v) for v in range({step})]")
            c.eq(f"acc_list == {list(range(step))!r}")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# --------------------------------------------------------------- consumers

def gen_consumers(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        xs = rng.sample(range(1, 60), 6)
        ys = rng.sample(range(1, 60), 3)
        c = Case(f"gen-cons-{i:03d}")
        variant = i % 4
        if variant == 0:
            truthy = [v for v in xs if v % 2]
            c.line(f"data = {xs!r}")
            c.eq(f"any(x % 2 for x in data) == {bool(truthy)!r}")
            c.eq("all(x > 0 for x in data) == True".replace(" == True", ""))
            c.eq(f"list(enumerate(data, start=1))[0] == (1, {xs[0]})")
            c.eq(f"[a + b for a, b in zip(data, {ys!r})][:3] == "
                 + repr([a + b for a, b in zip(xs, ys)]))
            c.eq("len(list(zip(data, range(99)))) == 6")
        elif variant == 1:
            start = rng.randint(0, 10)
            c.line(f"data = {xs!r}")
            c.eq(f"list(map(str, data[:2])) == {[str(v) for v in xs[:2]]!r}")
            c.eq(f"list(filter(lambda v: v % 2 == 0, data)) == "
                 + repr([v for v in xs if v % 2 == 0]))
            c.eq("list(filter(None, [0, 1, '', 'a'])) == [1, 'a']")
            c.eq(f"sum(data, {start}) == {sum(xs) + start}")
        elif variant == 2:
            c.line("short = []")
            c.line("def boom():")
            c.line("    short.append('called')")
            c.line("    return True")
            c.line("ans = False and boom()")
            c.eq("short == []")
            c.eq("ans == False".replace(" == False", " is False"))
            c.eq("(True or boom()) is True")
            c.eq("short == []")
        else:
            d = {chr(97 + j): xs[j] for j in range(4)}
            c.line(f"d = {d!r}")
            c.eq(f"min(d.values()) == {min(d.values())}")
            c.eq(f"max(d, key=d.get) == {max(d, key=lambda k: d[k])!r}")
            c.eq("repr({1: {2: [3, (4,)]}}) == \"{1: {2: [3, (4,)]}}\"")
            c.eq("len(repr({1: {2: [3, (4,)]}})) > 10")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# ------------------------------------------------------------------- loops

def gen_loops(rng: random.Random, n: int) -> list[dict]:
    out = []
    for i in range(n):
        lim = rng.randint(2, 7)
        stop = rng.randint(1, lim - 1) if lim > 2 else 1
        aug = rng.randint(5, 50)
        aug_val = (aug // 4 % 7) ** 2
        c = Case(f"gen-loop-{i:03d}")
        variant = i % 2
        if variant == 0:
            c.line("seen = []")
            c.line(f"for j in range({lim}):")
            c.line(f"    if j == {stop}:")
            c.line("        continue")
            c.line("    seen.append(j)")
            c.line("else:")
            c.line("    seen.append('else')")
            c.eq(f"seen == {[j for j in range(lim) if j != stop] + ['else']!r}")
            c.line("w = 0")
            c.line("while True:")
            c.line("    w += 1")
            c.line(f"    if w >= {stop + 1}:")
            c.line("        break")
            c.eq(f"w == {stop + 1}")
        else:
            c.line("total = 0")
            c.line(f"aug = {aug}")
            c.line("aug //= 4")
            c.line("aug %= 7")
            c.line("aug **= 2")
            c.line("total += aug")
            c.eq(f"total == {aug_val}")
            c.line("idx_aug = [1, 2, 3]")
            c.line("idx_aug[1] += 10")
            c.eq("idx_aug == [1, 12, 3]")
            c.eq("((5,),)[0][0] == 5")
        got = freeze(c)
        if got:
            out.append(got)
    return out


# ----------------------------------------------------------------- assembly

AREAS = [
    gen_arithmetic,
    gen_comparisons,
    gen_dicts,
    gen_sets,
    gen_lists,
    gen_strings,
    gen_bytes,
    gen_exceptions,
    gen_generators,
    gen_comprehensions,
    gen_closures,
    gen_consumers,
    gen_loops,
]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--seed", type=int, default=20260822)
    ap.add_argument("--count", type=int, default=130)
    ap.add_argument("--out", default=None)
    args = ap.parse_args(argv)

    rng = random.Random(args.seed)
    buckets = [fn(rng, max(4, args.count // len(AREAS))) for fn in AREAS]
    cases = []
    for bi in range(max(len(b) for b in buckets)):
        for b in buckets:
            if bi < len(b):
                cases.append(b[bi])

    seen_names = set()
    deduped = []
    for c in cases:
        if c["name"] in seen_names:
            continue
        seen_names.add(c["name"])
        deduped.append(c)
    payload = json.dumps(deduped[: args.count], indent=1)

    if args.out:
        with open(args.out, "w") as fh:
            fh.write(payload + "\n")
    else:
        sys.stdout.write(payload + "\n")


if __name__ == "__main__":
    main()
