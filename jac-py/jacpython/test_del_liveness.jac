# Delete-path liveness regression (TODO.md adversarial item 0).
#
# Compiled-jac `del` lowering inserts a destroy([targets]) call whose runtime
# touches the removed value's lazy `__jac__` anchor; before the sv_forget root
# fix (osp_graph_sv.sv_forget_by_id releasing the strong anchor ref), the
# cached ObjectAnchor pinned values past gc.collect(), so objects whose last
# reference died through a delete leaked forever. The VM now deletes through
# native paths directly; these fixtures pin the refcount contract end-to-end.
#
# Dropping an object's last reference via a VM delete path must free it
# immediately (weakref returns None with NO gc.collect -- the CPython
# refcount contract). A regression in the anchor release or a new delete site
# that over-retains keeps the object alive here.
#
# KNOWN OPEN (not asserted yet -- still over-retained past gc.collect, see
# TODO.md item 0): dict subscript delete, dict.pop/popitem, del attr. The
# retention there survives host gc.collect() entirely, which points below the
# ceval/Jac layer (na-runtime refcount release), not at these VM files.

import from objects { PyObj, PyStr, PyError, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<del_liveness>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_bool(ns: dict[str, PyObj], name: str) -> bool {
    return to_host(ns[name]) as bool;
}

test "del name frees last reference immediately" {
    ns = vm_exec(
        "import weakref\n"
        "class C:\n"
        "    pass\n"
        "o = C()\n"
        "r = weakref.ref(o)\n"
        "del o\n"
        "dead = r() is None\n"
    );
    assert vm_bool(ns, "dead");
}

test "del global frees last reference immediately" {
    ns = vm_exec(
        "import weakref\n"
        "class C:\n"
        "    pass\n"
        "def f():\n"
        "    global g\n"
        "    g = C()\n"
        "f()\n"
        "r = weakref.ref(g)\n"
        "del g\n"
        "dead = r() is None\n"
    );
    assert vm_bool(ns, "dead");
}

test "list index delete frees removed element immediately" {
    ns = vm_exec(
        "import weakref\n"
        "class C:\n"
        "    pass\n"
        "xs = [C()]\n"
        "r = weakref.ref(xs[0])\n"
        "del xs[0]\n"
        "dead = r() is None\n"
    );
    assert vm_bool(ns, "dead");
}

test "surviving references keep the object alive across deletes" {
    ns = vm_exec(
        "import weakref\n"
        "class C:\n"
        "    pass\n"
        "d = {}\n"
        "o = C()\n"
        "d['k'] = o\n"
        "r = weakref.ref(o)\n"
        "del o\n"
        "alive = r() is not None\n"
        "o = None\n"
        "alive2 = r() is not None\n"
    );
    # The container still held a reference, so the name delete must NOT free
    # it; only a real last-reference drop may.
    assert vm_bool(ns, "alive");
    assert vm_bool(ns, "alive2");
}
