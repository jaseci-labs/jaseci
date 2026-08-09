import jaclang.jac0core.unitree as uni;

glob DYNAMIC_TORCH_ATTRS: set[str] = {
         'item',
         'tolist',
         'sum',
         'max',
         'min',
         'mean',
         'prod',
         'argmax',
         'argmin',
         'nonzero',
         'count_nonzero',
         'all',
         'any',
         'equal',
         'allclose',
         'unique'
     },
     SCALAR_TORCH_ATTRS: set[str] = {'item', 'tolist', 'equal', 'allclose'};

def cond_is_data_dependent(cond: uni.Expr) -> bool {
    return cond_traces_attr(cond, DYNAMIC_TORCH_ATTRS);
}

def cond_materializes_scalar(cond: uni.Expr) -> bool {
    return cond_traces_attr(cond, SCALAR_TORCH_ATTRS);
}

def cond_traces_attr(cond: uni.Expr, attrs: set[str]) -> bool {
    if expr_uses_attr(cond, attrs) {
        return True;
    }
    st = cond.sym_tab;
    if not st {
        return False;
    }
    visited: set[str] = set();
    for nm in cond.get_all_sub_nodes(uni.Name) {
        sym = st.lookup(nm.value, deep=True);
        if sym and trace_symbol_attr(sym, attrs, visited, 0) {
            return True;
        }
    }
    return False;
}

def expr_uses_attr(expr: uni.UniNode, attrs: set[str]) -> bool {
    for tr in expr.get_all_sub_nodes(uni.AtomTrailer) {
        if tr.is_attr and isinstance(tr.right, uni.Name) {
            if tr.right.value in attrs {
                return True;
            }
        }
    }
    return False;
}

def trace_symbol_attr(
    sym: uni.Symbol, attrs: set[str], visited: set[str], depth: int
) -> bool {
    if (depth > 10) or (sym.sym_name in visited) {
        return False;
    }
    visited.add(sym.sym_name);
    assign = defining_assignment(sym);
    if (assign is None) or (assign.value is None) {
        return False;
    }
    if expr_uses_attr(assign.value, attrs) {
        return True;
    }
    st = assign.sym_tab;
    if not st {
        return False;
    }
    for nm in assign.value.get_all_sub_nodes(uni.Name) {
        dep = st.lookup(nm.value, deep=True);
        if dep and (dep.sym_name not in visited) {
            if trace_symbol_attr(dep, attrs, visited, depth + 1) {
                return True;
            }
        }
    }
    return False;
}

def defining_assignment(sym: uni.Symbol) -> (uni.Assignment | None) {
    if not sym.defn {
        return None;
    }
    cur = sym.defn[-1].parent;
    while cur and (not isinstance(cur, uni.Assignment)) {
        cur = cur.parent;
    }
    if isinstance(cur, uni.Assignment) {
        return cur;
    }
    return None;
}

def is_torch_attr_target(target: (uni.Expr | None), attr: str) -> bool {
    return (
        isinstance(target, uni.AtomTrailer)
        and isinstance(target.right, uni.Name)
        and (target.right.value == attr)
        and isinstance(target.target, uni.Name)
        and (target.target.value == 'torch')
    );
}

def has_torch_compile_decorator(nd: uni.UniNode) -> bool {
    for dec in (nd?.decorators or []) {
        target = dec.target if isinstance(dec, uni.FuncCall) else dec;
        if is_torch_attr_target(target, 'compile') {
            return True;
        }
    }
    return False;
}
