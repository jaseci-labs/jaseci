import from jaclang.jac0core { unitree as ut_mod }
import from jaclang.jac0core { constant as const_mod }
import from jaclang.jac0core.arena { SyntaxArena, Tag }
import from jaclang.jac0core.arena { SPECS }
import from jaclang.jac0core.unitree { Module, Source, UniNode }

glob _CLS_CACHE: dict[int, tuple] = {},
     _DECODE_CACHE: dict[int, tuple] = {};


def decode_spec(enc: str) -> tuple {
    fields: list[str] = enc.split("|");
    params: list = [];
    if fields[3] {
        parts: list[str] = fields[3].split(";");
        for part in parts {
            bits: list[str] = part.split(",");
            params.append((bits[0], bits[1], bits[2], bits[3] == "1", ));
        }
    }
    return (fields[0], tuple(params), fields[1] == "1", fields[2] == "1", );
}


def spec_of(kind: int) -> tuple {
    got = _DECODE_CACHE.get(kind);
    if got is None {
        got = decode_spec(SPECS[kind]);
        _DECODE_CACHE[kind] = got;
    }
    return got;
}


def _resolved_spec(kind: int) -> tuple {
    got = _CLS_CACHE.get(kind);
    if got is not None {
        return got;
    }
    spec: tuple = spec_of(kind);
    cls_name: str = spec[0];
    params: tuple = spec[1];
    token_family: bool = spec[2];
    has_kid: bool = spec[3];
    cls = getattr(ut_mod, cls_name);
    enums: list = [];
    for p in params {
        pt: tuple = p;
        ename: str = pt[2];
        if ename {
            enums.append(getattr(const_mod, ename, None) or getattr(ut_mod, ename));
        } else {
            enums.append(None);
        }
    }
    resolved = (cls, params, tuple(enums), token_family, has_kid);
    _CLS_CACHE[kind] = resolved;
    return resolved;
}


def _deps_of(a: SyntaxArena, i: int) -> list[int] {
    deps = a.kid_ids(i);
    n = a.arg_ns[i];
    p = a.arg_los[i];
    s = 0;
    while s < n {
        tag = a.args[p];
        v = a.args[p + 1];
        if tag == Tag.NODE {
            deps.append(v);
        } elif tag == Tag.LIST {
            for d in a.seq_ids(v) {
                deps.append(d);
            }
        }
        p += 2;
        s += 1;
    }
    return deps;
}


def _decode_post(key: str, v: int) -> any {
    if key == "param_kind" {
        return ut_mod.ParamKind(v);
    }
    if key == "code_context" {
        return list(const_mod.CodeContext)[v];
    }
    raise ValueError(f"materialize: unknown post-set key {key}");
}


def materialize_module(a: SyntaxArena, source: Source) -> Module {
    built = materialize(a, source);
    if not isinstance(built, Module) {
        raise ValueError("arena root is not a Module");
    }
    return built;
}


def materialize(a: SyntaxArena, source: Source) -> (UniNode | None) {
    if a.root_id == 0 {
        return None;
    }
    posts_by_id: dict[int, list] = {};
    pi = 0;
    pn = len(a.posts);
    while pi < pn {
        posts_by_id.setdefault(a.posts[pi], []).append(
            (a.strtab[a.posts[pi + 1]], a.posts[pi + 2])
        );
        pi += 3;
    }

    objs: dict[int, any] = {};
    stack: list = [(a.root_id, False)];
    while stack {
        entry: tuple = stack.pop();
        i: int = entry[0];
        expanded: bool = entry[1];
        if i in objs {
            continue;
        }
        if not expanded {
            stack.append((i, True));
            for d in _deps_of(a, i) {
                if d != 0 and d not in objs {
                    stack.append((d, False));
                }
            }
            continue;
        }
        rspec: tuple = _resolved_spec(a.kinds[i]);
        cls: any = rspec[0];
        params: tuple = rspec[1];
        enums: tuple = rspec[2];
        has_kid: bool = rspec[4];
        kwargs: dict[str, any] = {};
        p = a.arg_los[i];
        slot = 0;
        pi = 0;
        while pi < len(params) {
            pspec: tuple = params[pi];
            ecls: any = enums[pi];
            pi += 1;
            pname: str = pspec[0];
            cat: str = pspec[1];
            has_default: bool = pspec[3];
            if cat == "SOURCE" {
                kwargs[pname] = source;
                continue;
            }
            tag = a.args[p + (slot * 2)];
            v = a.args[p + (slot * 2) + 1];
            slot += 1;
            if tag == Tag.NONE {
                if not has_default {
                    kwargs[pname] = None;
                }
            } elif tag == Tag.NODE {
                kwargs[pname] = objs[v];
            } elif tag == Tag.LIST {
                kwargs[pname] = [objs[k] for k in a.seq_ids(v)];
            } elif tag == Tag.STR {
                kwargs[pname] = a.strtab[v];
            } elif tag == Tag.INT {
                kwargs[pname] = v;
            } elif tag == Tag.BOOL {
                kwargs[pname] = v != 0;
            } elif tag == Tag.ENUM {
                kwargs[pname] = ecls(v);
            }
        }
        kid_ids = a.kid_ids(i);
        if has_kid {
            kwargs["kid"] = [objs[k] for k in kid_ids];
        }
        made = cls(**kwargs);
        if kid_ids and not has_kid {
            made.set_kids([objs[k] for k in kid_ids]);
        }
        plist: list = posts_by_id.get(i, []);
        for entry in plist {
            et: tuple = entry;
            key: str = et[0];
            pv: int = et[1];
            if key == "ct_only" {
                continue;
            }
            setattr(made, key, _decode_post(key, pv));
        }
        objs[i] = made;
    }

    built = objs[a.root_id];
    if isinstance(built, Module) {
        node_list: list[UniNode] = [];
        seen: dict[int, bool] = {};
        walk: list[UniNode] = [built];
        while walk {
            nd = walk.pop();
            nid = id(nd);
            if nid not in seen {
                seen[nid] = True;
                node_list.append(nd);
                for child in nd.kid {
                    walk.append(child);
                }
            }
        }
        built._in_mod_nodes = node_list;
    }
    return built;
}
