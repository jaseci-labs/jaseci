# PEP 750 t-string runtime arms (BUILD_INTERPOLATION / BUILD_TEMPLATE).
# Our compiler does not emit t-string opcodes yet, but host-compiled bytecode
# carrying them must execute: the pins marshal a host-compiled t-string
# program and run it through unmarshal/exec_code (the exec/marshal path the
# opcode audit flagged as crash-class). Semantics verified against CPython
# 3.14: oparg bit0 = format spec present, bits 3+ = conversion id
# (0 None / 1 r / 2 s / 3 a); Template.strings holds literal parts;
# Interpolation(value, expression, conversion, format_spec) with format_spec
# '' when unset.
import from objects { PyObj, PyStr, PyError, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

# Host-side snippet builder: compiles on the pinned interpreter and returns
# the marshaled code object bytes for guest execution.
def hcompile(source: str) -> PyObj {
    raw = host_compile_marshal(source, "<jacpython-host>", "exec");
    return unmarshal(raw);
}

def run(body: str) -> str {
    co_r = hcompile(body);
    assert not is_error(co_r);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(co_r, [], ns);
    if is_error(outcome) {
        e = outcome as PyError;
        return "ERR " + e.exception.type_name + ": " + e.exception.message;
    }
    v = ns["rv"];
    if isinstance(v, PyStr) {
        return (v as PyStr).val;
    }
    return "<obj t=" + v.t + ">";
}

test "t-string arms: template assembly and field surface" {
    rv = run(
        "b = [1, 2]\n"
        "tmpl = t\"pre{b}mid{b!r:>8}\"\n"
        "lines = []\n"
        "lines.append('strings=' + str(tmpl.strings))\n"
        "lines.append('n=' + str(len(tmpl.interpolations)))\n"
        "i0 = tmpl.interpolations[0]\n"
        "i1 = tmpl.interpolations[1]\n"
        "lines.append('v0=' + str(i0.value) + ',' + i0.expression + ',' + str(i0.conversion))\n"
        "lines.append('fmt1=' + str(i1.format_spec) + ',' + str(i1.conversion))\n"
        "rv = ' | '.join(lines)\n"
    );
    assert rv == "strings=('pre', 'mid', '') | n=2 | v0=[1, 2],b,None | fmt1=>8,r";
}

test "t-string arms: iteration interleaves strings and interpolations" {
    rv = run(
        "b = [1, 2]\n"
        "tmpl = t\"pre{b}mid{b!r:>8}\"\n"
        "parts = []\n"
        "for part in tmpl:\n"
        "    if part.__class__.__name__ == 'Interpolation':\n"
        "        parts.append('<I>')\n"
        "    else:\n"
        "        parts.append(part)\n"
        "rv = '|'.join(parts)\n"
    );
    assert rv == "pre|<I>|mid|<I>|";
}
