import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { EdgeDir, Tokens as Tok }
import from jaclang.compiler.passes.compose { kotlin_ast as kt }
import from jaclang.compiler.passes.ecmascript.intent.detection { assignment_kt_op }
import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }

glob _JAC_ARITH_RT: dict[str, str] = {
         Tok.DIV.name: 'truediv',
         Tok.FLOOR_DIV.name: 'floorDiv',
         Tok.MOD.name: 'mod'
     },
     _KT_KEYWORDS: set[str] = {
         'as',
         'break',
         'class',
         'continue',
         'do',
         'else',
         'false',
         'for',
         'fun',
         'if',
         'in',
         'interface',
         'is',
         'null',
         'object',
         'return',
         'super',
         'this',
         'throw',
         'true',
         'try',
         'typeof',
         'val',
         'var',
         'when',
         'while'
     },
     _JAC_BINARY_OPS: dict[str, str] = {
         Tok.EE.name: '==',
         Tok.NE.name: '!=',
         Tok.LT.name: '<',
         Tok.GT.name: '>',
         Tok.LTE.name: '<=',
         Tok.GTE.name: '>=',
         Tok.PLUS.name: '+',
         Tok.MINUS.name: '-',
         Tok.STAR_MUL.name: '*',
         Tok.BW_AND.name: 'and',
         Tok.BW_OR.name: 'or',
         Tok.BW_XOR.name: 'xor',
         Tok.LSHIFT.name: 'shl',
         Tok.RSHIFT.name: 'shr',
         Tok.KW_IN.name: 'in'
     },
     _JAC_LOGICAL_OPS: dict[str, str] = {Tok.KW_AND.name: '&&', Tok.KW_OR.name: '||'},
     _JAC_UNARY_OPS: dict[str, str] = {
         Tok.MINUS.name: '-',
         Tok.PLUS.name: '+',
         Tok.NOT.name: '!'
     },
     _BINARY_INFIX_FUN: set[str] = {'and', 'or', 'xor', 'shl', 'shr'};

def _kt_id(name: str) -> str {
    if name in _KT_KEYWORDS {
        return f"`{name}`";
    }
    return name;
}

def _op_name(nd: (uni.Token | None)) -> (str | None) {
    if nd is None {
        return None;
    }
    return nd?.name;
}

def _unsupported(message: str) -> kt.KtRaw {
    return kt.KtRaw(code=f"/* {message} */");
}

def _jac_math_call(
    method: str, left: (kt.KtNode | None), right: (kt.KtNode | None)
) -> kt.KtNode {
    args: list[kt.KtNode] = [];
    if left is not None {
        args.append(left);
    }
    if right is not None {
        args.append(right);
    }
    return kt.KtCall(
        callee=kt.KtMemberAccess(
            object=kt.KtIdentifier(name="JacMath"),
            property=kt.KtIdentifier(name=method)
        ),
        args=args
    );
}

def _typography_style(prop_name: str) -> kt.KtMemberAccess {
    return kt.KtMemberAccess(
        object=kt.KtMemberAccess(
            object=kt.KtIdentifier(name="MaterialTheme"),
            property=kt.KtIdentifier(name="typography")
        ),
        property=kt.KtIdentifier(name=_kt_id(prop_name))
    );
}

def _string_value(nd: uni.String) -> str {
    raw: str | bytes = nd.lit_value;
    if isinstance(raw, bytes) {
        return raw.decode('utf-8', 'surrogateescape');
    }
    return raw;
}

def _map_entries(
    pairs: list[tuple[kt.KtNode, kt.KtNode]]
) -> list[(kt.KtNode, kt.KtNode)] {
    raw: any = pairs;
    return raw;
}

impl JacToKotlin.lower_state_read(name: str) -> kt.KtNode {
    return kt.KtIdentifier(name=_kt_id(name));
}

impl JacToKotlin.convert_expr(nd: (uni.UniNode | None)) -> (kt.KtNode | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, uni.String) {
        return kt.KtLiteral(value=_string_value(nd));
    }
    if isinstance(nd, uni.Int) {
        return kt.KtLiteral(value=nd.lit_value);
    }
    if isinstance(nd, uni.Float) {
        return kt.KtLiteral(value=nd.lit_value);
    }
    if isinstance(nd, uni.Bool) {
        return kt.KtLiteral(value=nd.lit_value);
    }
    if isinstance(nd, uni.Null) {
        return kt.KtLiteral(value=None);
    }
    if isinstance(nd, uni.Name) or isinstance(nd, uni.SpecialVarRef) {
        if self.walker_mode and nd.sym_name == "here" {
            return kt.KtIdentifier(name="here");
        }
        if self.walker_mode and nd.sym_name == "root" {
            return kt.KtMemberAccess(
                object=kt.KtIdentifier(name="JacGraph"),
                property=kt.KtIdentifier(name="root")
            );
        }
        if nd.sym_name in self.reactive_vars {
            return self.lower_state_read(nd.sym_name);
        }
        if nd.sym_name == 'self' {
            return kt.KtIdentifier(name='this');
        }
        name_map = {'None': 'null', 'True': 'true', 'False': 'false'};
        return kt.KtIdentifier(name=_kt_id(name_map.get(nd.sym_name, nd.sym_name)));
    }
    if isinstance(nd, uni.AtomUnit) {
        return self.convert_expr(nd.value);
    }
    if isinstance(nd, uni.MultiString) {
        parts: list[str | kt.KtNode] = [];
        for segment in nd.strings {
            if isinstance(segment, uni.String) {
                parts.append(_string_value(segment));
            } elif isinstance(segment, uni.FString) {
                inner = self.convert_expr(segment);
                if inner {
                    parts.append(inner);
                }
            }
        }
        return kt.KtStringTemplate(parts=parts);
    }
    if isinstance(nd, uni.FString) {
        parts: list[str | kt.KtNode] = [];
        for segment in nd.parts {
            if isinstance(segment, uni.String) {
                parts.append(_string_value(segment));
            } elif isinstance(segment, uni.FormattedValue) {
                inner = self.convert_expr(segment.format_part);
                if inner {
                    parts.append(inner);
                }
            }
        }
        return kt.KtStringTemplate(parts=parts);
    }
    if isinstance(nd, uni.IfElseExpr) {
        return kt.KtConditional(
            `test=self.convert_expr(nd.condition),
            consequent=self.convert_expr(nd.value),
            alternate=self.convert_expr(nd.else_value)
        );
    }
    if isinstance(nd, uni.ListVal) {
        elems: list[kt.KtNode] = [];
        for item in (nd.values or []) {
            converted = self.convert_expr(item);
            if converted {
                elems.append(converted);
            }
        }
        return kt.KtListLiteral(elements=elems);
    }
    if isinstance(nd, uni.DictVal) {
        entries: list[tuple[kt.KtNode, kt.KtNode]] = [];
        for pair in (nd.kv_pairs or []) {
            key = self.convert_expr(pair.key);
            val = self.convert_expr(pair.value);
            if key and val {
                entries.append((key, val));
            }
        }
        return kt.KtMapLiteral(entries=_map_entries(entries));
    }
    if isinstance(nd, uni.LambdaExpr) {
        params: list[str] = [];
        for p in (nd.signature.params if nd.signature else []) {
            if isinstance(p, uni.ParamVar) {
                params.append(_kt_id(p.name.sym_name));
            }
        }
        body_nodes = self._lambda_body(nd);
        if len(body_nodes) == 1 and isinstance(body_nodes[0], kt.KtReturn) {
            return kt.KtLambda(params=params, expression_body=body_nodes[0].argument);
        }
        return kt.KtLambda(params=params, body=body_nodes);
    }
    if isinstance(nd, uni.FuncCall) {
        callee = self.convert_expr(nd.target);
        args: list[kt.KtNode] = [];
        named: list[kt.KtNamedArg] = [];
        for param in (nd.params or []) {
            if isinstance(param, uni.KWPair) {
                arg_key = param.key.sym_name
                    if isinstance(param.key, uni.Name)
                    else str(param.key);
                val = self.convert_expr(param.value);
                if val {
                    named.append(kt.KtNamedArg(name=arg_key, value=val));
                }
            } else {
                converted = self.convert_expr(param);
                if converted {
                    args.append(converted);
                }
            }
        }
        return kt.KtCall(callee=callee, args=args, named_args=named);
    }
    if isinstance(nd, uni.AtomTrailer) {
        if isinstance(nd.right, uni.EdgeRefTrailer) {
            edge_kt = self._convert_edge_ref(nd.right);
            if edge_kt is not None {
                return edge_kt;
            }
        }
        if isinstance(nd.right, uni.FilterCompr) {
            edge_ref = self._edge_ref_trailer_from(nd.target);
            if edge_ref is not None {
                edge_kt = self._convert_edge_ref(edge_ref, nd.right);
                if edge_kt is not None {
                    return edge_kt;
                }
            }
        }
        base = self.convert_expr(nd.target);
        if nd.right is None {
            return base;
        }
        if isinstance(nd.right, uni.Name) {
            prop_name = nd.right.sym_name;
            if prop_name == "dp" {
                base_lit = self.convert_expr(nd.target);
                if isinstance(base_lit, kt.KtLiteral)
                    and isinstance(base_lit.value, (int, float)) {
                    return kt.KtMemberAccess(
                        object=base_lit, property=kt.KtIdentifier(name="dp")
                    );
                }
            }
            if prop_name == "len" {
                return kt.KtMemberAccess(
                    object=base, property=kt.KtIdentifier(name="size"), computed=False
                );
            }
            base = self.convert_expr(nd.target);
            if isinstance(base, kt.KtIdentifier) and base.name == "Typography" {
                return _typography_style(prop_name);
            }
            return kt.KtMemberAccess(
                object=base,
                property=kt.KtIdentifier(name=_kt_id(prop_name)),
                computed=False
            );
        }
        if isinstance(nd.right, uni.IndexSlice) {
            idx_info = nd.right;
            if idx_info.slices and len(idx_info.slices) > 0 {
                first = idx_info.slices[0];
                if idx_info.is_range {
                    start = self.convert_expr(first.start)
                        if first.start
                        else kt.KtLiteral(value=0);
                    stop = self.convert_expr(first.stop) if first.stop else None;
                    slice_args: list[kt.KtNode] = [start] if start else [];
                    if stop {
                        slice_args.append(stop);
                    }
                    return kt.KtCall(
                        callee=kt.KtMemberAccess(
                            object=base, property=kt.KtIdentifier(name="slice")
                        ),
                        args=slice_args
                    );
                }
                idx = self.convert_expr(first.start)
                    if first.start
                    else kt.KtLiteral(value=0);
                return kt.KtMemberAccess(object=base, property=idx, computed=True);
            }
        }
        if isinstance(nd.right, uni.FuncCall) {
            args: list[kt.KtNode] = [];
            named: list[kt.KtNamedArg] = [];
            for param in (nd.right.params or []) {
                if isinstance(param, uni.KWPair) {
                    arg_key = param.key.sym_name
                        if isinstance(param.key, uni.Name)
                        else str(param.key);
                    val = self.convert_expr(param.value);
                    if val {
                        named.append(kt.KtNamedArg(name=arg_key, value=val));
                    }
                } else {
                    converted = self.convert_expr(param);
                    if converted {
                        args.append(converted);
                    }
                }
            }
            return kt.KtCall(callee=base, args=args, named_args=named);
        }
        return self.convert_expr(nd.right);
    }
    if isinstance(nd, uni.BinaryExpr) {
        if isinstance(nd.op, uni.ConnectOp) {
            connect_kt = self._convert_connect(nd);
            if connect_kt is not None {
                return connect_kt;
            }
        }
        op_tok = nd.op if isinstance(nd.op, uni.Token) else None;
        op_key = _op_name(op_tok);
        if op_key == Tok.KW_SPAWN.name {
            spawn_kt = self._convert_spawn(nd);
            if spawn_kt is not None {
                return spawn_kt;
            }
        }
        left = self.convert_expr(nd.left);
        right = self.convert_expr(nd.right);
        op_key = _op_name(op_tok);
        if op_key and op_key in _JAC_LOGICAL_OPS {
            return kt.KtBinary(
                operator=_JAC_LOGICAL_OPS[op_key], left=left, right=right
            );
        }
        if op_key and op_key in _JAC_ARITH_RT {
            return _jac_math_call(_JAC_ARITH_RT[op_key], left, right);
        }
        if not op_key or op_key not in _JAC_BINARY_OPS {
            self.diagnostics.append(
                f"jac_to_kotlin: unsupported binary operator {op_key}"
            );
            return _unsupported(f"unsupported operator {op_key}");
        }
        op = _JAC_BINARY_OPS[op_key];
        infix_fun = op in _BINARY_INFIX_FUN;
        return kt.KtBinary(operator=op, left=left, right=right, infix_fun=infix_fun);
    }
    if isinstance(nd, uni.BoolExpr) {
        result: (kt.KtNode | None) = None;
        for (i, val) in enumerate(nd.values or []) {
            converted = self.convert_expr(val);
            if converted is None {
                continue;
            }
            if result is None {
                result = converted;
            } else {
                op = '&&' if nd.op.name == Tok.KW_AND.name else '||';
                result = kt.KtBinary(operator=op, left=result, right=converted);
            }
        }
        return result;
    }
    if isinstance(nd, uni.UnaryExpr) {
        op_key = _op_name(nd.op);
        arg = self.convert_expr(nd.operand);
        if op_key == Tok.BW_NOT.name {
            return kt.KtCall(
                callee=kt.KtMemberAccess(
                    object=arg, property=kt.KtIdentifier(name="inv")
                ),
                args=[]
            );
        }
        if not op_key or op_key not in _JAC_UNARY_OPS {
            self.diagnostics.append(
                f"jac_to_kotlin: unsupported unary operator {op_key}"
            );
            return _unsupported(f"unsupported unary {op_key}");
        }
        op = _JAC_UNARY_OPS[op_key];
        return kt.KtUnary(operator=op, argument=arg, prefix=True);
    }
    if isinstance(nd, uni.CompareExpr) {
        left = self.convert_expr(nd.left);
        acc: (kt.KtNode | None) = left;
        for (i, op_tok) in enumerate(nd.ops or []) {
            right_nd = nd.rights[i] if i < len(nd.rights or []) else None;
            right = self.convert_expr(right_nd);
            op_key = _op_name(op_tok);
            if not op_key or op_key not in _JAC_BINARY_OPS {
                self.diagnostics.append(
                    f"jac_to_kotlin: unsupported comparison operator {op_key}"
                );
                return _unsupported(f"unsupported operator {op_key}");
            }
            op = _JAC_BINARY_OPS[op_key];
            infix_fun = op in _BINARY_INFIX_FUN;
            acc = kt.KtBinary(operator=op, left=acc, right=right, infix_fun=infix_fun);
        }
        return acc;
    }
    if isinstance(nd, uni.CastExpr) {
        return self.convert_expr(nd.value);
    }
    if isinstance(nd, uni.AwaitExpr) {
        return self.convert_expr(nd.target);
    }
    if isinstance(nd, uni.EdgeRefTrailer) {
        edge_kt = self._convert_edge_ref(nd);
        if edge_kt is not None {
            return edge_kt;
        }
    }
    self.diagnostics.append(
        f"jac_to_kotlin: unsupported expression {type(nd).__name__}"
    );
    return _unsupported(f"unsupported {type(nd).__name__}");
}

impl JacToKotlin._lambda_body(nd: uni.LambdaExpr) -> list[kt.KtNode] {
    inner: any = nd.body;
    if isinstance(inner, uni.ImplDef) {
        inner = inner.body;
    }
    if not isinstance(inner, list) {
        expr = self.convert_expr(inner);
        if expr {
            return [kt.KtReturn(argument=expr)];
        }
        return [];
    }
    return self.convert_stmts(inner);
}

impl JacToKotlin.convert_stmt(nd: (uni.UniNode | None)) -> (kt.KtNode | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, uni.ExprStmt) {
        expr = self.convert_expr(nd.expr);
        return expr;
    }
    if isinstance(nd, uni.ReturnStmt) {
        return kt.KtReturn(argument=self.convert_expr(nd.expr));
    }
    if isinstance(nd, uni.Assignment) {
        if len(nd.target) != 1 or not isinstance(nd.target[0], uni.Name) {
            return _unsupported("multi-target assignment");
        }
        name = nd.target[0].sym_name;

        if (name in self.reactive_vars) or (nd.aug_op and nd.aug_op.name) {
            return kt.KtAssignment(
                operator=assignment_kt_op(nd),
                left=kt.KtIdentifier(name=_kt_id(name)),
                right=self.convert_expr(nd.value)
            );
        }
        if name in self.declared_locals {
            return kt.KtAssignment(
                operator='=',
                left=kt.KtIdentifier(name=_kt_id(name)),
                right=self.convert_expr(nd.value)
            );
        }
        self.declared_locals.add(name);
        return kt.KtProperty(
            name=_kt_id(name),
            mutable=(name in self._mutable_locals),
            init=self.convert_expr(nd.value)
        );
    }
    if isinstance(nd, uni.IfStmt) {
        cons = self.convert_stmts(list(nd.body));
        alt: list[kt.KtNode] = [];
        if nd.else_body and isinstance(nd.else_body, uni.ElseStmt) {
            alt = self.convert_stmts(list(nd.else_body.body));
        }
        return kt.KtIf(
            `test=self.convert_expr(nd.condition), consequent=cons, alternate=alt
        );
    }
    if isinstance(nd, uni.WhileStmt) {
        return kt.KtWhile(
            `test=self.convert_expr(nd.condition),
            body=self.convert_stmts(list(nd.body))
        );
    }
    if isinstance(nd, uni.InForStmt) {
        target = 'it';
        if nd.target and isinstance(nd.target, uni.Name) {
            target = _kt_id(nd.target.sym_name);
        }
        return kt.KtFor(
            variable=target,
            iterable=self.convert_expr(nd.collection),
            body=self.convert_stmts(list(nd.body))
        );
    }
    if isinstance(nd, uni.TryStmt) {
        try_body = self.convert_stmts(list(nd.body));
        catch_body: list[kt.KtNode] = [];
        for handler in (nd.excepts or []) {
            catch_body.extend(self.convert_stmts(list(handler.body)));
        }
        return kt.KtTry(try_body=try_body, catch_param='e', catch_body=catch_body);
    }
    if isinstance(nd, uni.DeleteStmt) {
        if not self.walker_mode {
            self.diagnostics.append("jac_to_kotlin: del is only supported in walker bodies");
            return None;
        }
        del_expr = self.convert_expr(nd.target);
        del_args: list[kt.KtNode] = [];
        if del_expr is not None {
            del_args.append(del_expr);
        }
        return kt.KtCall(
            callee=kt.KtMemberAccess(
                object=kt.KtIdentifier(name="JacGraph"),
                property=kt.KtIdentifier(name="delete")
            ),
            args=del_args
        );
    }
    if isinstance(nd, uni.ReportStmt) {
        if not self.walker_mode {
            self.diagnostics.append(
                "jac_to_kotlin: report is only supported in walker bodies"
            );
            return None;
        }
        expr = self.convert_expr(nd.expr);
        return kt.KtCall(
            callee=kt.KtIdentifier(name="report"),
            args=[expr] if expr else []
        );
    }
    if isinstance(nd, uni.VisitStmt) {
        self.diagnostics.append("sv_lower: visit is not supported in Phase 2");
        return None;
    }
    if isinstance(nd, uni.DisengageStmt) {
        self.diagnostics.append("sv_lower: disengage is not supported in Phase 2");
        return None;
    }
    self.diagnostics.append(
        f"jac_to_kotlin: unsupported statement {type(nd).__name__}"
    );
    return None;
}

impl JacToKotlin.convert_stmts(body: (list[uni.UniNode] | None)) -> list[kt.KtNode] {
    result: list[kt.KtNode] = [];
    if not body {
        return result;
    }
    saved_locals = set(self.declared_locals);
    saved_mutable = set(self._mutable_locals);
    self._mutable_locals = self._compute_mutable_locals(body);
    for stmt in body {
        converted = self.convert_stmt(stmt);
        if converted is None {
            continue;
        }
        if isinstance(converted, kt.KtBlock) {
            for item in converted.body {
                result.append(item);
            }
        } else {
            result.append(converted);
        }
    }
    self.declared_locals = saved_locals;
    self._mutable_locals = saved_mutable;
    return result;
}

impl JacToKotlin._compute_mutable_locals(body: (list[uni.UniNode] | None)) -> set[str] {
    counts: dict[str, int] = {};
    for stmt in (body or []) {
        self._count_assign_targets(stmt, counts);
    }
    result: set[str] = set();
    for (name, count) in counts.items() {
        if count >= 2 {
            result.add(name);
        }
    }
    return result;
}

impl JacToKotlin._count_assign_targets(
    nd: (uni.UniNode | None), counts: dict[str, int]
) -> None {
    if nd is None {
        return;
    }
    targets: list[uni.UniNode] = [];
    if isinstance(nd, uni.Assignment) {
        targets = list(nd.target or []);
    }
    for tgt in targets {
        if isinstance(tgt, uni.Name) {
            name = tgt.sym_name;
            counts[name] = counts.get(name, 0) + 1;
        }
    }
    for sub in nd.get_all_sub_nodes(uni.Assignment) {
        for tgt in (sub.target or []) {
            if isinstance(tgt, uni.Name) {
                name = tgt.sym_name;
                counts[name] = counts.get(name, 0) + 1;
            }
        }
    }
}

impl jac_expr_to_kt(
    nd: (uni.UniNode | None), reactive_vars: set[str] = {}
) -> (kt.KtNode | None) {
    lowerer = JacToKotlin(reactive_vars=reactive_vars);
    return lowerer.convert_expr(nd);
}

impl jac_stmts_to_kt(
    body: (list[uni.UniNode] | None), reactive_vars: set[str] = {}
) -> list[kt.KtNode] {
    lowerer = JacToKotlin(reactive_vars=reactive_vars);
    return lowerer.convert_stmts(body);
}

impl JacToKotlin._is_root_reference(expr: uni.Expr) -> bool {
    if isinstance(expr, uni.Name) and expr.sym_name == 'root' {
        return True;
    }
    return bool(isinstance(expr, uni.SpecialVarRef) and expr.sym_name == 'root');
}

impl JacToKotlin._spawn_request_named_args(call: uni.FuncCall) -> list[kt.KtNamedArg] {
    named: list[kt.KtNamedArg] = [];
    for param in (call.params or []) {
        if isinstance(param, uni.KWPair) {
            key = (
                param.key.sym_name
                    if isinstance(param.key, uni.Name)
                    else str(param.key)
            );
            val = self.convert_expr(param.value);
            if val {
                named.append(kt.KtNamedArg(name=key, value=val));
            }
        }
    }
    return named;
}

impl JacToKotlin._resolve_spawn_walker(
    expr: uni.Expr
) -> (tuple[str, uni.FuncCall] | None) {
    if not isinstance(expr, uni.FuncCall) {
        return None;
    }
    cur: any = expr.target;
    while isinstance(cur, (uni.FuncCall, uni.AtomTrailer)) {
        if isinstance(cur, uni.FuncCall) {
            cur = cur.target;
        } else {
            cur = cur.target;
        }
    }
    if isinstance(cur, uni.AtomExpr) {
        return (cur.sym_name, expr);
    }
    if isinstance(cur, uni.Name) {
        return (cur.sym_name, expr);
    }
    return None;
}

impl JacToKotlin._resolve_spawn_target(expr: uni.Expr) -> (kt.KtNode | None) {
    if self._is_root_reference(expr) {
        return None;
    }
    return self.convert_expr(expr);
}

impl JacToKotlin._convert_connect(nd: uni.BinaryExpr) -> (kt.KtNode | None) {
    if not self.walker_mode {
        return None;
    }
    co = nd.op;
    if not isinstance(co, uni.ConnectOp) {
        return None;
    }
    if co.edge_dir != EdgeDir.OUT {
        self.diagnostics.append("sv_lower: only ++> (outbound connect) is supported");
        return None;
    }
    if co.conn_type is not None {
        self.diagnostics.append("sv_lower: typed-edge connect (+>:) is not supported");
        return None;
    }
    left = self.convert_expr(nd.left);
    if left is None {
        return None;
    }
    ctor = self._connect_node_ctor(nd.right, co);
    if ctor is None {
        self.diagnostics.append("sv_lower: connect RHS must be a node constructor call");
        return None;
    }
    spawned_call = kt.KtCall(
        callee=kt.KtMemberAccess(
            object=kt.KtIdentifier(name="JacGraph"),
            property=kt.KtIdentifier(name="spawnNode")
        ),
        args=[ctor]
    );
    connect_stmt = kt.KtCall(
        callee=kt.KtMemberAccess(
            object=kt.KtIdentifier(name="JacGraph"),
            property=kt.KtIdentifier(name="connect")
        ),
        args=[left, kt.KtIdentifier(name="it")]
    );
    return kt.KtCall(
        callee=kt.KtMemberAccess(
            object=spawned_call, property=kt.KtIdentifier(name="also")
        ),
        trailing_lambda=kt.KtLambda(params=["it"], expression_body=connect_stmt)
    );
}

def _edge_type_name(filt: (uni.FilterCompr | None)) -> (str | None) {
    if filt is None or filt.f_type is None {
        return None;
    }
    if isinstance(filt.f_type, uni.Name) {
        return filt.f_type.sym_name;
    }
    if isinstance(filt.f_type, uni.AtomExpr) {
        return filt.f_type.sym_name;
    }
    return None;
}

def _edge_dir_kotlin(edge_dir: EdgeDir) -> (str | None) {
    if edge_dir == EdgeDir.OUT {
        return "OUT";
    }
    if edge_dir == EdgeDir.IN {
        return "IN";
    }
    if edge_dir == EdgeDir.ANY {
        return "ANY";
    }
    return None;
}

impl JacToKotlin._edge_ref_trailer_from(target: uni.UniNode) -> (uni.EdgeRefTrailer | None) {
    if isinstance(target, uni.EdgeRefTrailer) {
        if target.edges_only or target.is_async {
            return None;
        }
        return target;
    }
    if (
        isinstance(target, uni.AtomTrailer)
        and isinstance(target.right, uni.FilterCompr)
    ) {
        return self._edge_ref_trailer_from(target.target);
    }
    return None;
}

impl JacToKotlin._convert_edge_ref(
    nd: uni.EdgeRefTrailer, trailing_filt: (uni.FilterCompr | None) = None
) -> (kt.KtNode | None) {
    if not self.walker_mode {
        return None;
    }
    chain = nd.chain or [];
    if not chain {
        self.diagnostics.append("sv_lower: empty edge reference");
        return None;
    }
    idx = 0;
    origin: (kt.KtNode | None) = None;
    if isinstance(chain[0], uni.EdgeOpRef) {
        origin = kt.KtIdentifier(name="here");
    } else {
        origin = self.convert_expr(chain[0]);
        idx = 1;
    }
    if origin is None {
        return None;
    }
    if idx >= len(chain) or not isinstance(chain[idx], uni.EdgeOpRef) {
        self.diagnostics.append("sv_lower: malformed edge reference");
        return None;
    }
    if idx + 1 < len(chain) and isinstance(chain[idx + 1], uni.EdgeOpRef) {
        self.diagnostics.append("sv_lower: multi-hop edge references are not supported");
        return None;
    }
    step = chain[idx];
    if step.edge_dir != EdgeDir.OUT {
        self.diagnostics.append("sv_lower: only outbound --> edge references are supported");
        return None;
    }
    dir_member = _edge_dir_kotlin(step.edge_dir);
    if dir_member is None {
        self.diagnostics.append("sv_lower: unsupported edge direction");
        return None;
    }
    if step.filter_cond is not None {
        self.diagnostics.append("sv_lower: edge-type filters on hops are not supported");
        return None;
    }
    filt: (uni.FilterCompr | None) = trailing_filt;
    if idx + 1 < len(chain) {
        next_item = chain[idx + 1];
        if isinstance(next_item, uni.FilterCompr) {
            filt = next_item;
        }
    }
    if filt and filt.compares {
        self.diagnostics.append("sv_lower: node predicate filters are not supported");
        return None;
    }
    type_name = _edge_type_name(filt);
    args: list[kt.KtNode] = [
        origin,
        kt.KtMemberAccess(
            object=kt.KtIdentifier(name="Dir"),
            property=kt.KtIdentifier(name=dir_member)
        )
    ];
    neighbors = kt.KtCall(
        callee=kt.KtMemberAccess(
            object=kt.KtIdentifier(name="JacGraph"),
            property=kt.KtIdentifier(name="neighbors")
        ),
        args=args
    );
    if type_name {
        return kt.KtRaw(
            code=f"{kt_to_source(neighbors)}.filterIsInstance<{type_name}>()"
        );
    }
    return neighbors;
}

def _func_call_type_name(call: uni.FuncCall) -> (str | None) {
    cur: any = call.target;
    while isinstance(cur, (uni.FuncCall, uni.AtomTrailer)) {
        if isinstance(cur, uni.FuncCall) {
            cur = cur.target;
        } else {
            cur = cur.target;
        }
    }
    if isinstance(cur, uni.AtomExpr) {
        return cur.sym_name;
    }
    if isinstance(cur, uni.Name) {
        return cur.sym_name;
    }
    return None;
}

impl JacToKotlin._connect_node_ctor(
    expr: uni.Expr, co: uni.ConnectOp
) -> (kt.KtNode | None) {
    if isinstance(expr, uni.FuncCall) {
        type_name = _func_call_type_name(expr);
        if not type_name {
            return None;
        }
        named = self._spawn_request_named_args(expr);
        return kt.KtCall(
            callee=kt.KtIdentifier(name=type_name), args=[], named_args=named
        );
    }
    if co.conn_assign is not None and co.conn_type is not None {
        type_name: (str | None) = None;
        if isinstance(co.conn_type, uni.Name) {
            type_name = co.conn_type.sym_name;
        } elif isinstance(co.conn_type, uni.AtomExpr) {
            type_name = co.conn_type.sym_name;
        }
        if not type_name {
            return None;
        }
        named: list[kt.KtNamedArg] = [];
        for pair in (co.conn_assign.assigns or []) {
            if isinstance(pair, uni.KWPair) {
                key = (
                    pair.key.sym_name
                        if isinstance(pair.key, uni.Name)
                        else str(pair.key)
                );
                val = self.convert_expr(pair.value);
                if val {
                    named.append(kt.KtNamedArg(name=key, value=val));
                }
            }
        }
        return kt.KtCall(
            callee=kt.KtIdentifier(name=type_name), args=[], named_args=named
        );
    }
    return self.convert_expr(expr);
}

impl JacToKotlin._convert_spawn(nd: uni.BinaryExpr) -> (kt.KtNode | None) {
    import from jaclang.compiler.passes.compose.rpc_client { walker_to_pascal }

    left_walker = self._resolve_spawn_walker(nd.left);
    right_walker = self._resolve_spawn_walker(nd.right);
    walker_info: (tuple[str, uni.FuncCall] | None) = None;
    target_expr: uni.Expr;
    if left_walker and right_walker {
        walker_info = right_walker;
        target_expr = nd.left;
    } elif left_walker {
        walker_info = left_walker;
        target_expr = nd.right;
    } elif right_walker {
        walker_info = right_walker;
        target_expr = nd.left;
    } else {
        return None;
    }
    (walker_name, call_node) = walker_info;
    pascal = walker_to_pascal(walker_name);
    named = self._spawn_request_named_args(call_node);
    req_call = kt.KtCall(
        callee=kt.KtIdentifier(name=f"{pascal}Request"), args=[], named_args=named
    );
    call_named: list[kt.KtNamedArg] = [];
    node_id = self._resolve_spawn_target(target_expr);
    if node_id is not None {
        call_named.append(kt.KtNamedArg(name="nodeId", value=node_id));
    }
    return kt.KtCall(
        callee=kt.KtMemberAccess(
            object=kt.KtMemberAccess(
                object=kt.KtIdentifier(name="JacBackends"),
                property=kt.KtIdentifier(name="current")
            ),
            property=kt.KtIdentifier(name=walker_name)
        ),
        args=[req_call],
        named_args=call_named
    );
}
