"""Implementation for Postgres-backed TTG prefetch planning."""

import logging;
import sys;
import jaclang.compiler.frontend.unitree as uni;
import from uuid { UUID }

import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.runtime.archetype {
    NodeAnchor,
    NodeArchetype,
    VisitType
}
import from jaclang.runtime.graph_query { QHop }
import from jaclang.runtime.topology_index { ingest_topology_rows }

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
    raise RuntimeError("TTG query-planner fallback is disabled");
}

@classmethod
impl JacTTGGenerator._arch_types_for_ids(
    cls: type[JacTTGGenerator], mem: any, ids: list[UUID]
) -> dict[UUID, str] {
    raise RuntimeError("TTG extra arch-type lookup is disabled");
}

@classmethod
impl JacTTGGenerator._chain_to_hops(
    cls: type[JacTTGGenerator],
    warch: any,
    chain: list[tuple[str | None, str | None, int]]
) -> list[QHop] {
    raise RuntimeError("TTG query-planner fallback is disabled");
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
    raise RuntimeError("TTG query-planner fallback is disabled");
}


def _sql_visit_specs(
    cls: type[JacTTGGenerator], visits: list[VisitType]
) -> (list[dict] | None) {
    specs: list[dict] = [];
    for v in visits {
        if not isinstance(v, VisitType) {
            return None;
        }
        if v.edge_chain is not None {
            chain = v.edge_chain;
        } else {
            edge_name = cls._resolve_type_name(v.edge_type);
            chain = [(edge_name, None, 2)];
        }
        if not chain {
            return None;
        }
        normalized_chain: list[tuple[str | None, str | None, int]] = [];
        for hop in chain {
            try {
                direction = int(hop[2] or 2);
            } except Exception {
                return None;
            }
            if direction not in (1, 2, 3) {
                return None;
            }
            normalized_chain.append((hop[0], hop[1], direction));
        }
        specs.append({
            "idx": len(specs),
            "from_type": cls._resolve_type_name(v.from_node_type),
            "chain": normalized_chain,
            "is_visit": bool(v.is_visit)
        });
    }
    return specs if specs else None;
}


def _resolve_sql_visit_bfs_budgeted(
    mem: any,
    origins: list[UUID],
    specs: list[dict],
    max_length: int,
    type_cache: (dict[UUID, str] | None) = None
) -> list[UUID] {
    import os as _os;
    fanout_raw = (
        _os.environ.get("JAC_TTG_SQL_FANOUT", "unlimited").strip().lower()
    );
    fanout = 0;
    fanout_limited = False;
    if (
        fanout_raw
        and fanout_raw not in (
            "0",
            "none",
            "unlimited",
            "unbounded",
            "all",
            "false",
            "no",
            "off",
        )
    ) {
        try {
            fanout = int(fanout_raw);
        } except Exception {
            fanout = 0;
        }
        if fanout > 0 {
            fanout_limited = True;
        }
    }
    max_chain_len = 1;
    for spec in specs {
        chain = spec.get("chain") or [];
        max_chain_len = max(max_chain_len, len(chain));
    }
    params: dict[str, object] = {
        "origin_ids": [str(i) for i in origins],
        "limit": int(max_length),
        "max_depth": int(max_length),
        "fanout": int(fanout),
        "fanout_limited": fanout_limited
    };
    spec_values: list[str] = [];
    hop_values: list[str] = [];
    for spec in specs {
        idx = int(spec["idx"]);
        pfx = f"s{idx}";
        params[f"{pfx}idx"] = idx;
        params[f"{pfx}from"] = spec.get("from_type");
        params[f"{pfx}visit"] = bool(spec.get("is_visit"));
        chain = spec.get("chain") or [];
        params[f"{pfx}len"] = len(chain);
        spec_values.append(
            f"(CAST(:{pfx}idx AS int), CAST(:{pfx}from AS text), "
            f"CAST(:{pfx}visit AS boolean), CAST(:{pfx}len AS int))"
        );
        for (hop_idx, hop) in enumerate(chain) {
            hpfx = f"s{idx}h{hop_idx}";
            params[f"{hpfx}sidx"] = idx;
            params[f"{hpfx}hidx"] = hop_idx;
            params[f"{hpfx}edge"] = hop[0];
            params[f"{hpfx}node"] = hop[1];
            params[f"{hpfx}dir"] = int(hop[2] or 2);
            hop_values.append(
                f"(CAST(:{hpfx}sidx AS int), CAST(:{hpfx}hidx AS int), "
                f"CAST(:{hpfx}edge AS text), CAST(:{hpfx}node AS text), "
                f"CAST(:{hpfx}dir AS int))"
            );
        }
    }
    spec_values_sql = ",\n                    ".join(spec_values);
    hop_values_sql = ",\n                    ".join(hop_values);
    sql = f"""
            WITH RECURSIVE
            specs(idx, from_type, is_visit, chain_len) AS (
                VALUES
                    {spec_values_sql}
            ),
            hops(spec_idx, hop_idx, edge_type, node_type, direction) AS (
                VALUES
                    {hop_values_sql}
            ),
            walk(depth, node_id, path_nodes, path_ord, is_frontier) AS (
                SELECT
                    0::int AS depth,
                    seed.id AS node_id,
                    ARRAY[seed.id]::uuid[] AS path_nodes,
                    ARRAY[CAST(seed.ord AS bigint)]::bigint[] AS path_ord,
                    TRUE AS is_frontier
                FROM unnest(CAST(:origin_ids AS uuid[]))
                    WITH ORDINALITY AS seed(id, ord)
                JOIN anchors n ON n.id = seed.id
                 AND n.kind = 'NodeAnchor'
                UNION ALL
                SELECT
                    walk.depth + 1 AS depth,
                    step.next_id AS node_id,
                    step.path_nodes AS path_nodes,
                    (
                        walk.path_ord
                        || CAST(step.spec_idx AS bigint)
                    ) || step.hop_ord AS path_ord,
                    step.is_visit AS is_frontier
                FROM walk
                JOIN anchors cur
                    ON cur.id = walk.node_id
                   AND cur.kind = 'NodeAnchor'
                JOIN LATERAL (
                    WITH RECURSIVE chain_walk(
                        spec_idx,
                        chain_len,
                        is_visit,
                        hop_idx,
                        node_id,
                        path_nodes,
                        hop_ord
                    ) AS (
                        SELECT
                            specs.idx AS spec_idx,
                            specs.chain_len AS chain_len,
                            specs.is_visit AS is_visit,
                            0 AS hop_idx,
                            walk.node_id AS node_id,
                            walk.path_nodes AS path_nodes,
                            ARRAY[]::bigint[] AS hop_ord
                        FROM specs
                        WHERE specs.chain_len > 0
                          AND (
                              specs.from_type IS NULL
                              OR cur.arch_type = specs.from_type
                              OR EXISTS (
                                  SELECT 1 FROM graph_types gt
                                  WHERE gt.type_name = cur.arch_type
                                    AND gt.ancestor = specs.from_type
                              )
                          )
                        UNION ALL
                        SELECT
                            chain_walk.spec_idx,
                            chain_walk.chain_len,
                            chain_walk.is_visit,
                            hops.hop_idx + 1,
                            edge_step.next_id,
                            chain_walk.path_nodes || edge_step.next_id,
                            chain_walk.hop_ord || edge_step.step_rank
                        FROM chain_walk
                        JOIN hops
                            ON hops.spec_idx = chain_walk.spec_idx
                           AND hops.hop_idx = chain_walk.hop_idx
                        JOIN LATERAL (
                            WITH candidate_edges AS (
                                SELECT
                                    edge.dst AS next_id,
                                    edge.seq AS edge_seq,
                                    edge.id AS edge_id,
                                    edge.arch_type AS edge_arch_type,
                                    tgt.arch_type AS target_arch_type
                                FROM anchors edge
                                JOIN anchors tgt ON tgt.id = edge.dst
                                 AND tgt.kind = 'NodeAnchor'
                                WHERE hops.direction IN (2, 3)
                                  AND edge.kind = 'EdgeAnchor'
                                  AND edge.src = chain_walk.node_id
                                  AND edge.dst IS NOT NULL
                                UNION ALL
                                SELECT
                                    edge.src AS next_id,
                                    edge.seq AS edge_seq,
                                    edge.id AS edge_id,
                                    edge.arch_type AS edge_arch_type,
                                    tgt.arch_type AS target_arch_type
                                FROM anchors edge
                                JOIN anchors tgt ON tgt.id = edge.src
                                 AND tgt.kind = 'NodeAnchor'
                                WHERE hops.direction IN (1, 3)
                                  AND edge.kind = 'EdgeAnchor'
                                  AND edge.dst = chain_walk.node_id
                                  AND edge.src IS NOT NULL
                                UNION ALL
                                SELECT
                                    edge.dst AS next_id,
                                    edge.seq AS edge_seq,
                                    edge.id AS edge_id,
                                    edge.arch_type AS edge_arch_type,
                                    tgt.arch_type AS target_arch_type
                                FROM anchors edge
                                JOIN anchors tgt ON tgt.id = edge.dst
                                 AND tgt.kind = 'NodeAnchor'
                                WHERE hops.direction = 1
                                  AND edge.kind = 'EdgeAnchor'
                                  AND edge.undirected
                                  AND edge.src = chain_walk.node_id
                                  AND edge.dst IS NOT NULL
                                UNION ALL
                                SELECT
                                    edge.src AS next_id,
                                    edge.seq AS edge_seq,
                                    edge.id AS edge_id,
                                    edge.arch_type AS edge_arch_type,
                                    tgt.arch_type AS target_arch_type
                                FROM anchors edge
                                JOIN anchors tgt ON tgt.id = edge.src
                                 AND tgt.kind = 'NodeAnchor'
                                WHERE hops.direction = 2
                                  AND edge.kind = 'EdgeAnchor'
                                  AND edge.undirected
                                  AND edge.dst = chain_walk.node_id
                                  AND edge.src IS NOT NULL
                            )
                            SELECT *
                            FROM (
                                SELECT
                                    candidate_edges.next_id,
                                    ROW_NUMBER() OVER (
                                        ORDER BY candidate_edges.edge_seq NULLS FIRST,
                                                 candidate_edges.edge_id
                                    ) AS step_rank
                                FROM candidate_edges
                                WHERE (
                                      hops.edge_type IS NULL
                                      OR candidate_edges.edge_arch_type = hops.edge_type
                                      OR EXISTS (
                                          SELECT 1 FROM graph_types gt
                                          WHERE gt.type_name = candidate_edges.edge_arch_type
                                            AND gt.ancestor = hops.edge_type
                                      )
                                  )
                                  AND (
                                      hops.node_type IS NULL
                                      OR candidate_edges.target_arch_type = hops.node_type
                                      OR EXISTS (
                                          SELECT 1 FROM graph_types gt
                                          WHERE gt.type_name = candidate_edges.target_arch_type
                                            AND gt.ancestor = hops.node_type
                                      )
                                  )
                            ) ranked_edges
                            WHERE (
                                NOT CAST(:fanout_limited AS boolean)
                                OR ranked_edges.step_rank <= CAST(:fanout AS bigint)
                            )
                            ORDER BY ranked_edges.step_rank
                        ) edge_step ON edge_step.next_id IS NOT NULL
                                 AND NOT (
                                     edge_step.next_id = ANY(chain_walk.path_nodes)
                                 )
                        WHERE chain_walk.hop_idx < chain_walk.chain_len
                    ),
                    final_chain AS (
                        SELECT
                            chain_walk.spec_idx,
                            chain_walk.is_visit,
                            chain_walk.node_id AS next_id,
                            chain_walk.path_nodes,
                            chain_walk.hop_ord
                        FROM chain_walk
                        WHERE chain_walk.hop_idx = chain_walk.chain_len
                    ),
                    ranked_chain AS (
                        SELECT
                            final_chain.*,
                            ROW_NUMBER() OVER (
                                PARTITION BY final_chain.spec_idx
                                ORDER BY final_chain.hop_ord, final_chain.next_id
                            ) AS result_ord
                        FROM final_chain
                    )
                    SELECT
                        ranked_chain.spec_idx,
                        ranked_chain.is_visit,
                        ranked_chain.next_id,
                        ranked_chain.path_nodes,
                        ranked_chain.hop_ord
                    FROM ranked_chain
                    WHERE ranked_chain.result_ord <= CAST(:limit AS bigint)
                ) step ON TRUE
                WHERE walk.is_frontier
                  AND walk.depth < CAST(:max_depth AS int)
            ),
            candidate_node_rows AS (
                SELECT
                    walk.depth,
                    walk.node_id AS target_id,
                    walk.path_ord,
                    CASE
                        WHEN n.kind = 'NodeAnchor' AND n.arch_type = 'Root'
                            THEN n.id
                        ELSE n.root_id
                    END AS owner_root
                FROM walk
                JOIN anchors n ON n.id = walk.node_id
                 AND n.kind = 'NodeAnchor'
            ),
            raw_additions AS (
                SELECT
                    depth,
                    path_ord,
                    0 AS sub_ord,
                    target_id AS id
                FROM candidate_node_rows
                UNION ALL
                SELECT
                    depth,
                    path_ord,
                    1 AS sub_ord,
                    owner_root AS id
                FROM candidate_node_rows
                WHERE owner_root IS NOT NULL
                  AND owner_root <> target_id
            ),
            dedup_additions AS (
                SELECT DISTINCT ON (id)
                    id,
                    depth,
                    path_ord,
                    sub_ord
                FROM raw_additions
                WHERE id IS NOT NULL
                ORDER BY id, depth, path_ord, sub_ord
            ),
            ordered_plan AS (
                SELECT
                    id,
                    ROW_NUMBER() OVER (
                        ORDER BY depth, path_ord, sub_ord, id
                    ) AS ord
                FROM dedup_additions
            ),
            prefetch_plan AS (
                SELECT id, ord
                FROM ordered_plan
                WHERE ord <= CAST(:limit AS bigint)
            ),
            plan_rows AS (
                SELECT
                    p.ord,
                    p.id,
                    n.arch_type,
                    CASE
                        WHEN n.kind = 'NodeAnchor' AND n.arch_type = 'Root'
                            THEN n.id
                        ELSE n.root_id
                    END AS owner_root,
                    COALESCE(string_agg(DISTINCT gt.ancestor, ','), n.arch_type)
                        AS ancestors
                FROM prefetch_plan p
                JOIN anchors n ON n.id = p.id
                 AND n.kind = 'NodeAnchor'
                LEFT JOIN graph_types gt ON gt.type_name = n.arch_type
                GROUP BY p.ord, p.id, n.id, n.kind, n.arch_type, n.root_id
            )
            SELECT
                ord,
                id,
                arch_type,
                owner_root,
                ancestors
            FROM plan_rows
            ORDER BY ord
            """;
    fanout_desc = "unlimited";
    if fanout_limited {
        fanout_desc = str(fanout);
    }
    logger.info(
        f"[TTG-SQL-BFS-START] specs={len(specs)} origins={len(origins)} "
        f"fanout={fanout_desc} max_chain={max_chain_len} "
        f"limit={max_length} mode=set-based"
    );
    mem.read_barrier();
    explain_mode = (_os.environ.get("JAC_TTG_SQL_EXPLAIN", "").strip().lower());
    try {
        if explain_mode in ("plan", "analyze", "true", "1", "on", "yes") {
            explain_options = "VERBOSE, FORMAT TEXT";
            if explain_mode in ("analyze", "true", "1", "on", "yes") {
                explain_options = "ANALYZE, BUFFERS, VERBOSE, SUMMARY, FORMAT TEXT";
            }
            explain_rows = mem.store.rows(
                f"EXPLAIN ({explain_options}) {sql}",
                params
            );
            explain_lines: list[str] = [];
            for r in explain_rows {
                explain_lines.append(str(r[0]));
            }
            logger.warning("[TTG-SQL-EXPLAIN]\n" + "\n".join(explain_lines));
            raise RuntimeError("TTG SQL EXPLAIN requested");
        }
        rows = mem.store.rows(sql, params);
    } except Exception as e {
        logger.warning(f"TTG set-based SQL BFS failed: {e}");
        raise;
    }
    prefetch: list[UUID] = [];
    prefetch_seen: set[UUID] = set();
    topology_rows: list[tuple] = [];
    for r in rows {
        uid = UUID(str(r[1]));
        if uid in prefetch_seen {
            continue;
        }
        if len(prefetch) >= max_length {
            break;
        }
        prefetch_seen.add(uid);
        prefetch.append(uid);
        arch_type = str(r[2] or "unknown");
        if type_cache is not None {
            type_cache[uid] = arch_type;
        }
        topology_rows.append((
            0,
            r[1],
            arch_type,
            r[3],
            None,
            None,
            False,
            r[4],
            None
        ));
    }
    try {
        ingest_topology_rows(mem, topology_rows);
    } except Exception as e {
        logger.debug(f"TTG SQL BFS topology ingest failed: {e}");
    }
    logger.info(
        f"[TTG-SQL-BFS] specs={len(specs)} origins={len(origins)} "
        f"prefetched={len(prefetch)} fanout={fanout_desc} "
        f"max_chain={max_chain_len} query_count=1 mode=set-based"
    );
    return prefetch;
}


def _resolve_sql_visit_bfs_layered_budgeted(
    mem: any,
    origins: list[UUID],
    specs: list[dict],
    max_length: int,
    type_cache: (dict[UUID, str] | None) = None
) -> list[UUID] {
    import os as _os;
    fanout_raw = (
        _os.environ.get("JAC_TTG_SQL_FANOUT", "unlimited").strip().lower()
    );
    if (
        fanout_raw
        and fanout_raw not in (
            "0",
            "none",
            "unlimited",
            "unbounded",
            "all",
            "false",
            "no",
            "off",
        )
    ) {
        try {
            if int(fanout_raw) > 0 {
                raise RuntimeError(
                    "TTG layered SQL does not support fanout-limited planning"
                );
            }
        } except RuntimeError {
            raise;
        } except Exception {
            fanout_raw = "";
        }
    }
    max_chain_len = 1;
    for spec in specs {
        chain = spec.get("chain") or [];
        max_chain_len = max(max_chain_len, len(chain));
    }
    base_params: dict[str, object] = {
        "max_depth": int(max_length)
    };
    spec_values: list[str] = [];
    hop_values: list[str] = [];
    all_outgoing = True;
    all_incoming = True;
    for spec in specs {
        idx = int(spec["idx"]);
        pfx = f"s{idx}";
        base_params[f"{pfx}idx"] = idx;
        base_params[f"{pfx}from"] = spec.get("from_type");
        base_params[f"{pfx}visit"] = bool(spec.get("is_visit"));
        chain = spec.get("chain") or [];
        base_params[f"{pfx}len"] = len(chain);
        spec_values.append(
            f"(CAST(:{pfx}idx AS int), CAST(:{pfx}from AS text), "
            f"CAST(:{pfx}visit AS boolean), CAST(:{pfx}len AS int))"
        );
        for (hop_idx, hop) in enumerate(chain) {
            hpfx = f"s{idx}h{hop_idx}";
            base_params[f"{hpfx}sidx"] = idx;
            base_params[f"{hpfx}hidx"] = hop_idx;
            base_params[f"{hpfx}edge"] = hop[0];
            base_params[f"{hpfx}node"] = hop[1];
            direction = int(hop[2] or 2);
            base_params[f"{hpfx}dir"] = direction;
            if direction != 2 {
                all_outgoing = False;
            }
            if direction != 1 {
                all_incoming = False;
            }
            hop_values.append(
                f"(CAST(:{hpfx}sidx AS int), CAST(:{hpfx}hidx AS int), "
                f"CAST(:{hpfx}edge AS text), CAST(:{hpfx}node AS text), "
                f"CAST(:{hpfx}dir AS int))"
            );
        }
    }
    spec_values_sql = ",\n                    ".join(spec_values);
    hop_values_sql = ",\n                    ".join(hop_values);
    mem.read_barrier();
    has_undirected = True;
    try {
        undirected_rows = mem.store.rows(
            """
            SELECT EXISTS (
                SELECT 1
                FROM anchors
                WHERE kind = 'EdgeAnchor'
                  AND undirected
                LIMIT 1
            )
            """,
            {}
        );
        has_undirected = bool(undirected_rows[0][0]) if undirected_rows else True;
    } except Exception as e {
        logger.debug(f"TTG layered SQL undirected-edge probe failed: {e}");
    }
    direction_mode = "generic";
    if not has_undirected and all_outgoing {
        direction_mode = "directed-out";
        edge_step_sql = """
                JOIN anchors edge
                    ON edge.kind = 'EdgeAnchor'
                   AND edge.src = chain_walk.node_id
                   AND edge.src IS NOT NULL
                   AND edge.dst IS NOT NULL
                JOIN anchors tgt
                    ON tgt.id = edge.dst
                   AND tgt.kind = 'NodeAnchor'
                """;
    } elif not has_undirected and all_incoming {
        direction_mode = "directed-in";
        edge_step_sql = """
                JOIN anchors edge
                    ON edge.kind = 'EdgeAnchor'
                   AND edge.dst = chain_walk.node_id
                   AND edge.src IS NOT NULL
                   AND edge.dst IS NOT NULL
                JOIN anchors tgt
                    ON tgt.id = edge.src
                   AND tgt.kind = 'NodeAnchor'
                """;
    } else {
        edge_step_sql = """
                JOIN anchors edge
                    ON edge.kind = 'EdgeAnchor'
                   AND edge.src IS NOT NULL
                   AND edge.dst IS NOT NULL
                   AND (
                       (
                           hops.direction IN (2, 3)
                           AND edge.src = chain_walk.node_id
                       )
                       OR (
                           hops.direction IN (1, 3)
                           AND edge.dst = chain_walk.node_id
                       )
                       OR (
                           hops.direction = 1
                           AND edge.undirected
                           AND edge.src = chain_walk.node_id
                       )
                       OR (
                           hops.direction = 2
                           AND edge.undirected
                           AND edge.dst = chain_walk.node_id
                       )
                   )
                JOIN anchors tgt
                    ON tgt.id = CASE
                        WHEN edge.src = chain_walk.node_id THEN edge.dst
                        ELSE edge.src
                    END
                   AND tgt.kind = 'NodeAnchor'
                """;
    }
    sql = f"""
            WITH RECURSIVE
            specs(idx, from_type, is_visit, chain_len) AS (
                VALUES
                    {spec_values_sql}
            ),
            hops(spec_idx, hop_idx, edge_type, node_type, direction) AS (
                VALUES
                    {hop_values_sql}
            ),
            frontier(node_id, frontier_ord) AS (
                SELECT seed.id, seed.ord
                FROM unnest(CAST(:frontier_ids AS uuid[]))
                    WITH ORDINALITY AS seed(id, ord)
                JOIN anchors n ON n.id = seed.id
                 AND n.kind = 'NodeAnchor'
            ),
            chain_walk(
                spec_idx,
                chain_len,
                is_visit,
                seed_ord,
                hop_idx,
                node_id,
                path_nodes,
                hop_ord
            ) AS (
                SELECT
                    specs.idx AS spec_idx,
                    specs.chain_len AS chain_len,
                    specs.is_visit AS is_visit,
                    frontier.frontier_ord AS seed_ord,
                    0 AS hop_idx,
                    frontier.node_id AS node_id,
                    ARRAY[frontier.node_id]::uuid[] AS path_nodes,
                    ARRAY[]::bigint[] AS hop_ord
                FROM frontier
                JOIN anchors cur
                    ON cur.id = frontier.node_id
                   AND cur.kind = 'NodeAnchor'
                JOIN specs ON specs.chain_len > 0
                 AND (
                     specs.from_type IS NULL
                     OR cur.arch_type = specs.from_type
                     OR EXISTS (
                         SELECT 1 FROM graph_types gt
                         WHERE gt.type_name = cur.arch_type
                           AND gt.ancestor = specs.from_type
                     )
                 )
                UNION ALL
                SELECT
                    chain_walk.spec_idx,
                    chain_walk.chain_len,
                    chain_walk.is_visit,
                    chain_walk.seed_ord,
                    hops.hop_idx + 1,
                    tgt.id AS node_id,
                    chain_walk.path_nodes || tgt.id,
                    chain_walk.hop_ord
                        || CAST(COALESCE(edge.seq, 0) AS bigint)
                FROM chain_walk
                JOIN hops
                    ON hops.spec_idx = chain_walk.spec_idx
                   AND hops.hop_idx = chain_walk.hop_idx
                {edge_step_sql}
                WHERE chain_walk.hop_idx < chain_walk.chain_len
                  AND (
                      hops.edge_type IS NULL
                      OR edge.arch_type = hops.edge_type
                      OR EXISTS (
                          SELECT 1 FROM graph_types gt
                          WHERE gt.type_name = edge.arch_type
                            AND gt.ancestor = hops.edge_type
                      )
                  )
                  AND (
                      hops.node_type IS NULL
                      OR tgt.arch_type = hops.node_type
                      OR EXISTS (
                          SELECT 1 FROM graph_types gt
                          WHERE gt.type_name = tgt.arch_type
                            AND gt.ancestor = hops.node_type
                      )
                  )
                  AND NOT (tgt.id = ANY(chain_walk.path_nodes))
            ),
            candidate_node_rows AS (
                SELECT
                    0::int AS phase,
                    frontier.frontier_ord::bigint AS seed_ord,
                    -1::int AS spec_idx,
                    ARRAY[]::bigint[] AS hop_ord,
                    frontier.node_id AS target_id,
                    FALSE AS is_frontier
                FROM frontier
                UNION ALL
                SELECT
                    1::int AS phase,
                    chain_walk.seed_ord,
                    chain_walk.spec_idx,
                    chain_walk.hop_ord,
                    chain_walk.node_id AS target_id,
                    chain_walk.is_visit AS is_frontier
                FROM chain_walk
                WHERE chain_walk.hop_idx = chain_walk.chain_len
            ),
            node_rows AS (
                SELECT
                    candidate_node_rows.phase,
                    candidate_node_rows.seed_ord,
                    candidate_node_rows.spec_idx,
                    candidate_node_rows.hop_ord,
                    candidate_node_rows.target_id,
                    candidate_node_rows.is_frontier,
                    CASE
                        WHEN n.kind = 'NodeAnchor' AND n.arch_type = 'Root'
                            THEN n.id
                        ELSE n.root_id
                    END AS owner_root
                FROM candidate_node_rows
                JOIN anchors n ON n.id = candidate_node_rows.target_id
                 AND n.kind = 'NodeAnchor'
            ),
            raw_additions AS (
                SELECT
                    phase,
                    seed_ord,
                    spec_idx,
                    hop_ord,
                    0 AS sub_ord,
                    target_id AS id,
                    is_frontier
                FROM node_rows
                UNION ALL
                SELECT
                    phase,
                    seed_ord,
                    spec_idx,
                    hop_ord,
                    1 AS sub_ord,
                    owner_root AS id,
                    FALSE AS is_frontier
                FROM node_rows
                WHERE owner_root IS NOT NULL
                  AND owner_root <> target_id
            ),
            filtered_additions AS (
                SELECT *
                FROM raw_additions
                WHERE id IS NOT NULL
                  AND (
                      CAST(:seen_count AS int) = 0
                      OR NOT (id = ANY(CAST(:seen_ids AS uuid[])))
                  )
            ),
            dedup_additions AS (
                SELECT DISTINCT ON (id)
                    id,
                    phase,
                    seed_ord,
                    spec_idx,
                    hop_ord,
                    sub_ord,
                    is_frontier
                FROM filtered_additions
                ORDER BY id, phase, seed_ord, spec_idx, hop_ord, sub_ord
            ),
            ordered_plan AS (
                SELECT
                    id,
                    is_frontier,
                    ROW_NUMBER() OVER (
                        ORDER BY phase, seed_ord, spec_idx, hop_ord, sub_ord, id
                    ) AS ord
                FROM dedup_additions
            ),
            prefetch_plan AS (
                SELECT id, is_frontier, ord
                FROM ordered_plan
                WHERE ord <= CAST(:limit AS bigint)
            ),
            plan_rows AS (
                SELECT
                    p.ord,
                    p.id,
                    n.arch_type,
                    CASE
                        WHEN n.kind = 'NodeAnchor' AND n.arch_type = 'Root'
                            THEN n.id
                        ELSE n.root_id
                    END AS owner_root,
                    COALESCE(string_agg(DISTINCT gt.ancestor, ','), n.arch_type)
                        AS ancestors,
                    p.is_frontier
                FROM prefetch_plan p
                JOIN anchors n ON n.id = p.id
                 AND n.kind = 'NodeAnchor'
                LEFT JOIN graph_types gt ON gt.type_name = n.arch_type
                GROUP BY
                    p.ord,
                    p.id,
                    p.is_frontier,
                    n.id,
                    n.kind,
                    n.arch_type,
                    n.root_id
            )
            SELECT
                ord,
                id,
                arch_type,
                owner_root,
                ancestors,
                is_frontier
            FROM plan_rows
            ORDER BY ord
            """;
    logger.info(
        f"[TTG-SQL-LAYERED-START] specs={len(specs)} origins={len(origins)} "
        f"fanout=unlimited max_chain={max_chain_len} limit={max_length} "
        f"direction_mode={direction_mode} has_undirected={has_undirected}"
    );
    explain_mode = (_os.environ.get("JAC_TTG_SQL_EXPLAIN", "").strip().lower());
    prefetch: list[UUID] = [];
    prefetch_seen: set[UUID] = set();
    topology_rows: list[tuple] = [];
    frontier: list[UUID] = list(origins);
    expanded_seen: set[UUID] = set();
    depth = 0;
    query_count = 0;
    nil_uuid = "00000000-0000-0000-0000-000000000000";
    while (
        len(frontier) > 0
        and len(prefetch) < max_length
        and depth < max_length
    ) {
        remaining = max_length - len(prefetch);
        params = dict(base_params);
        params["frontier_ids"] = [str(i) for i in frontier];
        params["seen_count"] = len(prefetch_seen);
        params["seen_ids"] = (
            [str(i) for i in prefetch_seen]
            if len(prefetch_seen) > 0
            else [nil_uuid]
        );
        params["limit"] = int(remaining);
        try {
            if explain_mode in ("plan", "analyze", "true", "1", "on", "yes") {
                explain_options = "VERBOSE, FORMAT TEXT";
                if explain_mode in ("analyze", "true", "1", "on", "yes") {
                    explain_options = (
                        "ANALYZE, BUFFERS, VERBOSE, SUMMARY, FORMAT TEXT"
                    );
                }
                explain_rows = mem.store.rows(
                    f"EXPLAIN ({explain_options}) {sql}",
                    params
                );
                explain_lines: list[str] = [];
                for r in explain_rows {
                    explain_lines.append(str(r[0]));
                }
                logger.warning(
                    f"[TTG-SQL-LAYERED-EXPLAIN depth={depth}]\n"
                    + "\n".join(explain_lines)
                );
                raise RuntimeError("TTG layered SQL EXPLAIN requested");
            }
            rows = mem.store.rows(sql, params);
            query_count += 1;
        } except Exception as e {
            logger.warning(f"TTG layered SQL BFS failed at depth {depth}: {e}");
            raise;
        }
        next_frontier: list[UUID] = [];
        next_seen: set[UUID] = set();
        for r in rows {
            uid = UUID(str(r[1]));
            if uid in prefetch_seen {
                continue;
            }
            if len(prefetch) >= max_length {
                break;
            }
            prefetch_seen.add(uid);
            prefetch.append(uid);
            arch_type = str(r[2] or "unknown");
            if type_cache is not None {
                type_cache[uid] = arch_type;
            }
            topology_rows.append((
                0,
                r[1],
                arch_type,
                r[3],
                None,
                None,
                False,
                r[4],
                None
            ));
            if bool(r[5]) and uid not in expanded_seen and uid not in next_seen {
                next_seen.add(uid);
                next_frontier.append(uid);
            }
        }
        for id in frontier {
            expanded_seen.add(id);
        }
        logger.info(
            f"[TTG-SQL-LAYERED] depth={depth} frontier={len(frontier)} "
            f"rows={len(rows)} next_frontier={len(next_frontier)} "
            f"prefetched={len(prefetch)} remaining={max_length - len(prefetch)}"
        );
        frontier = next_frontier;
        depth += 1;
    }
    try {
        ingest_topology_rows(mem, topology_rows);
    } except Exception as e {
        logger.debug(f"TTG layered SQL BFS topology ingest failed: {e}");
    }
    logger.info(
        f"[TTG-SQL-BFS] specs={len(specs)} origins={len(origins)} "
        f"prefetched={len(prefetch)} fanout=unlimited max_chain={max_chain_len} "
        f"query_count={query_count} mode=layered direction_mode={direction_mode}"
    );
    return prefetch;
}


def _resolve_sql_visit_bfs(
    cls: type[JacTTGGenerator],
    mem: any,
    origins: list[UUID],
    visits: list[VisitType],
    max_length: int,
    type_cache: (dict[UUID, str] | None) = None
) -> list[UUID] {
    if max_length <= 0 {
        return [];
    }
    if mem is None or mem?.store is None {
        raise RuntimeError("TTG SQL BFS requires a SQL-backed memory store");
    }
    if not origins {
        raise RuntimeError("TTG SQL BFS requires at least one origin");
    }
    specs = _sql_visit_specs(cls, visits);
    if specs is None {
        raise RuntimeError("TTG SQL BFS cannot lower this walker's visit graph to SQL");
    }
    import os as _os;
    layered_raw = _os.environ.get("JAC_TTG_SQL_LAYERED", "").strip().lower();
    if layered_raw in ("1", "true", "yes", "on") {
        return _resolve_sql_visit_bfs_layered_budgeted(
            mem, origins, specs, max_length, type_cache
        );
    }
    return _resolve_sql_visit_bfs_budgeted(
        mem, origins, specs, max_length, type_cache
    );
}


def _finalize_ttg_prefetch(
    cls: type[JacTTGGenerator],
    prefetch: list[UUID],
    type_cache: dict[UUID, str],
    ast_ms: float,
    resolve_ms: float,
    resolve_calls: int,
    max_length: int
) -> list[UUID] {
    import os as _os;
    avg_resolve = resolve_ms / resolve_calls if resolve_calls > 0 else 0.0;
    missing_types = [
        id
        for id in prefetch
        if id not in type_cache
    ];
    if missing_types {
        logger.warning(
            "[TTG-COVERAGE] missing type metadata for "
            f"{len(missing_types)} prefetched ids"
        );
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
                    fh.write("order,id,type\n");
                }
                for (idx, id) in enumerate(prefetch) {
                    fh.write(f"{idx},{id},{type_cache.get(id, 'unknown')}\n");
                }
            }
        } except Exception as e {
            logger.debug(f"[PREFETCH-DUMP] write failed: {e}");
        }
    }
    setattr(cls, "_last_resolve_ms", resolve_ms);
    return prefetch;
}


@classmethod
impl JacTTGGenerator.get_ttg_prefetch_list(
    cls: type[JacTTGGenerator],
    warch: any,
    start_anchor: NodeAnchor,
    mem: any = None,
    max_length: int = 200
) -> list[UUID] {
    import time as _time;
    if max_length <= 0 or start_anchor is None or start_anchor.id is None {
        return [];
    }
    if mem is None or mem?.store is None {
        raise RuntimeError("TTG prefetch requires a SQL-backed memory store");
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
    type_cache: dict[UUID, str] = {};
    if start_anchor.archetype is not None {
        type_cache[start_id] = type(start_anchor.archetype).__name__;
    }
    sql_start = _time.perf_counter();
    sql_prefetch = _resolve_sql_visit_bfs(
        cls, mem, [start_id], visits, max_length, type_cache
    );
    sql_ms = (_time.perf_counter() - sql_start) * 1000;
    return _finalize_ttg_prefetch(
        cls, sql_prefetch, type_cache, ast_ms, sql_ms, 1, max_length
    );
}
