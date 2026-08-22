# c2jac: 1 best-effort site lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L19 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied

glob Py_ssize_t = int;


def itertools_count_next_fast(cnt: object, out: object) -> int {
    if (cnt == 9223372036854775807) {
        return -1;
    }

    out = cnt;
    cnt = cnt + 1;
    return 0;
}


def itertools_cycle_advance(index: int, saved_len: int) -> int {
    next: int = index + 1;
    if (next >= saved_len) {
        next = 0;
    }

    return next;
}


def itertools_repeat_take(cnt: object) -> int {
    if (cnt == 0) {
        return 0;
    }

    if (cnt > 0) {
        cnt = cnt - 1;
    }

    return 1;
}


def itertools_chain_scan(remaining: object, nsrc: int, active: object) -> int {
    if (active < 0) {
        active = 0;
    }

    while (active < nsrc) {
        if (remaining[active] > 0) {
            remaining[active] = remaining[active] - 1;
            return active;
        }

        active = active + 1;
    }

    return -1;
}
