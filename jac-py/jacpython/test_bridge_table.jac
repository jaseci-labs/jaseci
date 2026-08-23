# Typed guest<->host boundary table regression pins (bridge-table lane).
#
# Pins the ONE authoritative policy table (ceval.to_host_policy): every native
# type tag has an explicit crossing policy -- VALUE_COPY / DEEP_COPY /
# MUTABLE_COPY / VIEW_COPY / TRAMPOLINE / LAZY_ITER / STANDIN / EXCEPTION /
# PROXY -- and an UNKNOWN tag fails loudly instead of degrading to None.
#
# Also pins the closed defect matrix against the system python3 oracle:
#   - PyClass / plain PyUserObj crossings get name-faithful stand-ins
#     (previously None -> json.dumps said "null")
#   - iterators/generators cross LAZILY sharing position (previously drained
#     silently: list(islice(it, 2)); next(it) raised StopIteration)
#   - host-raised module exceptions keep their FULL args tuple
#     (previously e.args == ())
#   - module-exception registry drives matching/minting without bare
#     getattr(builtins, name) lookups

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from ceval { to_host_policy, BridgePolicy }
import from exceptions_core { exc_name_matches, registered_exc_base }
import from objects { PyObj, PyStr, PyHandler, is_error }
# Importing the facade modules runs their AT-IMPORT registry declarations.
import from _structmodule { _scale_pow2 }
import from _jsonmodule { _decode_error }
import from _csvmodule { QUOTE_MINIMAL }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<bridge_table>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_repr_src(src: str) -> str {
    ns = vm_exec(src);
    return to_host(ns["r"]) as str;
}

# ---- the table itself: explicit policy per tag -----------------------------

test "table gives VALUE_COPY to immutable scalars" {
    assert to_host_policy("none") == BridgePolicy.VALUE_COPY;
    assert to_host_policy("bool") == BridgePolicy.VALUE_COPY;
    assert to_host_policy("int") == BridgePolicy.VALUE_COPY;
    assert to_host_policy("float") == BridgePolicy.VALUE_COPY;
    assert to_host_policy("complex") == BridgePolicy.VALUE_COPY;
    assert to_host_policy("str") == BridgePolicy.VALUE_COPY;
    assert to_host_policy("bytes") == BridgePolicy.VALUE_COPY;
    assert to_host_policy("notimplemented") == BridgePolicy.VALUE_COPY;
}

test "table gives DEEP_COPY to immutable aggregates" {
    assert to_host_policy("tuple") == BridgePolicy.DEEP_COPY;
    assert to_host_policy("frozenset") == BridgePolicy.DEEP_COPY;
    assert to_host_policy("slice") == BridgePolicy.DEEP_COPY;
    assert to_host_policy("range") == BridgePolicy.DEEP_COPY;
}

test "table gives MUTABLE_COPY to mutable containers" {
    assert to_host_policy("list") == BridgePolicy.MUTABLE_COPY;
    assert to_host_policy("dict") == BridgePolicy.MUTABLE_COPY;
    assert to_host_policy("set") == BridgePolicy.MUTABLE_COPY;
}

test "table gives TRAMPOLINE to every callable tag" {
    assert to_host_policy("function") == BridgePolicy.TRAMPOLINE;
    assert to_host_policy("native_builtin") == BridgePolicy.TRAMPOLINE;
    assert to_host_policy("bound_method") == BridgePolicy.TRAMPOLINE;
    assert to_host_policy("gen_method") == BridgePolicy.TRAMPOLINE;
    assert to_host_policy("native_new") == BridgePolicy.TRAMPOLINE;
    assert to_host_policy("classmethod_ctor") == BridgePolicy.TRAMPOLINE;
    assert to_host_policy("property_ctor") == BridgePolicy.TRAMPOLINE;
    assert to_host_policy("property") == BridgePolicy.TRAMPOLINE;
}

test "table gives LAZY_ITER to every iterator/generator tag" {
    assert to_host_policy("iter") == BridgePolicy.LAZY_ITER;
    assert to_host_policy("seqiter") == BridgePolicy.LAZY_ITER;
    assert to_host_policy("rangeiter") == BridgePolicy.LAZY_ITER;
    assert to_host_policy("dictiter") == BridgePolicy.LAZY_ITER;
    assert to_host_policy("calliter") == BridgePolicy.LAZY_ITER;
    assert to_host_policy("generator") == BridgePolicy.LAZY_ITER;
}

test "table gives STANDIN/EXCEPTION/PROXY to guest-life tags" {
    assert to_host_policy("class") == BridgePolicy.STANDIN;
    assert to_host_policy("instance") == BridgePolicy.STANDIN;
    assert to_host_policy("exception") == BridgePolicy.EXCEPTION;
    assert to_host_policy("host") == BridgePolicy.PROXY;
}

test "unknown tag FAILS loudly, never None" {
    # PyHandler is VM-internal (no table entry, no conversion arm): crossing it
    # must raise, naming the tag -- the old fallthrough returned None silently.
    h = PyHandler(t="handler", start=0, end=0, target=0, depth=0, lasti=True);
    raised = False;
    try {
        to_host(h);
    } except RuntimeError {
        raised = True;
    }
    assert raised;
}

# ---- module-exception registry ---------------------------------------------

test "registry declares facade exception bases" {
    assert registered_exc_base("struct.error") == "Exception";
    assert registered_exc_base("json.JSONDecodeError") == "ValueError";
    assert registered_exc_base("csv.Error") == "Exception";
    assert registered_exc_base("_csv.Error") == "Exception";
    assert registered_exc_base("no.such.exception") == "";
}

test "registry parent links drive matching" {
    assert exc_name_matches("struct.error", "Exception");
    assert exc_name_matches("_csv.Error", "Exception");
    assert exc_name_matches("json.JSONDecodeError", "ValueError");
    assert exc_name_matches("json.JSONDecodeError", "BaseException");
    assert not exc_name_matches("json.JSONDecodeError", "OSError");
}

# ---- closed defects vs the python3 oracle ----------------------------------

test "guest class crossing gets name-faithful stand-in (was null)" {
    assert vm_repr_src(
        "class Widget:\n    pass\n"
        "try:\n"
        "    __import__('json').dumps(Widget)\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    ) == "TypeError: Object of type type is not JSON serializable";
}

test "plain user instance crossing gets name-faithful stand-in (was null)" {
    assert vm_repr_src(
        "class Point:\n    pass\n"
        "try:\n"
        "    __import__('json').dumps(Point())\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    ) == "TypeError: Object of type Point is not JSON serializable";
}

test "generator crosses lazily - non-consuming host API sees no list" {
    # Draining would hand json a list "[0, 1, 2]"; laziness keeps CPython's
    # TypeError (the generator is not JSON serializable).
    assert vm_repr_src(
        "try:\n"
        "    __import__('json').dumps((i for i in range(3)))\n"
        "    r = 'drained'\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__\n"
    ) == "TypeError";
}

test "iterator position SHARED across boundary - no silent consumption" {
    # Previously the crossing drained ALL remaining items, so next(it) raised
    # StopIteration; CPython yields 4.
    assert vm_repr_src(
        "it = iter([1, 2, 3, 4])\n"
        "next(it)\n"
        "lv = list(__import__('itertools').islice(it, 2))\n"
        "r = str(lv) + '|' + str(next(it))\n"
    ) == "[2, 3]|4";
}

test "generator still fully materializes through consuming host APIs" {
    assert vm_repr_src("g = (i*i for i in range(4))\nr = str(list(g))\n")
        == "[0, 1, 4, 9]";
    assert vm_repr_src("m = map(str, [1, 2, 3])\nr = str(list(m))\n")
        == "['1', '2', '3']";
}

test "host-raised module exception keeps FULL args tuple" {
    # Previously e.args was () -- the channel carried only str(exc).
    assert vm_repr_src(
        "import struct\n"
        "try:\n"
        "    struct.pack('z', 1)\n"
        "except BaseException as e:\n"
        "    r = repr(e.args)\n"
    ) == "('bad char in struct format',)";
}

test "except struct.error catches host-raised error by registry identity" {
    assert vm_repr_src(
        "import struct\n"
        "try:\n"
        "    struct.pack('z', 1)\n"
        "except struct.error as e:\n"
        "    r = 'caught:' + str(e.args[0])\n"
    ) == "caught:bad char in struct format";
}

test "user __repr__ replays through the VM on the stand-in" {
    assert vm_repr_src(
        "class P:\n"
        "    def __repr__(self):\n"
        "        return 'P!<>'\n"
        "r = repr(P())\n"
    ) == "P!<>";
}
