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


def itertools_product_advance(indices: object, sizes: object, npools: int) -> int {
    i: int = npools - 1;
    while (i >= 0) {
        indices[i] = indices[i] + 1;
        if (indices[i] < sizes[i]) {
            return 0;
        }

        indices[i] = 0;
        i = i - 1;
    }

    return -1;
}


def itertools_combinations_scan(indices: object, n: int, r: int) -> int {
    i: int = r - 1;
    j: int = 0;
    while ((i >= 0) and (indices[i] == ((i + n) - r))) {
        i = i - 1;
    }

    if (i < 0) {
        return -1;
    }

    indices[i] = indices[i] + 1;
    for j = i + 1 while j < r with j += 1 {
        indices[j] = indices[(j - 1)] + 1;
    }

    return i;
}


def itertools_cwr_scan(indices: object, n: int, r: int) -> int {
    i: int = r - 1;
    j: int = 0;
    index: int = 0;
    while ((i >= 0) and (indices[i] == (n - 1))) {
        i = i - 1;
    }

    if (i < 0) {
        return -1;
    }

    index = indices[i] + 1;
    for j = i while j < r with j += 1 {
        indices[j] = index;
    }

    return i;
}


def itertools_permutations_step(
    indices: object, cycles: object, n: int, r: int
) -> int {
    i: int = r - 1;
    j: int = 0;
    index: int = 0;
    while (i >= 0) {
        cycles[i] = cycles[i] - 1;
        if (cycles[i] == 0) {
            index = indices[i];
            for j = i while j < (n - 1) with j += 1 {
                indices[j] = indices[(j + 1)];
            }

            indices[(n - 1)] = index;
            cycles[i] = n - i;
            i = i - 1;
        } else {
            j = cycles[i];
            index = indices[i];
            indices[i] = indices[(n - j)];
            indices[(n - j)] = index;
            break;
        }
    }

    if (i < 0) {
        return -1;
    }

    return i;
}


def itertools_islice_take(
    cnt: object, next: object, stop: int, step: int, remaining: object
) -> int {
    while (cnt < next) {
        if (remaining <= 0) {
            return -1;
        }

        remaining = remaining - 1;
        cnt = cnt + 1;
    }

    if ((stop != -1) and (cnt >= stop)) {
        return 0;
    }

    if (remaining <= 0) {
        return -1;
    }

    remaining = remaining - 1;
    cnt = cnt + 1;

    oldnext: int = next;

    next = next + step;
    if ((next < oldnext) or ((stop != -1) and (next > stop))) {
        next = stop;
    }

    return 1;
}


def itertools_ziplongest_round(remaining: object, nsrc: int, numactive: object) -> int {
    i: int = 0;
    for i = 0 while i < nsrc with i += 1 {
        if (remaining[i] > 0) {
            remaining[i] = remaining[i] - 1;
        } else {
            numactive = numactive - 1;
            if (numactive == 0) {
                return 0;
            }
        }
    }

    return 1;
}


def itertools_groupby_run(keys: object, n: int, run_key: object) -> int {
    taken: int = 0;
    if (n <= 0) {
        return -1;
    }

    run_key = keys[0];
    taken = 1;
    while ((taken < n) and (keys[taken] == run_key)) {
        taken = taken + 1;
    }

    i: int = 0;
    for i = taken while i < n with i += 1 {
        keys[(i - taken)] = keys[i];
    }

    return taken;
}


def itertools_batched_take(
    remaining: object, n: int, strict: int, taken_out: object
) -> int {
    taken: int = 0;
    while ((taken < n) and (remaining > 0)) {
        remaining = remaining - 1;
        taken = taken + 1;
    }

    taken_out = taken;
    if (taken == 0) {
        return -1;
    }

    if ((taken < n) and strict) {
        return -2;
    }

    return 0;
}


def itertools_dropwhile_flip(pred: int, remaining: object, dropping: object) -> int {
    if (remaining <= 0) {
        return -1;
    }

    if dropping {
        if pred {
            remaining = remaining - 1;
            return 0;
        }

        dropping = 0;
    }

    remaining = remaining - 1;
    return 1;
}


def itertools_takewhile_flip(pred: int, remaining: object, taking: object) -> int {
    if not taking {
        return 0;
    }

    if (remaining <= 0) {
        return -1;
    }

    if pred {
        remaining = remaining - 1;
        return 1;
    }

    taking = 0;
    return 0;
}
