# Product-path facade for _collections (wave 19): deque + defaultdict.
#
# Staged ``jac-py/Modules/collectionsmodule.{c,jac}`` remain the wave-19
# c2jac corpus oracle pair (staging=lift); this module carries the runtime
# truth. Semantics mirror CPython 3.14 ``Modules/_collectionsmodule.c`` on
# the pinned host, verified against the host stdlib ``_collections`` at
# authoring time.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original stores
# elements in a doubly-linked list of 64-slot blocks with left/right cursor
# indices plus a freeblock cache. This facade uses a flat insertion-ordered
# list with logical-left at index 0 and a ``state`` mutation counter. Every
# observable semantic (maxlen trimming on both ends, byte-exact error
# strings, iterator invalidation, comparison/repr/reduce shapes) is
# preserved; only memory layout and operation complexity differ, which are
# unobservable through the Python-level surface except via ``__sizeof__``
# (documented divergence: returns a fixed shape, not block accounting).
#
# Iterator invalidation IS modeled: every structural mutation bumps
# ``state``; iterators snapshot it at creation and raise
# ``RuntimeError("deque mutated during iteration")`` on the next and every
# subsequent ``__next__``, matching dequeiter_next_lock_held.


def _p2_deque_type_name(v: any) -> str {
    return type(v).__name__;
}


def _p2_deque_index_arg(v: any) -> int {
    # Mirrors the clinic integer converter for maxlen/index args:
    # "an integer is required" rather than the __index__-protocol message.
    if not isinstance(v, int) or isinstance(v, bool) {
        raise TypeError("an integer is required");
    }
    return v;
}


obj _P2DequeIter {
    has deq: any = None,
        pos: int = 0,
        snap_state: int = 0,
        counter: int = 0,
        rev: bool = False;


    def __iter__ -> any {
        return self;
    }

    def __next__ -> any {
        if self.snap_state != self.deq.state {
            self.counter = 0;
            raise RuntimeError("deque mutated during iteration");
        }
        if self.counter == 0 {
            raise StopIteration();
        }
        self.counter = self.counter - 1;
        item: any;
        if self.rev {
            item = self.deq.items[len(self.deq.items) - 1 - self.pos];
        } else {
            item = self.deq.items[self.pos];
        }
        self.pos = self.pos + 1;
        return item;
    }

    def __length_hint__ -> int {
        return self.counter;
    }

    def __reduce__ -> any {
        # Mirrors dequeiter_reduce: (type, (deque, consumed)).
        return (type(self), (self.deq, len(self.deq.items) - self.counter));
    }
}


obj _P2Deque {
    has items: list = [],
        maxlen: any = None,
        state: int = 0;


    def _trim_right -> any {
        # NEEDS_TRIM after a right append pops from the left (and vice versa).
        # Returns the popped item so callers mirror the C refcount flow.
        if self.maxlen is not None and len(self.items) > self.maxlen {
            old = self.items[0];
            del self.items[0];
            self.state = self.state + 1;
            return old;
        }
        return None;
    }

    def _trim_left -> any {
        if self.maxlen is not None and len(self.items) > self.maxlen {
            old = self.items[len(self.items) - 1];
            del self.items[len(self.items) - 1];
            self.state = self.state + 1;
            return old;
        }
        return None;
    }

    def append(item: any) {
        self.items.append(item);
        self._trim_right();
        self.state = self.state + 1;
    }

    def appendleft(item: any) {
        self.items.insert(0, item);
        self._trim_left();
        self.state = self.state + 1;
    }

    def pop -> any {
        if len(self.items) == 0 {
            raise IndexError("pop from an empty deque");
        }
        item = self.items[len(self.items) - 1];
        del self.items[len(self.items) - 1];
        self.state = self.state + 1;
        return item;
    }

    def popleft -> any {
        if len(self.items) == 0 {
            raise IndexError("pop from an empty deque");
        }
        item = self.items[0];
        del self.items[0];
        self.state = self.state + 1;
        return item;
    }

    def __len__ -> int {
        return len(self.items);
    }

    def __iter__ -> any {
        it = _P2DequeIter();
        it.deq = self;
        it.pos = 0;
        it.snap_state = self.state;
        it.counter = len(self.items);
        it.rev = False;
        return it;
    }

    def __reversed__ -> any {
        it = _P2DequeIter();
        it.deq = self;
        it.pos = 0;
        it.snap_state = self.state;
        it.counter = len(self.items);
        it.rev = True;
        return it;
    }

    def __repr__ -> str {
        parts: list = [];
        for item in self.items {
            parts.append(repr(item));
        }
        inner = "[" + ", ".join(parts) + "]";
        if self.maxlen is not None {
            return "deque(" + inner + ", maxlen=" + str(self.maxlen) + ")";
        }
        return "deque(" + inner + ")";
    }
}


def _p2_deque(iterable: any = None, maxlen: any = None) -> _P2Deque {
    d = _P2Deque();
    if maxlen is not None {
        m = _p2_deque_index_arg(maxlen);
        if m < 0 {
            raise ValueError("maxlen must be non-negative");
        }
        d.maxlen = m;
    }
    if iterable is not None {
        try {
            src_iter = iter(iterable);
        } except Exception {
            raise TypeError("'" + _p2_deque_type_name(iterable)
                            + "' object is not iterable");
        }
        while True {
            try {
                item = next(src_iter);
            } except StopIteration {
                break;
            }
            d.append(item);
        }
    }
    return d;
}
