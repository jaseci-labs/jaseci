# M12 probe wrapper: compiles scenario_f_deep_chain_tb.py on the HOST oracle and executes it on
# the guest ceval via exec_code. The script's own stdout (tb walks + labels)
# is the guest half of the host-vs-guest diff. Run from jac-py/jacpython:
#   cd jac-py/jacpython && timeout 240 jac run probes_m12/probe_f.jac
import from pyc_first { host_compile_marshal, unmarshal }
import from pyc_first { exec_code, unmarshal }
import from objects { PyObj, PyStr, PyError, is_error }

::py::
with open("probes_m12/scenario_f_deep_chain_tb.py") as fh:
    SRC = fh.read()
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
