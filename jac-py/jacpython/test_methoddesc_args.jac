# Method-descriptor arg-check fidelity pins (divergence-table sweep).
#
# Each fixture compiles a probe source the host CPython would run, executes it
# on ceval, and pins the byte-exact error text against the python3 oracle.
# Covers the owner-prefixed qualname forms and arg-count contracts for
# PyRangeMethod / PySetMethod / PyDictMethod / dict views plus the sorted /
# setattr / next / id builtin suffixes. Companion to test_msg_fidelity.jac
# (which owns slice/tuple/str descriptors); kept separate so both files stay
# append-only.

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<methoddesc_args>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(expr: str) -> str {
    ns = vm_exec(
        "try:\n"
        "    r = " + expr + "\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    );
    return to_host(ns["r"]) as str;
}

def vm_stmt(stmt: str) -> str {
    # Returns the statement's `r` binding on success, else "Type: text".
    indented = "";
    for ln in stmt.split("\n") {
        if indented != "" {
            indented = indented + "\n";
        }
        indented = indented + "    " + ln;
    }
    ns = vm_exec(
        "status = ''\n"
        "try:\n"
        "    r = None\n"
        + indented + "\n"
        "    status = r\n"
        "except BaseException as e:\n"
        "    status = type(e).__name__ + ': ' + str(e)\n"
    );
    return to_host(ns["status"]) as str;
}

def expect(expr: str, want: str) {
    got = vm_str(expr);
    assert got == want,
        "probe `" + expr + "` gave `" + got + "`, want `" + want + "`";
}

def expect_stmt(stmt: str, want: str) {
    got = vm_stmt(stmt);
    assert got == want,
        "stmt `" + stmt + "` gave `" + got + "`, want `" + want + "`";
}

# ---- range.index / range.count: owner-prefixed METH_O wording ---------------

test "range.index zero args pins owner-qualified message" {
    expect("repr(range(3).index())",
        "TypeError: range.index() takes exactly one argument (0 given)");
}

test "range.count too many args pins given-count" {
    expect("repr(range(3).count(1, 2))",
        "TypeError: range.count() takes exactly one argument (2 given)");
}

test "range.index kwargs refused" {
    expect("repr(range(3).index(1, x=2))",
        "TypeError: range.index() takes no keyword arguments");
}

# ---- set methods: owner-prefixed contracts, no silent extras ----------------

test "set.add extra positional raises owner-qualified TypeError" {
    expect_stmt("{1}.add(1, 2)",
        "TypeError: set.add() takes exactly one argument (2 given)");
}

test "set.add kwarg refused" {
    expect("repr({1}.add(x=1))",
        "TypeError: set.add() takes no keyword arguments");
}

test "set.pop takes no arguments" {
    expect("repr({1}.pop(2))",
        "TypeError: set.pop() takes no arguments (1 given)");
}

test "set.clear takes no arguments" {
    expect("repr({1}.clear(9))",
        "TypeError: set.clear() takes no arguments (1 given)");
}

test "set.copy takes no arguments" {
    expect("repr({1}.copy(1))",
        "TypeError: set.copy() takes no arguments (1 given)");
}

test "set.discard extra args pinned" {
    expect("repr({1}.discard(1, 2))",
        "TypeError: set.discard() takes exactly one argument (2 given)");
}

test "set.remove extra args pinned" {
    expect("repr({1}.remove(1, 2))",
        "TypeError: set.remove() takes exactly one argument (2 given)");
}

test "set.symmetric_difference arity is exactly one" {
    expect("repr({1}.symmetric_difference([2], [3]))",
        "TypeError: set.symmetric_difference() takes exactly one argument (2 given)");
    expect("repr({1}.symmetric_difference())",
        "TypeError: set.symmetric_difference() takes exactly one argument (0 given)");
}

test "set predicate zero args pinned" {
    expect("repr({1}.issubset())",
        "TypeError: set.issubset() takes exactly one argument (0 given)");
    expect("repr({1}.issuperset())",
        "TypeError: set.issuperset() takes exactly one argument (0 given)");
    expect("repr({1}.isdisjoint())",
        "TypeError: set.isdisjoint() takes exactly one argument (0 given)");
}

test "set predicate extra args pinned" {
    expect("repr({1}.issubset([1], [2]))",
        "TypeError: set.issubset() takes exactly one argument (2 given)");
}

test "set.update kwarg refused but variadic positionals still fine" {
    expect("repr({1}.update(a=1))",
        "TypeError: set.update() takes no keyword arguments");
    expect("repr({1}.union([2], x=3))",
        "TypeError: set.union() takes no keyword arguments");
}

test "set.__contains__ zero args pinned" {
    expect("repr({1}.__contains__())",
        "TypeError: set.__contains__() takes exactly one argument (0 given)");
}

# ---- dict methods: clinic min/max forms + METH_NOARGS view wording ----------

test "dict.get arity bounds pinned" {
    expect("repr({}.get())",
        "TypeError: get expected at least 1 argument, got 0");
    expect("repr({}.get(1, 2, 3))",
        "TypeError: get expected at most 2 arguments, got 3");
}

test "dict.setdefault arity bounds pinned" {
    expect("repr({}.setdefault())",
        "TypeError: setdefault expected at least 1 argument, got 0");
    expect("repr({}.setdefault(1, 2, 3))",
        "TypeError: setdefault expected at most 2 arguments, got 3");
}

test "dict.pop missing key keeps KeyError, arity bounds pinned" {
    expect("repr({}.pop())",
        "TypeError: pop expected at least 1 argument, got 0");
    expect("repr({}.pop(1, 2, 3))",
        "TypeError: pop expected at most 2 arguments, got 3");
}

test "dict.pop missing key raises KeyError (form pinned via subscript-free path)" {
    got = vm_stmt("r = {}.pop(9)");
    assert got.startswith("KeyError"), "wanted KeyError, got `" + got + "`";
}

test "dict no-arg methods refuse extras with owner prefix" {
    expect("repr({}.clear(1))",
        "TypeError: dict.clear() takes no arguments (1 given)");
    expect("repr({}.copy(1))",
        "TypeError: dict.copy() takes no arguments (1 given)");
    expect("repr({}.popitem(1))",
        "TypeError: dict.popitem() takes no arguments (1 given)");
}

test "dict.update caps positionals at one but keeps kwargs form" {
    expect("repr({}.update([], []))",
        "TypeError: update expected at most 1 argument, got 2");
    expect_stmt("r = repr({1: 2}.update(a=5))", "None");
}

test "dict slot wrappers keep host wording" {
    expect("repr({}.__contains__())",
        "TypeError: dict.__contains__() takes exactly one argument (0 given)");
    expect("repr({}.__contains__(1, 2))",
        "TypeError: dict.__contains__() takes exactly one argument (2 given)");
    expect("repr({}.__getitem__())",
        "TypeError: dict.__getitem__() takes exactly one argument (0 given)");
    expect("repr({}.__setitem__(1))",
        "TypeError: __setitem__ expected 2 arguments, got 1");
    expect("repr({}.__delitem__())",
        "TypeError: expected 1 argument, got 0");
}

# ---- dict views (keys/values/items): METH_NOARGS descriptor contract --------

test "dict views refuse positional extras with owner prefix" {
    expect("repr({}.keys(1))",
        "TypeError: dict.keys() takes no arguments (1 given)");
    expect("repr({}.values(1))",
        "TypeError: dict.values() takes no arguments (1 given)");
    expect("repr({}.items(1))",
        "TypeError: dict.items() takes no arguments (1 given)");
}

test "dict views refuse kwargs" {
    expect("repr({}.keys(k=1))",
        "TypeError: dict.keys() takes no keyword arguments");
}

# ---- builtins: setattr / next / id suffixes, sorted clinic text -------------

test "setattr reports got-count on both sides of 3" {
    expect_stmt("setattr(1, 'a')",
        "TypeError: setattr expected 3 arguments, got 2");
    expect_stmt("setattr(1, 'a', 1, 4)",
        "TypeError: setattr expected 3 arguments, got 4");
}

test "next reports got-count on both sides of its bounds" {
    expect("next()",
        "TypeError: next expected at least 1 argument, got 0");
    expect("next([], 1, 2)",
        "TypeError: next expected at most 2 arguments, got 3");
}

test "id rejects wrong arity instead of ignoring extras" {
    expect("id(1, 2)",
        "TypeError: id() takes exactly one argument (2 given)");
}

test "sorted uses the plain clinic expected-1 wording" {
    expect("sorted()",
        "TypeError: sorted expected 1 argument, got 0");
    expect("sorted([], [], [])",
        "TypeError: sorted expected 1 argument, got 3");
}

# ---- behavior parity: normal operation unbroken -----------------------------

test "happy paths unaffected by the new checks" {
    expect("repr(sorted([3, 1, 2], reverse=True))", "[3, 2, 1]");
    expect("repr(range(3).index(1))", "1");
    expect("repr(range(5).count(2))", "1");
    expect("repr({1}.union({2}, [3]))", "{1, 2, 3}");
    expect("repr(next(iter([7]), None))", "7");
    expect_stmt("r = repr({1: 'a'}.pop(2, 'z'))", "'z'");
    expect_stmt("s = {1}\ns.update([2, 3])\nr = repr(sorted(s))", "[1, 2, 3]");
}
