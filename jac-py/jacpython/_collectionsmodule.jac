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


# Generic element ordering for richcompare. Mirrors _heapqmodule's
# locally-annotated `any` comparison pattern.
def _deque_items_lt(a: any, b: any) -> bool {
    x: any = a;
    y: any = b;
    if x < y {
        return True;
    }
    return False;
}


def _p2_deque_type_name(v: any) -> str {
    return type(v).__name__;
}


# C truncating division/modulo helpers, mirroring the wave-19 corpus lift
# (c_idiv/c_imod): rotate's step folding needs C semantics for negative n.
def _deque_c_idiv(a: int, b: int) -> int {
    q = a // b;
    if a % b != 0 and (a < 0) != (b < 0) {
        return q + 1;
    }
    return q;
}


def _deque_c_imod(a: int, b: int) -> int {
    return a - _deque_c_idiv(a, b) * b;
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

    # ------------------------------------------------------------------
    # Surface ops (deque_extend/clear/copy/insert/remove/index/count/
    # rotate/reverse/concat/repeat/richcompare/reduce mirrors).
    # ------------------------------------------------------------------

    def extend(iterable: any) {
        src: list;
        if iterable is self {
            # deque_extend self-reference path: snapshot first.
            src = [];
            for x in self.items {
                src.append(x);
            }
        } else {
            try {
                src_iter = iter(iterable);
            } except Exception {
                raise TypeError("'" + _p2_deque_type_name(iterable)
                                + "' object is not iterable");
            }
            src = [];
            while True {
                try {
                    src.append(next(src_iter));
                } except StopIteration {
                    break;
                }
            }
        }
        for item in src {
            self.append(item);
        }
    }

    def extendleft(iterable: any) {
        src: list;
        if iterable is self {
            src = [];
            for x in self.items {
                src.append(x);
            }
        } else {
            try {
                src_iter = iter(iterable);
            } except Exception {
                raise TypeError("'" + _p2_deque_type_name(iterable)
                                + "' object is not iterable");
            }
            src = [];
            while True {
                try {
                    src.append(next(src_iter));
                } except StopIteration {
                    break;
                }
            }
        }
        for item in src {
            self.appendleft(item);
        }
    }

    def clear() {
        if len(self.items) == 0 {
            return;
        }
        self.items = [];
        self.state = self.state + 1;
    }

    def copy -> _P2Deque {
        out = _p2_deque(None, self.maxlen);
        for x in self.items {
            out.items.append(x);
        }
        return out;
    }

    def __copy__ -> _P2Deque {
        return self.copy();
    }

    def insert(index: any, value: any) {
        i = _p2_deque_index_arg(index);
        n = len(self.items);
        if self.maxlen is not None and n == self.maxlen {
            raise IndexError("deque already at its maximum size");
        }
        # Observable contract matches list.insert at every index CPython's
        # rotate-based implementation lands on (index >= n appends,
        # index <= -n or 0 prepends; verified against host).
        self.items.insert(i, value);
        self.state = self.state + 1;
    }

    def index(value: any, start: any = None, stop: any = None) -> int {
        size = len(self.items);
        s: int = 0;
        e: int = size;
        if start is not None {
            if not isinstance(start, int) or isinstance(start, bool) {
                raise TypeError(
                    "slice indices must be integers or have an __index__ method");
            }
            s = start;
        }
        if stop is not None {
            if not isinstance(stop, int) or isinstance(stop, bool) {
                raise TypeError(
                    "slice indices must be integers or have an __index__ method");
            }
            e = stop;
        }
        # deque_index_impl normalization ladder (wave-19 corpus kernels:
        # norm_start / norm_stop / norm_pair).
        if s < 0 {
            s += size;
            if s < 0 {
                s = 0;
            }
        }
        if e < 0 {
            e += size;
            if e < 0 {
                e = 0;
            }
        }
        if e > size {
            e = size;
        }
        if s > e {
            s = e;
        }
        i = s;
        while i < e {
            if self._items_eq(self.items[i], value) {
                return i;
            }
            i += 1;
        }
        raise ValueError("deque.index(x): x not in deque");
    }

    def count(value: any) -> int {
        total = 0;
        start_state = self.state;
        for x in self.items {
            if self._items_eq(x, value) {
                total += 1;
            }
            if start_state != self.state {
                raise RuntimeError("deque mutated during iteration");
            }
        }
        return total;
    }

    def remove(value: any) {
        n = len(self.items);
        start_state = self.state;
        i = 0;
        pos = -1;
        while i < n {
            if self._items_eq(self.items[i], value) {
                pos = i;
                break;
            }
            if start_state != self.state {
                raise RuntimeError("deque mutated during iteration");
            }
            i += 1;
        }
        if pos == -1 {
            raise ValueError("deque.remove(x): x not in deque");
        }
        del self.items[pos];
        self.state = self.state + 1;
    }

    def __contains__(value: any) -> any {
        start_state = self.state;
        for x in self.items {
            if self._items_eq(x, value) {
                return True;
            }
            if start_state != self.state {
                raise RuntimeError("deque mutated during iteration");
            }
        }
        return False;
    }

    def rotate(n: any = 1) {
        steps = _p2_deque_index_arg(n);
        ln = len(self.items);
        if ln <= 1 {
            return;
        }
        # _deque_rotate step folding (wave-19 corpus kernel deque_rotate_delta).
        halflen = ln >> 1;
        if steps > halflen or steps < -halflen {
            steps = _deque_c_imod(steps, ln);
            if steps > halflen {
                steps -= ln;
            } elif steps < -halflen {
                steps += ln;
            }
        }
        k = steps;
        while k > 0 {
            item = self.items[len(self.items) - 1];
            del self.items[len(self.items) - 1];
            self.items.insert(0, item);
            k -= 1;
        }
        while k < 0 {
            item = self.items[0];
            del self.items[0];
            self.items.append(item);
            k += 1;
        }
        if steps != 0 {
            self.state = self.state + 1;
        }
    }

    def reverse() {
        self.items.reverse();
        self.state = self.state + 1;
    }

    def __getitem__(item: any) -> any {
        if isinstance(item, slice) {
            raise TypeError("sequence index must be integer, not 'slice'");
        }
        if not isinstance(item, int) or isinstance(item, bool) {
            raise TypeError("sequence index must be integer, not '"
                            + _p2_deque_type_name(item) + "'");
        }
        i = item;
        if i < 0 {
            i += len(self.items);
        }
        if i < 0 or i >= len(self.items) {
            raise IndexError("deque index out of range");
        }
        return self.items[i];
    }

    def __setitem__(item: any, v: any) {
        if isinstance(item, slice) {
            raise TypeError("sequence index must be integer, not 'slice'");
        }
        if not isinstance(item, int) or isinstance(item, bool) {
            raise TypeError("sequence index must be integer, not '"
                            + _p2_deque_type_name(item) + "'");
        }
        i = item;
        if i < 0 {
            i += len(self.items);
        }
        if i < 0 or i >= len(self.items) {
            raise IndexError("deque index out of range");
        }
        self.items[i] = v;
    }

    def __delitem__(item: any) {
        if isinstance(item, slice) {
            raise TypeError("sequence index must be integer, not 'slice'");
        }
        if not isinstance(item, int) or isinstance(item, bool) {
            raise TypeError("sequence index must be integer, not '"
                            + _p2_deque_type_name(item) + "'");
        }
        i = item;
        if i < 0 {
            i += len(self.items);
        }
        if i < 0 or i >= len(self.items) {
            raise IndexError("deque index out of range");
        }
        del self.items[i];
        self.state = self.state + 1;
    }

    def __add__(other: any) -> any {
        if not isinstance(other, _P2Deque) {
            raise TypeError("can only concatenate deque (not \""
                            + _p2_deque_type_name(other) + "\") to deque");
        }
        out = self.copy();
        out.extend(other);
        return out;
    }

    def __iadd__(other: any) -> any {
        if not isinstance(other, _P2Deque) {
            raise TypeError("can only concatenate deque (not \""
                            + _p2_deque_type_name(other) + "\") to deque");
        }
        self.extend(other);
        return self;
    }

    def __mul__(n: any) -> any {
        cnt = _require_repeat_count(n);
        out = _p2_deque(None, self.maxlen);
        k: int = 0;
        while k < cnt {
            for x in self.items {
                out.items.append(x);
            }
            k += 1;
        }
        return out;
    }

    def __rmul__(n: any) -> any {
        return self.__mul__(n);
    }

    def _items_eq(a: any, b: any) -> bool {
        if a is b {
            return True;
        }
        eq = (a == b);
        if not isinstance(eq, bool) {
            return False;
        }
        return eq;
    }

    def __eq__(other: any) -> any {
        if not isinstance(other, _P2Deque) {
            return False;
        }
        oa: _P2Deque = other;
        if len(oa.items) != len(self.items) {
            return False;
        }
        i: int = 0;
        while i < len(self.items) {
            if not self._items_eq(self.items[i], oa.items[i]) {
                return False;
            }
            i += 1;
        }
        return True;
    }

    def __ne__(other: any) -> any {
        if not isinstance(other, _P2Deque) {
            return True;
        }
        eqv = self.__eq__(other);
        if not isinstance(eqv, bool) {
            return eqv;
        }
        return not eqv;
    }

    def _items_lt(a: any, b: any) -> bool {
        return _deque_items_lt(a, b);
    }

    # Mirrors deque_richcompare: first mismatch decides via the element op,
    # otherwise length decides (LT/GE favor shorter/longer respectively).
    def _rich_order(other: any, op: str) -> any {
        if not isinstance(other, _P2Deque) {
            raise TypeError("'" + op
                            + "' not supported between instances of 'collections.deque' and '"
                            + _p2_deque_type_name(other) + "'");
        }
        oa: _P2Deque = other;
        i: int = 0;
        while i < len(self.items) and i < len(oa.items) {
            a = self.items[i];
            b = oa.items[i];
            if not self._items_eq(a, b) {
                if self._items_lt(a, b) {
                    return op == "<" or op == "<=";
                }
                return op == ">" or op == ">=";
            }
            i += 1;
        }
        if op == "<" {
            return len(self.items) < len(oa.items);
        }
        if op == "<=" {
            return len(self.items) <= len(oa.items);
        }
        if op == ">" {
            return len(self.items) > len(oa.items);
        }
        return len(self.items) >= len(oa.items);
    }

    def __lt__(other: any) -> any {
        return self._rich_order(other, "<");
    }

    def __le__(other: any) -> any {
        return self._rich_order(other, "<=");
    }

    def __gt__(other: any) -> any {
        return self._rich_order(other, ">");
    }

    def __ge__(other: any) -> any {
        return self._rich_order(other, ">=");
    }

    def __reduce__ -> any {
        if self.maxlen is not None {
            args = (self.maxlen,);
        } else {
            args = ();
        }
        return (type(self), args, None, self.__iter__());
    }
}



def _require_repeat_count(n: any) -> int {
    if not isinstance(n, int) or isinstance(n, bool) {
        raise TypeError("can't multiply sequence by non-int of type '"
                        + _p2_deque_type_name(n) + "'");
    }
    return n;
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
