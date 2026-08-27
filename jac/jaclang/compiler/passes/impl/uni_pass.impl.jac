impl UniPass.postinit -> None {
    super.postinit();
}

impl UniPass.before_pass -> None { }

impl UniPass.after_pass -> None { }

impl UniPass.enter_node(nd: UniNode) -> None {
    nd.accept_enter(self);
}

impl UniPass.exit_node(nd: UniNode) -> None {
    nd.accept_exit(self);
}


impl UniPass.default_enter(nd: UniNode) -> None { }

impl UniPass.default_exit(nd: UniNode) -> None { }

impl UniPass.prune -> None {
    self.prune_signal = True;
}

impl UniPass.recalculate_parents(nd: UniNode) -> None {
    if nd {
        nd._invalidate_sub_node_tab();
    }
}

impl UniPass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    if not isinstance(ir_in, UniNode) {
        return ir_in;
    }
    self.before_pass();
    if not isinstance(ir_in, UniNode) {
        raise RuntimeError(self.ice('Current node is not an UniNode.'));
    }
    self.traverse(ir_in);
    self.after_pass();
    return self.ir_in;
}

impl UniPass.traverse(nd: UniNode) -> UniNode {
    if self.is_canceled() or nd.ct_pruned {
        return nd;
    }
    nd spawn self;
    return nd;
}

impl UniPass.enter_walk with UniNode entry {
    if self.is_canceled() or here.ct_pruned {
        return;
    }
    self.cur_node = here;
    self.enter_node(here);
    if self.prune_signal {
        self.prune_signal = False;
    } else {
        for k in here.kid {
            if k and not k.ct_pruned and not self.is_canceled() {
                k spawn self;
            }
        }
    }
}

impl UniPass.exit_walk with UniNode exit {
    if here.ct_pruned {
        return;
    }
    self.cur_node = here;
    if not self.is_canceled() {
        self.exit_node(here);
    }
}
