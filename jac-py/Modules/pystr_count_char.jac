# c2jac: 2 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L12 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L12 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied

def pystr_count_char(s: str, ch: int) -> int {
    n: int = 0;
    i: int = 0;
    if (s == 0) {
        return 0;
    }

    n = 0;
    i = 0;
    while (s[i] != 0) {
        if (s[i] == ch) {
            n += 1;
        }

        i += 1;
    }

    return n;
}
