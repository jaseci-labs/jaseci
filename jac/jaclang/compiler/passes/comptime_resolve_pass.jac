import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree {
    Ability,
    AssertStmt,
    Assignment,
    GlobalVars,
    IfStmt,
    Import,
    InForStmt,
    ParamVar,
    TypeParam,
    UniNode
}

def _is_comptime_marker(nd: UniNode) -> bool {
    if isinstance(nd, GlobalVars) {
        return nd.is_frozen;
    }
    if isinstance(
        nd,
        (
            Ability,
            AssertStmt,
            Assignment,
            IfStmt,
            Import,
            InForStmt,
            ParamVar,
            TypeParam
        )
    ) {
        return nd.is_comptime;
    }
    return False;
}

def comptime_reach(top: UniNode) -> set[int] {
    keep: set[int] = set();
    stack: list[UniNode] = [top];
    marked: list[UniNode] = [];
    while stack {
        nd = stack.pop();
        if _is_comptime_marker(nd) {
            marked.append(nd);
        }
        for k in nd.kid {
            if k {
                stack.append(k);
            }
        }
    }
    for m in marked {
        cur: (UniNode | None) = m;
        while cur is not None and id(cur) not in keep {
            keep.add(id(cur));
            cur = cur.parent;
        }
        inner: list[UniNode] = [m];
        while inner {
            nd = inner.pop();
            keep.add(id(nd));
            for k in nd.kid {
                if k {
                    inner.append(k);
                }
            }
        }
    }
    return keep;
}

walker ComptimeResolvePass(TypeCheckPass) {
    has _armed: bool = False,
        _keep: set[int] = set();

    static has PROVIDES: tuple = ('comptime', ),
        HOST_PASS: bool = True;

    def init(prog: JacProgram, **kwargs: any) {
        self._keep = set();
        self._armed = False;
        super.init(prog, **kwargs);
    }

    override def before_pass() {
        self._keep = comptime_reach(self.ir_in);
        self._armed = bool(self._keep) and not self.ir_in.ct_resolved;
        if self._armed {
            super.before_pass();
        }
    }

    override def after_pass() -> None {
        if not self._armed {
            return;
        }
        self.ir_in.ct_resolved = True;
        self.evaluator.ct_quiet = self._prev_ct_quiet;
        if self.evaluator._pass is self {
            self.evaluator._pass = self._prev_eval_pass;
        }
    }

    override def enter_node(nd: UniNode) -> None {
        if not self._armed or id(nd) not in self._keep {
            self.prune();
            return;
        }
        super.enter_node(nd);
    }

    override def exit_node(nd: UniNode) -> None {
        if not self._armed or id(nd) not in self._keep {
            return;
        }
        super.exit_node(nd);
    }
}
