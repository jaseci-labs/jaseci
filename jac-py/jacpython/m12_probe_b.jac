# M12 probe wrapper: compiles scenario_b_athrow_escape.py on the HOST oracle and executes it on
# the guest ceval via exec_code. The script's own stdout (tb walks + labels)
# is the guest half of the host-vs-guest diff. Run from jac-py/jacpython:
#   cd jac-py/jacpython && timeout 240 jac run probes_m12/probe_b.jac
import from pyc_first { host_compile_marshal, unmarshal }
import from pyc_first { exec_code, unmarshal }
import from objects { PyObj, PyStr, PyError, is_error }

::py::
SRC = None
for _p in ("probes_m12/scenario_b_athrow_escape.py", "jac-py/jacpython/probes_m12/scenario_b_athrow_escape.py"):
    try:
        with open(_p) as fh:
            SRC = fh.read()
        break
    except OSError:
        continue
::py::

with entry {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(SRC)), [], ns
    );
    if is_error(outcome) {
        exc = (outcome as PyError).exception;
        print("WRAPPER-ERROR:", exc.type_name, exc.message);
    }
}
