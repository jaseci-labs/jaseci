import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind }
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    cond_is_data_dependent,
    has_torch_compile_decorator
}

impl GraphBreakDetectPass.before_pass -> None {
    self._enabled = self.prog._compile_options.graphmend;
    if not self._enabled {
        self.prune_signal = True;
        return;
    }
    self._entry_ids = self._collect_entry_points();
    if not self._entry_ids {
        self._enabled = False;
        self.prune_signal = True;
    }
}

impl GraphBreakDetectPass._collect_entry_points -> set[int] {
    ids: set[int] = set();
    for ab in self.ir_in.get_all_sub_nodes(uni.Ability) {
        if has_torch_compile_decorator(ab) {
            ids.add(id(ab));
        }
    }
    for arch in self.ir_in.get_all_sub_nodes(uni.Archetype) {
        if has_torch_compile_decorator(arch) {
            ids.add(id(arch));
        }
    }
    return ids;
}

impl GraphBreakDetectPass._in_torch_compiled_scope(nd: uni.UniNode) -> bool {
    cur = nd.parent;
    while cur {
        if id(cur) in self._entry_ids {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl GraphBreakDetectPass.enter_if_stmt(nd: uni.IfStmt) -> None {
    if not self._enabled {
        return;
    }
    if isinstance(nd, uni.ElseIf) {
        return;
    }
    if not self._in_torch_compiled_scope(nd) {
        return;
    }
    if not cond_is_data_dependent(nd.condition) {
        return;
    }
    if self._body_is_only_raise(nd.body) {
        self.prog.graphmend_breaks[id(nd)] = GraphBreakKind.VAL_GUARD;
    } else {
        self.prog.graphmend_breaks[id(nd)] = GraphBreakKind.DYN_CTRL_FL;
    }
}

impl GraphBreakDetectPass._body_is_only_raise(
    body: Sequence[uni.CodeBlockStmt]
) -> bool {
    if (not body) or (len(body) != 1) {
        return False;
    }
    return isinstance(body[0], uni.RaiseStmt);
}
