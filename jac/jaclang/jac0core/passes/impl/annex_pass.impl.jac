impl JacAnnexPass.transform(self: JacAnnexPass, ir_in: Module) -> Module {
    for annex_mod in ir_in.annex_mods {
        self._merge_annex(ir_in, annex_mod);
    }
    ir_in.annex_mods = [];
    return ir_in;
}

impl JacAnnexPass._merge_annex(
    self: JacAnnexPass, nd: Module, annex_mod: Module
) -> None {
    stmts = list(annex_mod.body);
    if not stmts {
        return;
    }
    nd.body = [*nd.body, *stmts];
    nd.add_kids_right(stmts, pos_update=False, parent_update=True);
    for sub in annex_mod._in_mod_nodes {
        if sub is not annex_mod {
            nd._in_mod_nodes.append(sub);
        }
    }
}
