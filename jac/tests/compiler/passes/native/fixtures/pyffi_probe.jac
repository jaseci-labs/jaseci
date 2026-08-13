"""Probe: call CPython C-API functions as named clib externs from native jac.
The `python` clib namespace resolves against the host process: under the JIT
the symbols are already mapped (the engine searches the process image), and a
sealed artifact binds them at load via lazy PLT (ELF) or flat lookup
(Mach-O), so there is never a second interpreter copy."""
import from python {
    def PyLong_FromLongLong(v: int) -> int;  def PyLong_AsLongLong(o: int) -> int;  def Py_DecRef(
        o: int
    ) -> None;
}

def roundtrip(v: int) -> int {
    boxed = PyLong_FromLongLong(v);
    if boxed == 0 {
        return -1;
    }
    out = PyLong_AsLongLong(boxed);
    Py_DecRef(boxed);
    return out;
}
