import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.cfront.c_types {
    JacPrim,
    C_PRIM_MAP,
    user_type_name,
    walk_to_typedecl,
    TypeKind,
    is_char_ptr,
    ptr_inner_typedecl
}

def flatten_mult(nd: c_ast.Node, acc: list) {
    if isinstance(nd, c_ast.BinaryOp) and nd.op == "*" {
        flatten_mult(nd.left, acc);
        flatten_mult(nd.right, acc);
    } else {
        acc.append(nd);
    }
}

def sizeof_type(f: c_ast.Node) -> str | None {
    if not isinstance(f, c_ast.UnaryOp) or f.op != "sizeof" {
        return None;
    }
    inner = f.expr;
    if isinstance(inner, c_ast.ID) {
        return inner.name;
    }
    if isinstance(inner, c_ast.Typename) {
        tt = inner.type;
        if isinstance(tt, c_ast.PtrDecl) {
            tt = tt.type;
        }
        if isinstance(tt, c_ast.TypeDecl) {
            it = tt.type;
            if isinstance(it, c_ast.Struct) and it.name {
                return it.name;
            }
            if it is not None {
                names = it.names;
                if names {
                    return str(names[-1]);
                }
            }
        }
    }
    return None;
}

def is_listable_elem(tname: str) -> bool {
    if tname in C_PRIM_MAP {
        return C_PRIM_MAP.get(tname, JacPrim.INT)
            in (JacPrim.INT, JacPrim.FLOAT, JacPrim.BOOL);
    }
    return True;
}

def _is_call_1arg(nd: c_ast.Node, fname: str) -> bool {
    if not isinstance(nd, c_ast.FuncCall) {
        return False;
    }
    if not isinstance(nd.name, c_ast.ID) or nd.name.name != fname {
        return False;
    }
    return nd.args is not None and len(nd.args.exprs) == 1;
}

def realloc_ptr_arg(nd: c_ast.Node) -> object | None {
    if not isinstance(nd, c_ast.FuncCall) {
        return None;
    }
    if not isinstance(nd.name, c_ast.ID) or nd.name.name != "realloc" {
        return None;
    }
    if nd.args is None or len(nd.args.exprs) < 1 {
        return None;
    }
    return nd.args.exprs[0];
}

def malloc_array_match(nd: c_ast.Node) -> str | None {
    if not _is_call_1arg(nd, "malloc") {
        return None;
    }
    factors: list[c_ast.Node] = [];
    flatten_mult(nd.args.exprs[0], factors);

    sizeof_name: str = "";
    have_size = False;
    others = 0;
    for f in factors {
        t = sizeof_type(f);
        if t is not None and not have_size {
            sizeof_name = t;
            have_size = True;
        } else {
            others += 1;
        }
    }
    if not have_size or others == 0 {
        return None;
    }
    if not is_listable_elem(sizeof_name) {
        return None;
    }
    return sizeof_name;
}

def malloc_struct_type(nd: c_ast.Node) -> str | None {
    if not _is_call_1arg(nd, "malloc") {
        return None;
    }
    arg = nd.args.exprs[0];
    if not isinstance(arg, c_ast.UnaryOp) or arg.op != "sizeof" {
        return None;
    }
    inner = arg.expr;
    if isinstance(inner, c_ast.Typename) and isinstance(inner.type, c_ast.TypeDecl) {
        return user_type_name(inner.type.type);
    }
    if isinstance(inner, c_ast.ID) {
        return inner.name;
    }
    return None;
}

def realloc_of_list_bound(nd: c_ast.Node, list_bound: set) -> bool {
    ptr = realloc_ptr_arg(nd);
    return isinstance(ptr, c_ast.ID) and ptr.name in list_bound;
}

def ptr_realloc_elidable(decl_type: c_ast.Node) -> bool {
    chain = walk_to_typedecl(decl_type);
    if chain.kind != TypeKind.PTR {
        return False;
    }
    if is_char_ptr(chain.node) {
        return False;
    }
    inner = ptr_inner_typedecl(chain.node);
    if inner is None {
        return False;
    }
    if isinstance(inner.type, c_ast.IdentifierType) {
        names = inner.type.names or [];
        if not names {
            return False;
        }
        base = names[-1];
        if base == "void" {
            return False;
        }
        return is_listable_elem(base);
    }
    if isinstance(inner.type, c_ast.Struct) and inner.type.name {
        return True;
    }
    return user_type_name(inner.type) is not None;
}

def realloc_elidable(
    nd: c_ast.Node, list_bound: set[str], ptr_params: set[str]
) -> bool {
    ptr = realloc_ptr_arg(nd);
    if not isinstance(ptr, c_ast.ID) {
        return False;
    }
    return ptr.name in list_bound or ptr.name in ptr_params;
}
