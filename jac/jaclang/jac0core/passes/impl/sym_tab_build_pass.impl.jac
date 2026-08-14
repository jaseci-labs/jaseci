impl SymTabBuildPass.before_pass(self: SymTabBuildPass) -> None {
    self.cur_sym_tab = [];
}

impl SymTabBuildPass.push_scope_and_link(
    self: SymTabBuildPass, key_node: UniScopeNode
) -> None {
    if not len(self.cur_sym_tab) {
        self.cur_sym_tab.append(key_node);
    } else {
        self.cur_sym_tab.append(self.cur_scope.link_kid_scope(key_node=key_node));
    }
}

impl SymTabBuildPass.pop_scope(self: SymTabBuildPass) -> UniScopeNode {
    return self.cur_sym_tab.pop();
}

impl SymTabBuildPass.cur_scope.getter(self: SymTabBuildPass) -> UniScopeNode {
    return self.cur_sym_tab[-1];
}

impl SymTabBuildPass._bind_import_path_symbols(
    self: SymTabBuildPass, module_path: ModulePath
) -> None {
    if module_path.path {
        for n in module_path.path {
            if isinstance(n, Name) {
                n.sym = n.create_symbol(access=SymbolAccess.PUBLIC, imported=True);
            }
        }
    }
}

impl SymTabBuildPass.enter_module(self: SymTabBuildPass, nd: Module) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_module(self: SymTabBuildPass, nd: Module) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_type_alias(self: SymTabBuildPass, nd: TypeAlias) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='type_alias');
}

impl SymTabBuildPass.exit_type_alias(self: SymTabBuildPass, nd: TypeAlias) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_type_param(self: SymTabBuildPass, nd: TypeParam) -> None {
    if nd.sym_tab is not None {
        nd.sym_tab.def_insert(nd, single_decl='type_param');
    }
}

impl SymTabBuildPass.exit_global_vars(self: SymTabBuildPass, nd: GlobalVars) -> None {
    import from jaclang.jac0core.constant { SymbolType }
    for i in nd.assignments {
        for j in i.target {
            if isinstance(j, AstSymbolNode) {
                j.name_spec._sym_category = SymbolType.MOD_VAR;
                j.sym_tab.def_insert(j, access_spec=nd, single_decl='global var');
            } else {
                self.ice('Expected name type for global vars');
            }
        }
    }
}

impl lookup_enclosing_binding(from_scope: UniScopeNode, name: str) -> (Symbol | None) {
    import from jaclang.jac0core.constant { SymbolType }
    scope = find_python_scope_node_of(from_scope);
    while scope is not None {
        if isinstance(scope, Module) {
            sym = scope.names_in_scope.get(name);
            if sym is not None and sym.sym_type == SymbolType.MOD_VAR {
                return sym;
            }
            return None;
        }
        if isinstance(scope, (Ability, ImplDef, Test, LambdaExpr)) {
            sym = scope.names_in_scope.get(name);
            if sym is not None {
                return sym;
            }
        }
        scope = find_python_scope_node_of(scope);
    }
    return None;
}

impl record_cross_scope_rebind(py_scope: UniScopeNode, name: str, sym: Symbol) -> None {
    import from jaclang.jac0core.constant { SymbolType }
    outer_tab = sym.parent_tab;
    if outer_tab is None or outer_tab is py_scope {
        return;
    }
    if not isinstance(py_scope, (Ability, ImplDef, Test)) {
        return;
    }
    if py_scope.names_in_scope is outer_tab.names_in_scope {
        return;
    }
    if isinstance(outer_tab, Module) {
        if sym.sym_type == SymbolType.MOD_VAR {
            py_scope.implicit_rebinds[name] = sym;
        }
        return;
    }
    if isinstance(outer_tab, (Ability, ImplDef, Test)) {
        py_scope.implicit_rebinds[name] = sym;
    }
}

impl rebind_or_def_insert(
    target: AstSymbolNode, py_scope: UniScopeNode, single_decl: str
) -> None {
    if isinstance(py_scope, (Ability, ImplDef, Test, LambdaExpr)) {
        outer_sym = lookup_enclosing_binding(py_scope, target.sym_name);
        if outer_sym is not None {
            outer_sym.add_use(target.name_spec);
            py_scope.names_in_scope[target.sym_name] = outer_sym;
            py_scope.implicit_rebinds[target.sym_name] = outer_sym;
            return;
        }
    }
    py_scope.def_insert(target, single_decl=single_decl);
}

impl SymTabBuildPass.exit_assignment(self: SymTabBuildPass, nd: Assignment) -> None {
    if nd.find_parent_of_type(ImplDef) is not None {
        return;
    }

    if isinstance(nd.parent, GlobalVars) {
        return;
    }
    if nd.type_tag is not None {
        for i in nd.target {
            if isinstance(i, Name) {
                scope = find_python_scope_node_of(i);
                if scope is not None and i.sym_name in scope.implicit_rebinds {
                    self.emit(E0064, node_override=i, name=i.sym_name);
                }
            }
        }
    }
    bind_assignment_targets(nd);
}

impl SymTabBuildPass.exit_binary_expr(self: SymTabBuildPass, nd: BinaryExpr) -> None {
    import from jaclang.jac0core.constant { Tokens as Tok }
    if not (isinstance(nd.op, Token) and (nd.op.name == Tok.WALRUS_EQ)) {
        return;
    }
    if isinstance(nd.left, Name) {
        target_scope = nd.left.sym_tab;
        owner: (UniNode | None) = nd.parent;
        while (owner is not None and not isinstance(owner, (Ability, LambdaExpr))) {
            owner = owner.parent;
        }
        if owner is not None {
            target_scope = owner.sym_tab;
        }
        if ((sym := target_scope.lookup(nd.left.sym_name, deep=False)) is None) {
            rebind_or_def_insert(nd.left, target_scope, single_decl='walrus var');
        } else {
            sym.add_use(nd.left.name_spec);
            record_cross_scope_rebind(target_scope, nd.left.sym_name, sym);
        }
    }
}

impl SymTabBuildPass.enter_test(self: SymTabBuildPass, nd: Test) -> None {
    self.push_scope_and_link(nd);
    import from unittest { TestCase }
    for i in [
        j
        for j in dir(TestCase())
        if j.startswith('assert')
    ] {
        nd.sym_tab.def_insert(
            Name.gen_stub_from_node(nd, i, set_name_of=nd), imported=True
        );
    }
}

impl SymTabBuildPass.exit_test(self: SymTabBuildPass, nd: Test) -> None {
    self.pop_scope();
}

impl SymTabBuildPass._exit_import_absorb(self: SymTabBuildPass, nd: Import) -> None {
    sym_table_to_update = find_python_scope_node_of(nd);
    if (sym_table_to_update is None) {
        return;
    }
    import_all_module_path_node: ModulePath = nd.items[0];
    import_all_module_path = import_all_module_path_node.resolve_relative_path();
    module: (Module | None) = None;
    if (import_all_module_path in self.prog.mod.hub) {
        module = self.prog.mod.hub[import_all_module_path];
    } else {
        try {
            module = self.prog.compile(
                import_all_module_path, no_cgen=True, type_check=False
            );
        } except Exception {
            return;
        }
    }
    self._bind_import_path_symbols(import_all_module_path_node);
    if module {
        for sym in module.names_in_scope.values() {
            if (sym.access != SymbolAccess.PRIVATE) {
                sym_table_to_update.def_insert(
                    sym.defn[0], single_decl='import absorb', imported=True
                );
            }
        }

        for (name, overload_syms) in module.names_in_scope_overload.items() {
            for sym in overload_syms {
                if (sym.access != SymbolAccess.PRIVATE) {
                    sym_table_to_update.def_insert(
                        sym.defn[0], single_decl='import absorb', imported=True
                    );
                }
            }
        }
    }
}

impl SymTabBuildPass.exit_import(self: SymTabBuildPass, nd: Import) -> None {
    if nd.is_absorb {
        return self._exit_import_absorb(nd);
    }
}

impl SymTabBuildPass.exit_module_path(self: SymTabBuildPass, nd: ModulePath) -> None {
    if nd.alias {
        nd.alias.sym_tab.def_insert(nd.alias, single_decl='import', imported=True);
    } elif (
        nd.path
        and not nd.is_import_from
        and nd.parent_of_type(Import)
        and not (
            nd.parent_of_type(Import).from_loc and nd.parent_of_type(Import).is_jac
        )
    ) {
        if isinstance(nd.path[0], Name) {
            nd.path[0].sym_tab.def_insert(nd.path[0], imported=True);
        }
    } else {
        ;
    }
    if (nd.path and (nd.is_import_from or nd.alias)) {
        self._bind_import_path_symbols(nd);
    }
}

impl SymTabBuildPass.exit_module_item(self: SymTabBuildPass, nd: ModuleItem) -> None {
    if isinstance(nd.name, Name) {
        sym_node = nd.alias or nd.name;
        sym_node.sym_tab.def_insert(sym_node, single_decl='import', imported=True);
        if nd.alias {
            nd.name.sym = nd.name.create_symbol(
                access=SymbolAccess.PUBLIC, imported=True
            );
        }
    } elif (isinstance(nd.name, Token) and nd.alias) {
        sym_node = nd.alias;
        sym_node.sym_tab.def_insert(sym_node, single_decl='import', imported=True);
    }
}

impl SymTabBuildPass.enter_archetype(self: SymTabBuildPass, nd: Archetype) -> None {
    if self.cur_sym_tab {
        existing_sym = self.cur_scope.names_in_scope.get(nd.sym_name, None);
        if existing_sym {
            nd_native = nd.in_native_context();
            nd_client = nd.in_client_context();
            for d in existing_sym.defn {
                if (
                    isinstance(d.name_of, Archetype)
                    and (d.name_of.in_native_context() == nd_native)
                    and (d.name_of.in_client_context() == nd_client)
                ) {
                    self.emit(
                        E0077,
                        node_override=nd,
                        name=nd.sym_name,
                        kind=d.name_of.arch_type.value
                    );
                    break;
                }
            }
        }
    }
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='archetype');
}

impl SymTabBuildPass.exit_archetype(self: SymTabBuildPass, nd: Archetype) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_ability(self: SymTabBuildPass, nd: Ability) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='ability');
    if nd.is_method {
        nd.sym_tab.def_insert(Name.gen_stub_from_node(nd, 'self'));
        nd.sym_tab.def_insert(
            Name.gen_stub_from_node(nd, 'super', set_name_of=nd.method_owner)
        );
    }
}

impl SymTabBuildPass.exit_ability(self: SymTabBuildPass, nd: Ability) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_impl_def(self: SymTabBuildPass, nd: ImplDef) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, single_decl='impl');
}

impl SymTabBuildPass.exit_impl_def(self: SymTabBuildPass, nd: ImplDef) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_sem_def(self: SymTabBuildPass, nd: SemDef) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, single_decl='sem');
}

impl SymTabBuildPass.exit_sem_def(self: SymTabBuildPass, nd: SemDef) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_enum(self: SymTabBuildPass, nd: Enum) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='enum');
}

impl SymTabBuildPass.enter_has_var(self: SymTabBuildPass, nd: HasVar) -> None {
    if isinstance(nd.parent, ArchHas) {
        nd.sym_tab.def_insert(nd, single_decl='has var', access_spec=nd.parent);
    }
}

impl SymTabBuildPass.enter_param_var(self: SymTabBuildPass, nd: ParamVar) -> None {
    nd.sym_tab.def_insert(nd, single_decl='param');
}

impl SymTabBuildPass.exit_atom_trailer(self: SymTabBuildPass, nd: AtomTrailer) -> None {
    if not self._is_self_member_assignment(nd) {
        return;
    }
    chain = nd.as_attr_list;

    ability = nd.find_parent_of_type(Ability);
    if (ability and ability.method_owner) {
        archetype = ability.method_owner;
        if isinstance(archetype, Archetype) {
            if (
                archetype.arch_type.name == 'KW_CLASS'
                or archetype.sym_tab.lookup(chain[1].sym_name, deep=False) is not None
            ) {
                archetype.sym_tab.def_insert(chain[1], access_spec=archetype);
            }
        }
        return;
    }

    impl_def = nd.find_parent_of_type(ImplDef);
    if (impl_def and (len(impl_def.target) >= 2)) {
        archetype_name = impl_def.target[0].sym_name;
        if impl_def.sym_tab and impl_def.sym_tab.parent_scope {
            lookup = impl_def.sym_tab.parent_scope.lookup(archetype_name, deep=True);
            if (lookup and isinstance(lookup.decl.name_of, Archetype)) {
                archetype = lookup.decl.name_of;

                if (
                    archetype.arch_type.name == 'KW_CLASS'
                    or archetype.sym_tab.lookup(chain[1].sym_name, deep=False)
                        is not None
                ) {
                    archetype.sym_tab.def_insert(chain[1], access_spec=archetype);
                }
            }
        }
    }
}

impl SymTabBuildPass._is_self_member_assignment(
    self: SymTabBuildPass, nd: AtomTrailer
) -> bool {
    if not (nd.parent and isinstance(nd.parent, Assignment)) {
        return False;
    }
    if (nd != nd.parent.target[0]) {
        return False;
    }
    chain = nd.as_attr_list;
    if ((len(chain) != 2) or (chain[0].sym_name != 'self')) {
        return False;
    }

    ability = nd.find_parent_of_type(Ability);
    if ability is not None {
        return (
            ability.is_method and not ability.is_static and not ability.is_cls_method
        );
    }

    impl_def = nd.find_parent_of_type(ImplDef);
    if (impl_def and (len(impl_def.target) >= 2)) {
        return True;
    }
    return False;
}

impl SymTabBuildPass.exit_enum(self: SymTabBuildPass, nd: Enum) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_typed_ctx_block(
    self: SymTabBuildPass, nd: TypedCtxBlock
) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_typed_ctx_block(
    self: SymTabBuildPass, nd: TypedCtxBlock
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_open_stmt(self: SymTabBuildPass, nd: OpenStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_open_stmt(self: SymTabBuildPass, nd: OpenStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_if_stmt(self: SymTabBuildPass, nd: IfStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_if_stmt(self: SymTabBuildPass, nd: IfStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_else_if(self: SymTabBuildPass, nd: ElseIf) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_else_if(self: SymTabBuildPass, nd: ElseIf) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_else_stmt(self: SymTabBuildPass, nd: ElseStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_else_stmt(self: SymTabBuildPass, nd: ElseStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_try_stmt(self: SymTabBuildPass, nd: TryStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_try_stmt(self: SymTabBuildPass, nd: TryStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_except(self: SymTabBuildPass, nd: Except) -> None {
    self.push_scope_and_link(nd);
    if nd.name {
        nd.sym_tab.def_insert(nd.name, single_decl='local var');
    }
}

impl SymTabBuildPass.exit_except(self: SymTabBuildPass, nd: Except) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_finally_stmt(
    self: SymTabBuildPass, nd: FinallyStmt
) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_finally_stmt(self: SymTabBuildPass, nd: FinallyStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_iter_for_stmt(
    self: SymTabBuildPass, nd: IterForStmt
) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_iter_for_stmt(
    self: SymTabBuildPass, nd: IterForStmt
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_in_for_stmt(self: SymTabBuildPass, nd: InForStmt) -> None {
    self.push_scope_and_link(nd);
    def_insert_unpacking(nd.target, nd.sym_tab);
}

impl SymTabBuildPass.exit_in_for_stmt(self: SymTabBuildPass, nd: InForStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_while_stmt(self: SymTabBuildPass, nd: WhileStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_while_stmt(self: SymTabBuildPass, nd: WhileStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_forever_stmt(
    self: SymTabBuildPass, nd: ForeverStmt
) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_forever_stmt(self: SymTabBuildPass, nd: ForeverStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_with_stmt(self: SymTabBuildPass, nd: WithStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_with_stmt(self: SymTabBuildPass, nd: WithStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.exit_expr_as_item(self: SymTabBuildPass, nd: ExprAsItem) -> None {
    if (nd.alias and isinstance(nd.alias, Name)) {
        nd.alias.sym_tab.def_insert(nd.alias, single_decl='context var');
    }
}

impl SymTabBuildPass.enter_lambda_expr(self: SymTabBuildPass, nd: LambdaExpr) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_lambda_expr(self: SymTabBuildPass, nd: LambdaExpr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_list_compr(self: SymTabBuildPass, nd: ListCompr) -> None {
    self.push_scope_and_link(nd);
    for i in nd.compr {
        def_insert_unpacking(i.target, nd.sym_tab);
    }
}

impl SymTabBuildPass.exit_list_compr(self: SymTabBuildPass, nd: ListCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_set_compr(self: SymTabBuildPass, nd: SetCompr) -> None {
    self.push_scope_and_link(nd);
    for i in nd.compr {
        def_insert_unpacking(i.target, nd.sym_tab);
    }
}

impl SymTabBuildPass.exit_set_compr(self: SymTabBuildPass, nd: SetCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_gen_compr(self: SymTabBuildPass, nd: GenCompr) -> None {
    self.push_scope_and_link(nd);
    for i in nd.compr {
        def_insert_unpacking(i.target, nd.sym_tab);
    }
}

impl SymTabBuildPass.exit_gen_compr(self: SymTabBuildPass, nd: GenCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_dict_compr(self: SymTabBuildPass, nd: DictCompr) -> None {
    self.push_scope_and_link(nd);
    for i in nd.compr {
        def_insert_unpacking(i.target, nd.sym_tab);
    }
}

impl SymTabBuildPass.exit_dict_compr(self: SymTabBuildPass, nd: DictCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_inner_compr(self: SymTabBuildPass, nd: InnerCompr) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_inner_compr(self: SymTabBuildPass, nd: InnerCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_match_case(self: SymTabBuildPass, nd: MatchCase) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_match_case(self: SymTabBuildPass, nd: MatchCase) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_switch_case(self: SymTabBuildPass, nd: SwitchCase) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_switch_case(self: SymTabBuildPass, nd: SwitchCase) -> None {
    self.pop_scope();
}

impl find_python_scope_node_of(nd: UniNode) -> (UniScopeNode | None) {
    while nd.parent {
        if UniScopeNode.is_python_scoping(nd.parent) {
            return nd.parent;
        }
        nd = nd.parent;
    }
    return None;
}

impl find_typed_decl_scope_of(nd: AstSymbolNode) -> UniScopeNode {
    if UniScopeNode.is_python_scoping(nd.sym_tab) {
        return nd.sym_tab;
    }
    py_scope = find_python_scope_node_of(nd);
    if isinstance(py_scope, (Ability, ImplDef, Test, LambdaExpr)) {
        return py_scope;
    }
    return nd.sym_tab;
}

impl def_insert_unpacking(
    nd: Expr, sym_tab: UniScopeNode, rebind_in_python_scope: bool = False
) -> None {
    if isinstance(nd, Name) {
        if rebind_in_python_scope {
            if ((existing := sym_tab.lookup(nd.sym_name, deep=False)) is not None) {
                existing.add_use(nd.name_spec);
                return;
            }
            py_scope = find_python_scope_node_of(nd);
            if py_scope is not None {
                if ((outer := py_scope.lookup(nd.sym_name, deep=False)) is not None) {
                    outer.add_use(nd.name_spec);
                    record_cross_scope_rebind(py_scope, nd.sym_name, outer);
                } else {
                    rebind_or_def_insert(nd, py_scope, single_decl='local var');
                }
                return;
            }
        }
        sym_tab.def_insert(nd, single_decl='iterator');
    } elif isinstance(nd, (TupleVal, ListVal)) {
        for target_var in nd.values {
            if isinstance(target_var, Expr) {
                def_insert_unpacking(target_var, sym_tab, rebind_in_python_scope);
            }
        }
    } elif (isinstance(nd, UnaryExpr) and (nd.op.name == Tokens.STAR_MUL)) {
        def_insert_unpacking(nd.operand, sym_tab, rebind_in_python_scope);
    }
}

impl bind_assignment_targets(nd: Assignment) -> None {
    import from jaclang.jac0core.constant { SymbolType }
    for i in nd.target {
        if isinstance(i, AstSymbolNode) {
            if isinstance(i, (ListVal, TupleVal)) {
                def_insert_unpacking(i, i.sym_tab, rebind_in_python_scope=True);
            } elif (
                (i.sym_name in i.sym_tab.names_in_scope)
                and ((sym := i.sym_tab.names_in_scope[i.sym_name]) is not None)
            ) {
                sym.add_use(i.name_spec);
                record_cross_scope_rebind(i.sym_tab, i.sym_name, sym);
            } elif (
                (nd.type_tag is None)
                and ((outer_has := i.sym_tab.lookup(i.sym_name, deep=True)) is not None)
                and outer_has.sym_type == SymbolType.HAS_VAR
                and isinstance(outer_has.parent_tab, Ability)
            ) {
                outer_has.add_use(i.name_spec);
            } elif (
                (nd.type_tag is None) and not UniScopeNode.is_python_scoping(i.sym_tab)
            ) {
                py_scope = find_python_scope_node_of(i);
                if py_scope is not None {
                    if (
                        (outer := py_scope.lookup(i.sym_name, deep=False)) is not None
                    ) {
                        outer.add_use(i.name_spec);
                        record_cross_scope_rebind(py_scope, i.sym_name, outer);
                    } else {
                        rebind_or_def_insert(i, py_scope, single_decl='local var');
                    }
                } else {
                    i.sym_tab.def_insert(i, single_decl='local var');
                }
            } elif (
                (nd.type_tag is None)
                and isinstance(i.sym_tab, (Ability, ImplDef, Test, LambdaExpr))
            ) {
                rebind_or_def_insert(i, i.sym_tab, single_decl='local var');
            } else {
                if isinstance(i.sym_tab, Enum) {
                    i.name_spec._sym_category = SymbolType.ENUM_MEMBER;
                }
                find_typed_decl_scope_of(i).def_insert(i, single_decl='local var');
            }
        }
    }
}
