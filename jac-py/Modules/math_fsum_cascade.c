/* Header-free extract: math module float/integer kernels.
 *
 * Source: CPython 3.14.6 Modules/mathmodule.c (pinned reference).
 * Slices: dl_fast_sum/dl_sum error-free transformations (Algorithms 1.1
 * and 3.1), the math.fsum partial-compaction hi/lo cascade, the
 * math.isclose tolerance ladder, and the perm_comb_small sequential
 * product/divide fast loops for comb() and perm().
 *
 * Mechanical lift adaptations (statement-level, semantics-preserving):
 * - DoubleLength struct returns are flattened to a caller-owned
 *   `double out[]` array so the kernels stay header-free standalone
 *   functions without pointer-to-scalar params (out[0]=hi, out[1]=lo;
 *   fsum's surviving x uses the same channel via x_out[0]).
 * - The post-increment store `p[i++] = lo` is split into an indexed
 *   store plus a separate increment; c2jac lowers the fused idiom to a
 *   no-op walrus (verified against wave 15 output), the split form
 *   lifts faithfully.
 * - perm_comb_small's `result *= --n` / `result /= ++i` are split into
 *   separate update statements; the fused forms lift to walrus-mixed
 *   compound assignment that loses integer-division lowering.
 * - fabs() is spelled as a branch stand-in (m_fabs) with identical IEEE
 *   semantics including -0.0 -> 0.0.
 * - The isclose sanity check returns an error flag instead of raising;
 *   callers map it to ValueError "tolerances must be non-negative".
 *
 * The PyObject glue (iterators, Argument Clinic surfaces, PyFloat
 * boxing) stays in the product facade; these kernels carry the
 * floating/integer control-state machines verbatim so they can be
 * differentially lifted and ratcheted by c2jac.
 */

typedef long Py_ssize_t; /* LP64, mirrors jacport.h */
typedef unsigned long long uint64_t_; /* <stdint.h> stand-in */

/* Algorithm 1.1: compensated (error-free) sum of two doubles.
 * Requires |a| >= |b| (fsum calls it with partially sorted partials). */
void
dl_fast_sum(double a, double b, double out[2])
{
    double x = a + b;
    double y = (a - x) + b;
    out[0] = x;
    out[1] = y;
}

/* Algorithm 3.1: error-free transformation of the sum, no magnitude
 * precondition. */
void
dl_sum(double a, double b, double out[2])
{
    double x = a + b;
    double z = x - a;
    double y = (a - (x - z)) + (b - z);
    out[0] = x;
    out[1] = y;
}

/* fabs stand-in: clears the sign bit; -0.0 -> 0.0 like libm fabs. */
double
m_fabs(double x)
{
    if (x == 0.0) {
        return 0.0;
    }
    if (x < 0.0) {
        return -x;
    }
    return x;
}

/* math_fsum inner loop over the partials array: folds x into p[0..n),
 * keeping the partials non-overlapping and sorted by magnitude.
 * Returns the new count i (ps[i:] = [x]); stores the surviving x
 * through x_out[0] so callers can run the nonfinite/special-value
 * epilogue verbatim. */
Py_ssize_t
fsum_fold_partials(double *p, Py_ssize_t n, double x, double x_out[1])
{
    Py_ssize_t i, j;
    double y, t, hi, yr, lo = 0.0;
    for (i = j = 0; j < n; j++) {       /* for y in partials */
        y = p[j];
        if (m_fabs(x) < m_fabs(y)) {
            t = x; x = y; y = t;
        }
        hi = x + y;
        yr = hi - x;
        lo = y - yr;
        if (lo != 0.0) {
            p[i] = lo;
            i = i + 1;
        }
        x = hi;
    }
    x_out[0] = x;
    return i;                           /* ps[i:] = [x] */
}

/* math.isclose sanity check on the tolerances: returns 1 when the
 * inputs are invalid (ValueError raised in the C impl). */
int
isclose_tol_invalid(double rel_tol, double abs_tol)
{
    return rel_tol < 0.0 || abs_tol < 0.0;
}

/* math_isclose_impl tail: the "weak" Boost-style test. The equality and
 * infinity short-circuits live at the call site (a == b then
 * isinf(a) || isinf(b) -> 0). */
int
isclose_weak_test(double a, double b, double rel_tol, double abs_tol)
{
    double diff = m_fabs(b - a);
    return ((diff <= m_fabs(rel_tol * b)) ||
            (diff <= m_fabs(rel_tol * a))) ||
           (diff <= abs_tol);
}

/* perm_comb_small second fast path (iscomb): C(n, k) via
 * C(n, k) = C(n, k-1) * (n-k+1) / k. Precondition: no intermediate
 * exceeds uint64 (callers gate on fast_comb_limits2). Division is exact
 * on this path because every prefix C(n', i) is integral.
 * Statements decomposed from `result *= --n; result /= ++i;` -- see
 * the adaptation notes above. */
unsigned long long
comb_small_step(unsigned long long n, unsigned long long k)
{
    unsigned long long result = n;
    unsigned long long i = 1;
    while (i < k) {
        n = n - 1;
        result = result * n;
        i = i + 1;
        result = result / i;
    }
    return result;
}

/* perm_comb_small second fast path (!iscomb): P(n, k) via
 * P(n, k) = P(n, k-1) * (n-k+1). Same limits-table precondition.
 * Decomposed from `result *= --n; ++i;` like comb_small_step. */
unsigned long long
perm_small_step(unsigned long long n, unsigned long long k)
{
    unsigned long long result = n;
    unsigned long long i = 1;
    while (i < k) {
        n = n - 1;
        result = result * n;
        i = i + 1;
    }
    return result;
}
