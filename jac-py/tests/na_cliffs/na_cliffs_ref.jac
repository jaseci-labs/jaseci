# T7 known-na-cliffs conformance reference (jac-py/PLAN.md §6.7, TODO.md D4 #4).
#
# Each function here mirrors a pattern jacpython's na-clean core ALREADY uses,
# and each targets a documented na landmine. This file pins the CORRECT answer
# on the bytecode backend; CI nacompiles the identical logic (the sibling
# cliff_*.na.jac fixtures) and diffs against these values. A divergence is a
# real na miscompile on a pattern the port depends on -- discovered here on
# day one instead of at P7.
#
# Measured na status (local `jac nacompile`, 2026-07-15): all four reach
# capability-clean + LLVM IR + object-code emit; only the final musl link is
# blocked locally (env, not code). Runtime-correctness legs (NUL-drop,
# union-receiver-drop) require the linked binary and run in CI. See README.md.

# --- cliff 1: list[int] subscript. Core site: marshal Reader.r_byte ---
def r_byte(data: list[int], pos: int) -> int {
    b = data[pos];
    return b & 0xFF;
}

# --- cliff 2: dict[str,T] build + return + subscript. Core site: exec_module ---
def exec_module_like() -> dict[str, int] {
    g: dict[str, int] = {};
    g["y"] = 43;
    return g;
}

# --- cliff 3: method/field on a T|None receiver. Core site: deref_cell ---
obj Cell { has val: int; }

def find_cell(hit: bool) -> Cell | None {
    if hit { return Cell(val=7); }
    return None;
}

def cell_value(hit: bool) -> int {
    c = find_cell(hit);
    if c is None { return -1; }
    return c.val;
}

# --- cliff 4: binary buffer via chr concat incl NUL. Core site: bytes_to_str ---
def build_binary() -> str {
    s = "";
    s = s + chr(0);
    s = s + chr(65);
    return s;
}

test "cliff: list[int] subscript reads the right byte" {
    assert r_byte([227, 2, 0], 0) == 227;
    assert r_byte([227, 2, 0], 1) == 2;
}

test "cliff: dict build/return/subscript round-trips" {
    assert exec_module_like()["y"] == 43;
}

test "cliff: T|None receiver field access after None-guard" {
    assert cell_value(True) == 7;
    assert cell_value(False) == -1;
}

test "cliff: binary buffer preserves NUL (na len=strlen would report 1)" {
    # Bytecode truth: two code units. On na this is the canary -- if len()
    # degrades to strlen, this returns 1 and the CI differential goes red.
    assert len(build_binary()) == 2;
}
