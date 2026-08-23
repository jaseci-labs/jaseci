/* Header-free extract: MT19937 Mersenne Twister kernels.
 *
 * Source: CPython 3.14.6 Modules/_randommodule.c (pinned reference).
 * Slices: init_genrand seeding (Knuth multiplier 1812433253 path),
 * init_by_array key-mixing (1664525 / 1566083941 non-linear passes),
 * the N-word twist block of genrand_uint32, the tempering shift/xor
 * cascade, the genrand_res53 double composition, and the seed/getrandbits
 * size helpers.
 *
 * The PyObject glue (RandomObject type, urandom/time-pid seeding,
 * getstate/setstate tuples, PyLong word assembly) stays in the product
 * facade (jac-py/jacpython/_randommodule.jac); these kernels carry the
 * integer control flow verbatim so they can be differentially lifted and
 * ratcheted by c2jac.
 *
 * Bit-exactness note: uint32_t multiplication wraps mod 2^32.  c2jac lifts
 * C arithmetic into wide (unbounded) ints, so each wrapping step is spelled
 * with a uint64_t intermediate and an explicit & 0xffffffff mask — which is
 * exactly equivalent in C (the mask is a no-op there) and exact under the
 * lift.  All operands are unsigned, so no sign issues arise.  mag01[] is
 * spelled as its value: mag01[y & 1] is 0 or MATRIX_A.
 */

typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
typedef long long int64_t;

/* Period parameters -- These are all magic.  Don't change. */
#define N 624
#define M 397
#define MATRIX_A 0x9908b0dfU    /* constant vector a */
#define UPPER_MASK 0x80000000U  /* most significant w-r bits */
#define LOWER_MASK 0x7fffffffU  /* least significant r bits */

/* initializes mt[N] with a seed */
void
mt_init_genrand(uint32_t mt[N], uint32_t s)
{
    int mti;
    uint64_t prod;
    mt[0] = s;
    for (mti = 1; mti < N; mti++) {
        /* mt[mti] = (1812433253U * (mt[mti-1] ^ (mt[mti-1] >> 30)) + mti)
         *            mod 2^32; see Knuth TAOCP Vol2. 3rd Ed. P.106. */
        prod = (uint64_t)(uint32_t)(mt[mti-1] ^ (mt[mti-1] >> 30)) * 1812433253ULL;
        mt[mti] = (uint32_t)((prod + (uint64_t)mti) & 0xffffffffULL);
    }
}

/* initialize by an array with array-length */
/* init_key is the array for initializing keys */
/* key_length is its length */
void
mt_init_by_array(uint32_t mt[N], uint32_t init_key[], int key_length)
{
    int i, j, k;
    int maxinit;
    uint64_t prod;
    mt_init_genrand(mt, 19650218U);
    i = 1; j = 0;
    maxinit = (N > key_length ? N : key_length);
    for (k = maxinit; k; k--) {
        /* mt[i] = (mt[i] ^ ((mt[i-1] ^ (mt[i-1] >> 30)) * 1664525U))
         *         + init_key[j] + (uint32_t)j;  all mod 2^32 (non linear) */
        prod = (uint64_t)(uint32_t)(mt[i-1] ^ (mt[i-1] >> 30)) * 1664525ULL;
        mt[i] = (uint32_t)((((uint64_t)(mt[i] ^ (uint32_t)(prod & 0xffffffffULL))
                             + init_key[j] + (uint64_t)j)) & 0xffffffffULL);
        i++; j++;
        if (i >= N) { mt[0] = mt[N-1]; i = 1; }
        if (j >= key_length) j = 0;
    }
    for (k = N - 1; k; k--) {
        /* mt[i] = (mt[i] ^ ((mt[i-1] ^ (mt[i-1] >> 30)) * 1566083941U))
         *         - (uint32_t)i;  all mod 2^32 (non linear) */
        prod = (uint64_t)(uint32_t)(mt[i-1] ^ (mt[i-1] >> 30)) * 1566083941ULL;
        mt[i] = (uint32_t)((((uint64_t)(mt[i] ^ (uint32_t)(prod & 0xffffffffULL))
                             + 0x100000000ULL - (uint64_t)(uint32_t)i)) & 0xffffffffULL);
        i++;
        if (i >= N) { mt[0] = mt[N-1]; i = 1; }
    }

    mt[0] = 0x80000000U; /* MSB is 1; assuring non-zero initial array */
}

/* The "generate N words at one time" block of genrand_uint32: twists the
 * whole state in place so index can restart at 0. */
void
mt_generate_block(uint32_t mt[N])
{
    uint32_t y;
    uint32_t mag;
    int kk;
    for (kk = 0; kk < N - M; kk++) {
        y = (mt[kk] & UPPER_MASK) | (mt[kk+1] & LOWER_MASK);
        mag = (y & 0x1U) ? MATRIX_A : 0U; /* mag01[y & 1] */
        mt[kk] = mt[kk+M] ^ (y >> 1) ^ mag;
    }
    for (; kk < N - 1; kk++) {
        y = (mt[kk] & UPPER_MASK) | (mt[kk+1] & LOWER_MASK);
        mag = (y & 0x1U) ? MATRIX_A : 0U; /* mag01[y & 1] */
        mt[kk] = mt[kk+(M-N)] ^ (y >> 1) ^ mag;
    }
    y = (mt[N-1] & UPPER_MASK) | (mt[0] & LOWER_MASK);
    mag = (y & 0x1U) ? MATRIX_A : 0U; /* mag01[y & 1] */
    mt[N-1] = mt[M-1] ^ (y >> 1) ^ mag;
}

/* Tempering cascade applied to each output word of genrand_uint32. */
uint32_t
mt_temper(uint32_t y)
{
    y ^= (y >> 11);
    y ^= (y << 7) & 0x9d2c5680U;
    y ^= (y << 15) & 0xefc60000U;
    y ^= (y >> 18);
    return y;
}

/* random_random is the function named genrand_res53 in the original code;
 * generates a random number on [0,1) with 53-bit resolution; a holds the
 * top 27 bits, b fills in the lower 26 of the 53-bit numerator.  Every
 * step scales by a power of two, so the double result is bit-exact.
 * Isaku Wada algorithm, 2002/01/09. */
double
mt_random_res53(uint32_t a, uint32_t b)
{
    return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);
}

/* Number of 32-bit key words needed to cover a seed of `bits` bits
 * (`keyused` in random_seed): a zero-bit seed still consumes one word. */
int
mt_seed_key_words(int64_t bits)
{
    if (bits == 0) {
        return 1;
    }
    return (int)((bits - 1) / 32 + 1);
}

/* Word count for getrandbits(k): `(k - 1) / 32 + 1`. */
int
mt_getrandbits_words(uint64_t k)
{
    return (int)(((k - 1u) / 32u) + 1u);
}

/* Per-word right-truncation in getrandbits: when fewer than 32 bits remain,
 * drop the least significant bits of the drawn word (fast path k <= 32
 * shares this shape with k == 32 as a no-op). */
uint32_t
mt_getrandbits_word(uint32_t r, uint64_t k)
{
    if (k < 32) {
        return r >> (32 - k); /* Drop least significant bits */
    }
    return r;
}
