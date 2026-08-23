# c2jac: 17 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L22 [W4201] cast to `uint64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L22 [W4201] cast to `uint32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L23 [W4201] cast to `uint32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L23 [W4201] cast to `uint64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L42 [W4201] cast to `uint64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L42 [W4201] cast to `uint32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L43 [W4201] cast to `uint32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L43 [W4201] cast to `uint64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L43 [W4201] cast to `uint32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L44 [W4201] cast to `uint64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L52 [W4201] cast to `uint64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L52 [W4201] cast to `uint32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L53 [W4201] cast to `uint32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L53 [W4201] cast to `uint64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L53 [W4201] cast to `uint32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L54 [W4201] cast to `uint64_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L54 [W4201] cast to `uint32_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied

glob uint32_t = int;
glob uint64_t = int;
glob int64_t = int;


def mt_init_genrand(mt: list, s: int) -> None {
    mti: int = 0;
    prod: int = 0;
    mt[0] = s;
    for mti = 1 while mti < 624 with mti += 1 {
        prod = (mt[(mti - 1)] ^ (mt[(mti - 1)] >> 30)) * 1812433253;
        mt[mti] = (prod + mti) & 4294967295;
    }
}


def mt_init_by_array(mt: list, init_key: list, key_length: int) -> None {
    i: int = 0;
    j: int = 0;
    k: int = 0;
    maxinit: int = 0;
    prod: int = 0;
    mt_init_genrand(mt, 19650218);
    i = 1;
    j = 0;
    maxinit = 624 if (624 > key_length) else key_length;
    k = maxinit;
    while k {
        prod = (mt[(i - 1)] ^ (mt[(i - 1)] >> 30)) * 1664525;
        mt[i] = (((mt[i] ^ (prod & 4294967295)) + init_key[j]) + j) & 4294967295;

        i += 1;
        j += 1;
        if (i >= 624) {
            mt[0] = mt[(624 - 1)];
            i = 1;
        }
        if (j >= key_length) {
            j = 0;
        }
        k -= 1;
    }

    k = 624 - 1;
    while k {
        prod = (mt[(i - 1)] ^ (mt[(i - 1)] >> 30)) * 1566083941;
        mt[i] = (((mt[i] ^ (prod & 4294967295)) + 4294967296) - i) & 4294967295;

        i += 1;
        if (i >= 624) {
            mt[0] = mt[(624 - 1)];
            i = 1;
        }
        k -= 1;
    }

    mt[0] = 2147483648;
}


def mt_generate_block(mt: list) -> None {
    y: int = 0;
    mag: int = 0;
    kk: int = 0;
    for kk = 0 while kk < (624 - 397) with kk += 1 {
        y = (mt[kk] & 2147483648) | (mt[(kk + 1)] & 2147483647);
        mag = 2567483615 if (y & 1) else 0;
        mt[kk] = (mt[(kk + 397)] ^ (y >> 1)) ^ mag;
    }

    while (kk < (624 - 1)) {
        y = (mt[kk] & 2147483648) | (mt[(kk + 1)] & 2147483647);
        mag = 2567483615 if (y & 1) else 0;
        mt[kk] = (mt[(kk + (397 - 624))] ^ (y >> 1)) ^ mag;
        kk += 1;
    }

    y = (mt[(624 - 1)] & 2147483648) | (mt[0] & 2147483647);
    mag = 2567483615 if (y & 1) else 0;
    mt[(624 - 1)] = (mt[(397 - 1)] ^ (y >> 1)) ^ mag;
}


def mt_temper(y: int) -> int {
    y ^= y >> 11;
    y ^= (y << 7) & 2636928640;
    y ^= (y << 15) & 4022730752;
    y ^= y >> 18;
    return y;
}


def mt_random_res53(a: int, b: int) -> float {
    return (((a * 67108864.0) + b) * (1.0 / 9007199254740992.0));
}


def mt_seed_key_words(bits: int) -> int {
    if (bits == 0) {
        return 1;
    }

    return (((bits - 1) / 32) + 1);
}


def mt_getrandbits_words(k: int) -> int {
    return (((k - 1) / 32) + 1);
}


def mt_getrandbits_word(r: int, k: int) -> int {
    if (k < 32) {
        return (r >> (32 - k));
    }

    return r;
}
