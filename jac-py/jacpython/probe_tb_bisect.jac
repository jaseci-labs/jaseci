import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }
import from objects { PyObj, PyStr, PyCode, PyError, is_error }


def _run(src: str, native: bool) -> str {
    co = compile_source(src, "<bisect>", "exec", 0);
    if not native {
        co = unmarshal(host_compile_marshal(src, "<bisect>", "exec"));
    }
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    out = exec_code(co as PyCode, [], ns);
    if is_error(out) {
        e = out as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    return "ok";
}


glob SRC_WALK2 = (
    "def h():\n"
    "    raise ValueError('deep')\n"
    "try:\n"
    "    h()\n"
    "except ValueError as e:\n"
    "    parts = []\n"
    "    t = e.__traceback__\n"
    "    while t is not None:\n"
    "        parts.append((t.tb_frame.f_code.co_name, t.tb_lineno))\n"
    "        t = t.tb_next\n"
    "raise RuntimeError('OBS ' + repr(parts))\n"
);

# same but raise inside except block
glob SRC_WALK2_INNER = (
    "def h():\n"
    "    raise ValueError('deep')\n"
    "try:\n"
    "    h()\n"
    "except ValueError as e:\n"
    "    parts = []\n"
    "    t = e.__traceback__\n"
    "    while t is not None:\n"
    "        parts.append((t.tb_frame.f_code.co_name, t.tb_lineno))\n"
    "        t = t.tb_next\n"
    "    raise RuntimeError('OBS ' + repr(parts))\n"
);

test "bisect walk2 native" { print("native: " + _run(SRC_WALK2, True)); print("native-inner: " + _run(SRC_WALK2_INNER, true)); }
test "bisect walk2 marshal" { print("marshal: " + _run(SRC_WALK2, False)); print("marshal-inner: " + _run(SRC_WALK2_INNER, false)); }
