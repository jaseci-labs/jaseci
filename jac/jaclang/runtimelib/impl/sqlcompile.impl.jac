def _ident_ok(name: str) -> bool {
    if not name {
        return False;
    }
    for ch in name {
        if not (ch.isalnum() or ch == '_') {
            return False;
        }
    }
    return not name[0].isdigit();
}


def _scalar(v: any) -> any {
    return str(v) if isinstance(v, UUID) else v;
}


def _pushable_value(v: any) -> bool {
    if isinstance(v, (str, int, float, bool, UUID)) or v is None {
        return True;
    }
    if isinstance(v, (list, tuple, set)) {
        for x in v {
            if not isinstance(x, (str, int, float, bool, UUID)) {
                return False;
            }
        }
        return True;
    }
    return False;
}


def _type_cond(alias: str, tname: str, params: dict, pfx: str) -> str {
    key = f"{pfx}t";
    params[key] = tname;
    return (
        f"({alias}.arch_type = :{key} OR {alias}.arch_type IN "
        f"(SELECT type_name FROM graph_types WHERE ancestor = :{key}))"
    );
}


def _sql_type_of(v: any) -> str {
    if isinstance(v, bool) {
        return 'boolean';
    }
    if isinstance(v, int) {
        return 'bigint';
    }
    if isinstance(v, float) {
        return 'float8';
    }
    return 'text';
}


def _sanitize_ident(name: str) -> str {
    out = '';
    for ch in name.lower() {
        out += ch if (ch.isalnum() or ch == '_') else '_';
    }
    return out;
}


def _promoted_col(
    alias: str, arch_names: list[str], field: str, promotions: (dict | None)
) -> (str | None) {
    if not promotions {
        return None;
    }
    for arch in arch_names {
        declared = promotions.get(arch);
        if declared and field in declared {
            col = f"g_{_sanitize_ident(arch)}_{_sanitize_ident(field)}";
            return f"{alias}.{col}";
        }
    }
    return None;
}


def _field_expr(
    alias: str, field: str, arch_names: list[str], promotions: (dict | None)
) -> str {
    col = _promoted_col(alias, arch_names, field, promotions);
    return col if col is not None else f"{alias}.props->'archetype'->'{field}'";
}


def _pred_cond(
    alias: str,
    p: QPred,
    params: dict,
    pfx: str,
    arch_names: (list[str] | None) = None,
    promotions: (dict | None) = None
) -> (str | None) {
    if not _ident_ok(p.field) or not _pushable_value(p.value) {
        return None;
    }
    expr = _field_expr(alias, p.field, arch_names or [], promotions);
    if p.op == 'in' {
        vals = list(p.value) if isinstance(p.value, (list, tuple, set)) else [p.value];
        parts: list[str] = [];
        for (i, v) in enumerate(vals) {
            key = f"{pfx}v{i}";
            params[key] = _scalar(v);
            parts.append(f"to_jsonb(CAST(:{key} AS {_sql_type_of(v)}))");
        }
        if not parts {
            return 'FALSE';
        }
        return f"{expr} IN ({', '.join(parts)})";
    }
    if p.value is None {
        if p.op == '==' {
            return f"{expr} = 'null'::jsonb";
        }
        if p.op == '!=' {
            return f"({expr} IS NULL OR {expr} <> 'null'::jsonb)";
        }
        return 'FALSE';
    }
    key = f"{pfx}v";
    params[key] = _scalar(p.value);
    rhs = f"to_jsonb(CAST(:{key} AS {_sql_type_of(p.value)}))";
    if p.op == '==' {
        return f"{expr} = {rhs}";
    }
    if p.op == '!=' {
        return f"({expr} IS NULL OR {expr} <> {rhs})";
    }
    op = {'<': '<', '<=': '<=', '>': '>', '>=': '>='}.get(p.op);
    if op is None {
        return None;
    }
    return f"{expr} {op} {rhs}";
}


def _dir_cond(alias: str, fid: str, dir: int) -> str {
    if dir == 1 {
        return (
            f"({alias}.dst = {fid} OR ({alias}.undirected AND {alias}.src = {fid}))"
        );
    }
    if dir == 3 {
        return f"({alias}.src = {fid} OR {alias}.dst = {fid})";
    }
    return f"({alias}.src = {fid} OR ({alias}.undirected AND {alias}.dst = {fid}))";
}


def _other_expr(alias: str, fid: str) -> str {
    return f"CASE WHEN {alias}.src = {fid} THEN {alias}.dst ELSE {alias}.src END";
}


def _nd_types(hop: QHop) -> list {
    nd = hop.nd;
    if nd is None {
        return [];
    }
    return list(nd) if isinstance(nd, tuple) else [nd];
}


impl compile_query(
    q: GraphQuery, upto: int, promotions: (dict | None) = None
) -> CompiledQuery {
    out = CompiledQuery();
    params: dict = {};
    params['origin'] = [];
    joins: list[str] = [];
    order: list[str] = [];
    fid = 'f0.id';
    n = 0;
    for (i, hop) in enumerate(q.hops[:upto]) {
        n = i + 1;
        e = f"e{n}";
        nd_alias = f"n{n}";
        pfx_e = f"h{n}e";
        econds = [f"{e}.kind = 'EdgeAnchor'", _dir_cond(e, fid, hop.dir)];
        if hop.`edge is not None {
            econds.append(_type_cond(e, hop.`edge.__name__, params, pfx_e));
        }
        edge_names: list[str] = (
            [str(getattr(hop.`edge, '__name__', ''))] if hop.`edge is not None else []
        );
        for (j, p) in enumerate(hop.epreds) {
            cond = _pred_cond(e, p, params, f"{pfx_e}p{j}", edge_names, promotions);
            if cond is None {
                out.residual.setdefault(i, []).append(p);
            } else {
                econds.append(cond);
            }
        }
        joins.append(f"JOIN anchors {e} ON {' AND '.join(econds)}");
        nconds = [
            f"{nd_alias}.id = {_other_expr(e, fid)}",
            f"{nd_alias}.kind = 'NodeAnchor'"
        ];
        for (k, nt) in enumerate(_nd_types(hop)) {
            tname = str(getattr(nt, '__name__', ''));
            if tname {
                nconds.append(_type_cond(nd_alias, tname, params, f"h{n}n{k}"));
            }
        }
        node_names: list[str] = [
            str(getattr(nt, '__name__', '')) for nt in _nd_types(hop)
        ];
        for (j, p) in enumerate(hop.preds) {
            cond = _pred_cond(
                nd_alias, p, params, f"h{n}np{j}", node_names, promotions
            );
            if cond is None {
                out.residual.setdefault(i, []).append(p);
            } else {
                nconds.append(cond);
            }
        }
        want = hop.only_ids();
        if want is not None {
            key = f"h{n}only";
            params[key] = [str(x) for x in want];
            nconds.append(f"{nd_alias}.id = ANY(CAST(:{key} AS uuid[]))");
        }
        joins.append(f"JOIN anchors {nd_alias} ON {' AND '.join(nconds)}");
        order.append(f"{e}.seq");
        order.append(f"{e}.id");
        fid = f"{nd_alias}.id";
    }
    if n == 0 {
        out.sql = (
            'SELECT f0.id, NULL FROM ' 'unnest(CAST(:origin AS uuid[])) AS f0(id)'
        );
        out.params = params;
        return out;
    }
    out.sql = (
        f"SELECT n{n}.id, e{n}.id "
        f"FROM unnest(CAST(:origin AS uuid[])) WITH ORDINALITY AS f0(id, ord) "
        f"LEFT JOIN anchors s1 ON s1.id = f0.id "
        + ' '.join(joins)
        + ' ORDER BY f0.ord, '
        + ', '.join(order)
    );
    out.params = params;
    return out;
}
