#!/usr/bin/env python3
"""Dump exact PyCode fields for the P0.10 expression fixtures.

Test/shim only (PLAN.md P0.2/P0.10). Prints co_code units, consts, names,
flags, stacksize, linetable bytes, exceptiontable bytes, and dis for each
fixture so the Jac compiler has byte-exact ground truth to match.
"""
import dis
import marshal

FIXTURES = [
    ("add", "1+1", "eval"),
    ("neg", "-x", "eval"),
    ("add_mul", "a*b+c", "eval"),
    ("call", "f(x,1)", "eval"),
    ("chain_cmp", "x<y<z", "eval"),
    ("add_exec", "1+1\n", "exec"),
    ("assign_exec", "a = 1 + 2\n", "exec"),
]


def dump(name, src, mode):
    print("=" * 70)
    print(f"FIXTURE {name}  mode={mode}  src={src!r}")
    print("=" * 70)
    co = compile(src, "<f>", mode)
    code = co.co_code
    # co_code is bytes; each instruction is 2 bytes (op, arg). Print as units.
    print(f"co_code len (bytes) = {len(code)}  (= {len(code)//2} code units)")
    print("co_code units (op,arg) pairs:")
    i = 0
    while i < len(code):
        op = code[i]
        arg = code[i + 1]
        print(f"  [{i//2:3d}] byte_off={i:4d} op={op:3d} arg={arg:3d}")
        i += 2
    print(f"argcount={co.co_argcount} posonly={co.co_posonlyargcount} "
          f"kwonly={co.co_kwonlyargcount}")
    print(f"stacksize={co.co_stacksize} flags={co.co_flags} "
          f"firstlineno={co.co_firstlineno}")
    print(f"filename={co.co_filename!r} name={co.co_name!r} "
          f"qualname={co.co_qualname!r}")
    print(f"consts={list(co.co_consts)!r}")
    print(f"names={list(co.co_names)!r}")
    print(f"varnames={list(co.co_varnames)!r}")
    print(f"cellvars={list(co.co_cellvars)!r}")
    print(f"freevars={list(co.co_freevars)!r}")
    print(f"linetable bytes = {list(co.co_linetable)!r}")
    print(f"exceptiontable bytes = {list(co.co_exceptiontable)!r}")
    print("--- dis ---")
    dis.dis(co)
    print()


def main():
    for name, src, mode in FIXTURES:
        dump(name, src, mode)


if __name__ == "__main__":
    main()
