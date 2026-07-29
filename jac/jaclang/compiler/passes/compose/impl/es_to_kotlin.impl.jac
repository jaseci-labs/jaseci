"""estree → kotlin_ast lowering (ANDROID_COMPOSE_IMPL_SPEC §3)."""
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.compose { kotlin_ast as kt }

glob _BINARY_INFIX_FUN: set[str] = {'and', 'or', 'xor', 'shl', 'shr'};

glob _BINARY_OP_MAP: dict[str, str] = {
    '===': '==',
    '!==': '!=',
    '==': '==',
    '!=': '!=',
    '<': '<',
    '>': '>',
    '<=': '<=',
    '>=': '>=',
    '+': '+',
    '-': '-',
    '*': '*',
    '/': '/',
    '%': '%',
    '&': 'and',
    '|': 'or',
    '^': 'xor',
    '<<': 'shl',
    '>>': 'shr',
    'in': 'in'
};

glob _SUPPORTED_AUG_OPS: set[str] = {
    '=', '+=', '-=', '*=', '/=', '%='
};

def _unsupported_kt(message: str) -> kt.KtRaw {
    return kt.KtRaw(code=f"/* {message} */");
}

def _pattern_name(pattern: (es.Pattern | None)) -> str {
    if pattern is None {
        return '_';
    }
    if isinstance(pattern, es.Identifier) {
        return pattern.name;
    }
    if isinstance(pattern, es.RestElement) {
        return _pattern_name(pattern.argument);
    }
    if isinstance(pattern, es.AssignmentPattern) {
        return _pattern_name(pattern.left);
    }
    return '_';
}

impl EsToKotlin._property_key_expr(
    key: (es.Expression | es.Identifier | es.Literal | None)
) -> (kt.KtNode | None) {
    if key is None {
        return None;
    }
    if isinstance(key, es.Literal) and isinstance(key.value, str) {
        return kt.KtLiteral(value=key.value);
    }
    if isinstance(key, es.Identifier) {
        return kt.KtIdentifier(name=key.name);
    }
    return self.convert_expr(key);
}

impl EsToKotlin._convert_call_args(
    arguments: list[(es.Expression | es.SpreadElement)]
) -> list[kt.KtNode] {
    args: list[kt.KtNode] = [];
    for arg in arguments {
        if isinstance(arg, es.SpreadElement) {
            args.append(kt.KtSpread(argument=self.convert_expr(arg.argument)));
        } else {
            converted = self.convert_expr(arg);
            if converted {
                args.append(converted);
            }
        }
    }
    return args;
}

impl EsToKotlin._convert_function_params(
    params: list[es.Pattern]
) -> list[kt.KtParam] {
    result: list[kt.KtParam] = [];
    for param in params {
        name = _pattern_name(param);
        default: (kt.KtNode | None) = None;
        if isinstance(param, es.AssignmentPattern) {
            default = self.convert_expr(param.right);
        }
        result.append(kt.KtParam(name=name, default=default));
    }
    return result;
}

impl EsToKotlin._convert_lambda_params(params: list[es.Pattern]) -> list[str] {
    names: list[str] = [];
    for param in params {
        names.append(_pattern_name(param));
    }
    return names;
}

impl EsToKotlin._convert_function_body(
    body: (es.BlockStatement | es.Expression | None),
    expression: bool = False
) -> (list[kt.KtNode], (kt.KtNode | None)) {
    if body is None {
        return ([], None);
    }
    if isinstance(body, es.BlockStatement) {
        return (self.convert_stmts(body.body), None);
    }
    expr = self.convert_expr(body);
    if expression or not isinstance(body, es.BlockStatement) {
        return ([], expr);
    }
    return ([], expr);
}

impl EsToKotlin._stmt_to_nodes(nd: (es.Statement | None)) -> list[kt.KtNode] {
    if nd is None {
        return [];
    }
    if isinstance(nd, es.BlockStatement) {
        return self.convert_stmts(nd.body);
    }
    converted = self.convert_stmt(nd);
    if converted is None {
        return [];
    }
    if isinstance(converted, kt.KtBlock) {
        return converted.body;
    }
    return [converted];
}

impl EsToKotlin.convert_expr(nd: (es.Expression | None)) -> (kt.KtNode | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, es.Literal) {
        return kt.KtLiteral(value=nd.value);
    }
    if isinstance(nd, es.Identifier) {
        return kt.KtIdentifier(name=nd.name);
    }
    if isinstance(nd, es.ThisExpression) {
        return kt.KtThis();
    }
    if isinstance(nd, es.MemberExpression) {
        obj_expr = self.convert_expr(nd.object);
        prop = self.convert_expr(nd.property);
        return kt.KtMemberAccess(
            object=obj_expr,
            property=prop,
            computed=nd.computed,
            safe=nd.optional
        );
    }
    if isinstance(nd, es.CallExpression) {
        if (isinstance(nd.callee, es.Identifier)
            and nd.callee.name in ("__jacSpawn", "jacSpawn")) {
            spawn_kt = self._convert_jac_spawn(nd);
            if spawn_kt is not None {
                return spawn_kt;
            }
        }
        runtime_kt = self._convert_jac_runtime_call(nd);
        if runtime_kt is not None {
            return runtime_kt;
        }
        callee = self.convert_expr(nd.callee);
        args = self._convert_call_args(nd.arguments);
        return kt.KtCall(callee=callee, args=args, safe=nd.optional);
    }
    if isinstance(nd, es.NewExpression) {
        callee = self.convert_expr(nd.callee);
        args = self._convert_call_args(nd.arguments);
        return kt.KtCall(callee=callee, args=args);
    }
    if isinstance(nd, es.ConditionalExpression) {
        return kt.KtConditional(
            test=self.convert_expr(nd.test),
            consequent=self.convert_expr(nd.consequent),
            alternate=self.convert_expr(nd.alternate)
        );
    }
    if isinstance(nd, es.TemplateLiteral) {
        parts: list[str | kt.KtNode] = [];
        for (idx, quasi) in enumerate(nd.quasis) {
            raw = '';
            if quasi.value {
                raw = quasi.value.get('cooked') or quasi.value.get('raw') or '';
            }
            parts.append(raw);
            if idx < len(nd.expressions) {
                parts.append(self.convert_expr(nd.expressions[idx]));
            }
        }
        return kt.KtStringTemplate(parts=parts);
    }
    if isinstance(nd, es.BinaryExpression) {
        op = _BINARY_OP_MAP.get(nd.operator, nd.operator);
        infix_fun = op in _BINARY_INFIX_FUN;
        return kt.KtBinary(
            operator=op,
            left=self.convert_expr(nd.left),
            right=self.convert_expr(nd.right),
            infix_fun=infix_fun
        );
    }
    if isinstance(nd, es.LogicalExpression) {
        return kt.KtBinary(
            operator=nd.operator,
            left=self.convert_expr(nd.left),
            right=self.convert_expr(nd.right)
        );
    }
    if isinstance(nd, es.UnaryExpression) {
        if nd.operator == '~' {
            arg = self.convert_expr(nd.argument);
            inv_access = kt.KtMemberAccess(
                object=arg,
                property=kt.KtIdentifier(name='inv')
            );
            return kt.KtCall(callee=inv_access, args=[]);
        }
        return kt.KtUnary(
            operator=nd.operator,
            argument=self.convert_expr(nd.argument),
            prefix=nd.prefix
        );
    }
    if isinstance(nd, es.AssignmentExpression) {
        if nd.operator not in _SUPPORTED_AUG_OPS {
            return _unsupported_kt(
                f"unsupported assignment operator {nd.operator}"
            );
        }
        return kt.KtAssignment(
            operator=nd.operator,
            left=self.convert_expr(nd.left),
            right=self.convert_expr(nd.right)
        );
    }
    if isinstance(nd, es.AwaitExpression) {
        return self.convert_expr(nd.argument);
    }
    if isinstance(nd, es.ArrayExpression) {
        elements: list[kt.KtNode] = [];
        for el in nd.elements {
            if el is None {
                continue;
            }
            if isinstance(el, es.SpreadElement) {
                spread_arg = self.convert_expr(el.argument);
                to_typed = kt.KtMemberAccess(
                    object=spread_arg,
                    property=kt.KtIdentifier(name='toTypedArray')
                );
                elements.append(
                    kt.KtSpread(
                        argument=kt.KtCall(callee=to_typed, args=[])
                    )
                );
            } else {
                converted = self.convert_expr(el);
                if converted {
                    elements.append(converted);
                }
            }
        }
        return kt.KtListLiteral(elements=elements);
    }
    if isinstance(nd, es.ObjectExpression) {
        entries: list[(kt.KtNode, kt.KtNode)] = [];
        for prop in nd.properties {
            if isinstance(prop, es.SpreadElement) {
                entries.append(
                    (
                        _unsupported_kt('object spread unsupported'),
                        _unsupported_kt('object spread unsupported')
                    )
                );
                continue;
            }
            key_expr = self._property_key_expr(prop.key);
            if prop.shorthand and isinstance(prop.key, es.Identifier) {
                value_expr = kt.KtIdentifier(name=prop.key.name);
            } else {
                value_expr = self.convert_expr(prop.value);
            }
            if key_expr and value_expr {
                entries.append((key_expr, value_expr));
            }
        }
        return kt.KtMapLiteral(entries=entries);
    }
    if isinstance(nd, es.ArrowFunctionExpression) {
        params = self._convert_lambda_params(nd.params);
        (body_stmts, expr_body) = self._convert_function_body(
            nd.body, expression=nd.expression
        );
        return kt.KtLambda(
            params=params,
            body=body_stmts,
            expression_body=expr_body
        );
    }
    if isinstance(nd, es.FunctionExpression) {
        params = self._convert_lambda_params(nd.params);
        (body_stmts, expr_body) = self._convert_function_body(nd.body);
        return kt.KtLambda(
            params=params,
            body=body_stmts,
            expression_body=expr_body
        );
    }
    if isinstance(nd, es.JsxElement) or isinstance(nd, es.JsxFragment) {
        return _unsupported_kt('jsx unsupported in es_to_kotlin');
    }
    return _unsupported_kt(f"unsupported expression type {nd.type}");
}

impl EsToKotlin.convert_stmt(nd: (es.Statement | None)) -> (kt.KtNode | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, es.ExpressionStatement) {
        expr = self.convert_expr(nd.expression);
        if expr is None {
            return None;
        }
        return kt.KtExprStmt(expression=expr);
    }
    if isinstance(nd, es.BlockStatement) {
        return kt.KtBlock(body=self.convert_stmts(nd.body));
    }
    if isinstance(nd, es.VariableDeclaration) {
        mutable = nd.kind != 'const';
        props: list[kt.KtNode] = [];
        for decl in nd.declarations {
            if not isinstance(decl.id, es.Identifier) {
                props.append(
                    _unsupported_kt('variable declaration id must be Identifier')
                );
                continue;
            }
            props.append(
                kt.KtProperty(
                    name=decl.id.name,
                    mutable=mutable,
                    `init=self.convert_expr(decl.`init)
                )
            );
        }
        if len(props) == 1 {
            return props[0];
        }
        return kt.KtBlock(body=props);
    }
    if isinstance(nd, es.IfStatement) {
        test_kt = self.convert_expr(nd.test);
        consequent = self._stmt_to_nodes(nd.consequent);
        alternate = self._stmt_to_nodes(nd.alternate);
        # Flatten `if (true) { ... }` from rewritten _jac.exc.matches.
        if isinstance(test_kt, kt.KtLiteral) and test_kt.value is True {
            if not alternate {
                return kt.KtBlock(body=consequent);
            }
        }
        return kt.KtIf(
            test=test_kt,
            consequent=consequent,
            alternate=alternate
        );
    }
    if isinstance(nd, es.ForOfStatement) {
        var_name = '';
        if isinstance(nd.left, es.VariableDeclaration) {
            if nd.left.declarations {
                var_name = _pattern_name(nd.left.declarations[0].id);
            }
        } else {
            var_name = _pattern_name(nd.left);
        }
        return kt.KtFor(
            variable=var_name,
            iterable=self.convert_expr(nd.right),
            body=self._stmt_to_nodes(nd.body)
        );
    }
    if isinstance(nd, es.WhileStatement) {
        return kt.KtWhile(
            test=self.convert_expr(nd.test),
            body=self._stmt_to_nodes(nd.body)
        );
    }
    if isinstance(nd, es.ForStatement) {
        block_body: list[kt.KtNode] = [];
        if nd.`init {
            if isinstance(nd.`init, es.VariableDeclaration) {
                init_stmt = self.convert_stmt(nd.`init);
                if init_stmt {
                    if isinstance(init_stmt, kt.KtBlock) {
                        block_body.extend(init_stmt.body);
                    } else {
                        block_body.append(init_stmt);
                    }
                }
            } else {
                init_expr = self.convert_expr(nd.`init);
                if init_expr {
                    block_body.append(kt.KtExprStmt(expression=init_expr));
                }
            }
        }
        while_body = self._stmt_to_nodes(nd.body);
        if nd.update {
            update_expr = self.convert_expr(nd.update);
            if update_expr {
                while_body.append(kt.KtExprStmt(expression=update_expr));
            }
        }
        block_body.append(
            kt.KtWhile(
                test=self.convert_expr(nd.test),
                body=while_body
            )
        );
        return kt.KtBlock(body=block_body);
    }
    if isinstance(nd, es.ReturnStatement) {
        label: (str | None) = None;
        return kt.KtReturn(
            argument=self.convert_expr(nd.argument),
            label=label
        );
    }
    if isinstance(nd, es.TryStatement) {
        try_body: list[kt.KtNode] = [];
        if nd.block {
            try_body = self.convert_stmts(nd.block.body);
        }
        catch_param = 'e';
        catch_body: list[kt.KtNode] = [];
        if nd.handler {
            if isinstance(nd.handler.param, es.Identifier) {
                catch_param = nd.handler.param.name;
            }
            if nd.handler.body {
                catch_body = self.convert_stmts(nd.handler.body.body);
            }
        }
        finally_body: list[kt.KtNode] = [];
        if nd.finalizer {
            finally_body = self.convert_stmts(nd.finalizer.body);
        }
        return kt.KtTry(
            try_body=try_body,
            catch_param=catch_param,
            catch_body=catch_body,
            finally_body=finally_body
        );
    }
    if isinstance(nd, es.ThrowStatement) {
        return kt.KtThrow(argument=self.convert_expr(nd.argument));
    }
    if isinstance(nd, es.BreakStatement) {
        return kt.KtBreak();
    }
    if isinstance(nd, es.ContinueStatement) {
        return kt.KtContinue();
    }
    if isinstance(nd, es.SwitchStatement) {
        entries: list[kt.KtWhenEntry] = [];
        for case in nd.cases {
            test: (kt.KtNode | None) = None;
            if case.test {
                test = self.convert_expr(case.test);
            }
            entries.append(
                kt.KtWhenEntry(
                    test=test,
                    body=self.convert_stmts(case.consequent)
                )
            );
        }
        return kt.KtWhen(
            subject=self.convert_expr(nd.discriminant),
            entries=entries
        );
    }
    if isinstance(nd, es.FunctionDeclaration) {
        name = nd.id.name if nd.id else '';
        params = self._convert_function_params(nd.params);
        body_stmts: list[kt.KtNode] = [];
        if nd.body {
            body_stmts = self.convert_stmts(nd.body.body);
        }
        return kt.KtFunction(
            name=name,
            params=params,
            body=body_stmts,
            is_suspend=nd.async_
        );
    }
    if isinstance(nd, es.ClassDeclaration) {
        return _unsupported_kt('class declaration unsupported in view scope');
    }
    return _unsupported_kt(f"unsupported statement type {nd.type}");
}

impl EsToKotlin.convert_stmts(stmts: list[es.Statement]) -> list[kt.KtNode] {
    result: list[kt.KtNode] = [];
    for stmt in stmts {
        converted = self.convert_stmt(stmt);
        if converted is None {
            continue;
        }
        if isinstance(converted, kt.KtBlock) {
            result.extend(converted.body);
        } else {
            result.append(converted);
        }
    }
    return result;
}

impl EsToKotlin._object_to_named_args(
    nd: (es.Expression | None)
) -> list[kt.KtNamedArg] {
    named: list[kt.KtNamedArg] = [];
    if not isinstance(nd, es.ObjectExpression) {
        return named;
    }
    for prop in nd.properties {
        if isinstance(prop, es.SpreadElement) {
            continue;
        }
        key_name = "";
        if isinstance(prop.key, es.Identifier) {
            key_name = prop.key.name;
        } elif isinstance(prop.key, es.Literal) and isinstance(prop.key.value, str) {
            key_name = prop.key.value;
        }
        if not key_name {
            continue;
        }
        if prop.shorthand and isinstance(prop.key, es.Identifier) {
            val = kt.KtIdentifier(name=prop.key.name);
        } else {
            val = self.convert_expr(prop.value);
        }
        if val is not None {
            named.append(kt.KtNamedArg(name=key_name, value=val));
        }
    }
    return named;
}

impl EsToKotlin._convert_jac_spawn(nd: es.CallExpression) -> (kt.KtNode | None) {
    import from jaclang.compiler.passes.compose.rpc_client { walker_to_pascal }

    args = nd.arguments;
    if len(args) < 1 {
        return None;
    }
    walker_arg = args[0];
    if not (isinstance(walker_arg, es.Literal) and isinstance(walker_arg.value, str)) {
        return None;
    }
    walker_name = walker_arg.value;
    pascal = walker_to_pascal(walker_name);
    fields_expr = args[2] if len(args) > 2 else None;
    named = self._object_to_named_args(fields_expr);
    req_call = kt.KtCall(
        callee=kt.KtIdentifier(name=f"{pascal}Request"),
        args=[],
        named_args=named
    );
    node_id_arg: (kt.KtNode | None) = None;
    if len(args) > 1 {
        target = args[1];
        if isinstance(target, es.Literal) {
            if target.value not in ("", None) {
                node_id_arg = self.convert_expr(target);
            }
        } else {
            node_id_arg = self.convert_expr(target);
        }
    }
    call_named: list[kt.KtNamedArg] = [];
    call_args: list[kt.KtNode] = [req_call];
    if node_id_arg is not None {
        call_named.append(kt.KtNamedArg(name="nodeId", value=node_id_arg));
    }
    return kt.KtCall(
        callee=kt.KtMemberAccess(
            object=kt.KtIdentifier(name="JacClient"),
            property=kt.KtIdentifier(name=walker_name)
        ),
        args=call_args,
        named_args=call_named
    );
}

impl EsToKotlin._member_path(nd: (es.Expression | None)) -> list[str] {
    parts: list[str] = [];
    cur: any = nd;
    while cur is not None {
        if isinstance(cur, es.Identifier) {
            parts.append(cur.name);
            break;
        }
        if isinstance(cur, es.MemberExpression)
        and isinstance(cur.property, es.Identifier)
        and not cur.computed {
            parts.append(cur.property.name);
            cur = cur.object;
            continue;
        }
        return [];
    }
    parts.reverse();
    return parts;
}

impl EsToKotlin._convert_jac_runtime_call(
    nd: es.CallExpression
) -> (kt.KtNode | None) {
    path = self._member_path(nd.callee);
    if not path {
        return None;
    }
    # _jac.builtin.bool(x) → x (Kotlin truthiness / collection checks at use site)
    if path == ["_jac", "builtin", "bool"] and nd.arguments {
        arg = nd.arguments[0];
        if isinstance(arg, es.SpreadElement) {
            return None;
        }
        converted = self.convert_expr(arg);
        if converted is None {
            return None;
        }
        # Prefer idiomatic emptiness checks for .reports / collections.
        if isinstance(arg, es.MemberExpression)
        and isinstance(arg.property, es.Identifier)
        and arg.property.name == "reports" {
            return kt.KtCall(
                callee=kt.KtMemberAccess(
                    object=converted,
                    property=kt.KtIdentifier(name="isNotEmpty")
                ),
                args=[]
            );
        }
        return converted;
    }
    # _jac.exc.matches(e, "Exception") → true (outer catch already typed)
    if path == ["_jac", "exc", "matches"] {
        return kt.KtLiteral(value=True);
    }
    return None;
}

impl es_expr_to_kt(nd: (es.Expression | None)) -> (kt.KtNode | None) {
    return EsToKotlin().convert_expr(nd);
}

impl es_stmt_to_kt(nd: (es.Statement | None)) -> (kt.KtNode | None) {
    return EsToKotlin().convert_stmt(nd);
}
