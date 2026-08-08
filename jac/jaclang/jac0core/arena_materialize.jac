"""Materialize a SyntaxArena into the mutable unitree object graph.

This is the Python-side bridge of the flat-handoff milestone: the parser
(bytecode or sealed-native) produces only the arena; every consumer that
needs real unitree nodes goes through here, exactly once per parse. The
walk is a memoized, order-independent DFS from root_id, so it tolerates
records amended after emission, shared children (DAG), and unreachable
records abandoned by parser backtracking.

Construction calls the real unitree constructors, so postinit behavior
(kid reparenting, loc derivation from token ranges) is reproduced
exactly. TAG_NONE arguments are omitted when the constructor has a
default (letting the real default apply) and passed as None otherwise.
SOURCE-classified params receive the shared Source object. The `posts`
channel replays the few post-construction field sets the parser records
against postinit fields (param_kind, code_context).
"""

import from jaclang.jac0core { unitree as ut_mod }
import from jaclang.jac0core { constant as const_mod }
import from jaclang.jac0core.arena {
    SyntaxArena,
    TAG_BOOL,
    TAG_ENUM,
    TAG_INT,
    TAG_LIST,
    TAG_NODE,
    TAG_NONE,
    TAG_STR
}
import from jaclang.jac0core.arena_specs { SPECS }
import from jaclang.jac0core.unitree { Module, Source, UniNode }

glob _CLS_CACHE: dict[int, tuple] = {};


"""Resolve (class, enum-classes-per-slot) for a kind id, memoized."""
def _resolved_spec(kind: int) -> tuple {
    got = _CLS_CACHE.get(kind);
    if got is not None {
        return got;
    }
    (cls_name, params, token_family, has_kid) = SPECS[kind];
    cls = getattr(ut_mod, cls_name);
    enums: list = [];
    for p in params {
        ename = p[2];
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


"""All node ids a record references (kids plus NODE/LIST args)."""
def _deps_of(a: SyntaxArena, i: int) -> list[int] {
    deps = a.kid_ids(i);
    n = a.arg_ns[i];
    p = a.arg_los[i];
    s = 0;
    while s < n {
        tag = a.args[p];
        v = a.args[p + 1];
        if tag == TAG_NODE {
            deps.append(v);
        } elif tag == TAG_LIST {
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
        return const_mod.CodeContext(v);
    }
    raise ValueError(f"materialize: unknown post-set key {key}");
}


"""Build the unitree object graph for the arena, returning the root."""
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
        (i, expanded) = stack.pop();
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
        (cls, params, enums, token_family, has_kid) = _resolved_spec(a.kinds[i]);
        kwargs: dict[str, any] = {};
        p = a.arg_los[i];
        slot = 0;
        for (pspec, ecls) in zip(params, enums) {
            (pname, cat, _ename, has_default) = pspec;
            if cat == "SOURCE" {
                kwargs[pname] = source;
                continue;
            }
            tag = a.args[p + (slot * 2)];
            v = a.args[p + (slot * 2) + 1];
            slot += 1;
            if tag == TAG_NONE {
                if not has_default {
                    kwargs[pname] = None;
                }
            } elif tag == TAG_NODE {
                kwargs[pname] = objs[v];
            } elif tag == TAG_LIST {
                kwargs[pname] = [objs[k] for k in a.seq_ids(v)];
            } elif tag == TAG_STR {
                kwargs[pname] = a.strtab[v];
            } elif tag == TAG_INT {
                kwargs[pname] = v;
            } elif tag == TAG_BOOL {
                kwargs[pname] = v != 0;
            } elif tag == TAG_ENUM {
                kwargs[pname] = ecls(v);
            }
        }
        if has_kid {
            kwargs["kid"] = [objs[k] for k in a.kid_ids(i)];
        }
        obj = cls(**kwargs);
        for entry in posts_by_id.get(i, []) {
            (key, pv) = entry;
            setattr(obj, key, _decode_post(key, pv));
        }
        objs[i] = obj;
    }

    root = objs[a.root_id];
    if isinstance(root, Module) {
        node_list: list[UniNode] = [];
        seen: dict[int, bool] = {};
        walk: list[UniNode] = [root];
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
        root._in_mod_nodes = node_list;
    }
    return root;
}
