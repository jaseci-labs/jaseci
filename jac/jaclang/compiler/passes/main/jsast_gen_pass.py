"""JavaScript AST Generation Pass for the Jac compiler.

This pass transforms the Jac AST into equivalent JavaScript AST by:

1. Traversing the Jac AST and generating corresponding JavaScript AST nodes
2. Handling all Jac language constructs and translating them to JavaScript equivalents:
   - Classes, functions, and methods
   - Control flow statements (if/else, loops, try/except)
   - Data structures (arrays, objects)
   - Special Jac features (walkers, abilities, archetypes)
   - Data spatial operations (node/edge connections)

3. Managing imports and dependencies between modules
4. Preserving source location information for error reporting
5. Generating appropriate JavaScript code for Jac-specific constructs

The output of this pass is a complete JavaScript AST representation that can be
serialized to JavaScript source code.
"""

from typing import Optional, Union, cast

import jaclang.compiler.emcatree as js
import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import UniPass


class JsastGenPass(UniPass):
    """Jac transpilation to JS pass."""

    JS_BIN_OP_MAP: dict[str, str] = {
        Tok.PLUS: "+",
        Tok.MINUS: "-",
        Tok.STAR_MUL: "*",
        Tok.DIV: "/",
        Tok.MOD: "%",
        Tok.STAR_POW: "**",
        Tok.EE: "===",
        Tok.NE: "!==",
        Tok.GT: ">",
        Tok.GTE: ">=",
        Tok.LT: "<",
        Tok.LTE: "<=",
        Tok.KW_AND: "&&",
        Tok.KW_OR: "||",
        Tok.BW_AND: "&",
        Tok.BW_OR: "|",
        Tok.BW_XOR: "^",
        Tok.LSHIFT: "<<",
        Tok.RSHIFT: ">>",
        Tok.KW_IN: "in",
    }

    JS_UNARY_OP_MAP: dict[str, str] = {
        Tok.NOT: "!",
        Tok.BW_NOT: "~",
        Tok.PLUS: "+",
        Tok.MINUS: "-",
    }

    JS_AUG_ASSIGN_OP_MAP: dict[str, str] = {
        Tok.ADD_EQ: "+=",
        Tok.SUB_EQ: "-=",
        Tok.MUL_EQ: "*=",
        Tok.DIV_EQ: "/=",
        Tok.MOD_EQ: "%=",
        Tok.STAR_POW_EQ: "**=",
        Tok.LSHIFT_EQ: "<<=",
        Tok.RSHIFT_EQ: ">>=",
        Tok.BW_AND_EQ: "&=",
        Tok.BW_OR_EQ: "|=",
        Tok.BW_XOR_EQ: "^=",
    }

    def gen_js_ident(self, jac_node: uni.NameAtom) -> js.JSIdentifier:
        """Generate a JSIdentifier node."""
        ident = js.JSIdentifier(name=jac_node.sym_name, kid=[jac_node])
        self.sync_jac_node(ident, jac_node)
        return ident

    def enter_node(self, node: uni.UniNode) -> None:
        """Enter node."""
        if hasattr(node.gen, "js_ast") and node.gen.js_ast:
            self.prune()
        else:
            super().enter_node(node)

    def sync_jac_node(self, to_node: js.JSNode, from_node: uni.UniNode) -> None:
        """Sync jac node."""
        to_node.loc = from_node.loc

    def exit_module(self, node: uni.Module) -> None:
        """Exit module node."""
        body_items = []
        if node.doc:
            self.ice("Docstrings not supported for JS backend yet.")
        for item in node.body:
            if not isinstance(item, (uni.ImplDef, uni.Semi, uni.CommentToken)) and (
                hasattr(item, "gen") and hasattr(item.gen, "js_ast") and item.gen.js_ast
            ):
                body_items.extend(item.gen.js_ast)

        prog = js.JSProgram(
            body=cast(list[Union[js.JSStmt, js.JSExpr]], body_items),
            kid=body_items if body_items else [uni.EmptyToken(node.source)],
            source_type="module",
        )
        self.sync_jac_node(prog, node)
        node.gen.js_ast = [prog]

    def exit_global_vars(self, node: uni.GlobalVars) -> None:
        """Exit global vars node."""
        if node.doc:
            self.ice("Docstrings not supported for JS backend yet.")
        decls = [decl for assign in node.assignments for decl in assign.gen.js_ast]
        node.gen.js_ast = decls

    def exit_test(self, node: uni.Test) -> None:
        """Exit test node."""
        self.ice(f"Tests not supported for JS backend yet: {node.sym_name}")

    def exit_module_code(self, node: uni.ModuleCode) -> None:
        """Exit module code node."""
        if node.name:
            self.ice("Module code with name not supported for JS backend yet.")
        if node.body:
            node.gen.js_ast = self.flatten(
                [i.gen.js_ast for i in node.body if hasattr(i, "gen") and i.gen.js_ast]
            )
        else:
            node.gen.js_ast = []

    def exit_py_inline_code(self, node: uni.PyInlineCode) -> None:
        """Exit python inline code node."""
        self.ice("PyInlineCode not supported for JS backend.")

    def exit_import(self, node: uni.Import) -> None:
        """Exit import node."""
        specifiers = []
        source: Optional[js.JSLiteral] = None

        if node.from_loc:
            path_str = node.from_loc.dot_path_str
            source = js.JSLiteral(
                value=path_str, raw=f"'{path_str}'", kid=[node.from_loc]
            )
            self.sync_jac_node(source, node.from_loc)
            for item in node.items:
                if not isinstance(item, uni.ModuleItem):
                    self.ice("Unsupported import item.")
                local = (
                    self.gen_js_ident(item.alias)
                    if item.alias
                    else self.gen_js_ident(item.name)
                )
                imported = self.gen_js_ident(item.name)
                spec = js.JSImportSpecifier(local=local, imported=imported, kid=[item])
                self.sync_jac_node(spec, item)
                specifiers.append(spec)
        elif node.is_absorb:
            if not node.from_loc:
                self.ice("Absorb import must have a from location.")
                return
            path_str = node.from_loc.dot_path_str
            source = js.JSLiteral(value=path_str, raw=f"'{path_str}'", kid=[node])
            if node.from_loc:
                self.sync_jac_node(source, node.from_loc)
            spec = js.JSImportNamespaceSpecifier(
                local=js.JSIdentifier(name="*", kid=[node]), kid=[node]
            )
            if (
                node.items
                and isinstance(node.items[0], uni.ModulePath)
                and node.items[0].alias
            ):
                spec.local = self.gen_js_ident(node.items[0].alias)
            self.sync_jac_node(spec, node)
            specifiers.append(spec)
        else:
            for item in node.items:
                if not isinstance(item, uni.ModulePath):
                    self.ice("Unsupported import item.")
                path_str = item.dot_path_str
                source = js.JSLiteral(value=path_str, raw=f"'{path_str}'", kid=[item])
                self.sync_jac_node(source, item)
                local = (
                    self.gen_js_ident(item.alias)
                    if item.alias
                    else self.gen_js_ident(item.path[-1])
                )
                spec = js.JSImportDefaultSpecifier(local=local, kid=[item])
                self.sync_jac_node(spec, item)
                specifiers.append(spec)
        if source:
            import_decl = js.JSImportDeclaration(
                specifiers=specifiers, source=source, kid=[node]
            )
            self.sync_jac_node(import_decl, node)
            node.gen.js_ast = [import_decl]
        else:
            node.gen.js_ast = []

    def exit_archetype(self, node: uni.Archetype) -> None:
        """Exit archetype node."""
        name = self.gen_js_ident(node.name)
        self.sync_jac_node(name, node.name)

        super_class = None
        if node.base_classes:
            if len(node.base_classes) > 1:
                self.ice("JS backend does not support multiple inheritance.")
            if node.base_classes[0].gen.js_ast:
                super_class = node.base_classes[0].gen.js_ast[0]

        body_nodes: list[
            Union[js.JSMethodDefinition, js.JSProperty, js.JSStaticBlock]
        ] = []
        if isinstance(node.body, list):
            for item in node.body:
                if item.gen.js_ast:
                    body_nodes.extend(item.gen.js_ast)

        class_body = js.JSClassBody(body=body_nodes, kid=[node])
        self.sync_jac_node(class_body, node)

        class_decl = js.JSClassDeclaration(
            id=name, superClass=super_class, body=class_body, kid=[node]
        )
        self.sync_jac_node(class_decl, node)
        node.gen.js_ast = [class_decl]

    def exit_ability(self, node: uni.Ability) -> None:
        """Exit ability node."""
        is_async = node.is_async
        is_gen = (
            isinstance(node.signature, uni.FuncSignature)
            and node.signature.return_type
            and isinstance(node.signature.return_type, uni.YieldExpr)
        )

        if not isinstance(node.name_ref, (uni.Name, uni.SpecialVarRef)):
            self.ice("Unsupported ability name type.")

        id_node = self.gen_js_ident(node.name_ref)
        params = []
        if node.signature and node.signature.params:
            for param in node.signature.params:
                if param.gen.js_ast:
                    params.append(param.gen.js_ast[0])

        body_stmts: list[js.JSStmt] = []
        if node.body and isinstance(node.body, list):
            for stmt in node.body:
                if stmt.gen.js_ast:
                    body_stmts.extend(stmt.gen.js_ast)
        body = js.JSBlockStatement(body=body_stmts, kid=[node])
        if node.body:
            self.sync_jac_node(
                body,
                node.body[0] if isinstance(node.body, list) and node.body else node,
            )

        func_decl = js.JSFunctionDeclaration(
            id=id_node,
            params=params,
            body=body,
            is_async=is_async,
            generator=is_gen,
            kid=[node],
        )
        self.sync_jac_node(func_decl, node)
        node.gen.js_ast = [func_decl]

    def exit_param_var(self, node: uni.ParamVar) -> None:
        """Exit param var node."""
        if not node.name:
            self.ice("Param var name is required.")
        id_node = self.gen_js_ident(node.name)
        if node.value:
            assign = js.JSAssignmentPattern(
                left=id_node, right=node.value.gen.js_ast[0], kid=[node]
            )
            self.sync_jac_node(assign, node)
            node.gen.js_ast = [assign]
        else:
            node.gen.js_ast = [id_node]

    def exit_arch_has(self, node: uni.ArchHas) -> None:
        """Exit arch has node."""
        node.gen.js_ast = self.flatten(
            [v.gen.js_ast for v in node.vars if hasattr(v, "gen") and v.gen.js_ast]
        )

    def exit_has_var(self, node: uni.HasVar) -> None:
        """Exit has var node."""
        ident = self.gen_js_ident(node.name)
        if node.value:
            prop = js.JSProperty(
                kind="init",
                key=ident,
                value=node.value.gen.js_ast[0],
                computed=False,
                method=False,
                shorthand=False,
                kid=[node],
            )
        else:
            prop = js.JSProperty(
                kind="init",
                key=ident,
                value=js.JSLiteral(value=None, raw="null", kid=[node]),
                computed=False,
                method=False,
                shorthand=False,
                kid=[node],
            )
        self.sync_jac_node(prop, node)
        node.gen.js_ast = [prop]

    def exit_if_stmt(self, node: uni.IfStmt) -> None:
        """Exit if stmt node."""
        test = node.condition.gen.js_ast[0]
        consequent_list: list[js.JSStmt] = []
        if node.body:
            for i in node.body:
                if hasattr(i, "gen") and hasattr(i.gen, "js_ast"):
                    consequent_list.extend(i.gen.js_ast)
        consequent = js.JSBlockStatement(body=consequent_list, kid=[node])
        if node.body:
            self.sync_jac_node(consequent, node.body[0] if node.body else node)

        alternate = None
        if node.else_body:
            if isinstance(node.else_body, uni.IfStmt):  # This is ElseIf
                alternate = node.else_body.gen.js_ast[0]
            else:
                alternate_list: list[js.JSStmt] = []
                for i in node.else_body.body:
                    alternate_list.extend(i.gen.js_ast)
                alternate = js.JSBlockStatement(body=alternate_list, kid=[node])
                if node.else_body:
                    self.sync_jac_node(alternate, node.else_body)

        if_stmt = js.JSIfStatement(
            test=test, consequent=consequent, alternate=alternate, kid=[node]
        )
        self.sync_jac_node(if_stmt, node)
        node.gen.js_ast = [if_stmt]

    def exit_else_if(self, node: uni.ElseIf) -> None:
        """Exit else if node."""
        self.exit_if_stmt(node)  # Same logic as IfStmt

    def exit_else_stmt(self, node: uni.ElseStmt) -> None:
        """Exit else stmt node."""
        body_stmts = []
        if node.body:
            for stmt in node.body:
                if stmt.gen.js_ast:
                    body_stmts.extend(stmt.gen.js_ast)
        block = js.JSBlockStatement(body=body_stmts, kid=[node])
        if node.body:
            self.sync_jac_node(block, node.body[0] if node.body else node)
        node.gen.js_ast = [block]

    def exit_expr_stmt(self, node: uni.ExprStmt) -> None:
        """Exit expr stmt node."""
        expr_stmt = js.JSExpressionStatement(
            expression=node.expr.gen.js_ast[0], kid=[node]
        )
        self.sync_jac_node(expr_stmt, node)
        node.gen.js_ast = [expr_stmt]

    def exit_in_for_stmt(self, node: uni.InForStmt) -> None:
        """Exit in for stmt node."""
        left = node.target.gen.js_ast[0]
        if isinstance(node.target, uni.Assignment):
            left = node.target.gen.js_ast[0]
        right = node.collection.gen.js_ast[0]
        body_stmts = []
        if node.body:
            for stmt in node.body:
                body_stmts.extend(stmt.gen.js_ast)
        body = js.JSBlockStatement(body=body_stmts, kid=[node])
        if node.body:
            self.sync_jac_node(body, node.body[0] if node.body else node)

        for_of_stmt = js.JSForOfStatement(left=left, right=right, body=body, kid=[node])
        self.sync_jac_node(for_of_stmt, node)
        node.gen.js_ast = [for_of_stmt]

    def exit_while_stmt(self, node: uni.WhileStmt) -> None:
        """Exit while stmt node."""
        test = node.condition.gen.js_ast[0]
        body = js.JSBlockStatement(
            body=self.flatten([s.gen.js_ast for s in node.body if s.gen.js_ast]),
            kid=[node],
        )
        self.sync_jac_node(body, node.body[0] if node.body else node)
        while_stmt = js.JSWhileStatement(test=test, body=body, kid=[node])
        self.sync_jac_node(while_stmt, node)
        node.gen.js_ast = [while_stmt]

    def exit_ctrl_stmt(self, node: uni.CtrlStmt) -> None:
        """Exit ctrl stmt node."""
        stmt: Union[js.JSBreakStatement, js.JSContinueStatement, js.JSReturnStatement]
        if node.ctrl.name == Tok.KW_BREAK:
            stmt = js.JSBreakStatement(kid=[node])
        elif node.ctrl.name == Tok.KW_CONTINUE:
            stmt = js.JSContinueStatement(kid=[node])
        elif node.ctrl.name == Tok.KW_SKIP:  # Treat as return in JS
            stmt = js.JSReturnStatement(kid=[node])
        else:
            self.ice(f"Unsupported control statement: {node.ctrl.value}")
        self.sync_jac_node(stmt, node)
        node.gen.js_ast = [stmt]

    def exit_return_stmt(self, node: uni.ReturnStmt) -> None:
        """Exit return stmt node."""
        arg = node.expr.gen.js_ast[0] if node.expr and node.expr.gen.js_ast else None
        ret_stmt = js.JSReturnStatement(argument=arg, kid=[node])
        self.sync_jac_node(ret_stmt, node)
        node.gen.js_ast = [ret_stmt]

    def exit_assignment(self, node: uni.Assignment) -> None:
        """Exit assignment node."""
        if len(node.target) > 1:
            self.ice("Multiple assignment not supported for JS backend yet.")

        target_node = node.target[0]
        if node.type_tag:  # let x: T = ...
            if not isinstance(target_node, (uni.Name, uni.AtomExpr)):
                self.ice("Typed assignment must be to a simple name.")

            init_expr = None
            if node.value and node.value.gen.js_ast:
                init_expr = node.value.gen.js_ast[0]

            declarator = js.JSVariableDeclarator(
                id=target_node.gen.js_ast[0],
                init=init_expr,
                kid=[node],
            )
            self.sync_jac_node(declarator, node)
            var_decl = js.JSVariableDeclaration(
                declarations=[declarator],
                kind="let",  # Or const if not mutable
                kid=[node],
            )
            self.sync_jac_node(var_decl, node)
            node.gen.js_ast = [var_decl]
        else:
            op = "="
            if node.aug_op:
                op = self.JS_AUG_ASSIGN_OP_MAP[node.aug_op.name]

            assign_expr = js.JSAssignmentExpression(
                operator=op,
                left=target_node.gen.js_ast[0],
                right=node.value.gen.js_ast[0],
                kid=[node],
            )
            self.sync_jac_node(assign_expr, node)
            node.gen.js_ast = [
                js.JSExpressionStatement(expression=assign_expr, kid=[node])
            ]

    def exit_binary_expr(self, node: uni.BinaryExpr) -> None:
        """Exit binary expr node."""
        if isinstance(node.op, uni.Token):
            op_str = self.JS_BIN_OP_MAP.get(node.op.name)
            expr: Union[js.JSLogicalExpression, js.JSBinaryExpression]
            if op_str in ["&&", "||", "??"]:
                expr = js.JSLogicalExpression(
                    operator=op_str,
                    left=node.left.gen.js_ast[0],
                    right=node.right.gen.js_ast[0],
                    kid=[node],
                )
            elif op_str:
                expr = js.JSBinaryExpression(
                    operator=op_str,
                    left=node.left.gen.js_ast[0],
                    right=node.right.gen.js_ast[0],
                    kid=[node],
                )
            else:
                self.ice(f"Unsupported binary operator: {node.op.value}")
            self.sync_jac_node(expr, node)
            node.gen.js_ast = [expr]
        else:  # ConnectOp/DisconnectOp etc.
            self.ice(
                f"Data spatial operations not supported for JS backend yet: {type(node.op).__name__}"
            )

    def exit_unary_expr(self, node: uni.UnaryExpr) -> None:
        """Exit unary expr node."""
        op_str = self.JS_UNARY_OP_MAP.get(node.op.name)
        if op_str:
            expr = js.JSUnaryExpression(
                operator=op_str,
                argument=node.operand.gen.js_ast[0],
                prefix=True,
                kid=[node],
            )
            self.sync_jac_node(expr, node)
            node.gen.js_ast = [expr]
        else:
            self.ice(f"Unsupported unary operator: {node.op.value}")

    def exit_atom_unit(self, node: uni.AtomUnit) -> None:
        """Exit atom unit node."""
        node.gen.js_ast = node.value.gen.js_ast

    def exit_if_else_expr(self, node: uni.IfElseExpr) -> None:
        """Exit if else expr node."""
        expr = js.JSConditionalExpression(
            test=node.condition.gen.js_ast[0],
            consequent=node.value.gen.js_ast[0],
            alternate=node.else_value.gen.js_ast[0],
            kid=[node],
        )
        self.sync_jac_node(expr, node)
        node.gen.js_ast = [expr]

    def exit_list_val(self, node: uni.ListVal) -> None:
        """Exit list val node."""
        elements = [val.gen.js_ast[0] for val in node.values if val.gen.js_ast]
        arr_expr = js.JSArrayExpression(elements=elements, kid=[node])
        self.sync_jac_node(arr_expr, node)
        node.gen.js_ast = [arr_expr]

    def exit_dict_val(self, node: uni.DictVal) -> None:
        """Exit dict val node."""
        properties = []
        for pair in node.kv_pairs:
            # Handle spread (unsupported for now)
            if pair.key is None:
                self.ice("Spread in objects not supported for JS backend yet.")
                continue

            # Ensure key has js_ast; if not, generate
            if not pair.key.gen.js_ast:
                if isinstance(pair.key, uni.Name):
                    pair.key.gen.js_ast = [self.gen_js_ident(pair.key)]
                elif isinstance(pair.key, uni.String):
                    lit = js.JSLiteral(
                        value=pair.key.lit_value, raw=pair.key.value, kid=[pair.key]
                    )
                    self.sync_jac_node(lit, pair.key)
                    pair.key.gen.js_ast = [lit]
                else:
                    # Attempt best-effort literal conversion
                    lit = js.JSLiteral(
                        value=str(pair.key), raw=str(pair.key), kid=[pair.key]
                    )
                    self.sync_jac_node(lit, pair.key)
                    pair.key.gen.js_ast = [lit]

            if not pair.value.gen.js_ast:
                # Generate literal null for missing value AST to avoid crash
                pair.value.gen.js_ast = [
                    js.JSLiteral(value=None, raw="null", kid=[pair.value])
                ]

            key = pair.key.gen.js_ast[0]
            # Determine if the key should be treated as computed (non-identifier literals)
            computed = isinstance(key, js.JSLiteral) and isinstance(key.value, str)

            prop = js.JSProperty(
                key=key,
                value=pair.value.gen.js_ast[0],
                kind="init",
                computed=computed,
                method=False,
                shorthand=False,  # can be improved
                kid=[pair],
            )
            self.sync_jac_node(prop, pair)
            properties.append(prop)
        obj_expr = js.JSObjectExpression(properties=properties, kid=[node])
        self.sync_jac_node(obj_expr, node)
        node.gen.js_ast = [obj_expr]

    def exit_atom_trailer(self, node: uni.AtomTrailer) -> None:
        """Exit atom trailer node."""
        if node.is_attr:
            if not isinstance(node.right, uni.AstSymbolNode):
                self.ice("Invalid attribute access.")
                return
            prop = js.JSIdentifier(name=node.right.sym_name, kid=[node.right])
            self.sync_jac_node(prop, node.right)
            expr = js.JSMemberExpression(
                object=node.target.gen.js_ast[0],
                property=prop,
                computed=False,
                optional=node.is_null_ok,
                kid=[node],
            )
            self.sync_jac_node(expr, node)
            node.gen.js_ast = [expr]
        else:  # index
            expr = js.JSMemberExpression(
                object=node.target.gen.js_ast[0],
                property=node.right.gen.js_ast[0],
                computed=True,
                optional=node.is_null_ok,
                kid=[node],
            )
            self.sync_jac_node(expr, node)
            node.gen.js_ast = [expr]

    def exit_func_call(self, node: uni.FuncCall) -> None:
        """Exit func call node."""
        args = (
            [p.gen.js_ast[0] for p in node.params if p.gen.js_ast]
            if node.params
            else []
        )
        callee = node.target.gen.js_ast[0]
        call_expr = js.JSCallExpression(callee=callee, arguments=args, kid=[node])
        self.sync_jac_node(call_expr, node)
        node.gen.js_ast = [call_expr]

    def exit_special_var_ref(self, node: uni.SpecialVarRef) -> None:
        """Exit special var ref node."""
        if node.name == Tok.KW_SUPER:
            node.gen.js_ast = [js.JSSuper(kid=[node])]
        elif node.name == Tok.KW_ROOT:
            node.gen.js_ast = [js.JSIdentifier(name="jac.root", kid=[node])]
        elif node.name == Tok.KW_HERE:
            node.gen.js_ast = [js.JSThisExpression(kid=[node])]
        else:
            ident = self.gen_js_ident(node)
            node.gen.js_ast = [ident]

    def exit_name(self, node: uni.Name) -> None:
        """Exit name node."""
        ident = self.gen_js_ident(node)
        node.gen.js_ast = [ident]

    def exit_float(self, node: uni.Float) -> None:
        """Exit float node."""
        lit = js.JSLiteral(value=float(node.value), raw=node.value, kid=[node])
        self.sync_jac_node(lit, node)
        node.gen.js_ast = [lit]

    def exit_int(self, node: uni.Int) -> None:
        """Exit int node."""
        lit = js.JSLiteral(value=int(node.value, 0), raw=node.value, kid=[node])
        self.sync_jac_node(lit, node)
        node.gen.js_ast = [lit]

    def exit_string(self, node: uni.String) -> None:
        """Exit string node."""
        lit = js.JSLiteral(value=node.lit_value, raw=node.value, kid=[node])
        self.sync_jac_node(lit, node)
        node.gen.js_ast = [lit]

    def exit_multi_string(self, node: uni.MultiString) -> None:
        """Exit multi-string node."""
        text = ""
        for item in node.strings:
            if isinstance(item, uni.String):
                text += item.lit_value
            elif isinstance(item, uni.FString):
                for part in item.parts:
                    if isinstance(part, uni.String):
                        text += part.lit_value
        lit = js.JSLiteral(value=text, raw=repr(text), kid=[node])
        self.sync_jac_node(lit, node)
        node.gen.js_ast = [lit]

    def exit_bool(self, node: uni.Bool) -> None:
        """Exit bool node."""
        lit = js.JSLiteral(value=node.value == "True", raw=node.value, kid=[node])
        self.sync_jac_node(lit, node)
        node.gen.js_ast = [lit]

    def exit_null(self, node: uni.Null) -> None:
        """Exit null node."""
        lit = js.JSLiteral(value=None, raw="null", kid=[node])
        self.sync_jac_node(lit, node)
        node.gen.js_ast = [lit]

    def flatten(self, body: list) -> list:
        """Flatten a list of items or lists into a single list."""
        new_body = []
        for item in body:
            if isinstance(item, list):
                new_body.extend(item)
            elif item is not None:
                new_body.append(item)
        return new_body

    def ice(self, msg: str) -> None:
        """Issue a compiler error."""
        self.log_error(f"Internal Compiler Error: {msg}")
        raise RuntimeError(f"JSastGenPass ICE: {msg}")
