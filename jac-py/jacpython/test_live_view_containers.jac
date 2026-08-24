# Live-view container bridge conformance pins (fp-e87c).
#
# Guest containers crossing the host boundary default to MUTABLE_COPY
# snapshots (see docs/LIVE-VIEW-BRIDGE-POLICY.md). Consumers that need
# WRITE-THROUGH semantics opt in via live_container_bridge, which mints a
# collections.abc MutableSequence/MutableMapping/MutableSet delegating every
# access back into the guest PyObj protocol surface.
#
# Each pin runs guest code on ceval (vm_exec pattern from
# test_dir_enumeration.jac -- host_compile_marshal + unmarshal + exec_code),
# drives the host-side view from the test process's own interpreter, then
# re-execs into the SAME namespace to observe the guest side. Values surface
# through assert-fail GOT<> messages (the runner swallows prints).

import from objects { PyObj, PyStr, PyError, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host, live_container_bridge }

::py::
def _lv_len(view):
    return len(view)

def _lv_iter_join(view):
    return ",".join(str(x) for x in view)

def _lv_contains(view, v):
    return v in view

def _lv_list_write(view):
    # __setitem__ through mp_ass_subscript + append through the insert route.
    view[0] = 10
    view.append(3)

def _lv_list_delete(view):
    del view[-1]

def _lv_dict_write(d, k, v):
    d[k] = v

def _lv_dict_delete(d, k):
    del d[k]

def _lv_set_add(s, v):
    s.add(v)

def _lv_set_discard(s, v):
    s.discard(v)
::py::

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<live_view_pins>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

# Re-exec into an EXISTING namespace -- the write-through contract needs the
# second snippet to see the same module globals the view delegates into.
def vm_exec_in(ns: dict[str, PyObj], src: str) {
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<live_view_pins>", "exec")), [], ns
    );
    assert not is_error(outcome);
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return to_host(ns[name]) as str;
}

test "live list: view write visible in guest" {
    ns = vm_exec("xs = [1, 2]\n");
    view = live_container_bridge(ns["xs"]);
    assert view is not None;
    assert _lv_len(view) == 2, "len GOT<" + str(_lv_len(view)) + ">";
    _lv_list_write(view);
    vm_exec_in(ns, "out = ','.join(str(x) for x in xs)\n");
    assert vm_str(ns, "out") == "10,2,3", "GOT<" + vm_str(ns, "out") + ">";
}

test "live list: guest mutation visible through view" {
    ns = vm_exec("xs = [1, 2]\n");
    view = live_container_bridge(ns["xs"]);
    vm_exec_in(ns, "xs.append(9)\n");
    assert _lv_len(view) == 3, "len GOT<" + str(_lv_len(view)) + ">";
    assert _lv_iter_join(view) == "1,2,9", "iter GOT<"
        + _lv_iter_join(view) + ">";
    assert _lv_contains(view, 9);
}

test "live list: delete round-trips into guest" {
    ns = vm_exec("xs = [7, 8, 9]\n");
    view = live_container_bridge(ns["xs"]);
    _lv_list_delete(view);
    vm_exec_in(ns, "out = ','.join(str(x) for x in xs)\n");
    assert vm_str(ns, "out") == "7,8", "GOT<" + vm_str(ns, "out") + ">";
}

test "live dict: view write + delete visible in guest" {
    ns = vm_exec("d = {'a': 1}\n");
    view = live_container_bridge(ns["d"]);
    assert view is not None;
    assert _lv_len(view) == 1, "len GOT<" + str(_lv_len(view)) + ">";
    _lv_dict_write(view, "b", 2);
    _lv_dict_delete(view, "a");
    vm_exec_in(ns, "out = ','.join(k + '=' + str(d[k]) for k in d)\n");
    assert vm_str(ns, "out") == "b=2", "GOT<" + vm_str(ns, "out") + ">";
}

test "live dict: guest mutation visible through view" {
    ns = vm_exec("d = {'b': 2}\n");
    view = live_container_bridge(ns["d"]);
    vm_exec_in(ns, "d['c'] = 3\n");
    assert _lv_len(view) == 2, "len GOT<" + str(_lv_len(view)) + ">";
    assert _lv_contains(view, "c");
    assert _lv_iter_join(view) == "b,c", "keys GOT<"
        + _lv_iter_join(view) + ">";
}

test "live set: view add/discard visible in guest" {
    ns = vm_exec("s = {1, 2}\n");
    view = live_container_bridge(ns["s"]);
    assert view is not None;
    assert _lv_len(view) == 2, "len GOT<" + str(_lv_len(view)) + ">";
    _lv_set_add(view, 3);
    _lv_set_discard(view, 1);
    vm_exec_in(ns, "out = ','.join(str(x) for x in sorted(s))\n");
    assert vm_str(ns, "out") == "2,3", "GOT<" + vm_str(ns, "out") + ">";
}

test "live set: guest mutation visible through view" {
    ns = vm_exec("s = {1, 2}\n");
    view = live_container_bridge(ns["s"]);
    vm_exec_in(ns, "s.add(4)\n");
    assert _lv_len(view) == 3, "len GOT<" + str(_lv_len(view)) + ">";
    assert _lv_contains(view, 4);
    assert _lv_iter_join(view) == "1,2,4", "iter GOT<"
        + _lv_iter_join(view) + ">";
}

test "gating: frozenset and non-containers get no view" {
    ns = vm_exec("fs = frozenset((1,))\nn = 5\n");
    assert live_container_bridge(ns["fs"]) is None;
    assert live_container_bridge(ns["n"]) is None;
}

test "scope guard: default to_host stays a snapshot" {
    ns = vm_exec("xs = [1]\n");
    snap = to_host(ns["xs"]);
    snap.append(99);
    vm_exec_in(ns, "out = str(len(xs))\n");
    assert vm_str(ns, "out") == "1", "GOT<" + vm_str(ns, "out") + ">";
}
