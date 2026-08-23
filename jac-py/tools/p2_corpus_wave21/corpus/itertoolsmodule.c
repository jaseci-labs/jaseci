/* Header-free extract: itertools core iterator control kernels.
 *
 * Source: CPython 3.14.6 Modules/itertoolsmodule.c (pinned reference).
 * Slices: count fast/slow mode advance, cycle saved-index wrap,
 * repeat bounded-countdown, chain active-source scan, islice skip/stop
 * ladder with step-advance clamp, zip_longest numactive countdown,
 * groupby head-run scan, batched short-batch decision, takewhile and
 * dropwhile sticky predicate flips.
 *
 * Wave 21 extends the wave-12 kernel set in place (the wave-12 corpus
 * itself grew the same way); the staged pair jac-py/Modules/
 * itertoolsmodule.{c,jac} tracks this file, not the frozen wave-12
 * ratchet snapshot under _lifted/p2_corpus_wave12.
 *
 * The PyObject protocol glue (GetIter/iter-next/StopIteration plumbing)
 * stays in the staged oracle (jac-py/Modules/itertoolsmodule.*) and the
 * product facade (jac-py/jacpython/itertoolsmodule.jac); these kernels
 * carry the integer control-state machines verbatim so they can be
 * differentially lifted and ratcheted by c2jac.
 */

typedef long Py_ssize_t; /* LP64, mirrors jacport.h */

/* PY_SSIZE_T_MAX on LP64. Written as a plain literal (not the usual
 * ((unsigned long)-1 >> 1) expression) so the c2jac W4201 cast-elision
 * idiom cannot change its value. */
#define PY_SSIZE_T_MAX ((Py_ssize_t)9223372036854775807L)

/* itertools.count fast-mode __next__ kernel.
 *
 * Mirrors count_next/count_nextlong mode selection: fast mode advances an
 * ssize_t counter; hitting PY_SSIZE_T_MAX signals the switch to slow_mode,
 * where counting continues via object arithmetic in the caller.
 * Returns 0 and stores the current value in *out on the fast path;
 * returns -1 when the caller must switch to slow_mode.
 */
int
itertools_count_next_fast(Py_ssize_t *cnt, Py_ssize_t *out)
{
    if (*cnt == PY_SSIZE_T_MAX) {
        return -1; /* switch to slow_mode: long_cnt = long_cnt + long_step */
    }
    *out = *cnt;
    *cnt = *cnt + 1;
    return 0;
}

/* itertools.cycle saved-sequence wrap kernel.
 *
 * Mirrors the tail of cycle_next: after reading saved[index], advance and
 * wrap around the saved list length. Callers guarantee saved_len >= 1.
 */
Py_ssize_t
itertools_cycle_advance(Py_ssize_t index, Py_ssize_t saved_len)
{
    Py_ssize_t next = index + 1;
    if (next >= saved_len) {
        next = 0;
    }
    return next;
}

/* itertools.repeat bounded-countdown kernel.
 *
 * Mirrors repeat_next: cnt == 0 exhausts the iterator, cnt > 0 decrements,
 * cnt < 0 repeats forever. Returns 1 when the element is produced, 0 on
 * exhaustion.
 */
int
itertools_repeat_take(Py_ssize_t *cnt)
{
    if (*cnt == 0) {
        return 0;
    }
    if (*cnt > 0) {
        *cnt = *cnt - 1;
    }
    return 1;
}

/* itertools.chain active-source scan kernel.
 *
 * Models the skip-over-exhausted loop of chain_next over an array of
 * per-source remaining counts: advance the active index past exhausted
 * sources, consume one item from the first live source, and report -1
 * once every source is exhausted (chain_next returns NULL there).
 * Returns the active source index, or -1 when exhausted.
 */
Py_ssize_t
itertools_chain_scan(Py_ssize_t *remaining, Py_ssize_t nsrc, Py_ssize_t *active)
{
    if (*active < 0) {
        *active = 0;
    }
    while (*active < nsrc) {
        if (remaining[*active] > 0) {
            remaining[*active] = remaining[*active] - 1;
            return *active;
        }
        *active = *active + 1;
    }
    return -1;
}

/* itertools.product odometer-advance kernel.
 *
 * Mirrors the index update loop of product_next: increment right-to-left,
 * carrying on roll-over. Returns 0 when a new combination exists (indices
 * updated) or -1 when all indices rolled over (product_next -> empty).
 */
int
itertools_product_advance(Py_ssize_t *indices, const Py_ssize_t *sizes,
                          Py_ssize_t npools)
{
    Py_ssize_t i = npools - 1;
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

/* itertools.combinations index-scan kernel.
 *
 * Mirrors combinations_next: scan right-to-left for an index below its
 * maximum (i + n - r), increment it, and reset every later index to one
 * more than its predecessor (sorted-order invariant). Returns the leftmost
 * changed position, or -1 when exhausted.
 */
Py_ssize_t
itertools_combinations_scan(Py_ssize_t *indices, Py_ssize_t n, Py_ssize_t r)
{
    Py_ssize_t i = r - 1;
    Py_ssize_t j;
    while (i >= 0 && indices[i] == i + n - r) {
        i = i - 1;
    }
    if (i < 0) {
        return -1;
    }
    indices[i] = indices[i] + 1;
    for (j = i + 1; j < r; j++) {
        indices[j] = indices[j - 1] + 1;
    }
    return i;
}

/* itertools.combinations_with_replacement index-scan kernel.
 *
 * Mirrors cwr_next: scan right-to-left for an index below n-1, then set
 * the whole suffix from that position to the incremented value.
 * Returns the leftmost changed position, or -1 when exhausted.
 */
Py_ssize_t
itertools_cwr_scan(Py_ssize_t *indices, Py_ssize_t n, Py_ssize_t r)
{
    Py_ssize_t i = r - 1;
    Py_ssize_t j;
    Py_ssize_t index;
    while (i >= 0 && indices[i] == n - 1) {
        i = i - 1;
    }
    if (i < 0) {
        return -1;
    }
    index = indices[i] + 1;
    for (j = i; j < r; j++) {
        indices[j] = index;
    }
    return i;
}

/* itertools.permutations cycle-step kernel.
 *
 * Mirrors the permutations_next advance loop (see also the canonical
 * Python transliteration in the C source comment): decrement cycles
 * right-to-left; on zero rotate indices[i:] left by one and reset
 * cycles[i] = n - i; otherwise swap indices[i] with indices[n-cycles[i]]
 * and stop. Returns the leftmost changed position after a swap (caller
 * yields), or -1 when every cycle rolled over (exhausted).
 */
Py_ssize_t
itertools_permutations_step(Py_ssize_t *indices, Py_ssize_t *cycles,
                            Py_ssize_t n, Py_ssize_t r)
{
    Py_ssize_t i = r - 1;
    Py_ssize_t j;
    Py_ssize_t index;
    while (i >= 0) {
        cycles[i] = cycles[i] - 1;
        if (cycles[i] == 0) {
            /* rotation: indices[i:] = indices[i+1:] + indices[i:i+1] */
            index = indices[i];
            for (j = i; j < n - 1; j++) {
                indices[j] = indices[j + 1];
            }
            indices[n - 1] = index;
            cycles[i] = n - i;
            i = i - 1;
        } else {
            j = cycles[i];
            index = indices[i];
            indices[i] = indices[n - j];
            indices[n - j] = index;
            break;
        }
    }
    if (i < 0) {
        return -1;
    }
    return i;
}

/* itertools.islice skip/take ladder kernel (wave 21).
 *
 * Mirrors islice_next over an abstract source represented by `remaining`
 * (items the source can still produce): burn skipped items while
 * cnt < next, refuse at stop, take one item, then advance next by step
 * with the same overflow clamp islice_next applies via its (size_t)
 * cast trick. Returns 1 when an item is taken, 0 when the stop bound
 * rejects, -1 when the source runs dry (islice_next -> NULL).
 */
int
itertools_islice_take(Py_ssize_t *cnt, Py_ssize_t *next, Py_ssize_t stop,
                      Py_ssize_t step, Py_ssize_t *remaining)
{
    while (*cnt < *next) {
        if (*remaining <= 0) {
            return -1;
        }
        *remaining = *remaining - 1;
        *cnt = *cnt + 1;
    }
    if (stop != -1 && *cnt >= stop) {
        return 0;
    }
    if (*remaining <= 0) {
        return -1;
    }
    *remaining = *remaining - 1;
    *cnt = *cnt + 1;
    {
        Py_ssize_t oldnext = *next;
        /* The plain add mirrors lz->next += (size_t)lz->step: wraparound
         * detection compares against oldnext, and a wrapped or
         * stop-exceeding next collapses to stop. */
        *next = *next + step;
        if (*next < oldnext || (stop != -1 && *next > stop)) {
            *next = stop;
        }
    }
    return 1;
}

/* itertools.zip_longest active-source countdown kernel (wave 21).
 *
 * Mirrors the numactive bookkeeping of zip_longest_next over per-source
 * remaining counts: each round draws from every slot; a dry slot drops
 * out (ittuple[i] = NULL) and decrements numactive; when the last active
 * source dries mid-round the whole round is abandoned (zip_longest_next
 * returns NULL without emitting a partial tuple). Returns 1 when the
 * round completed (a tuple is emitted), 0 when exhausted.
 */
int
itertools_ziplongest_round(Py_ssize_t *remaining, Py_ssize_t nsrc,
                           Py_ssize_t *numactive)
{
    Py_ssize_t i;
    for (i = 0; i < nsrc; i++) {
        if (remaining[i] > 0) {
            remaining[i] = remaining[i] - 1;
        } else {
            *numactive = *numactive - 1;
            if (*numactive == 0) {
                return 0;
            }
        }
    }
    return 1;
}

/* itertools.groupby head-run scan kernel (wave 21).
 *
 * Mirrors the groupby_next/_grouper_next interplay over a key stream:
 * groupby_next fixes tgtkey to the current key and _grouper_next keeps
 * consuming while currkey == tgtkey, so together they peel one run of
 * equal keys per outer next(). Scans the leading run of keys[0..n)
 * equal to *run_key, consumes it, and reports its length (-1 when the
 * stream is empty, i.e. StopIteration).
 */
Py_ssize_t
itertools_groupby_run(Py_ssize_t *keys, Py_ssize_t n, Py_ssize_t *run_key)
{
    Py_ssize_t taken;
    if (n <= 0) {
        return -1;
    }
    *run_key = keys[0];
    taken = 1;
    while (taken < n && keys[taken] == *run_key) {
        taken = taken + 1;
    }
    {
        Py_ssize_t i;
        for (i = taken; i < n; i++) {
            keys[i - taken] = keys[i];
        }
    }
    return taken;
}

/* itertools.batched short-batch decision kernel (wave 21).
 *
 * Mirrors batched_next's fill loop and null_item tail: draw up to n
 * items; a full batch returns n. A short batch resizes to what was
 * drawn unless strict mode turns the incomplete tail into a ValueError
 * (reported here as -2). An empty tail ends iteration (-1). *taken_out
 * carries the drawn count for the resize.
 */
int
itertools_batched_take(Py_ssize_t *remaining, Py_ssize_t n, int strict,
                       Py_ssize_t *taken_out)
{
    Py_ssize_t taken = 0;
    while (taken < n && *remaining > 0) {
        *remaining = *remaining - 1;
        taken = taken + 1;
    }
    *taken_out = taken;
    if (taken == 0) {
        return -1;
    }
    if (taken < n && strict) {
        return -2;
    }
    return 0;
}

/* itertools.dropwhile sticky-flip kernel (wave 21).
 *
 * Mirrors dropwhile_next: items are discarded while the predicate holds;
 * the first failure flips *dropping off permanently, after which every
 * item passes through untested. Returns 1 to emit the current item,
 * -1 when the source ran dry first (dropwhile_next -> NULL). */
int
itertools_dropwhile_flip(int pred, Py_ssize_t *remaining, int *dropping)
{
    if (*remaining <= 0) {
        return -1;
    }
    if (*dropping) {
        if (pred) {
            *remaining = *remaining - 1;
            return 0; /* discarded; caller advances and retries */
        }
        *dropping = 0;
    }
    *remaining = *remaining - 1;
    return 1;
}

/* itertools.takewhile sticky-flip kernel (wave 21).
 *
 * Mirrors takewhile_next: emit while the predicate holds; the first
 * failure latches *taking off and exhausts the iterator even though the
 * source still has items. Returns 1 to emit, 0 once latched off, -1 on
 * a dry source. */
int
itertools_takewhile_flip(int pred, Py_ssize_t *remaining, int *taking)
{
    if (!*taking) {
        return 0;
    }
    if (*remaining <= 0) {
        return -1;
    }
    if (pred) {
        *remaining = *remaining - 1;
        return 1;
    }
    *taking = 0;
    return 0;
}
