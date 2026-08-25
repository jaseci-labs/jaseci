impl NaIRGenContextMgr._codegen_with(nd: uni.WithStmt) -> None {
    if not nd.exprs {
        if isinstance(nd.body, (list, tuple)) {
            self._codegen_body(nd.body);
        }
        return;
    }

    self._codegen_with_recursive(nd.exprs, 0, nd.body);
}

impl NaIRGenContextMgr._context_manager_class(
    expr_item: uni.ExprAsItem
) -> (str | None) {
    """The native layout whose `__enter__` / `__exit__` a `with` item runs.

    The manager's class comes from the checker's type on the expression. A
    manager whose type the checker did not resolve is an upstream bug and
    raises; a resolved class with no native layout is the one E5092 here.
    """;
    _t = self._tb_solve(self._flow_narrowed_type_of(expr_item.expr));
    _payload = self._tb_opt_payload(_t);
    if _payload is not None {
        _t = self._tb_solve(_payload);
    }
    _name = self._tb_class_name(_t);
    if _name is None {
        raise AssertionError(
            f"`with` item at {expr_item.expr.loc} is typed {_t} ({self._tb_kind(
                _t
            )}), which names no class"
        );
    }
    if self._tb_kind(_t) in ("file", "binary_file") {
        self._emit_file_helpers();
        if self._tb_kind(_t) == "binary_file" {
            self._emit_binary_file_helpers();
        }
    } else {
        self._lower_type(_t);
    }
    if _name not in self.struct_types {
        self.emit(
            E5092,
            node_override=expr_item.expr,
            kind="context manager",
            name=_name,
            help_text="The manager's class has no native layout visible to this unit, so its `__enter__` / `__exit__` cannot be called natively."
        );
        return None;
    }
    return _name;
}

impl NaIRGenContextMgr._codegen_with_recursive(
    exprs: object, idx: int, body: object
) -> None {
    if idx >= len(exprs) {
        if isinstance(body, (list, tuple)) {
            self._codegen_body(body);
        }
        return;
    }
    expr_item = exprs[idx];
    i8p = ir.IntType(8).as_pointer();
    func = self.builder.function;

    type_name = self._context_manager_class(expr_item);
    if type_name is None {
        return;
    }
    enter_owner = self._resolve_method_owner(type_name, "__enter__");
    exit_owner = self._resolve_method_owner(type_name, "__exit__");
    enter_fn = self._resolve_method(type_name, "__enter__");
    exit_fn = self._resolve_method(type_name, "__exit__");
    if enter_fn is None or exit_fn is None {
        self.emit(
            E5092,
            node_override=expr_item.expr,
            kind="context manager",
            name=type_name,
            help_text=(
                f"`with` needs native `__enter__` and `__exit__` methods on the manager; "
                f"'{type_name}' resolves __enter__ to {enter_owner} and __exit__ to {exit_owner}, "
                f"and at least one has no native lowering."
            )
        );
        return;
    }

    cm_val = self._codegen_expr(expr_item.expr);
    if cm_val is None {
        return;
    }
    cm_val = self._opt_unwrap_attr(cm_val);
    _cm_t = self._expr_type_of(expr_item.expr);
    _cm_pl = self._tb_opt_payload(_cm_t);
    if _cm_pl is not None {
        _cm_t = _cm_pl;
    }
    if _cm_t is None {
        _cm_t = self._flow_narrowed_type_of(expr_item.expr);
    }

    enter_args: list[ir.Value] = [
        self._coerce_type(cm_val, enter_fn.args[0].type, _cm_t)
    ];
    enter_result = self.builder.call(enter_fn, enter_args, name="cm.enter");

    if expr_item.alias is not None {
        alias_name = self._get_name(expr_item.alias);
        if alias_name is not None {
            _alias_t = self._lower_type(expr_item.alias.type);
            if _alias_t is None {
                raise AssertionError(
                    f"`with ... as {alias_name}` at {expr_item.alias.loc} has no lowerable type ({expr_item.alias.type})"
                );
            }
            _bound = self._coerce_type(enter_result, _alias_t, expr_item.alias.type);
            alloca = self._entry_alloca(_alias_t, alias_name);

            if isinstance(_alias_t, ir.PointerType) {
                self.builder.store(ir.Constant(_alias_t, None), alloca);
                self._emit_rc_retain(
                    _bound, op="ctx_enter", loc=getattr(enter_result, 'jac_loc', '')
                );
            }
            self.builder.store(_bound, alloca);
            self.local_vars[alias_name] = alloca;
        }
    }

    body_bb = func.append_basic_block(name=f"with.body.{idx}");
    exit_bb = func.append_basic_block(name=f"with.exit.{idx}");
    merge_bb = func.append_basic_block(name=f"with.merge.{idx}");
    self.builder.branch(body_bb);

    self.builder.position_at_end(body_bb);
    self._codegen_with_recursive(exprs, idx + 1, body);
    if not self.builder.block.is_terminated {
        self.builder.branch(exit_bb);
    }

    self.builder.position_at_end(exit_bb);

    null_ptr = ir.Constant(i8p, None);
    exit_args: list[ir.Value] = [
        self._coerce_type(cm_val, exit_fn.args[0].type, _cm_t)
    ];
    for i in range(1, len(exit_fn.args)) {
        _exit_pt = exit_fn.args[i].type;
        if self?.jacval_type and _exit_pt == self.jacval_type {
            exit_args.append(self._jacval_none());
        } else {
            exit_args.append(self._coerce_type(null_ptr, _exit_pt));
        }
    }
    self.builder.call(exit_fn, exit_args, name="cm.exit");
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
}
