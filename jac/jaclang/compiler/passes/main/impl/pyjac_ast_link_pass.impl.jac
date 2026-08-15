impl PyJacAstLinkPass.exit_atom_trailer(nd: AtomTrailer) -> None {
    if (nd.is_attr and isinstance(nd.right, AstSymbolNode)) {
        self.link_jac_py_nodes(jac_node=nd.right.name_spec, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_k_w_pair(nd: KWPair) -> None {
    if nd.key {
        self.link_jac_py_nodes(jac_node=nd.key, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_expr_as_item(nd: ExprAsItem) -> None {
    self.link_jac_py_nodes(jac_node=nd.expr, py_nodes=nd.gen.py_ast);
    if nd.alias {
        self.link_jac_py_nodes(jac_node=nd.alias, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_except(nd: Except) -> None {
    if nd.name {
        self.link_jac_py_nodes(jac_node=nd.name, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_param_var(nd: ParamVar) -> None {
    self.link_jac_py_nodes(jac_node=nd.name, py_nodes=nd.gen.py_ast);
}

impl PyJacAstLinkPass.exit_impl_def(nd: ImplDef) -> None {
    for i in nd.target {
        if i.name_spec.name_of.sym {
            self.link_jac_py_nodes(
                jac_node=i, py_nodes=i.name_spec.name_of.sym.decl.gen.py_ast
            );
            self.link_jac_py_nodes(
                jac_node=i.name_spec, py_nodes=i.name_spec.name_of.sym.decl.gen.py_ast
            );
        }
    }
    if (isinstance(nd.decl_link, Ability) and nd.decl_link.signature) {
        if (isinstance(nd.spec, FuncSignature) and nd.spec.params) {
            for src_prm in nd.spec.params {
                if (
                    isinstance(nd.decl_link.signature, FuncSignature)
                    and nd.decl_link.signature.params
                ) {
                    for trg_prm in nd.decl_link.signature.params {
                        if (src_prm.name.sym_name == trg_prm.name.sym_name) {
                            self.link_jac_py_nodes(
                                jac_node=src_prm, py_nodes=trg_prm.gen.py_ast
                            );
                            self.link_jac_py_nodes(
                                jac_node=src_prm.name, py_nodes=trg_prm.name.gen.py_ast
                            );
                        }
                    }
                }
            }
        }
        if (
            (isinstance(nd.spec, FuncSignature) and nd.spec.return_type)
            and (
                isinstance(nd.decl_link.signature, FuncSignature)
                and nd.decl_link.signature.return_type
            )
        ) {
            self.link_jac_py_nodes(
                jac_node=nd.spec.return_type,
                py_nodes=nd.decl_link.signature.return_type.gen.py_ast
            );
        }
    }
    if (isinstance(nd.decl_link, Ability) and isinstance(nd.target, Sequence)) {
        for arch in nd.target {
            if arch.name_spec.name_of.sym {
                arch.name_spec.name_of.sym.add_use(arch.name_spec);
            }
        }
    }
}

impl PyJacAstLinkPass.exit_ability(nd: Ability) -> None {
    self.link_jac_py_nodes(jac_node=nd.name_ref, py_nodes=nd.gen.py_ast);
    if isinstance(nd.body, ImplDef) {
        self.link_jac_py_nodes(jac_node=nd.body, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_enum(nd: Enum) -> None {
    if isinstance(nd.body, ImplDef) {
        self.link_jac_py_nodes(jac_node=nd.body, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_type_alias(nd: TypeAlias) -> None {
    self.link_jac_py_nodes(jac_node=nd.name, py_nodes=nd.gen.py_ast);
}

impl PyJacAstLinkPass.exit_archetype(nd: Archetype) -> None {
    self.link_jac_py_nodes(jac_node=nd.name, py_nodes=nd.gen.py_ast);
    if isinstance(nd.body, ImplDef) {
        self.link_jac_py_nodes(jac_node=nd.body, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_module_path(nd: ModulePath) -> None {
    if nd.alias {
        self.link_jac_py_nodes(jac_node=nd.alias, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.link_jac_py_nodes(
    jac_node: UniNode, py_nodes: list[ast3.AST]
) -> None {
    if (
        isinstance(jac_node, ContextAwareNode)
        and jac_node.code_context == CodeContext.CLIENT
    ) {
        return;
    }
    jac_node.gen.py_ast = py_nodes;
    for i in py_nodes {
        if isinstance(i.jac_link, list) {
            i.jac_link.append(jac_node);
        }
    }
}
