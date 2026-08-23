# Product-path facade for the pure-Python layer of ``collections``
# (CPython 3.14 ``Lib/collections/__init__.py``): Counter, OrderedDict,
# namedtuple. deque/defaultdict live in ``_collectionsmodule.jac`` (wave-19).
#
# Representation follows the wave-19 ledger entry: insertion-ordered parallel
# key/value lists instead of hash tables. Every observable semantic -- missing
# protocols, tie ordering, byte-exact error texts, repr shapes -- mirrors the
# pinned host stdlib; only lookup complexity differs.

import keyword as _keyword;

import from _collectionsmodule { _p2_defaultdict_is_map, }


obj _P2Missing {
    # pop()/setdefault() sentinel distinguishing "no default given" from an
    # explicit None default (a scalar glob cannot serve: rebinds are local).
}

glob _P2_MISSING: any = _P2Missing();


# ---------------------------------------------------------------------------
# Counter (_count_elements / most_common / elements / total / update /
# subtract / add-sub-and-or-neg-pos mirrors).
# ---------------------------------------------------------------------------

def _p2_counter_stable_by_count(items: list) -> list {
    # Stable sort by descending count: decorate with (-count, index), plain
    # sort on the unique-index prefix, undecorate. Matches sorted(key=count,
    # reverse=True) tie behavior without relying on reverse-mode stability.
    decorated: list = [];
    i: int = 0;
    while i < len(items) {
        pair = items[i];
        decorated.append((-pair[1], i, pair));
        i += 1;
    }
    out: list = [];
    for triple in sorted(decorated) {
        out.append(triple[2]);
    }
    return out;
}


def _p2_counter_type_name(v: any) -> str {
    return type(v).__name__;
}


obj _P2Counter {
    has keylist: list = [],
        vallist: list = [];


    def _pos_of(key: any) -> int {
        i: int = 0;
        while i < len(self.keylist) {
            if self._items_eq(self.keylist[i], key) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    def _items_eq(a: any, b: any) -> bool {
        x: any = a;
        y: any = b;
        if x is y {
            return True;
        }
        ev = (x == y);
        return isinstance(ev, bool) and ev;
    }

    def __missing__(key: any) -> any {
        # _count_missing: a missing element reads as 0 and is NOT inserted.
        return 0;
    }

    def __getitem__(key: any) -> any {
        pos = self._pos_of(key);
        if pos == -1 {
            return self.__missing__(key);
        }
        return self.vallist[pos];
    }

    def __setitem__(key: any, v: any) {
        pos = self._pos_of(key);
        if pos == -1 {
            self.keylist.append(key);
            self.vallist.append(v);
        } else {
            self.vallist[pos] = v;
        }
    }

    def __delitem__(key: any) {
        pos = self._pos_of(key);
        if pos == -1 {
            raise KeyError(key);
        }
        del self.keylist[pos];
        del self.vallist[pos];
    }

    def __contains__(key: any) -> bool {
        return self._pos_of(key) != -1;
    }

    def __len__ -> int {
        return len(self.keylist);
    }

    def __iter__ -> any {
        return iter(list(self.keylist));
    }

    def get(key: any, dflt: any = None) -> any {
        pos = self._pos_of(key);
        if pos == -1 {
            return dflt;
        }
        return self.vallist[pos];
    }

    def clear() {
        self.keylist = [];
        self.vallist = [];
    }

    def copy -> _P2Counter {
        return _p2_counter_from_pairs(self.items());
    }

    def keys -> list {
        return list(self.keylist);
    }

    def values -> list {
        return list(self.vallist);
    }

    def items -> list {
        out: list = [];
        i: int = 0;
        while i < len(self.keylist) {
            out.append((self.keylist[i], self.vallist[i]));
            i += 1;
        }
        return out;
    }

    def elements -> any {
        # chain.from_iterable(repeat(elem, count) ...): first-encountered
        # order, counts <= 0 skipped entirely.
        out: list = [];
        i: int = 0;
        while i < len(self.keylist) {
            n = self.vallist[i];
            if n > 0 {
                reps = 0;
                while reps < n {
                    out.append(self.keylist[i]);
                    reps += 1;
                }
            }
            i += 1;
        }
        return iter(out);
    }

    def most_common(n: any = None) -> list {
        ranked = _p2_counter_stable_by_count(self.items());
        if n is None {
            return ranked;
        }
        if not isinstance(n, int) {
            raise TypeError(
                "'>=' not supported between instances of '"
                + _p2_counter_type_name(n) + "' and 'int'");
        }
        if n < 0 {
            return [];
        }
        return ranked[:n];
    }

    def total -> any {
        total: any = 0;
        for v in self.vallist {
            total += v;
        }
        return total;
    }

    def update(iterable: any = None, **kwds: dict) {
        # Counter.update: mappings add counts pairwise; other iterables count
        # elements one by one; keywords last.
        if iterable is not None {
            if _p2_defaultdict_is_map(iterable) {
                for kv in iterable.items() {
                    k = kv[0];
                    self.__setitem__(k, kv[1] + self.get(k, 0));
                }
            } else {
                for elem in iterable {
                    self.__setitem__(elem, self.get(elem, 0) + 1);
                }
            }
        }
        for k in kwds.keys() {
            v = kwds[k];
            self.__setitem__(k, v + self.get(k, 0));
        }
    }

    def subtract(iterable: any = None, **kwds: dict) {
        if iterable is not None {
            if _p2_defaultdict_is_map(iterable) {
                for kv in iterable.items() {
                    k = kv[0];
                    self.__setitem__(k, self.get(k, 0) - kv[1]);
                }
            } else {
                for elem in iterable {
                    self.__setitem__(elem, self.get(elem, 0) - 1);
                }
            }
        }
        for k in kwds.keys() {
            v = kwds[k];
            self.__setitem__(k, self.get(k, 0) - v);
        }
    }

    def __repr__ -> str {
        # CPython 3.14 builds the display from most_common() order.
        if len(self.keylist) == 0 {
            return "Counter()";
        }
        parts: list = [];
        for kv in _p2_counter_stable_by_count(self.items()) {
            parts.append(repr(kv[0]) + ": " + repr(kv[1]));
        }
        return "Counter({" + ", ".join(parts) + "})";
    }

    def __eq__(other: any) -> any {
        # Dict-style equality: order-insensitive against any mapping.
        if not _p2_defaultdict_is_map(other) {
            return False;
        }
        other_items = other.items();
        if len(other_items) != len(self.keylist) {
            return False;
        }
        for kv in other_items {
            pos = self._pos_of(kv[0]);
            if pos == -1 or not self._items_eq(self.vallist[pos], kv[1]) {
                return False;
            }
        }
        return True;
    }

    def __ne__(other: any) -> any {
        eqv = self.__eq__(other);
        if isinstance(eqv, bool) {
            return not eqv;
        }
        return eqv;
    }

    def __add__(other: any) -> any {
        pairs = self._combined_counts(other, "+");
        kept: list = [];
        for kv in pairs {
            if kv[1] > 0 {
                kept.append(kv);
            }
        }
        return _p2_counter_from_pairs(_p2_counter_stable_by_count(kept));
    }

    def __sub__(other: any) -> any {
        pairs = self._combined_counts(other, "-");
        kept: list = [];
        for kv in pairs {
            if kv[1] > 0 {
                kept.append(kv);
            }
        }
        return _p2_counter_from_pairs(_p2_counter_stable_by_count(kept));
    }

    def __and__(other: any) -> any {
        self._require_counter(other, "&");
        kept: list = [];
        i: int = 0;
        while i < len(self.keylist) {
            oc = other.get(self.keylist[i], 0);
            m = self.vallist[i];
            if oc < m {
                m = oc;
            }
            if m > 0 {
                kept.append((self.keylist[i], m));
            }
            i += 1;
        }
        return _p2_counter_from_pairs(_p2_counter_stable_by_count(kept));
    }

    def __or__(other: any) -> any {
        self._require_counter(other, "|");
        pairs: list = [];
        i: int = 0;
        while i < len(self.keylist) {
            oc = other.get(self.keylist[i], 0);
            m = self.vallist[i];
            if oc > m {
                m = oc;
            }
            if m > 0 {
                pairs.append((self.keylist[i], m));
            }
            i += 1;
        }
        for kv in other.items() {
            if self._pos_of(kv[0]) == -1 and kv[1] > 0 {
                pairs.append((kv[0], kv[1]));
            }
        }
        return _p2_counter_from_pairs(_p2_counter_stable_by_count(pairs));
    }

    def __pos__ -> any {
        kept: list = [];
        i: int = 0;
        while i < len(self.keylist) {
            if self.vallist[i] > 0 {
                kept.append((self.keylist[i], self.vallist[i]));
            }
            i += 1;
        }
        return _p2_counter_from_pairs(_p2_counter_stable_by_count(kept));
    }

    def __neg__ -> any {
        kept: list = [];
        i: int = 0;
        while i < len(self.keylist) {
            if self.vallist[i] < 0 {
                kept.append((self.keylist[i], -self.vallist[i]));
            }
            i += 1;
        }
        return _p2_counter_from_pairs(_p2_counter_stable_by_count(kept));
    }

    def _combined_counts(other: any, op: str) -> list {
        self._require_counter(other, op);
        # (key, self_count-or-0) over first-encounter order, then one pass
        # applying other's counts.
        pairs: list = [];
        i: int = 0;
        while i < len(self.keylist) {
            pairs.append((self.keylist[i], self.vallist[i]));
            i += 1;
        }
        for kv in other.items() {
            if self._pos_of(kv[0]) == -1 {
                pairs.append((kv[0], 0));
            }
        }
        combined: list = [];
        for kv in pairs {
            if op == "+" {
                combined.append((kv[0], kv[1] + other.get(kv[0], 0)));
            } else {
                combined.append((kv[0], kv[1] - other.get(kv[0], 0)));
            }
        }
        return combined;
    }

    def _require_counter(other: any, op: str) {
        if not isinstance(other, _P2Counter) {
            raise TypeError(
                "unsupported operand type(s) for " + op + ": 'Counter' and '"
                + _p2_counter_type_name(other) + "'");
        }
    }
}


def _p2_counter_from_pairs(pairs: list) -> _P2Counter {
    c = _P2Counter();
    for kv in pairs {
        c.keylist.append(kv[0]);
        c.vallist.append(kv[1]);
    }
    return c;
}


def _p2_counter(initial: any = None, **kwds: dict) -> _P2Counter {
    c = _P2Counter();
    if initial is not None {
        c.update(initial);
    }
    c.update(**kwds);
    return c;
}


# ---------------------------------------------------------------------------
# OrderedDict (move_to_end/popitem/order-sensitive eq/repr mirrors).
# ---------------------------------------------------------------------------

obj _P2OrderedDict {
    has keylist: list = [],
        vallist: list = [];


    def _pos_of(key: any) -> int {
        i: int = 0;
        while i < len(self.keylist) {
            if self._od_items_eq(self.keylist[i], key) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    def _od_items_eq(a: any, b: any) -> bool {
        x: any = a;
        y: any = b;
        if x is y {
            return True;
        }
        ev = (x == y);
        return isinstance(ev, bool) and ev;
    }

    def __getitem__(key: any) -> any {
        pos = self._pos_of(key);
        if pos == -1 {
            raise KeyError(key);
        }
        return self.vallist[pos];
    }

    def __setitem__(key: any, v: any) {
        pos = self._pos_of(key);
        if pos == -1 {
            self.keylist.append(key);
            self.vallist.append(v);
        } else {
            self.vallist[pos] = v;
        }
    }

    def __delitem__(key: any) {
        pos = self._pos_of(key);
        if pos == -1 {
            raise KeyError(key);
        }
        del self.keylist[pos];
        del self.vallist[pos];
    }

    def __contains__(key: any) -> bool {
        return self._pos_of(key) != -1;
    }

    def __len__ -> int {
        return len(self.keylist);
    }

    def __iter__ -> any {
        return iter(list(self.keylist));
    }

    def __reversed__ -> any {
        return iter(list(reversed(self.keylist)));
    }

    def get(key: any, dflt: any = None) -> any {
        pos = self._pos_of(key);
        if pos == -1 {
            return dflt;
        }
        return self.vallist[pos];
    }

    def setdefault(key: any, dflt: any = None) -> any {
        pos = self._pos_of(key);
        if pos == -1 {
            self.keylist.append(key);
            self.vallist.append(dflt);
            return dflt;
        }
        return self.vallist[pos];
    }

    def pop(key: any, dflt: any = _P2_MISSING) -> any {
        pos = self._pos_of(key);
        if pos == -1 {
            if dflt is _P2_MISSING {
                raise KeyError(key);
            }
            return dflt;
        }
        v = self.vallist[pos];
        del self.keylist[pos];
        del self.vallist[pos];
        return v;
    }

    def popitem(last: bool = True) -> tuple {
        if len(self.keylist) == 0 {
            raise KeyError("dictionary is empty");
        }
        pos: int;
        if last {
            pos = len(self.keylist) - 1;
        } else {
            pos = 0;
        }
        kv = (self.keylist[pos], self.vallist[pos]);
        del self.keylist[pos];
        del self.vallist[pos];
        return kv;
    }

    def move_to_end(key: any, last: bool = True) {
        pos = self._pos_of(key);
        if pos == -1 {
            raise KeyError(key);
        }
        k = self.keylist[pos];
        v = self.vallist[pos];
        del self.keylist[pos];
        del self.vallist[pos];
        if last {
            self.keylist.append(k);
            self.vallist.append(v);
        } else {
            self.keylist.insert(0, k);
            self.vallist.insert(0, v);
        }
    }

    def clear() {
        self.keylist = [];
        self.vallist = [];
    }

    def copy -> _P2OrderedDict {
        return _p2_ordereddict_from_pairs(self.items());
    }

    def keys -> list {
        return list(self.keylist);
    }

    def values -> list {
        return list(self.vallist);
    }

    def items -> list {
        out: list = [];
        i: int = 0;
        while i < len(self.keylist) {
            out.append((self.keylist[i], self.vallist[i]));
            i += 1;
        }
        return out;
    }

    def update(iterable: any = None, **kwds: dict) {
        for kv in _p2_od_pairs(iterable) {
            self.__setitem__(kv[0], kv[1]);
        }
        for k in kwds.keys() {
            self.__setitem__(k, kwds[k]);
        }
    }

    def __repr__ -> str {
        parts: list = [];
        i: int = 0;
        while i < len(self.keylist) {
            parts.append(repr(self.keylist[i]) + ": " + repr(self.vallist[i]));
            i += 1;
        }
        return "OrderedDict({" + ", ".join(parts) + "})";
    }

    def __eq__(other: any) -> any {
        # od_eq: only another OrderedDict compares order-sensitively; every
        # other mapping falls back to unordered dict equality (both ways).
        if isinstance(other, _P2OrderedDict) {
            if len(other.keylist) != len(self.keylist) {
                return False;
            }
            i: int = 0;
            while i < len(self.keylist) {
                if not self._od_items_eq(self.keylist[i], other.keylist[i])
                    or not self._od_items_eq(self.vallist[i], other.vallist[i]) {
                    return False;
                }
                i += 1;
            }
            return True;
        }
        if not _p2_defaultdict_is_map(other) {
            return False;
        }
        other_items = other.items();
        if len(other_items) != len(self.keylist) {
            return False;
        }
        for kv in other_items {
            pos = self._pos_of(kv[0]);
            if pos == -1 or not self._od_items_eq(self.vallist[pos], kv[1]) {
                return False;
            }
        }
        return True;
    }

    def __ne__(other: any) -> any {
        eqv = self.__eq__(other);
        if isinstance(eqv, bool) {
            return not eqv;
        }
        return eqv;
    }
}


def _p2_od_pairs(iterable: any) -> list {
    if iterable is None {
        return [];
    }
    if _p2_defaultdict_is_map(iterable) {
        return iterable.items();
    }
    out: list = [];
    for kv in iterable {
        out.append((kv[0], kv[1]));
    }
    return out;
}


def _p2_ordereddict_from_pairs(pairs: list) -> _P2OrderedDict {
    od = _P2OrderedDict();
    for kv in pairs {
        od.keylist.append(kv[0]);
        od.vallist.append(kv[1]);
    }
    return od;
}


def _p2_ordereddict(initial: any = None, **kwds: dict) -> _P2OrderedDict {
    od = _P2OrderedDict();
    od.update(initial);
    od.update(**kwds);
    return od;
}


def _p2_ordereddict_fromkeys(seq: any, value: any = None) -> _P2OrderedDict {
    od = _P2OrderedDict();
    for k in seq {
        od.__setitem__(k, value);
    }
    return od;
}


# ---------------------------------------------------------------------------
# namedtuple (nt_make_nt / nt_new / nt_repr / _make/_asdict/_replace mirrors).
#
# CPython execs a generated class; this facade carries the same observable
# state explicitly: the type object holds typename + field names + defaults,
# instances hold the value sequence. Validation error texts are byte-exact
# against the pinned host oracle.
# ---------------------------------------------------------------------------

def _p2_nt_check_name(name: any) -> None {
    # Typename ladder: identifier, then keyword. Field-specific rules live in
    # the caller loop.
    if not name.isidentifier() {
        raise ValueError(
            "Type names and field names must be valid identifiers: "
            + _p2_nt_repr(name));
    }
    if _keyword.iskeyword(name) {
        raise ValueError(
            "Type names and field names cannot be a keyword: "
            + _p2_nt_repr(name));
    }
}


def _p2_nt_repr(v: any) -> str {
    return repr(v);
}


obj _P2NamedTupleType {
    has type_name: str = "",
        field_names: list = [],
        field_defaults: dict = {};


    def __call__(*args: list, **kwargs: dict) -> any {
        # nt_new: positional args fill fields left to right, keywords fill
        # named fields; defaults cover trailing omissions. Arity errors carry
        # the generated __new__ name ("P.__new__() ...").
        vals: list = [];
        n = len(self.field_names);
        if len(args) > n {
            raise TypeError(
                self.type_name + ".__new__() takes " + str(n + 1)
                + " positional arguments but " + str(len(args) + 1)
                + " were given");
        }
        i: int = 0;
        while i < len(args) {
            vals.append(args[i]);
            i += 1;
        }
        for k in kwargs.keys() {
            idx: int = -1;
            j: int = 0;
            while j < n {
                if self.field_names[j] == k {
                    idx = j;
                    break;
                }
                j += 1;
            }
            if idx == -1 {
                raise TypeError(
                    self.type_name + ".__new__() got an unexpected keyword"
                    + " argument '" + k + "'");
            }
            if idx < len(vals) {
                raise TypeError(
                    self.type_name + ".__new__() got multiple values for"
                    + " argument '" + k + "'");
            }
            while len(vals) < idx {
                vals.append(None);
            }
            vals.append(kwargs[k]);
        }
        while len(vals) < n {
            name = self.field_names[len(vals)];
            if name in self.field_defaults {
                vals.append(self.field_defaults[name]);
            } else {
                raise TypeError(
                    self.type_name + ".__new__() missing 1 required"
                    + " positional argument: '" + name + "'");
            }
        }
        return _p2_nt_instance(self, vals);
    }

    def _make(iterable: any) -> any {
        vals: list = [];
        for v in iterable {
            vals.append(v);
        }
        if len(vals) != len(self.field_names) {
            raise TypeError(
                "Expected " + str(len(self.field_names))
                + " arguments, got " + str(len(vals)));
        }
        return _p2_nt_instance(self, vals);
    }

    def __getattr__(name: str) -> any {
        # Class-level surface: _fields / _field_defaults / __name__.
        if name == "_fields" {
            return tuple(self.field_names);
        }
        if name == "_field_defaults" {
            return dict(self.field_defaults);
        }
        if name == "__name__" {
            return self.type_name;
        }
        raise AttributeError(
            "type object '" + self.type_name + "' has no attribute '" + name
            + "'");
    }

}


obj _P2NamedTupleInst {
    has tp: any = None,
        vals: list = [];


    def _field_index(name: str) -> int {
        i: int = 0;
        while i < len(self.tp.field_names) {
            if self.tp.field_names[i] == name {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    def __getattr__(name: str) -> any {
        idx = self._field_index(name);
        if idx != -1 {
            return self.vals[idx];
        }
        if name == "_fields" {
            return tuple(self.tp.field_names);
        }
        if name == "_field_defaults" {
            return dict(self.tp.field_defaults);
        }
        if name == "__name__" {
            return self.tp.type_name;
        }
        raise AttributeError(
            "'" + self.tp.type_name + "' object has no attribute '" + name
            + "'");
    }

    def _asdict -> any {
        # nt_asdict: zip(fields, self) into a plain dict.
        return dict(zip(self.tp.field_names, self.vals));
    }

    def _replace(**kwds: dict) -> any {
        # nt_replace: unknown names collect into one TypeError listing.
        bad: list = [];
        for k in kwds.keys() {
            if self._field_index(k) == -1 {
                bad.append(k);
            }
        }
        if len(bad) > 0 {
            raise TypeError("Got unexpected field names: " + repr(bad));
        }
        new_vals: list = [];
        for v in self.vals {
            new_vals.append(v);
        }
        for k in kwds.keys() {
            new_vals[self._field_index(k)] = kwds[k];
        }
        return _p2_nt_instance(self.tp, new_vals);
    }

    def _count(value: any) -> int {
        return self.vals.count(value);
    }

    def count(value: any) -> int {
        return self._count(value);
    }

    def index(value: any, start: any = None, stop: any = None) -> any {
        # Tuple.index semantics via the underlying sequence.
        if start is None and stop is None {
            return self.vals.index(value);
        }
        if stop is None {
            return self.vals.index(value, start);
        }
        return self.vals.index(value, start, stop);
    }

    def _index(value: any) -> any {
        return self.vals.index(value);
    }

    def __len__ -> int {
        return len(self.vals);
    }

    def __getitem__(item: any) -> any {
        if isinstance(item, slice) {
            host_slice = slice(item.start, item.stop, item.step);
            return tuple(self.vals[host_slice]);
        }
        if isinstance(item, int) {
            i = item;
            n = len(self.vals);
            if i < 0 {
                i += n;
            }
            if i < 0 or i >= n {
                raise IndexError("tuple index out of range");
            }
            return self.vals[i];
        }
        raise TypeError(
            "tuple indices must be integers or slices, not "
            + _p2_nt_type_of(item));
    }

    def __iter__ -> any {
        return iter(list(self.vals));
    }

    def __eq__(other: any) -> any {
        # Tuple equality: length plus pairwise ==, any sequence operand.
        try {
            ln = len(other);
        } except Exception {
            return NotImplemented;
        }
        if ln != len(self.vals) {
            return False;
        }
        i: int = 0;
        while i < ln {
            lhs: any = self.vals[i];
            rhs: any = other[i];
            if lhs is rhs {
                i += 1;
                continue;
            }
            ev = (lhs == rhs);
            if not (isinstance(ev, bool) and ev) {
                return False;
            }
            i += 1;
        }
        return True;
    }

    def __ne__(other: any) -> any {
        eqv = self.__eq__(other);
        if isinstance(eqv, bool) {
            return not eqv;
        }
        return eqv;
    }

    def __hash__ -> int {
        return hash(tuple(self.vals));
    }

    def __repr__ -> str {
        # nt_repr: "P(x=1, y=2)" over field/value pairs.
        parts: list = [];
        i: int = 0;
        while i < len(self.vals) {
            parts.append(
                self.tp.field_names[i] + "=" + repr(self.vals[i]));
            i += 1;
        }
        return self.tp.type_name + "(" + ", ".join(parts) + ")";
    }
}


def _p2_nt_type_of(v: any) -> str {
    return type(v).__name__;
}


def _p2_nt_instance(tp: any, vals: list) -> _P2NamedTupleInst {
    inst = _P2NamedTupleInst();
    inst.tp = tp;
    inst.vals = vals;
    return inst;
}


def _p2_namedtuple(
    typename: any,
    field_names: any,
    rename: bool = False,
    defaults: any = None,
    module: any = None,
) -> any {
    # nt_collect_field_names + validation ladder, byte-exact messages.
    if isinstance(field_names, str) {
        names: list = field_names.replace(",", " ").split();
    } else {
        names = list(field_names);
    }
    _p2_nt_check_name(typename);
    seen: dict = {};
    i: int = 0;
    while i < len(names) {
        name = names[i];
        invalid: bool = not name.isidentifier()
            or _keyword.iskeyword(name)
            or name.startswith("_");
        dup: bool = name in seen;
        if invalid or dup {
            if rename {
                names[i] = "_" + str(i);
            } else {
                if not name.isidentifier() {
                    raise ValueError(
                        "Type names and field names must be valid"
                        + " identifiers: " + repr(name));
                }
                if _keyword.iskeyword(name) {
                    raise ValueError(
                        "Type names and field names cannot be a keyword: "
                        + repr(name));
                }
                if name.startswith("_") {
                    raise ValueError(
                        "Field names cannot start with an underscore: "
                        + repr(name));
                }
                raise ValueError(
                    "Encountered duplicate field name: " + repr(name));
            }
        }
        seen[names[i]] = True;
        i += 1;
    }
    tp = _P2NamedTupleType();
    tp.type_name = typename;
    tp.field_names = names;
    if defaults is not None {
        dl = list(defaults);
        if len(dl) > len(names) {
            raise TypeError(
                "Got more default values than field names");
        }
        offset = len(names) - len(dl);
        j: int = 0;
        while j < len(dl) {
            tp.field_defaults[names[offset + j]] = dl[j];
            j += 1;
        }
    }
    return tp;
}
