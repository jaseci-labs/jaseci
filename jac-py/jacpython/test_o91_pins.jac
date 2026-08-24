# Lane-o91 pins: opcode 91 LOAD_FROM_DICT_OR_GLOBALS dispatch arm.
# Pins ceval's OP_LOAD_FROM_DICT_OR_GLOBALS arm against CPython 3.14 semantics
# (generated_cases.c.h TARGET(LOAD_FROM_DICT_OR_GLOBALS)):
#   - pop the mapping (class namespace / module dict), look up co_names[arg];
#   - on a miss fall back to frame globals, then builtins;
#   - still missing -> NAME_ERROR_MSG byte-exact ("name 'X' is not defined").
#
# Two routes are pinned:
#   1. Hand-assembled bytecode (the host 3.14 compiler only emits opcode 91
#      inside PEP 649 __annotate__ bodies, so marshaled source never carries
#      it) -- pins the arm in isolation.
#   2. Native-compiler emission: class-scope __annotate__ bodies emit
#      LOAD_DEREF __classdict__ + LOAD_FROM_DICT_OR_GLOBALS per name
#      (compiler_emit classdict_names rule); calling D.__annotate_func__(1)
#      drives the arm end-to-end through the VM.
#
# Host oracles (CPython 3.14.7, recorded):
#   class D: y: list          -> {'y': <class 'list'>}   (builtins fallback)
#   g = 7; class E: z: g      -> {'z': 7}                (globals fallback)
#   class F: w: nosuch        -> NameError: name 'nosuchname' is not defined
import from layer9_product_exec { product_exec }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, PyInt, PyCode, PyError, is_error }
import marshal;
import types as pytypes;


def _run_native(src: str) -> str {
    # Native front end -> PyCode -> VM; repr of module global `r` or
    # "Type: message" when the VM raised.
    co = product_exec(src);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    out = exec_code(co as PyCode, [], ns);
    if is_error(out) {
        e = out as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    if "r" in ns {
        return repr(to_host(ns["r"]));
    }
    return "";
}

def _run_hand_assembled(names: tuple[str, str], seed_ns: bool) -> str {
    # Hand-assemble LOAD_LOCALS; LOAD_FROM_DICT_OR_GLOBALS name0;
    # STORE_NAME r; LOAD_CONST None; RETURN_VALUE -- drives the popped-mapping
    # lookup against the module frame's locals/globals/builtins chain.
    co_host = pytypes.CodeType(
        0,
        0,
        0,
        0,
        3,
        64,
        bytes([22, 0, 91, 0, 116, 1, 82, 0, 35, 0]),
        (None,),
        names,
        (),
        "<o91>",
        "<o91>",
        "<o91>",
        1,
        b"",
        b"",
        (),
        ()
    );
    co = unmarshal(marshal.dumps(co_host) as list[int]);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    if seed_ns {
        seedco = unmarshal(marshal.dumps(compile("v = 42", "<o91>", "exec")) as list[int]);
        out0 = exec_code(seedco, [], ns);
        if is_error(out0) {
            e0 = out0 as PyError;
            return str(e0.exception.type_name) + ": " + str(e0.exception.message);
        }
    }
    out = exec_code(co, [], ns);
    if is_error(out) {
        e = out as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    if "r" in ns {
        # Builtins resolved through the fallback stay as VM-native objects
        # (BridgePolicy.TRAMPOLINE, no to_host arm), so report them by type
        # tag instead of forcing them across the host bridge.
        if ns["r"].t == "native_builtin" {
            return "<native_builtin>";
        }
        return repr(to_host(ns["r"]));
    }
    return "";
}


# ---------------- tests ----------------

test "o91 hand-assembled: mapping hit short-circuits globals" {
    # Host oracle: exec of the same code object with ns={"v": 42} stores 42.
    assert _run_hand_assembled(("v", "r"), True) == "42";
}

test "o91 hand-assembled: globals miss falls back to builtins" {
    # Host oracle: same shape resolves 'len' through builtins.
    assert _run_hand_assembled(("len", "r"), False) == "<native_builtin>";
}

test "o91 hand-assembled: full miss raises exact NAME_ERROR_MSG" {
    # Host oracle: NameError: name 'v' is not defined.
    assert _run_hand_assembled(("v", "r"), False) == "NameError: name 'v' is not defined";
}

test "o91 native emission: __annotate__ body resolves builtin through classdict" {
    # Host oracle (PEP 649): D.__annotations__ == {'y': list}.
    assert _run_native(
        "class D:\n"
        "    y: list\n"
        "r = D.__annotate_func__(1)['y'] is list\n"
    ) == "True";
}

test "o91 native emission: __annotate__ body resolves module global" {
    # Host oracle (PEP 649): g = 7; E.__annotations__ == {'z': 7}.
    assert _run_native(
        "g = 7\n"
        "class E:\n"
        "    z: g\n"
        "r = E.__annotate_func__(1)['z'] == 7\n"
    ) == "True";
}

test "o91 native emission: __annotate__ missing name raises exact NameError" {
    # Host oracle: accessing F.__annotations__ raises
    # NameError: name 'nosuch' is not defined.
    assert _run_native(
        "class F:\n"
        "    w: nosuch\n"
        "r = F.__annotate_func__(1)\n"
    ) == "NameError: name 'nosuch' is not defined";
}

test "o91 module differential: module-level from-import of dataclass binds callable" {
    # Host oracle (python3.14): prints True. Module-level
    # `from dataclasses import dataclass` never carries opcode 91 itself,
    # but binding the name is what unblocks the @dataclass workflow whose
    # annotation reads route through this arm (see the native-emission pins
    # above). Applying @dataclass to a VM-native class is still blocked by
    # the host-class bridge (BridgePolicy.STANDIN has no to_host arm) -- a
    # separate interop gap, not an opcode-91 semantics gap.
    assert _run_native(
        "from dataclasses import dataclass\n"
        "r = callable(dataclass)\n"
    ) == "True";
}
