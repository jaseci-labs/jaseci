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

def _p2_chain_from_iterable(iterable: any) -> _P2Chain {
    lz = _P2Chain();
    lz.source = _get_iter(iterable);
    lz.active = None;
    return lz;
}
