glob _r_src: list[int] = [],
     _r_tgt: list[int] = [],
     _r_undir: list[int] = [],
     _r_tag: list[int] = [],
     _r_handle: list[int] = [],
     _r_nsrc: list[int] = [],
     _r_ntgt: list[int] = [],
     _row_free: list[int] = [];

glob _nt_cnt: list[int] = [0],
     _nt_key: list[int] = [],
     _nt_ho: list[int] = [],
     _nt_to: list[int] = [],
     _nt_hi: list[int] = [],
     _nt_ti: list[int] = [];

glob _rt_cnt: list[int] = [0],
     _rt_key: list[int] = [],
     _rt_head: list[int] = [];

glob _et_cnt: list[int] = [0],
     _et_key: list[int] = [],
     _et_row: list[int] = [];

glob _rk_addr: list[int] = [],
     _rk_next: list[int] = [],
     _rk_free: list[int] = [];

def _hslot(k: int, m: int) -> int {
    return (((k ^ (k >> 4)) & 4294967295) * 40503) & m;
}

def _nt_grow {
    ocap = len(_nt_key);
    ok: list[int] = [];
    oho: list[int] = [];
    oto: list[int] = [];
    ohi: list[int] = [];
    oti: list[int] = [];
    live = 0;
    i = 0;
    while i < ocap {
        k = _nt_key[i];
        ok.append(k);
        oho.append(_nt_ho[i]);
        oto.append(_nt_to[i]);
        ohi.append(_nt_hi[i]);
        oti.append(_nt_ti[i]);
        if k != 0 {
            live += 1;
        }
        _nt_key[i] = 0;
        _nt_ho[i] = -1;
        _nt_to[i] = -1;
        _nt_hi[i] = -1;
        _nt_ti[i] = -1;
        i += 1;
    }
    ncap = ocap * 2;
    if ncap == 0 {
        ncap = 1024;
    }
    i = ocap;
    while i < ncap {
        _nt_key.append(0);
        _nt_ho.append(-1);
        _nt_to.append(-1);
        _nt_hi.append(-1);
        _nt_ti.append(-1);
        i += 1;
    }
    m = ncap - 1;
    i = 0;
    while i < ocap {
        k = ok[i];
        if k != 0 {
            h = _hslot(k, m);
            while _nt_key[h] != 0 {
                h = (h + 1) & m;
            }
            _nt_key[h] = k;
            _nt_ho[h] = oho[i];
            _nt_to[h] = oto[i];
            _nt_hi[h] = ohi[i];
            _nt_ti[h] = oti[i];
        }
        i += 1;
    }
    _nt_cnt[0] = live;
}

def _nt_slot(addr: int) -> int {
    if len(_nt_key) == 0 or _nt_cnt[0] * 4 >= len(_nt_key) * 3 {
        _nt_grow();
    }
    m = len(_nt_key) - 1;
    h = _hslot(addr, m);
    while True {
        k = _nt_key[h];
        if k == addr {
            return h;
        }
        if k == 0 {
            _nt_key[h] = addr;
            _nt_cnt[0] += 1;
            return h;
        }
        h = (h + 1) & m;
    }
    return -1;
}

def _nt_find(addr: int) -> int {
    if len(_nt_key) == 0 {
        return -1;
    }
    m = len(_nt_key) - 1;
    h = _hslot(addr, m);
    while True {
        k = _nt_key[h];
        if k == addr {
            return h;
        }
        if k == 0 {
            return -1;
        }
        h = (h + 1) & m;
    }
    return -1;
}

def _nt_del(s: int) {
    m = len(_nt_key) - 1;
    i = s;
    j = s;
    while True {
        j = (j + 1) & m;
        k = _nt_key[j];
        if k == 0 {
            break;
        }
        h = _hslot(k, m);
        move = False;
        if i <= j {
            if h <= i or h > j {
                move = True;
            }
        } else {
            if h <= i and h > j {
                move = True;
            }
        }
        if move {
            _nt_key[i] = k;
            _nt_ho[i] = _nt_ho[j];
            _nt_to[i] = _nt_to[j];
            _nt_hi[i] = _nt_hi[j];
            _nt_ti[i] = _nt_ti[j];
            i = j;
        }
    }
    _nt_key[i] = 0;
    _nt_ho[i] = -1;
    _nt_to[i] = -1;
    _nt_hi[i] = -1;
    _nt_ti[i] = -1;
    _nt_cnt[0] -= 1;
}

def _rt_grow {
    ocap = len(_rt_key);
    ok: list[int] = [];
    oh: list[int] = [];
    live = 0;
    i = 0;
    while i < ocap {
        k = _rt_key[i];
        ok.append(k);
        oh.append(_rt_head[i]);
        if k != 0 {
            live += 1;
        }
        _rt_key[i] = 0;
        _rt_head[i] = -1;
        i += 1;
    }
    ncap = ocap * 2;
    if ncap == 0 {
        ncap = 256;
    }
    i = ocap;
    while i < ncap {
        _rt_key.append(0);
        _rt_head.append(-1);
        i += 1;
    }
    m = ncap - 1;
    i = 0;
    while i < ocap {
        k = ok[i];
        if k != 0 {
            h = _hslot(k, m);
            while _rt_key[h] != 0 {
                h = (h + 1) & m;
            }
            _rt_key[h] = k;
            _rt_head[h] = oh[i];
        }
        i += 1;
    }
    _rt_cnt[0] = live;
}

def _rt_slot(rgn: int) -> int {
    if len(_rt_key) == 0 or _rt_cnt[0] * 4 >= len(_rt_key) * 3 {
        _rt_grow();
    }
    m = len(_rt_key) - 1;
    h = _hslot(rgn, m);
    while True {
        k = _rt_key[h];
        if k == rgn {
            return h;
        }
        if k == 0 {
            _rt_key[h] = rgn;
            _rt_cnt[0] += 1;
            return h;
        }
        h = (h + 1) & m;
    }
    return -1;
}

def _rt_del(s: int) {
    m = len(_rt_key) - 1;
    i = s;
    j = s;
    while True {
        j = (j + 1) & m;
        k = _rt_key[j];
        if k == 0 {
            break;
        }
        h = _hslot(k, m);
        move = False;
        if i <= j {
            if h <= i or h > j {
                move = True;
            }
        } else {
            if h <= i and h > j {
                move = True;
            }
        }
        if move {
            _rt_key[i] = k;
            _rt_head[i] = _rt_head[j];
            i = j;
        }
    }
    _rt_key[i] = 0;
    _rt_head[i] = -1;
    _rt_cnt[0] -= 1;
}


def _et_grow {
    ocap = len(_et_key);
    ok: list[int] = [];
    orow: list[int] = [];
    live = 0;
    i = 0;
    while i < ocap {
        k = _et_key[i];
        ok.append(k);
        orow.append(_et_row[i]);
        if k != 0 {
            live += 1;
        }
        _et_key[i] = 0;
        _et_row[i] = -1;
        i += 1;
    }
    ncap = ocap * 2;
    if ncap == 0 {
        ncap = 1024;
    }
    i = ocap;
    while i < ncap {
        _et_key.append(0);
        _et_row.append(-1);
        i += 1;
    }
    m = ncap - 1;
    i = 0;
    while i < ocap {
        k = ok[i];
        if k != 0 {
            h = _hslot(k, m);
            while _et_key[h] != 0 {
                h = (h + 1) & m;
            }
            _et_key[h] = k;
            _et_row[h] = orow[i];
        }
        i += 1;
    }
    _et_cnt[0] = live;
}

def _et_put(eh: int, row: int) {
    if len(_et_key) == 0 or _et_cnt[0] * 4 >= len(_et_key) * 3 {
        _et_grow();
    }
    m = len(_et_key) - 1;
    h = _hslot(eh, m);
    while True {
        k = _et_key[h];
        if k == eh {
            _et_row[h] = row;
            return;
        }
        if k == 0 {
            _et_key[h] = eh;
            _et_row[h] = row;
            _et_cnt[0] += 1;
            return;
        }
        h = (h + 1) & m;
    }
}

def _et_find(eh: int) -> int {
    if len(_et_key) == 0 {
        return -1;
    }
    m = len(_et_key) - 1;
    h = _hslot(eh, m);
    while True {
        k = _et_key[h];
        if k == eh {
            return _et_row[h];
        }
        if k == 0 {
            return -1;
        }
        h = (h + 1) & m;
    }
    return -1;
}

def osp_has_edge(eh: int) -> int {
    return 1 if _et_find(eh) >= 0 else 0;
}

def _et_del(eh: int) {
    if len(_et_key) == 0 {
        return;
    }
    m = len(_et_key) - 1;
    h = _hslot(eh, m);
    s = -1;
    while True {
        k = _et_key[h];
        if k == eh {
            s = h;
            break;
        }
        if k == 0 {
            return;
        }
        h = (h + 1) & m;
    }
    i = s;
    j = s;
    while True {
        j = (j + 1) & m;
        k = _et_key[j];
        if k == 0 {
            break;
        }
        hh = _hslot(k, m);
        move = False;
        if i <= j {
            if hh <= i or hh > j {
                move = True;
            }
        } else {
            if hh <= i and hh > j {
                move = True;
            }
        }
        if move {
            _et_key[i] = k;
            _et_row[i] = _et_row[j];
            i = j;
        }
    }
    _et_key[i] = 0;
    _et_row[i] = -1;
    _et_cnt[0] -= 1;
}

def _row_retire(row: int) {
    _et_del(_r_handle[row]);
    _r_src[row] = -1;
    _r_handle[row] = 0;
    _row_free.append(row);
}

def osp_conn(
    src: int,
    tgt: int,
    eobj: int,
    undirected: int,
    edge_tag: int,
    rgn_src: int,
    rgn_tgt: int
) -> int {
    ss = _nt_slot(src);
    ts = _nt_slot(tgt);
    if rgn_src != 0 and _nt_ho[ss] < 0 and _nt_hi[ss] < 0 {
        _rk_reg(src, rgn_src);
    }
    if rgn_tgt != 0 and ts != ss and _nt_ho[ts] < 0 and _nt_hi[ts] < 0 {
        _rk_reg(tgt, rgn_tgt);
    }
    r = -1;
    if _row_free {
        r = _row_free.pop();
        _r_src[r] = src;
        _r_tgt[r] = tgt;
        _r_undir[r] = undirected;
        _r_tag[r] = edge_tag;
        _r_handle[r] = eobj;
        _r_nsrc[r] = -1;
        _r_ntgt[r] = -1;
    } else {
        r = len(_r_src);
        _r_src.append(src);
        _r_tgt.append(tgt);
        _r_undir.append(undirected);
        _r_tag.append(edge_tag);
        _r_handle.append(eobj);
        _r_nsrc.append(-1);
        _r_ntgt.append(-1);
    }
    t = _nt_to[ss];
    if t >= 0 {
        _r_nsrc[t] = r;
    } else {
        _nt_ho[ss] = r;
    }
    _nt_to[ss] = r;
    t = _nt_ti[ts];
    if t >= 0 {
        _r_ntgt[t] = r;
    } else {
        _nt_hi[ts] = r;
    }
    _nt_ti[ts] = r;
    _et_put(eobj, r);
    return tgt;
}

def _rk_reg(addr: int, rgn: int) {
    s = _rt_slot(rgn);
    e = -1;
    if _rk_free {
        e = _rk_free.pop();
        _rk_addr[e] = addr;
        _rk_next[e] = _rt_head[s];
    } else {
        e = len(_rk_addr);
        _rk_addr.append(addr);
        _rk_next.append(_rt_head[s]);
    }
    _rt_head[s] = e;
}

def osp_refs(origin: int, dir: int, edge_tag: int, edges_only: int) -> list[int] {
    out: list[int] = [];
    s = _nt_find(origin);
    if s < 0 {
        return out;
    }
    r = _nt_ho[s];
    while r >= 0 {
        eff = dir;
        if _r_undir[r] != 0 {
            eff = 3;
        }
        if (eff == 2 or eff == 3) and (edge_tag < 0 or _r_tag[r] == edge_tag) {
            o = _r_handle[r] if edges_only != 0 else _r_tgt[r];
            if o not in out {
                out.append(o);
            }
        }
        r = _r_nsrc[r];
    }
    r = _nt_hi[s];
    while r >= 0 {
        eff = dir;
        if _r_undir[r] != 0 {
            eff = 3;
        }
        if (eff == 1 or eff == 3) and (edge_tag < 0 or _r_tag[r] == edge_tag) {
            o = _r_handle[r] if edges_only != 0 else _r_src[r];
            if o not in out {
                out.append(o);
            }
        }
        r = _r_ntgt[r];
    }
    return out;
}

def osp_refs_many(
    origins: list[int], dir: int, edge_tag: int, edges_only: int
) -> list[int] {
    out: list[int] = [];
    i = 0;
    n = len(origins);
    while i < n {
        hop = osp_refs(origins[i], dir, edge_tag, edges_only);
        i = i + 1;
        j = 0;
        m = len(hop);
        while j < m {
            o = hop[j];
            j = j + 1;
            if o not in out {
                out.append(o);
            }
        }
    }
    return out;
}

def osp_wrap1(x: int) -> list[int] {
    out: list[int] = [];
    out.append(x);
    return out;
}

def _unlink_out(src: int, row: int) {
    s = _nt_find(src);
    if s < 0 {
        return;
    }
    prev = -1;
    r = _nt_ho[s];
    while r >= 0 {
        if r == row {
            if prev < 0 {
                _nt_ho[s] = _r_nsrc[r];
            } else {
                _r_nsrc[prev] = _r_nsrc[r];
            }
            if _nt_to[s] == r {
                _nt_to[s] = prev;
            }
            return;
        }
        prev = r;
        r = _r_nsrc[r];
    }
}

def _unlink_in(tgt: int, row: int) {
    s = _nt_find(tgt);
    if s < 0 {
        return;
    }
    prev = -1;
    r = _nt_hi[s];
    while r >= 0 {
        if r == row {
            if prev < 0 {
                _nt_hi[s] = _r_ntgt[r];
            } else {
                _r_ntgt[prev] = _r_ntgt[r];
            }
            if _nt_ti[s] == r {
                _nt_ti[s] = prev;
            }
            return;
        }
        prev = r;
        r = _r_ntgt[r];
    }
}

def osp_edge_peer(edge_handle: int, origin: int) -> int {
    r = _et_find(edge_handle);
    if r < 0 or _r_src[r] == -1 {
        return -1;
    }
    if _r_src[r] == origin {
        return _r_tgt[r];
    }
    return _r_src[r];
}

def osp_disconn_between(src: int, tgt: int, dir: int, edge_tag: int) -> int {
    s = _nt_find(src);
    if s < 0 {
        return 0;
    }
    hits: list[int] = [];
    r = _nt_ho[s];
    while r >= 0 {
        eff = dir;
        if _r_undir[r] != 0 {
            eff = 3;
        }
        if (eff == 2 or eff == 3)
            and _r_tgt[r] == tgt
            and (edge_tag < 0 or _r_tag[r] == edge_tag) {
            hits.append(r);
        }
        r = _r_nsrc[r];
    }
    r = _nt_hi[s];
    while r >= 0 {
        eff = dir;
        if _r_undir[r] != 0 {
            eff = 3;
        }
        if (eff == 1 or eff == 3)
            and _r_src[r] == tgt
            and (edge_tag < 0 or _r_tag[r] == edge_tag) {
            if r not in hits {
                hits.append(r);
            }
        }
        r = _r_ntgt[r];
    }
    i = 0;
    n = len(hits);
    while i < n {
        row = hits[i];
        _unlink_out(_r_src[row], row);
        _unlink_in(_r_tgt[row], row);
        _row_retire(row);
        i = i + 1;
    }
    return n;
}

def osp_disconnect(edge_handle: int) -> int {
    r = _et_find(edge_handle);
    if r < 0 or _r_src[r] == -1 {
        return 0;
    }
    _unlink_out(_r_src[r], r);
    _unlink_in(_r_tgt[r], r);
    _row_retire(r);
    return 1;
}

def osp_node_destroy(addr: int) -> int {
    s = _nt_find(addr);
    if s < 0 {
        return 0;
    }
    ho = _nt_ho[s];
    hi = _nt_hi[s];
    _nt_del(s);
    n = 0;
    r = ho;
    while r >= 0 {
        nx = _r_nsrc[r];
        if _r_src[r] != -1 {
            if _nt_find(_r_tgt[r]) >= 0 {
                _unlink_in(_r_tgt[r], r);
            }
            _row_retire(r);
            n += 1;
        }
        r = nx;
    }
    r = hi;
    while r >= 0 {
        nx = _r_ntgt[r];
        if _r_src[r] != -1 {
            if _nt_find(_r_src[r]) >= 0 {
                _unlink_out(_r_src[r], r);
            }
            _row_retire(r);
            n += 1;
        }
        r = nx;
    }
    return n;
}

def osp_destroy(h: int) -> int {
    if _et_find(h) >= 0 {
        return osp_disconnect(h);
    }
    return osp_node_destroy(h);
}

def osp_destroy_all(hs: list[int]) -> int {
    n = 0;
    i = 0;
    while i < len(hs) {
        n += osp_destroy(hs[i]);
        i += 1;
    }
    return n;
}

def osp_region_died(rgn: int) -> int {
    n = 0;
    if len(_rt_key) == 0 {
        return 0;
    }
    m = len(_rt_key) - 1;
    h = _hslot(rgn, m);
    s = -1;
    while True {
        k = _rt_key[h];
        if k == rgn {
            s = h;
            break;
        }
        if k == 0 {
            return 0;
        }
        h = (h + 1) & m;
    }
    stash_ho: list[int] = [];
    stash_hi: list[int] = [];
    e = _rt_head[s];
    while e >= 0 {
        addr = _rk_addr[e];
        ns = _nt_find(addr);
        if ns >= 0 {
            stash_ho.append(_nt_ho[ns]);
            stash_hi.append(_nt_hi[ns]);
            _nt_del(ns);
        }
        nx2 = _rk_next[e];
        _rk_free.append(e);
        e = nx2;
    }
    _rt_del(s);
    i = 0;
    while i < len(stash_ho) {
        r = stash_ho[i];
        while r >= 0 {
            nx = _r_nsrc[r];
            if _r_src[r] != -1 {
                if _nt_find(_r_tgt[r]) >= 0 {
                    _unlink_in(_r_tgt[r], r);
                }
                _row_retire(r);
                n += 1;
            }
            r = nx;
        }
        r = stash_hi[i];
        while r >= 0 {
            nx = _r_ntgt[r];
            if _r_src[r] != -1 {
                if _nt_find(_r_src[r]) >= 0 {
                    _unlink_out(_r_src[r], r);
                }
                _row_retire(r);
                n += 1;
            }
            r = nx;
        }
        i += 1;
    }
    return n;
}
