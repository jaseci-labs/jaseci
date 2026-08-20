# c2jac: 1 best-effort site lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L6 [W4207] variadic `...` lowered to `*args` — `va_list`/`va_arg` not modelled

glob va_list = str;

def PyOS_snprintf(`str: str, size: int, format: str) -> int {
    raise "c2jac: quarantined function 'PyOS_snprintf' — L6 [W4207] variadic `...` lowered to `*args` — `va_list`/`va_arg` not modelled";
}

def PyOS_vsnprintf(`str: str, size: int, format: str, va: va_list) -> int {
    len: int = 0;
    if (size > 2147483646) {
        len = -666;
    } else {
        len = vsnprintf(`str, size, format, va);
    }

    if (size > 0) {
        `str[(size - 1)] = 0;
    }

    return len;
}
