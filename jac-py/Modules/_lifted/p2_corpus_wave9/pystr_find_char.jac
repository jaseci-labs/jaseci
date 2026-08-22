# c2jac: 2 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L10 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L10 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied

def pystr_find_char(s: str, ch: int) -> int {
    i: int = 0;
    if (s == 0) {
        return -1;
    }

    i = 0;
    while (s[i] != 0) {
        if (s[i] == ch) {
            return i;
        }

        i += 1;
    }

    return -1;
}
