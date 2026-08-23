# Product-path facade for _random (wave 18): the Mersenne Twister
# Random generator type.
#
# Staged ``jac-py/Modules/randommodule.{c,jac}`` remain the wave-18 c2jac
# corpus oracle pair (staging=lift); this module carries the runtime truth.
# Semantics mirror CPython 3.14.6 ``Modules/_randommodule.c`` exactly and
# are bit-exact against the pinned host stdlib ``_random``: seeded uint32
# streams, random()'s 53-bit doubles, getrandbits word assembly, and the
# 625-tuple getstate/setstate shape all match the host to the bit.
#
# Surface: Random.random(), .getrandbits(k), .getstate(), .setstate(state),
# .seed([n]).  ``jumpahead`` was removed in Python 3.11 and is absent from
# the pinned source.  Construct instances through ``Random_new(seed)``
# (mirrors ``_random.Random([seed])`` including the urandom default); a
# bare archetype instance carries the zeroed C layout (index 0) and must
# be seeded before use.
#
# Seeding semantics (random_seed in the pinned source):
# - None -> os.urandom key (falls back to time+pid in C; urandom never
#   fails here, so the fallback is unreachable and omitted)
# - int -> abs(n), split little-endian into 32-bit key words
# - anything else -> hash(n) cast to size_t (two's complement 64-bit),
#   split the same way
#
# Error mapping keeps builtin TypeError/ValueError/OverflowError exact,
# including the clinic converter messages for getrandbits(k).

import os;

glob MT_N = 624;
glob MT_M = 397;
glob MATRIX_A = 2567483615;      # 0x9908b0dfU
glob UPPER_MASK = 2147483648;    # 0x80000000U
glob LOWER_MASK = 2147483647;    # 0x7fffffffU


obj Random {
    has state: list[int] = [],
        index: int = 0;

    # ------------------------------------------------------------------
    # MT19937 kernel (bit-exact; see wave-18 corpus extract).

    def _generate_block {
        y: int = 0;
        mag: int = 0;
        st = self.state;
        for kk in range(MT_N - MT_M) {
            y = (st[kk] & UPPER_MASK) | (st[kk + 1] & LOWER_MASK);
            mag = MATRIX_A if y & 1 else 0;
            st[kk] = st[kk + MT_M] ^ (y >> 1) ^ mag;
        }
        for kk in range(MT_N - MT_M, MT_N - 1) {
            y = (st[kk] & UPPER_MASK) | (st[kk + 1] & LOWER_MASK);
            mag = MATRIX_A if y & 1 else 0;
            st[kk] = st[kk + (MT_M - MT_N)] ^ (y >> 1) ^ mag;
        }
        y = (st[MT_N - 1] & UPPER_MASK) | (st[0] & LOWER_MASK);
        mag = MATRIX_A if y & 1 else 0;
        st[MT_N - 1] = st[MT_M - 1] ^ (y >> 1) ^ mag;
    }

    def _temper(y: int) -> int {
        y ^= y >> 11;
        y ^= (y << 7) & 2636928640;   # 0x9d2c5680U
        y ^= (y << 15) & 4022730752;  # 0xefc60000U
        y ^= y >> 18;
        return y;
    }

    def _genrand_uint32 -> int {
        if self.index >= MT_N {
            self._generate_block();
            self.index = 0;
        }
        y = self.state[self.index];
        self.index = self.index + 1;
        return self._temper(y);
    }

    def _init_genrand(s: int) {
        mt: list[int] = [0] * MT_N;
        mt[0] = s;
        for mti in range(1, MT_N) {
            mt[mti] = (
                (1812433253 * (mt[mti - 1] ^ (mt[mti - 1] >> 30)) + mti)
                & 0xFFFFFFFF
            );
        }
        self.state = mt;
        self.index = MT_N;
    }

    def _init_by_array(key: list[int]) {
        key_length = len(key);
        self._init_genrand(19650218);
        mt = self.state;
        i = 1;
        j = 0;
        k = MT_N if MT_N > key_length else key_length;
        while k {
            mt[i] = (
                (
                    (mt[i] ^ ((mt[i - 1] ^ (mt[i - 1] >> 30)) * 1664525
                              & 0xFFFFFFFF))
                    + key[j] + j
                ) & 0xFFFFFFFF
            );
            i = i + 1;
            j = j + 1;
            if i >= MT_N {
                mt[0] = mt[MT_N - 1];
                i = 1;
            }
            if j >= key_length {
                j = 0;
            }
            k = k - 1;
        }
        k = MT_N - 1;
        while k {
            # (mt[i] ^ prod32) - i mod 2^32; the mask realizes unsigned wrap.
            mt[i] = (
                (
                    (mt[i] ^ ((mt[i - 1] ^ (mt[i - 1] >> 30)) * 1566083941
                              & 0xFFFFFFFF))
                    + 0x100000000 - i
                ) & 0xFFFFFFFF
            );
            i = i + 1;
            if i >= MT_N {
                mt[0] = mt[MT_N - 1];
                i = 1;
            }
            k = k - 1;
        }
        mt[0] = 0x80000000;  # MSB is 1; assuring non-zero initial array
    }

    # ------------------------------------------------------------------
    # Seeding (random_seed).

    def seed(n: any = None) {
        if n is None {
            # random_seed_urandom: one 624-word key straight from urandom.
            raw = os.urandom(MT_N * 4);
            key: list[int] = [];
            for i in range(0, MT_N * 4, 4) {
                key.append(
                    (raw[i] | (raw[i + 1] << 8) | (raw[i + 2] << 16)
                     | (raw[i + 3] << 24)) as int
                );
            }
            self._init_by_array(key);
            return;
        }
        v: int = 0;
        if isinstance(n, int) {
            # abs(n); relies on the value being treated as unsigned below.
            v = abs(n as int);
        } else {
            # hash(arg) cast to size_t (unsigned 64-bit).
            h = hash(n);
            if h < 0 {
                h = h + 18446744073709551616;
            }
            v = h as int;
        }
        # Split v into 32-bit little-endian chunks; a zero value still
        # consumes one key word.
        bits = v.bit_length();
        keyused = 1 if bits == 0 else (bits - 1) // 32 + 1;
        key: list[int] = [];
        for _ in range(keyused) {
            key.append((v & 0xFFFFFFFF) as int);
            v = v >> 32;
        }
        self._init_by_array(key);
    }

    # ------------------------------------------------------------------
    # Output surface.

    def random -> float {
        # genrand_res53: top 27 bits and low 26 bits form the numerator;
        # every step scales by a power of two, so the double is exact.
        a = self._genrand_uint32() >> 5;
        b = self._genrand_uint32() >> 6;
        return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);
    }

    def getrandbits(k: any) -> int {
        if not isinstance(k, int) {
            raise TypeError(
                "'" + type(k).__name__
                + "' object cannot be interpreted as an integer"
            );
        }
        kv = k as int;
        if kv < 0 {
            raise ValueError("Cannot convert negative int");
        }
        if kv >= 18446744073709551616 {
            raise OverflowError("Python int too large for C uint64_t");
        }
        if kv == 0 {
            return 0;
        }
        if kv <= 32 {
            return self._genrand_uint32() >> (32 - kv);
        }
        rem = kv;
        out = 0;
        shift = 0;
        while rem > 0 {
            r = self._genrand_uint32();
            if rem < 32 {
                r = r >> (32 - rem);  # Drop least significant bits
            }
            out = out | (r << shift);
            shift = shift + 32;
            rem = rem - 32;
        }
        return out;
    }

    def getstate -> tuple {
        items: list = [];
        for i in range(MT_N) {
            items.append(self.state[i]);
        }
        items.append(self.index);
        return tuple(items);
    }

    def setstate(state: any) {
        if not isinstance(state, tuple) {
            raise TypeError("state vector must be a tuple");
        }
        if len(state) != MT_N + 1 {
            raise ValueError("state vector is the wrong size");
        }
        new_state: list[int] = [];
        for i in range(MT_N) {
            element = state[i];
            if not isinstance(element, int) {
                raise TypeError("an integer is required");
            }
            ev = element as int;
            if ev < 0 {
                raise OverflowError(
                    "can't convert negative value to unsigned int"
                );
            }
            new_state.append(ev & 0xFFFFFFFF);
        }
        idx = state[MT_N];
        if not isinstance(idx, int) {
            raise TypeError("an integer is required");
        }
        iv = idx as int;
        if iv < 0 or iv > MT_N {
            raise ValueError("invalid state");
        }
        self.index = iv;
        self.state = new_state;
    }
}


# _random.Random([seed]): generic-new plus __init__(seed).
def Random_new(seed: any = None) -> Random {
    r: Random = Random();
    r.seed(seed);
    return r;
}
