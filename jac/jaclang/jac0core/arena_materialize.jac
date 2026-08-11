import from jaclang.jac0core { unitree as ut_mod }
import from jaclang.jac0core { constant as const_mod }
import from jaclang.jac0core.arena { KindId, NodeId, SyntaxArena, Tag }
import from jaclang.jac0core.arena { SPECS }
import from jaclang.jac0core.constant { ArgCat }
import from jaclang.jac0core.unitree { Module, Source, UniNode }

glob _SPEC_CACHE: dict[int, ResolvedSpec] = {};


obj ArgSpec {
    has name: str,
        cat: ArgCat,
        enum_cls: any,
        has_default: bool;
}


obj ResolvedSpec {
    has cls: any,
        params: list[ArgSpec],
        token_family: bool,
        has_kid: bool;
}


# SPECS rows arrive as structured comptime-spliced tuples:
# (class_name, token_family, has_kid, ((pname, cat, enum_name, hd), ...)).
def spec_of(kind: KindId) -> tuple {
    return SPECS[kind];
}


def _resolved_spec(kind: KindId) -> ResolvedSpec {
    got = _SPEC_CACHE.get(kind);
    if got is not None {
        return got;
    }
    spec: tuple = spec_of(kind);
    params: list[ArgSpec] = [];
    prows: tuple = spec[3];
    for p in prows {
        pt: tuple = p;
        ename: str = pt[2];
        ecls: any = None;
        if ename {
            ecls = getattr(const_mod, ename, None) or getattr(ut_mod, ename);
        }
        params.append(
            ArgSpec(name=pt[0], cat=ArgCat(pt[1]), enum_cls=ecls, has_default=pt[3])
        );
    }
    resolved = ResolvedSpec(
        cls=getattr(ut_mod, spec[0]),
        params=params,
        token_family=spec[1],
        has_kid=spec[2]
    );
    _SPEC_CACHE[kind] = resolved;
    return resolved;
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
    for pe in a.post_entries() {
        pet: tuple = pe;
        posts_by_id.setdefault(pet[0], []).append((pet[1], pet[2]));
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
            for d in a.deps_of(i) {
                if d != 0 and d not in objs {
                    stack.append((d, False));
                }
            }
            continue;
        }
        rspec = _resolved_spec(a.kind_of(i));
        kwargs: dict[str, any] = {};
        pairs = a.arg_pairs(i);
        slot = 0;
        for pspec in rspec.params {
            if pspec.cat == ArgCat.SOURCE {
                kwargs[pspec.name] = source;
                continue;
            }
            (tag, v) = pairs[slot];
            slot += 1;
            if tag == Tag.NONE {
                if not pspec.has_default {
                    kwargs[pspec.name] = None;
                }
            } elif tag == Tag.NODE {
                kwargs[pspec.name] = objs[v];
            } elif tag == Tag.LIST {
                kwargs[pspec.name] = [objs[k] for k in a.seq_ids(v)];
            } elif tag == Tag.STR {
                kwargs[pspec.name] = a.str_of(v);
            } elif tag == Tag.INT {
                kwargs[pspec.name] = v;
            } elif tag == Tag.BOOL {
                kwargs[pspec.name] = v != 0;
            } elif tag == Tag.ENUM {
                kwargs[pspec.name] = pspec.enum_cls(v);
            }
        }
        kid_ids = a.kid_ids(i);
        if rspec.has_kid {
            kwargs["kid"] = [objs[k] for k in kid_ids];
        }
        made = rspec.cls(**kwargs);
        if kid_ids and not rspec.has_kid {
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
