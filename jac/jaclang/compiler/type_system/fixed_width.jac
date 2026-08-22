import from jaclang.jac0core.unitree { Expr, FuncCall, Name, UniNode }
import from jaclang.jac0core.const_fold { fold_const }
import from jaclang.jac0core.constant { TOKEN_MAP }
import from jaclang.jac0core.diagnostics { E1126, E1127, E1128 }
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY, NumericKind }
import from .types { ClassType, TypeBase, UnionType, UnknownType }
import type from .type_evaluator { TypeEvaluator }

obj AssignVerdict {
    has ok: bool,
        diagnosed: bool = False;
}

def numeric_name_of(t: TypeBase | None) -> str | None {
    if not isinstance(t, ClassType) or not t.is_builtin() or not t.is_instance() {
        return None;
    }
    name = t.shared.class_name;
    return name if JAC_TYPE_REGISTRY.is_numeric(name) else None;
}

def folded_number(expr: UniNode | None) -> int | float | None {
    (ok, value) = fold_const(expr);
    if not ok or isinstance(value, bool) or not isinstance(value, (int, float)) {
        return None;
    }
    return value;
}

def _numeric_dest(evaluator: TypeEvaluator, dest: TypeBase) -> ClassType | None {
    if isinstance(dest, UnionType) {
        members = [
            m
            for m in dest.types
            if numeric_name_of(m) is not None
        ];
        if len(members) != 1 {
            return None;
        }
        dest = members[0];
    }
    inst = evaluator._convert_to_instance(dest);
    if isinstance(inst, ClassType) and numeric_name_of(inst) is not None {
        return inst;
    }
    return None;
}

def annotate_coercion(expr: Expr | None, target: TypeBase) {
    if expr is not None {
        expr.coerce_to = target;
    }
}

def adopt_literal(
    evaluator: TypeEvaluator, expr: Expr, value: int | float, target: ClassType
) -> AssignVerdict {
    name = target.shared.class_name;
    if JAC_TYPE_REGISTRY.literal_fits(name, value) {
        annotate_coercion(expr, target);
        return AssignVerdict(ok=True);
    }
    if isinstance(value, float) {
        return AssignVerdict(ok=False);
    }
    (lo, hi) = JAC_TYPE_REGISTRY.range_of(name);
    evaluator.emit_diag(E1126, expr, value=value, type=name, min=lo, max=hi);
    return AssignVerdict(ok=False, diagnosed=True);
}

def assign_numeric_expr(
    evaluator: TypeEvaluator, expr: Expr | None, src: TypeBase, dest: TypeBase
) -> AssignVerdict | None {
    dest_inst = _numeric_dest(evaluator, dest);
    if dest_inst is None {
        return None;
    }
    dn = dest_inst.shared.class_name;
    dest_sized = JAC_TYPE_REGISTRY.is_sized(dn);
    if expr is not None and dest_sized {
        value = folded_number(expr);
        if value is not None {
            verdict = adopt_literal(evaluator, expr, value, dest_inst);
            if verdict.ok or verdict.diagnosed {
                return verdict;
            }
        }
    }
    sn = numeric_name_of(src);
    if sn is None {
        return None;
    }
    if JAC_TYPE_REGISTRY.widens_to(sn, dn) {
        if sn != dn {
            annotate_coercion(expr, dest_inst);
        }
        return AssignVerdict(ok=True);
    }
    if not (dest_sized or JAC_TYPE_REGISTRY.is_sized(sn)) {
        return None;
    }
    if JAC_TYPE_REGISTRY.numeric_kind_of(sn) == NumericKind.FloatKind
        and JAC_TYPE_REGISTRY.numeric_kind_of(dn) == NumericKind.IntKind {
        return None;
    }
    if expr is not None {
        evaluator.emit_diag(E1127, expr, src=sn, dest=dn);
        return AssignVerdict(ok=False, diagnosed=True);
    }
    return AssignVerdict(ok=False);
}

def unify_numeric_operands(
    evaluator: TypeEvaluator,
    left_type: TypeBase,
    right_type: TypeBase,
    left_node: Expr | None,
    right_node: Expr | None,
    diag_node: UniNode,
    op: str
) -> TypeBase | None {
    ln = numeric_name_of(left_type);
    rn = numeric_name_of(right_type);
    if (
        ln is None
        or rn is None
        or not isinstance(left_type, ClassType)
        or not isinstance(right_type, ClassType)
    ) {
        return None;
    }
    left_inst: ClassType = left_type;
    right_inst: ClassType = right_type;
    if JAC_TYPE_REGISTRY.is_sized(rn)
        and not JAC_TYPE_REGISTRY.is_sized(ln)
        and left_node is not None {
        value = folded_number(left_node);
        if value is not None {
            verdict = adopt_literal(evaluator, left_node, value, right_inst);
            if verdict.diagnosed {
                return None;
            }
            if verdict.ok {
                return right_inst;
            }
        }
    }
    if JAC_TYPE_REGISTRY.is_sized(ln)
        and not JAC_TYPE_REGISTRY.is_sized(rn)
        and right_node is not None {
        value = folded_number(right_node);
        if value is not None {
            verdict = adopt_literal(evaluator, right_node, value, left_inst);
            if verdict.diagnosed {
                return None;
            }
            if verdict.ok {
                return left_inst;
            }
        }
    }
    unified = JAC_TYPE_REGISTRY.unify(ln, rn);
    if unified is None {
        evaluator.emit_diag(
            E1128, diag_node, op=TOKEN_MAP.get(op, op), left=ln, right=rn
        );
        return None;
    }
    if unified == ln {
        if rn != ln {
            annotate_coercion(right_node, left_inst);
        }
        return left_inst;
    }
    annotate_coercion(left_node, right_inst);
    return right_inst;
}

def both_numeric(left_type: TypeBase, right_type: TypeBase) -> bool {
    return numeric_name_of(left_type) is not None
        and numeric_name_of(right_type) is not None;
}

def is_unsigned_type(t: TypeBase | None) -> bool {
    name = numeric_name_of(t);
    if name is None {
        return False;
    }
    `entry = JAC_TYPE_REGISTRY.get(name);
    return `entry is not None
        and `entry.sized
        and not `entry.is_float
        and not `entry.signed;
}

glob WRAPPING_BINARY_BUILTINS: tuple = (
         "wrapping_add",
         "wrapping_sub",
         "wrapping_mul",
         "wrapping_shl"
     ),
     WRAPPING_UNARY_BUILTINS: tuple = ("wrapping_neg", );

def _is_jac_builtin_fn(evaluator: TypeEvaluator, callee: Expr, name: str) -> bool {
    if not isinstance(callee, Name) or callee.sym_name != name {
        return False;
    }
    stub_sym = evaluator.jac_builtins_module.names_in_scope.get(name);
    return stub_sym is not None and callee.sym is stub_sym;
}

def fixed_width_call_type(
    evaluator: TypeEvaluator, call: FuncCall, callee_type: TypeBase
) -> TypeBase | None {
    args = [
        a
        for a in (call.params or [])
        if isinstance(a, Expr)
    ];
    if len(args) != len(call.params or []) {
        return None;
    }
    if (
        isinstance(callee_type, ClassType)
        and callee_type.is_builtin()
        and not callee_type.is_instance()
        and JAC_TYPE_REGISTRY.is_sized(callee_type.shared.class_name)
        and len(args) == 1
    ) {
        arg_type = evaluator.get_type_of_expression(args[0]);
        if numeric_name_of(arg_type) is None {
            return None;
        }
        target = evaluator._convert_to_instance(callee_type);
        value = folded_number(args[0]);
        if isinstance(target, ClassType)
            and value is not None
            and isinstance(value, int) {
            adopt_literal(evaluator, args[0], value, target);
        }
        return target;
    }
    callee = call.target;
    for name in WRAPPING_BINARY_BUILTINS {
        if _is_jac_builtin_fn(evaluator, callee, name) and len(args) == 2 {
            left_type = evaluator.get_type_of_expression(args[0]);
            right_type = evaluator.get_type_of_expression(args[1]);
            if not both_numeric(left_type, right_type) {
                return None;
            }
            unified = unify_numeric_operands(
                evaluator, left_type, right_type, args[0], args[1], call, name
            );
            if unified is None {
                return UnknownType(is_diagnosed=True);
            }
            if JAC_TYPE_REGISTRY.is_sized(numeric_name_of(unified) or "") {
                return unified;
            }
            return None;
        }
    }
    for name in WRAPPING_UNARY_BUILTINS {
        if _is_jac_builtin_fn(evaluator, callee, name) and len(args) == 1 {
            operand_type = evaluator.get_type_of_expression(args[0]);
            operand = numeric_name_of(operand_type);
            if operand is not None and JAC_TYPE_REGISTRY.is_sized(operand) {
                return operand_type;
            }
            return None;
        }
    }
    return None;
}
