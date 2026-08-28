"""Implementation for Postgres-backed TTG prefetch planning."""

import logging;
import sys;
import jaclang.compiler.frontend.unitree as uni;
import from uuid { UUID }

import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.runtime.archetype {
    NodeAnchor,
    NodeArchetype,
    Root,
    VisitType
}
import from jaclang.runtime.graph_query { GraphQuery, QHop }

glob logger = logging.getLogger(__name__),
     _runtime_type_cache: dict[str, type] = {};

@classmethod
impl JacTTGGenerator._resolve_type_name(
    cls: type[JacTTGGenerator], ref: (type | str | None)
) -> (str | None) {
    if ref is None {
        return None;
    }
    if isinstance(ref, str) {
        return ref;
    }
    return ref.__name__;
}

@classmethod
impl JacTTGGenerator._runtime_type_for_name(
    cls: type[JacTTGGenerator], warch: any, name: (str | type | None)
) -> (type | None) {
    if name is None {
        return None;
    }
    if isinstance(name, `type) {
        return name;
    }
    key = str(name);
    if key in _runtime_type_cache {
        return _runtime_type_cache[key];
    }
    import from jaclang.runtime.runtime { JacRuntime }
    modules: list = [];
    wcls = `type(warch) if warch is not None else None;
    module_name = str(getattr(wcls, "__module__", "")) if wcls is not None else "";
    if module_name {
        modules.append(JacRuntime.loaded_modules.get(module_name));
        modules.append(sys.modules.get(module_name));
    }
    modules.extend(list(JacRuntime.loaded_modules.values()));
    for mod in modules {
        if mod is None {
            continue;
        }
        typ = getattr(mod, key, None);
        if isinstance(typ, `type) {
            _runtime_type_cache[key] = typ;
            return typ;
        }
    }
    fake = `type(key, (), {});
    _runtime_type_cache[key] = fake;
    return fake;
}

@classmethod
impl JacTTGGenerator._find_walker_ast_node(
    cls: type[JacTTGGenerator], warch_cls: type
) -> (uni.Archetype | None) {
    import from pathlib { Path }
    import from jaclang.runtime.runtime { JacRuntime }
    program = JacRuntime.get_program();
    module_name = warch_cls.__module__;
    class_name = warch_cls.__name__;
    py_module = JacRuntime.loaded_modules.get(module_name);
    if py_module is None {
        py_module = sys.modules.get(module_name);
    }
    if py_module is None {
        return None;
    }
    file_path = py_module?.__file__;
    if file_path is None {
        return None;
    }
    resolved = str(Path(str(file_path)).resolve());
    ast_module = program.find_module(resolved);
    if ast_module is None and resolved.endswith(".jac") {
        try {
            ast_module = program.compile(
                resolved, no_cgen=True, symtab_ir_only=True
            );
        } except Exception as e {
            logger.debug(f"TTG AST compile fallback failed for {resolved}: {e}");
            return None;
        }
    }
    if ast_module is None {
        return None;
    }
    for arch in ast_module.get_all_sub_nodes(uni.Archetype) {
        if (arch.arch_type.name == Tok.KW_WALKER and arch.name.value == class_name) {
            return arch;
        }
    }
    return None;
}

@classmethod
impl JacTTGGenerator._resolve_archetype(
    cls: type[JacTTGGenerator], scope_src: any, name: str
) -> (uni.Archetype | None) {
    import from typing { cast }
    scope = scope_src.find_parent_of_type(uni.UniScopeNode);
    if scope is None {
        return None;
    }
    result = scope.lookup(name);
    if result is None {
        return None;
    }
    return cast(uni.Archetype | None, result.decl.find_parent_of_type(uni.Archetype));
}

@classmethod
impl JacTTGGenerator._extract_edge_step(
    cls: type[JacTTGGenerator], scope: any, item: any
) -> tuple[str | None, str | None, int] {
    edge_type_name: (str | None) = None;
    node_filter_name: (str | None) = None;
    direction = 2;
    if isinstance(item, uni.EdgeOpRef) {
        fc = item?.filter_cond;
        if fc is not None {
            ft = fc?.f_type;
            if ft is not None {
                type_name: (str | None) = None;
                if isinstance(ft, uni.Name) {
                    type_name = ft.value;
                } else {
                    names = ft.get_all_sub_nodes(uni.Name);
                    if len(names) > 0 {
                        type_name = names[0].value;
                    }
                }
                if type_name is not None {
                    edge_arch = cls._resolve_archetype(scope, type_name);
                    if edge_arch is not None {
                        edge_type_name = edge_arch.name.value;
                    }
                }
            }
        }
        edge_dir = item?.edge_dir;
        try {
            direction = int(edge_dir.value);
        } except Exception {
            dir_name = getattr(edge_dir, 'name', '');
            if 'IN' in str(dir_name) {
                direction = 1;
            } elif 'ANY' in str(dir_name) {
                direction = 3;
            } else {
                direction = 2;
            }
        }
    } elif isinstance(item, uni.FilterCompr) {
        ft = item?.f_type;
        if ft is not None {
            type_name: (str | None) = None;
            if isinstance(ft, uni.Name) {
                type_name = ft.value;
            } else {
                names = ft.get_all_sub_nodes(uni.Name);
                if len(names) > 0 {
                    type_name = names[0].value;
                }
            }
            if type_name is not None {
                node_arch = cls._resolve_archetype(scope, type_name);
                if node_arch is not None {
                    node_filter_name = node_arch.name.value;
                }
            }
        }
    }
    return (edge_type_name, node_filter_name, direction);
}

@classmethod
impl JacTTGGenerator._extract_chains_from_trailer(
    cls: type[JacTTGGenerator], scope: any, trailer: any
) -> list[tuple[str | None, str | None, int]] {
    import from typing { cast }
    edge_chain: list[tuple[str | None, str | None, int]] = [];
    chain_items = getattr(trailer, 'chain', []);
    for item in chain_items {
        step = cls._extract_edge_step(scope, item);
        if step[0] is not None or isinstance(item, uni.EdgeOpRef) {
            edge_chain.append(step);
        } elif step[1] is not None {
            if len(edge_chain) > 0 {
                prev: tuple[str | None, str | None, int] = edge_chain[-1];
                prev_dir: int = cast(int, prev[2]);
                edge_chain[-1] = (prev[0], step[1], prev_dir);
            }
        }
    }
    if len(edge_chain) == 0 {
        edge_refs = trailer.get_all_sub_nodes(uni.EdgeOpRef);
        for edge_ref in edge_refs {
            step = cls._extract_edge_step(scope, edge_ref);
            edge_chain.append(step);
        }
    }
    return edge_chain;
}

@classmethod
impl JacTTGGenerator._extract_refs_from_body(
    cls: type[JacTTGGenerator], body: any
) -> list[list[tuple[str | None, str | None, int]]] {
    result: list[list[tuple[str | None, str | None, int]]] = [];
    trailers = body.get_all_sub_nodes(uni.EdgeRefTrailer);
    for trailer in trailers {
        chain = cls._extract_chains_from_trailer(body, trailer);
        if len(chain) > 0 {
            result.append(chain);
        }
    }
    return result;
}

@classmethod
impl JacTTGGenerator._ability_sub_nodes(
    cls: type[JacTTGGenerator], ability: uni.Ability, node_type: type
) -> list {
    result = ability.get_all_sub_nodes(node_type);
    body = ability?.body;
    if isinstance(body, uni.ImplDef) {
        result.extend(body.get_all_sub_nodes(node_type));
    }
    return result;
}

@classmethod
impl JacTTGGenerator._ast_type_name(
    cls: type[JacTTGGenerator], expr: (uni.UniNode | None)
) -> (str | None) {
    if expr is None {
        return None;
    }
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.Token) {
        return expr.value;
    }
    if isinstance(expr, uni.BuiltinType) {
        return expr?.sym_name or str(getattr(expr, "value", ""));
    }
    if isinstance(expr, uni.AtomTrailer) {
        attrs = expr.as_attr_list;
        if attrs {
            last = attrs[-1];
            if isinstance(last, uni.Name) {
                return last.value;
            }
            if isinstance(last, uni.AstSymbolNode) {
                return last.sym_name;
            }
        }
    }
    return str(getattr(expr, "value", getattr(expr, "sym_name", "")));
}

@classmethod
impl JacTTGGenerator._call_target_symbol(
    cls: type[JacTTGGenerator], call: uni.FuncCall
) -> (uni.Symbol | None) {
    if isinstance(call.target, uni.Name) {
        sym = call.target.sym;
        if not sym and call.target.sym_tab {
            sym = call.target.sym_tab.lookup(call.target.sym_name, deep=True);
        }
        return sym;
    }
    if isinstance(call.target, uni.AtomTrailer) {
        attrs = call.target.as_attr_list;
        if attrs {
            last = attrs[-1];
            if isinstance(last, uni.AstSymbolNode) and last.sym {
                return last.sym;
            }
        }
    }
    return None;
}

@classmethod
impl JacTTGGenerator._resolve_called_ability(
    cls: type[JacTTGGenerator], call: uni.FuncCall
) -> (uni.Ability | None) {
    sym = cls._call_target_symbol(call);
    if sym and sym.defn {
        defn_node = sym.defn[0];
        if isinstance(defn_node, uni.Ability) {
            return defn_node;
        }
        if defn_node.parent and isinstance(defn_node.parent, uni.Ability) {
            return defn_node.parent;
        }
    }
    method_name: (str | None) = None;
    target = call.target;
    if isinstance(target, uni.AtomTrailer) {
        names = target.get_all_sub_nodes(uni.Name);
        if len(names) > 0 {
            method_name = names[-1].value;
        }
    } elif isinstance(target, uni.NameAtom) {
        method_name = target.sym_name;
    }
    if method_name is None {
        return None;
    }
    module = call.find_parent_of_type(uni.Module);
    if module is None {
        return None;
    }
    for arch in module.get_all_sub_nodes(uni.Archetype) {
        for method in arch.get_all_sub_nodes(uni.Ability) {
            if method.py_resolve_name() == method_name {
                return method;
            }
        }
    }
    return None;
}

@classmethod
impl JacTTGGenerator._single_param_node_type(
    cls: type[JacTTGGenerator], ability: uni.Ability
) -> (str | None) {
    if not isinstance(ability.signature, uni.FuncSignature) {
        return None;
    }
    params = ability.signature.get_parameters();
    if len(params) != 1 {
        return None;
    }
    tag = params[0].type_tag;
    if tag is None {
        return None;
    }
    type_name = cls._ast_type_name(tag.tag);
    if type_name is None {
        return None;
    }
    arch = cls._resolve_archetype(tag, type_name);
    if arch is None or arch.arch_type.name != Tok.KW_NODE {
        return None;
    }
    return arch.name.value;
}

@classmethod
impl JacTTGGenerator._trace_method_calls(
    cls: type[JacTTGGenerator],
    ability: uni.Ability,
    current_node_type: (str | None) = None,
    seen: (set[int] | None) = None
) -> list[VisitType] {
    result: list[VisitType] = [];
    if seen is None {
        seen = set();
    }
    func_calls = cls._ability_sub_nodes(ability, uni.FuncCall);
    for call_any in func_calls {
        if not isinstance(call_any, uni.FuncCall) {
            continue;
        }
        call: uni.FuncCall = call_any;
        callee = cls._resolve_called_ability(call);
        if callee is None or id(callee) in seen {
            continue;
        }
        seen.add(id(callee));
        owner_type: (str | None) = None;
        if callee.method_owner and isinstance(callee.method_owner, uni.Archetype) {
            owner_type = callee.method_owner.name.value;
        }
        if owner_type is None {
            param_owner_type = cls._single_param_node_type(callee);
            if param_owner_type is not None {
                owner_type = param_owner_type;
            }
        }
        if owner_type is None and current_node_type is not None {
            owner_type = current_node_type;
        }
        trailers = cls._ability_sub_nodes(callee, uni.EdgeRefTrailer);
        for trailer in trailers {
            chain = cls._extract_chains_from_trailer(callee, trailer);
            if len(chain) > 0 {
                first_edge = chain[0][0] if len(chain) > 0 else None;
                result.append(
                    VisitType(
                        from_node_type=owner_type,
                        edge_type=first_edge,
                        edge_chain=chain if len(chain) > 0 else None,
                        is_visit=False
                    )
                );
            }
        }
        result.extend(cls._trace_method_calls(callee, owner_type, seen));
    }
    return result;
}

@classmethod
impl JacTTGGenerator._extract_visits_from_ast(
    cls: type[JacTTGGenerator], warch: any
) -> list[VisitType] {
    warch_cls = `type(warch);
    cached_raw = warch_cls?.__jac_ttg_visits__;
    if isinstance(cached_raw, list) and len(cached_raw) > 0 {
        logger.info(
            f"[TTG-EXTRACT] cache HIT for {warch_cls.__name__}, "
            f"returning {len(cached_raw)} visits"
        );
        return cached_raw;
    }
    logger.info(f"[TTG-EXTRACT] cache MISS for {warch_cls.__name__}");
    ast_node = cls._find_walker_ast_node(warch_cls);
    if ast_node is None {
        return [];
    }
    result: list[VisitType] = [];
    abilities = ast_node.get_all_sub_nodes(uni.Ability);
    for ability in abilities {
        event_sigs = ability.get_all_sub_nodes(uni.EventSignature);
        if len(event_sigs) == 0 {
            continue;
        }
        node_type_name: (str | None) = None;
        node_type_names = event_sigs[0].get_all_sub_nodes(uni.Name);
        if len(node_type_names) > 0 {
            node_arch = cls._resolve_archetype(
                node_type_names[0], node_type_names[0].value
            );
            if node_arch is not None {
                node_type_name = node_arch.name.value;
            }
        }
        visit_stmts = cls._ability_sub_nodes(ability, uni.VisitStmt);
        for visit_stmt in visit_stmts {
            chains = cls._extract_refs_from_body(visit_stmt);
            for chain in chains {
                first_edge = chain[0][0] if len(chain) > 0 else None;
                result.append(
                    VisitType(
                        from_node_type=node_type_name,
                        edge_type=first_edge,
                        edge_chain=chain if len(chain) > 0 else None
                    )
                );
            }
        }
        visit_trailer_ids: set[int] = set();
        for vs in visit_stmts {
            for t in vs.get_all_sub_nodes(uni.EdgeRefTrailer) {
                visit_trailer_ids.add(id(t));
            }
        }
        all_trailers = cls._ability_sub_nodes(ability, uni.EdgeRefTrailer);
        for trailer in all_trailers {
            if id(trailer) in visit_trailer_ids {
                continue;
            }
            chain = cls._extract_chains_from_trailer(ability, trailer);
            if len(chain) > 0 {
                first_edge = chain[0][0] if len(chain) > 0 else None;
                result.append(
                    VisitType(
                        from_node_type=node_type_name,
                        edge_type=first_edge,
                        edge_chain=chain if len(chain) > 0 else None,
                        is_visit=False
                    )
                );
            }
        }
        result.extend(cls._trace_method_calls(ability, node_type_name));
    }
    setattr(warch_cls, "__jac_ttg_visits__", result);
    return result;
}

@classmethod
impl JacTTGGenerator._origin_for_id(
    cls: type[JacTTGGenerator], id: UUID
) -> NodeArchetype {
    origin = Root();
    anchor = origin.__jac__;
    anchor.id = id;
    anchor.persistent = True;
    return origin;
}

@classmethod
impl JacTTGGenerator._arch_types_for_ids(
    cls: type[JacTTGGenerator], mem: any, ids: list[UUID]
) -> dict[UUID, str] {
    out: dict[UUID, str] = {};
    if mem is None or not ids {
        return out;
    }
    missing: list[UUID] = [];
    seen: set[UUID] = set();
    raw_mem = mem?.__raw_mem__;
    for id in ids {
        if id in seen {
            continue;
        }
        seen.add(id);
        anchor = mem?.__mem__?.get(id);
        if anchor is not None and anchor?.archetype is not None {
            out[id] = type(anchor.archetype).__name__;
            continue;
        }
        row = raw_mem.get(id) if isinstance(raw_mem, dict) else None;
        if row is not None and getattr(row, "arch_type", "") {
            out[id] = str(row.arch_type);
            continue;
        }
        missing.append(id);
    }
    store = mem?.store;
    if store is None or not missing {
        return out;
    }
    try {
        mem.read_barrier();
        rows = store.rows(
            """
            SELECT id, arch_type
              FROM anchors
             WHERE id = ANY(CAST(:ids AS uuid[]))
            """,
            {'ids': [str(i) for i in missing]}
        );
        for r in rows {
            out[UUID(str(r[0]))] = str(r[1]);
        }
    } except Exception as e {
        logger.debug(f"TTG arch_type lookup failed: {e}");
    }
    return out;
}

@classmethod
impl JacTTGGenerator._chain_to_hops(
    cls: type[JacTTGGenerator],
    warch: any,
    chain: list[tuple[str | None, str | None, int]]
) -> list[QHop] {
    hops: list[QHop] = [];
    for (edge_name, node_name, direction) in chain {
        edge_type = cls._runtime_type_for_name(warch, edge_name)
            if edge_name is not None
            else None;
        node_type = cls._runtime_type_for_name(warch, node_name)
            if node_name is not None
            else None;
        hops.append(QHop(dir=int(direction or 2), `edge=edge_type, nd=node_type));
    }
    return hops;
}

@classmethod
impl JacTTGGenerator._resolve_chain_ids(
    cls: type[JacTTGGenerator],
    mem: any,
    warch: any,
    origin_id: UUID,
    chain: list[tuple[str | None, str | None, int]],
    limit: int
) -> list[UUID] {
    if mem is None or mem?.store is None or limit <= 0 or not chain {
        return [];
    }
    import from jaclang.data.query_planner { resolve_query_prefix }
    try {
        hops = cls._chain_to_hops(warch, chain);
        query = GraphQuery(cls._origin_for_id(origin_id), hops=hops, limit=limit);
        return resolve_query_prefix(mem, query, len(hops));
    } except Exception as e {
        logger.debug(f"TTG query resolve failed: {e}");
        return [];
    }
}

@classmethod
impl JacTTGGenerator.get_ttg_prefetch_list(
    cls: type[JacTTGGenerator],
    warch: any,
    start_anchor: NodeAnchor,
    mem: any = None,
    max_length: int = 200
) -> list[UUID] {
    import os as _os;
    import time as _time;
    if max_length <= 0 or start_anchor is None or start_anchor.id is None {
        return [];
    }
    if mem is None or mem?.store is None {
        return [start_anchor.id];
    }
    t0 = _time.perf_counter();
    visits = cls._extract_visits_from_ast(warch);
    ast_ms = (_time.perf_counter() - t0) * 1000;
    logger.info(
        f"[TTG-DEBUG] extracted {len(visits)} visits: "
        + str(
            [
                (
                    f"from={cls._resolve_type_name(v.from_node_type)}",
                    f"edge={cls._resolve_type_name(v.edge_type)}",
                    f"chain={v.edge_chain}",
                    f"is_visit={v.is_visit}"
                )
                for v in visits
            ]
        )
    );
    start_id = start_anchor.id;
    prefetch: list[UUID] = [start_id];
    seen: set[UUID] = {start_id};
    queue: list[UUID] = [start_id];
    type_cache: dict[UUID, str] = {};
    if start_anchor.archetype is not None {
        type_cache[start_id] = type(start_anchor.archetype).__name__;
    } else {
        type_cache.update(cls._arch_types_for_ids(mem, [start_id]));
    }
    resolve_ms = 0.0;
    resolve_calls = 0;
    qpos = 0;
    while qpos < len(queue) {
        if len(prefetch) >= max_length {
            break;
        }
        cur = queue[qpos];
        qpos += 1;
        if cur not in type_cache {
            type_cache.update(cls._arch_types_for_ids(mem, [cur]));
        }
        cur_type = type_cache.get(cur);
        for v in visits {
            if len(prefetch) >= max_length {
                break;
            }
            from_type = cls._resolve_type_name(v.from_node_type)
                if isinstance(v, VisitType)
                else None;
            if from_type is not None {
                if cur_type is None or cur_type != from_type {
                    continue;
                }
            }
            if isinstance(v, VisitType) and v.edge_chain is not None {
                chain = v.edge_chain;
            } elif isinstance(v, VisitType) {
                edge_name = cls._resolve_type_name(v.edge_type);
                chain = [(edge_name, None, 2)];
            } else {
                chain = [(None, None, 2)];
            }
            remaining = max_length - len(prefetch);
            rc_start = _time.perf_counter();
            results = cls._resolve_chain_ids(mem, warch, cur, chain, remaining);
            resolve_ms += (_time.perf_counter() - rc_start) * 1000;
            resolve_calls += 1;
            is_visit_chain = (not isinstance(v, VisitType)) or v.is_visit;
            added: list[UUID] = [];
            enqueued = 0;
            for tgt in results {
                if tgt in seen {
                    continue;
                }
                if len(prefetch) >= max_length {
                    break;
                }
                seen.add(tgt);
                prefetch.append(tgt);
                added.append(tgt);
                if is_visit_chain {
                    queue.append(tgt);
                    enqueued += 1;
                }
            }
            if added {
                type_cache.update(cls._arch_types_for_ids(mem, added));
                logger.info(
                    f"[TTG-BFS] cur_type={cur_type} from={from_type} "
                    f"is_visit={is_visit_chain} chain_results={len(results)} "
                    f"added={len(added)} enqueued={enqueued}"
                );
            }
        }
    }
    avg_resolve = resolve_ms / resolve_calls if resolve_calls > 0 else 0.0;
    missing_types = [
        id
        for id in prefetch
        if id not in type_cache
    ];
    if missing_types {
        type_cache.update(cls._arch_types_for_ids(mem, missing_types));
    }
    type_counts: dict[str, int] = {};
    for id in prefetch {
        tname = type_cache.get(id, "unknown");
        type_counts[tname] = type_counts.get(tname, 0) + 1;
    }
    logger.info(
        f"[TTG] ast_ms={ast_ms:.3f} resolve_chain_total_ms={resolve_ms:.3f} "
        f"resolve_calls={resolve_calls} avg_per_call_ms={avg_resolve:.4f} "
        f"prefetched={len(prefetch)}"
    );
    logger.info(
        f"[TTG-COVERAGE] prefetched_by_type={type_counts} "
        f"max_length={max_length}"
    );
    dump_path = _os.environ.get("JAC_PREFETCH_DUMP");
    if dump_path {
        try {
            import pathlib as _pathlib;
            p = _pathlib.Path(dump_path);
            p.parent.mkdir(parents=True, exist_ok=True);
            new_file = not p.exists();
            with p.open("a") as fh {
                if new_file {
                    fh.write("id,type,owner\n");
                }
                for id in prefetch {
                    fh.write(f"{id},{type_cache.get(id, 'unknown')},\n");
                }
            }
        } except Exception as e {
            logger.debug(f"[PREFETCH-DUMP] write failed: {e}");
        }
    }
    setattr(cls, "_last_resolve_ms", resolve_ms);
    return prefetch;
}
