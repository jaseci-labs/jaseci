obj ArenaState {
    has records: list[int] = [],
        strings: list[bytes] = [],
        intern_ids: dict[bytes, int] = {},
        adj_out: dict[int, list[int]] = {},
        adj_in: dict[int, list[int]] = {},
        pay_out: dict[int, list[int]] = {},
        frozen: bool = False,
        dead: bool = False;
}

glob _ARENAS: list[ArenaState] = [];

glob _KIND_NSLOTS: dict[int, int] = {},
     _KIND_FROZEN: dict[int, int] = {},
     _KIND_STRS: dict[int, int] = {},
     _KIND_REFS: dict[int, int] = {},
     _EKIND_STRUCT: dict[int, int] = {};

glob _IDX_MASK: int = 1099511627775,
     _EK_SHIFT: int = 12,
     _EK_MASK: int = 4095;

def js_abi_version -> int {
    return 3;
}

def js_kind_register(
    kind: int, nslots: int, frozen_mask: int, str_mask: int, ref_mask: int
) -> int {
    _KIND_NSLOTS[kind] = nslots;
    _KIND_FROZEN[kind] = frozen_mask;
    _KIND_STRS[kind] = str_mask;
    _KIND_REFS[kind] = ref_mask;
    return 0;
}

def js_ekind_register(ekind: int, is_struct: int) -> int {
    _EKIND_STRUCT[ekind] = is_struct;
    return 0;
}

def _arena(a: int) -> ArenaState | None {
    if a < 0 or a >= len(_ARENAS) {
        return None;
    }
    st = _ARENAS[a];
    if st.dead {
        return None;
    }
    return st;
}

def js_arena_new -> int {
    _ARENAS.append(ArenaState());
    return len(_ARENAS) - 1;
}

def js_arena_freeze(a: int) -> int {
    st = _arena(a);
    if st is None {
        return 2;
    }
    st.frozen = True;
    return 0;
}

def js_arena_frozen(a: int) -> int {
    st = _arena(a);
    if st is None {
        return 2;
    }
    return 1 if st.frozen else 0;
}

def js_arena_drop(a: int) -> int {
    st = _arena(a);
    if st is None {
        return 2;
    }
    st.records = [];
    st.strings = [];
    st.intern_ids = {};
    st.adj_out = {};
    st.adj_in = {};
    st.pay_out = {};
    st.dead = True;
    return 0;
}

def js_node_new(a: int, kind: int) -> int {
    st = _arena(a);
    if st is None {
        return -1;
    }
    if st.frozen {
        return -1;
    }
    nslots = _KIND_NSLOTS.get(kind, -1);
    if nslots < 0 {
        return -1;
    }
    off = len(st.records);
    st.records.append(kind);
    st.records.append(nslots);
    i = 0;
    while i < nslots {
        st.records.append(0);
        i += 1;
    }
    return (a << 40) | off;
}

def js_node_kind(h: int) -> int {
    st = _arena(h >> 40);
    if st is None {
        return -1;
    }
    return st.records[h & _IDX_MASK];
}

def js_slot_get(h: int, i: int) -> int {
    st = _arena(h >> 40);
    if st is None {
        return 0;
    }
    off = h & _IDX_MASK;
    return st.records[off + 2 + i];
}

def js_slot_set(h: int, i: int, v: int) -> int {
    st = _arena(h >> 40);
    if st is None {
        return 2;
    }
    off = h & _IDX_MASK;
    if st.frozen and (_KIND_FROZEN.get(st.records[off], 0) & (1 << i)) != 0 {
        return 1;
    }
    st.records[off + 2 + i] = v;
    return 0;
}

def js_intern_bytes(a: int, b: bytes) -> int {
    st = _arena(a);
    if st is None {
        return -1;
    }
    if b in st.intern_ids {
        return st.intern_ids[b];
    }
    sid = len(st.strings);
    st.strings.append(b);
    st.intern_ids[b] = sid;
    return sid;
}

def js_intern_get_bytes(a: int, sid: int) -> bytes {
    st = _arena(a);
    if st is None or sid < 0 or sid >= len(st.strings) {
        return b"";
    }
    return st.strings[sid];
}

def js_edge_add(src: int, dst: int, ekind: int, payload_sid: int) -> int {
    sa = src >> 40;
    st = _arena(sa);
    if st is None {
        return 2;
    }
    if st.frozen and _EKIND_STRUCT.get(ekind, 0) != 0 {
        return 1;
    }
    okey = ((src & _IDX_MASK) << _EK_SHIFT) | ekind;
    if okey in st.adj_out {
        st.adj_out[okey].append(dst);
    } else {
        st.adj_out[okey] = [dst];
    }
    if payload_sid >= 0 {
        if okey in st.pay_out {
            st.pay_out[okey].append(payload_sid);
        } else {
            st.pay_out[okey] = [payload_sid];
        }
    }
    dt = _arena(dst >> 40);
    if dt is not None {
        ikey = ((dst & _IDX_MASK) << _EK_SHIFT) | ekind;
        if ikey in dt.adj_in {
            dt.adj_in[ikey].append(src);
        } else {
            dt.adj_in[ikey] = [src];
        }
    }
    return 0;
}

def js_adj(h: int, ekind: int, direction: int) -> list[int] {
    st = _arena(h >> 40);
    if st is None {
        return [];
    }
    key = ((h & _IDX_MASK) << _EK_SHIFT) | ekind;
    if direction == 0 {
        return list(st.adj_out.get(key, []));
    }
    return list(st.adj_in.get(key, []));
}

def js_adj_payloads(h: int, ekind: int) -> list[int] {
    st = _arena(h >> 40);
    if st is None {
        return [];
    }
    key = ((h & _IDX_MASK) << _EK_SHIFT) | ekind;
    return list(st.pay_out.get(key, []));
}

def js_adj_clear(h: int, ekind: int, direction: int) -> int {
    sa = h >> 40;
    st = _arena(sa);
    if st is None {
        return 2;
    }
    if st.frozen and _EKIND_STRUCT.get(ekind, 0) != 0 {
        return 1;
    }
    key = ((h & _IDX_MASK) << _EK_SHIFT) | ekind;
    if direction == 0 {
        olds = st.adj_out.get(key, []);
        for dst in olds {
            dt = _arena(dst >> 40);
            if dt is not None {
                ikey = ((dst & _IDX_MASK) << _EK_SHIFT) | ekind;
                if ikey in dt.adj_in {
                    dt.adj_in[ikey] = [s for s in dt.adj_in[ikey] if s != h];
                }
            }
        }
        st.adj_out[key] = [];
        st.pay_out[key] = [];
        return 0;
    }
    srcs = st.adj_in.get(key, []);
    for src in srcs {
        su = _arena(src >> 40);
        if su is not None {
            okey = ((src & _IDX_MASK) << _EK_SHIFT) | ekind;
            if okey in su.adj_out {
                su.adj_out[okey] = [d for d in su.adj_out[okey] if d != h];
            }
        }
    }
    st.adj_in[key] = [];
    return 0;
}

def js_copy_slots(src: int, dst: int) -> int {
    sa = src >> 40;
    da = dst >> 40;
    st = _arena(sa);
    dt = _arena(da);
    if st is None or dt is None {
        return 2;
    }
    soff = src & _IDX_MASK;
    doff = dst & _IDX_MASK;
    kind = st.records[soff];
    if dt.records[doff] != kind {
        return 3;
    }
    nslots = st.records[soff + 1];
    strs = _KIND_STRS.get(kind, 0);
    i = 0;
    while i < nslots {
        v = st.records[soff + 2 + i];
        if (strs & (1 << i)) != 0 and v > 0 and sa != da {
            v = js_intern_bytes(da, js_intern_get_bytes(sa, v - 1)) + 1;
        }
        dt.records[doff + 2 + i] = v;
        i += 1;
    }
    return 0;
}

def _copy_rec(h: int, dst_arena: int, memo: dict[int, int]) -> int {
    if h in memo {
        return memo[h];
    }
    sa = h >> 40;
    st = _arena(sa);
    dt = _arena(dst_arena);
    if st is None or dt is None {
        return -1;
    }
    off = h & _IDX_MASK;
    kind = st.records[off];
    nh = js_node_new(dst_arena, kind);
    if nh < 0 {
        return -1;
    }
    memo[h] = nh;
    nslots = st.records[off + 1];
    strs = _KIND_STRS.get(kind, 0);
    i = 0;
    while i < nslots {
        v = st.records[off + 2 + i];
        if (strs & (1 << i)) != 0 and v > 0 and sa != dst_arena {
            v = js_intern_bytes(dst_arena, js_intern_get_bytes(sa, v - 1)) + 1;
        }
        js_slot_set(nh, i, v);
        i += 1;
    }
    for ekind in _EKIND_STRUCT.keys() {
        if _EKIND_STRUCT[ekind] == 0 {
            continue;
        }
        key = (off << _EK_SHIFT) | ekind;
        kids = st.adj_out.get(key, []);
        pays = st.pay_out.get(key, []);
        j = 0;
        for kid in kids {
            nk = _copy_rec(kid, dst_arena, memo);
            if nk >= 0 {
                p = pays[j] if j < len(pays) else -1;
                js_edge_add(nh, nk, ekind, p);
            }
            j += 1;
        }
    }
    return nh;
}

def js_subtree_copy(h: int, dst_arena: int) -> int {
    memo: dict[int, int] = {};
    nh = _copy_rec(h, dst_arena, memo);
    if nh < 0 {
        return -1;
    }
    for old in memo.keys() {
        new = memo[old];
        sa = new >> 40;
        st = _arena(sa);
        if st is None {
            continue;
        }
        noff = new & _IDX_MASK;
        kind = st.records[noff];
        refs = _KIND_REFS.get(kind, 0);
        nslots = st.records[noff + 1];
        i = 0;
        while i < nslots {
            if (refs & (1 << i)) != 0 {
                v = st.records[noff + 2 + i];
                if v in memo {
                    st.records[noff + 2 + i] = memo[v];
                }
            }
            i += 1;
        }
    }
    return nh;
}
