# Product-path facade for itertools (wave 12): count / cycle / repeat / chain.
# Staged ``jac-py/Modules/itertoolsmodule.{c,jac}`` remain the wave-12 c2jac
# corpus oracle pair (staging=lift); this module carries the runtime truth.
# Semantics mirror CPython 3.14 ``Modules/itertoolsmodule.c``.
#
# Iterator types are stateful obj archetypes driven through ``__next__``
# (T7 na-clean forbids yield); StopIteration signals exhaustion exactly like
# the C tp_iternext returning NULL.

# Iterator-protocol helpers. Free functions keep the dynamic dispatch on
# plain ``any`` (obj-field access narrows to NoneType under the checker).
def _advance(it: any) -> any {
    return it.__next__();
}

def _get_iter(x: any) -> any {
    return x.__iter__();
}

obj _P2Count {
    # Fast mode: cnt carries an int counter, long_cnt is None.
    # Slow mode: counting goes through object arithmetic (long_cnt += long_step),
    # matching CPython's count_nextlong switch at PY_SSIZE_T_MAX.
    has cnt: int = 0,
        long_cnt: any = None,
        long_step: any = None;

    def __next__ -> any {
        cur: any = long_cnt;
        if cur is None {
            current: int = cnt;
            cnt = cnt + 1;
            return current;
        }
        long_cnt = cur + long_step;
        return cur;
    }

    def __repr__ -> str {
        if long_cnt is None {
            return "count(" + str(cnt) + ")";
        }
        if isinstance(long_step, int) and long_step == 1 {
            return "count(" + str(long_cnt) + ")";
        }
        return "count(" + str(long_cnt) + ", " + str(long_step) + ")";
    }
}

obj _P2Cycle {
    # it drains on the first pass (items saved); afterwards the saved list is
    # cycled forever. Mirrors cycle_next including firstpass/setstate restore.
    has it: any = None,
        saved: list = [],
        index: int = 0,
        firstpass: bool = False;

    def __next__ -> any {
        src: any = it;
        while src is not None {
            try {
                item: any = _advance(src);
                if not firstpass {
                    saved.append(item);
                }
                return item;
            } except StopIteration {
                it = None;
                src = None;
            }
        }
        if len(saved) == 0 {
            raise StopIteration();
        }
        item = saved[index];
        index = index + 1;
        if index >= len(saved) {
            index = 0;
        }
        return item;
    }
}

obj _P2Repeat {
    # remaining < 0 means unbounded (CPython keeps cnt == -1); the constructor
    # maps an explicitly-passed negative times to 0 (exhausted), like repeat_new.
    has element: any = None,
        remaining: int = -1;

    def __next__ -> any {
        if remaining == 0 {
            raise StopIteration();
        }
        if remaining > 0 {
            remaining = remaining - 1;
        }
        return element;
    }

    def __repr__ -> str {
        if remaining < 0 {
            return "repeat(" + str(element) + ")";
        }
        return "repeat(" + str(element) + ", " + str(remaining) + ")";
    }

    def __length_hint__ -> int {
        if remaining < 0 {
            raise TypeError("len() of unsized object");
        }
        return remaining;
    }
}

obj _P2Chain {
    # source walks the input iterables; active is the currently-drained one.
    # Mirrors chain_next: pull a fresh active iterator whenever needed, skip
    # exhausted ones, end when the source itself is exhausted.
    has source: any = None,
        active: any = None;

    def __next__ -> any {
        src: any = source;
        act: any = active;
        while src is not None {
            if act is None {
                try {
                    iterable: any = _advance(src);
                    act = _get_iter(iterable);
                } except StopIteration {
                    source = None;
                    break;
                }
            }
            try {
                item: any = _advance(act);
                active = act;
                return item;
            } except StopIteration {
                act = None;
                active = None;
            }
        }
        raise StopIteration();
    }
}

def _is_number(x: any) -> bool {
    return isinstance(x, int) or isinstance(x, float) or isinstance(x, complex);
}

def _p2_count(start: any = None, step: any = None) -> _P2Count {
    if start is not None and not _is_number(start) {
        raise TypeError("a number is required");
    }
    if step is not None and not _is_number(step) {
        raise TypeError("a number is required");
    }
    fast = (start is None or isinstance(start, int))
        and (step is None or isinstance(step, int));
    if fast and step is not None and (not isinstance(step, int) or step != 1) {
        fast = False;
    }
    counter = _P2Count();
    if fast {
        counter.cnt = 0 if start is None else start;
        counter.long_cnt = None;
        return counter;
    }
    counter.cnt = 0;
    counter.long_cnt = 0 if start is None else start;
    counter.long_step = 1 if step is None else step;
    return counter;
}

def _p2_cycle(iterable: any) -> _P2Cycle {
    lz = _P2Cycle();
    lz.it = _get_iter(iterable);
    lz.saved = [];
    lz.index = 0;
    lz.firstpass = False;
    return lz;
}

# Pickle/state-restoration surface: resume cycling without a first pass over
# the source (mirrors cycle.__setstate__).
def _p2_cycle_setstate(lz: _P2Cycle, saved: list, index: int) {
    lz.it = None;
    lz.saved = saved;
    lz.index = index;
    lz.firstpass = True;
}

def _p2_repeat(element: any, times: any = None) -> _P2Repeat {
    ro = _P2Repeat();
    ro.element = element;
    if times is None {
        ro.remaining = -1;
        return ro;
    }
    if not isinstance(times, int) {
        raise TypeError("an integer is required");
    }
    ro.remaining = 0 if times < 0 else times;
    return ro;
}

def _p2_chain(*iterables: list) -> _P2Chain {
    lz = _P2Chain();
    lz.source = _get_iter(iterables);
    lz.active = None;
    return lz;
}

obj _P2Product {
    # pools is a list of tuples; indices mirrors lz->indices. CPython reuses
    # or copies the previous result tuple and updates it in-place; rebuilding
    # from indices after each odometer advance is value-equivalent.
    has pools: list = [],
        indices: list = [],
        started: bool = False,
        stopped: bool = False;

    def __next__ -> any {
        if stopped {
            raise StopIteration();
        }
        npools = len(pools);
        if not started {
            started = True;
            out: list = [];
            for i in range(npools) {
                if len(pools[i]) == 0 {
                    stopped = True;
                    raise StopIteration();
                }
                out.append(pools[i][0]);
            }
            return tuple(out);
        }
        # Advance the odometer right-to-left; carry on roll-over.
        i = npools - 1;
        while i >= 0 {
            indices[i] = indices[i] + 1;
            if indices[i] < len(pools[i]) {
                break;
            }
            indices[i] = 0;
            i = i - 1;
        }
        if i < 0 {
            stopped = True;
            raise StopIteration();
        }
        out = [];
        for k in range(npools) {
            out.append(pools[k][indices[k]]);
        }
        return tuple(out);
    }
}

obj _P2Combinations {
    # pool is the input tuple; indices[i] starts at i. Scan right-to-left for
    # an index below its maximum (i + n - r), increment it, reset the suffix.
    has pool: any = None,
        indices: list = [],
        r: int = 0,
        started: bool = False,
        stopped: bool = False;

    def __next__ -> any {
        if stopped {
            raise StopIteration();
        }
        n = len(pool);
        if not started {
            started = True;
            return _index_tuple(pool, indices, r);
        }
        i = r - 1;
        while i >= 0 and indices[i] == i + n - r {
            i = i - 1;
        }
        if i < 0 {
            stopped = True;
            raise StopIteration();
        }
        indices[i] = indices[i] + 1;
        for j in range(i + 1, r) {
            indices[j] = indices[j - 1] + 1;
        }
        return _index_tuple(pool, indices, r);
    }
}

obj _P2Cwr {
    # combinations_with_replacement: indices[i] starts at 0; scan right-to-left
    # for an index below n-1, then set the whole suffix to the incremented index.
    has pool: any = None,
        indices: list = [],
        r: int = 0,
        started: bool = False,
        stopped: bool = False;

    def __next__ -> any {
        if stopped {
            raise StopIteration();
        }
        n = len(pool);
        if not started {
            started = True;
            return _index_tuple(pool, indices, r);
        }
        i = r - 1;
        while i >= 0 and indices[i] == n - 1 {
            i = i - 1;
        }
        if i < 0 {
            stopped = True;
            raise StopIteration();
        }
        index = indices[i] + 1;
        for j in range(i, r) {
            indices[j] = index;
        }
        return _index_tuple(pool, indices, r);
    }
}

obj _P2Permutations {
    # Exact port of permutations_next: cycles decrement right-to-left with
    # rotation on zero (indices[i:] = indices[i+1:] + indices[i:i+1]); a
    # swap at cycles[i] > 0 fixes position i and yields.
    has pool: any = None,
        indices: list = [],
        cycles: list = [],
        r: int = 0,
        started: bool = False,
        stopped: bool = False;

    def __next__ -> any {
        if stopped {
            raise StopIteration();
        }
        n = len(pool);
        if not started {
            started = True;
            return _index_tuple(pool, indices, r);
        }
        if n == 0 {
            stopped = True;
            raise StopIteration();
        }
        i = r - 1;
        while i >= 0 {
            cycles[i] = cycles[i] - 1;
            if cycles[i] == 0 {
                index = indices[i];
                for j in range(i, n - 1) {
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
        if i < 0 {
            stopped = True;
            raise StopIteration();
        }
        return _index_tuple(pool, indices, r);
    }
}

def _index_tuple(pool: list, indices: list, r: int) -> any {
    out: list = [];
    for k in range(r) {
        out.append(pool[indices[k]]);
    }
    return tuple(out);
}

def _p2_product(iterables: list, repeat: int = 1) -> _P2Product {
    if repeat < 0 {
        raise ValueError("repeat argument cannot be negative");
    }
    lz = _P2Product();
    base: list = [];
    for it in iterables {
        base.append(tuple(it));
    }
    for rep in range(repeat) {
        for t in base {
            lz.pools.append(t);
        }
    }
    npools = len(lz.pools);
    lz.indices = [0] * npools;
    lz.started = False;
    lz.stopped = False;
    return lz;
}

def _p2_combinations(iterable: any, r: int) -> _P2Combinations {
    co = _P2Combinations();
    co.pool = tuple(iterable);
    if r < 0 {
        raise ValueError("r must be non-negative");
    }
    co.indices = list(range(r));
    co.r = r;
    co.started = False;
    co.stopped = r > len(co.pool);
    return co;
}

def _p2_cwr(iterable: any, r: int) -> _P2Cwr {
    co = _P2Cwr();
    co.pool = tuple(iterable);
    if r < 0 {
        raise ValueError("r must be non-negative");
    }
    co.indices = [0] * r;
    co.r = r;
    co.started = False;
    co.stopped = len(co.pool) == 0 and r > 0;
    return co;
}

def _p2_permutations(iterable: any, r: any = None) -> _P2Permutations {
    po = _P2Permutations();
    po.pool = tuple(iterable);
    n = len(po.pool);
    if r is None {
        r = n;
    } else {
        if not isinstance(r, int) {
            raise TypeError("an integer is required");
        }
        if r < 0 {
            raise ValueError("r must be non-negative");
        }
    }
    po.indices = list(range(n));
    cyc: list = [];
    for c in range(n, n - r, -1) {
        cyc.append(c);
    }
    po.cycles = cyc;
    po.r = r;
    po.started = False;
    po.stopped = r > n;
    return po;
}

def _p2_chain_from_iterable(iterable: any) -> _P2Chain {
    lz = _P2Chain();
    lz.source = _get_iter(iterable);
    lz.active = None;
    return lz;
}
