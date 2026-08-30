glob UNTYPED: int = -1;

obj Slot {
    has trig_tag: int,
        fn: Callable[([any, any], any)];
}

obj Plan {
    has ctag: int,
        w_entry: list[Slot],
        n_entry_u: list[Slot],
        n_entry_t: list[Slot],
        n_exit_t: list[Slot],
        n_exit_u: list[Slot],
        w_exit: list[Slot];
}

obj WalkerDesc {
    has type_tag: int,
        `entry: list[Slot],
        `exit: list[Slot],
        plans: (dict[int, Plan] | None) = None;
}

obj NodeDesc {
    has type_tag: int,
        `entry: list[Slot],
        `exit: list[Slot];
}

obj WalkScope {
    has wlk: any,
        path: list[int],
        next: list[int],
        front: list[int],
        ignores: list[int],
        reports: list[any],
        disengaged: bool = False,
        next_head: int = 0,
        nested: bool = False,
        fenced: bool = False,
        pending_fence: int = 0,
        skip_node: bool = False;
}

obj OspRuntime {
    has tag_of: Callable[([any], int)],
        is_a: Callable[([int, int], bool)],
        node_desc: Callable[([int], NodeDesc)],
        on_complete: Callable[([WalkScope, bool], None)];
}

glob _walk_stack: list[WalkScope] = [];

def scope_of(wlk: any) -> (WalkScope | None) {
    i = len(_walk_stack) - 1;
    while i >= 0 {
        sc = _walk_stack[i];
        if sc.wlk is wlk {
            return sc;
        }
        i -= 1;
    }
    return None;
}

def _current_scope -> (WalkScope | None) {
    if _walk_stack {
        return _walk_stack[-1];
    }
    return None;
}

def osp_visit(targets: list[int], insert_loc: int = -1) -> bool {
    scope = _current_scope();
    if scope is None {
        return False;
    }
    filtered = targets;
    if scope.ignores {
        kept: list[int] = [];
        for t in targets {
            if t not in scope.ignores {
                kept.append(t);
            }
        }
        filtered = kept;
    }
    if not filtered {
        return False;
    }
    if insert_loc == -1 {
        scope.next.extend(filtered);
        return True;
    }
    if insert_loc == 0 {
        scope.front.extend(reversed(filtered));
        scope.fenced = True;
        scope.pending_fence += len(filtered);
        return True;
    }
    logical: list[int] = [];
    i = len(scope.front) - 1;
    while i >= 0 {
        logical.append(scope.front[i]);
        i -= 1;
    }
    j = scope.next_head;
    while j < len(scope.next) {
        logical.append(scope.next[j]);
        j += 1;
    }
    pos = insert_loc;
    if pos < -len(logical) {
        pos = 0;
    } elif pos < 0 {
        pos = pos + len(logical) + 1;
    }
    scope.front = [];
    scope.next = logical[:pos] + filtered + logical[pos:];
    scope.next_head = 0;
    return True;
}

def osp_disengage {
    scope = _current_scope();
    if scope is not None {
        scope.disengaged = True;
    }
}

def osp_skip_rest {
    scope = _current_scope();
    if scope is not None {
        scope.skip_node = True;
    }
}

def osp_report(val: any) {
    scope = _current_scope();
    if scope is not None {
        scope.reports.append(val);
    }
}

def run_typed(
    rt: OspRuntime, scope: WalkScope, slots: list[Slot], a: any, b: any, btag: int
) -> None {
    for s in slots {
        if (s.trig_tag != UNTYPED) and rt.is_a(btag, s.trig_tag) {
            s.fn(a, b);
            if scope.disengaged or scope.skip_node {
                return;
            }
        }
    }
}

def run_untyped(scope: WalkScope, slots: list[Slot], a: any, b: any) -> None {
    for s in slots {
        if s.trig_tag == UNTYPED {
            s.fn(a, b);
            if scope.disengaged or scope.skip_node {
                return;
            }
        }
    }
}

def _new_plans -> dict[int, Plan] {
    out: dict[int, Plan] = {};
    return out;
}

def _plan_for(
    rt: OspRuntime, wdesc: WalkerDesc, wtag: int, ndesc: NodeDesc, ctag: int
) -> Plan {
    plan = Plan(
        ctag=ctag,
        w_entry=[],
        n_entry_u=[],
        n_entry_t=[],
        n_exit_t=[],
        n_exit_u=[],
        w_exit=[]
    );
    for s in wdesc.`entry {
        if s.trig_tag != UNTYPED and rt.is_a(ctag, s.trig_tag) {
            plan.w_entry.append(s);
        }
    }
    for s in wdesc.`exit {
        if s.trig_tag != UNTYPED and rt.is_a(ctag, s.trig_tag) {
            plan.w_exit.append(s);
        }
    }
    for s in ndesc.`entry {
        if s.trig_tag == UNTYPED {
            plan.n_entry_u.append(s);
        } elif rt.is_a(wtag, s.trig_tag) {
            plan.n_entry_t.append(s);
        }
    }
    for s in ndesc.`exit {
        if s.trig_tag == UNTYPED {
            plan.n_exit_u.append(s);
        } elif rt.is_a(wtag, s.trig_tag) {
            plan.n_exit_t.append(s);
        }
    }
    return plan;
}

def _dequeue(scope: WalkScope) -> (int | None) {
    while scope.front {
        candidate = scope.front.pop();
        if (not scope.ignores) or (candidate not in scope.ignores) {
            return candidate;
        }
    }
    while scope.next_head < len(scope.next) {
        candidate = scope.next[scope.next_head];
        scope.next_head += 1;
        if (not scope.ignores) or (candidate not in scope.ignores) {
            return candidate;
        }
    }
    if scope.next_head > 0 {
        scope.next.clear();
        scope.next_head = 0;
    }
    return None;
}

def _visit_recursive(
    rt: OspRuntime, scope: WalkScope, wdesc: WalkerDesc, loc: int
) -> bool {
    wtag: int = wdesc.type_tag;
    if wdesc.plans is None {
        wdesc.plans = _new_plans();
    }
    plans = wdesc.plans;
    stack_loc: list[int] = [loc];
    stack_ph: list[int] = [0];
    stack_bud: list[int] = [0];
    stack_plan: list[Plan] = [];
    while stack_loc {
        top = len(stack_loc) - 1;
        phase: int = stack_ph[top];
        if scope.disengaged {
            return False;
        }
        if phase == 0 {
            cur = stack_loc[top];
            scope.path.append(cur);
            ctag: int = rt.tag_of(cur);
            if ctag in plans {
                plan = plans[ctag];
            } else {
                ndesc = rt.node_desc(ctag);
                plan = _plan_for(rt, wdesc, wtag, ndesc, ctag);
                plans[ctag] = plan;
            }
            stack_plan.append(plan);
            scope.pending_fence = 0;
            for s in plan.w_entry {
                s.fn(scope.wlk, cur);
                if scope.disengaged or scope.skip_node {
                    break;
                }
            }
            if scope.disengaged {
                return False;
            }
            if not scope.skip_node {
                for s in plan.n_entry_u {
                    s.fn(cur, scope.wlk);
                    if scope.disengaged or scope.skip_node {
                        break;
                    }
                }
                if scope.disengaged {
                    return False;
                }
            }
            if not scope.skip_node {
                for s in plan.n_entry_t {
                    s.fn(cur, scope.wlk);
                    if scope.disengaged or scope.skip_node {
                        break;
                    }
                }
                if scope.disengaged {
                    return False;
                }
            }
            scope.skip_node = False;
            stack_ph[top] = 1;
            stack_bud[top] = scope.pending_fence;
        } elif phase == 1 {
            if scope.fenced {
                budget: int = stack_bud[top];
                found = False;
                child = loc;
                while (budget > 0) and (not found) {
                    if scope.front {
                        candidate = scope.front.pop();
                        budget -= 1;
                        if (not scope.ignores) or (candidate not in scope.ignores) {
                            child = candidate;
                            found = True;
                        }
                    } else {
                        budget = 0;
                    }
                }
                stack_bud[top] = budget;
                if found {
                    stack_loc.append(child);
                    stack_ph.append(0);
                    stack_bud.append(0);
                } else {
                    stack_ph[top] = 2;
                }
            } else {
                nxt = _dequeue(scope);
                if nxt is not None {
                    stack_loc.append(nxt);
                    stack_ph.append(0);
                    stack_bud.append(0);
                } else {
                    stack_ph[top] = 2;
                }
            }
        } else {
            cur = stack_loc.pop();
            stack_ph.pop();
            stack_bud.pop();
            done_plan = stack_plan.pop();
            scope.pending_fence = 0;
            for s in done_plan.n_exit_t {
                s.fn(cur, scope.wlk);
                if scope.disengaged or scope.skip_node {
                    break;
                }
            }
            if scope.disengaged {
                return False;
            }
            if not scope.skip_node {
                for s in done_plan.n_exit_u {
                    s.fn(cur, scope.wlk);
                    if scope.disengaged or scope.skip_node {
                        break;
                    }
                }
                if scope.disengaged {
                    return False;
                }
            }
            if not scope.skip_node {
                for s in done_plan.w_exit {
                    s.fn(scope.wlk, cur);
                    if scope.disengaged or scope.skip_node {
                        break;
                    }
                }
                if scope.disengaged {
                    return False;
                }
            }
            scope.skip_node = False;
            if scope.fenced and (scope.pending_fence > 0) and stack_loc {
                ptop = len(stack_bud) - 1;
                stack_bud[ptop] = stack_bud[ptop] + scope.pending_fence;
            }
        }
    }
    return not scope.disengaged;
}

def osp_spawn(rt: OspRuntime, wlk: any, wdesc: WalkerDesc, starts: list[int]) -> any {
    scope = WalkScope(
        wlk=wlk,
        path=[],
        next=`list(starts),
        front=[],
        ignores=[],
        reports=[],
        nested=(len(_walk_stack) > 0)
    );
    _walk_stack.append(scope);
    ok = False;
    try {
        if scope.next {
            anchor = scope.next[0];

            run_untyped(scope, wdesc.`entry, wlk, anchor);
        }

        while not scope.disengaged {
            nxt = _dequeue(scope);
            if nxt is None {
                break;
            }
            if not _visit_recursive(rt, scope, wdesc, nxt) {
                break;
            }
        }

        if scope.path and (not scope.disengaged) {
            run_untyped(scope, wdesc.`exit, wlk, scope.path[-1]);
        }
        ok = True;
    } finally {
        _walk_stack.pop();
        if scope.nested and _walk_stack {
            outer = _walk_stack[-1];
            for r in scope.reports {
                outer.reports.append(r);
            }
        }
        rt.on_complete(scope, ok);
    }
    return wlk;
}
