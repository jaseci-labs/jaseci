glob UNTYPED: int = -1;

obj Slot {
    has trig_tag: int,
        fn: Callable[([any, any], any)];
}

obj WalkerDesc {
    has type_tag: int,
        `entry: list[Slot],
        `exit: list[Slot],
        plans: (dict[type, tuple] | None) = None;
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

glob _walk_stack: list[WalkScope] = [],
     _scope_of: dict[int, WalkScope] = {};

def scope_of(wlk: any) -> (WalkScope | None) {
    return _scope_of.get(id(wlk));
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

glob _match_slots: dict[int, list[Slot]] = {},
     _match_by_tag: dict[int, dict[int, list[Slot]]] = {};

def run_typed(
    rt: OspRuntime, scope: WalkScope, slots: list[Slot], a: any, b: any, btag: int
) -> None {
    if not slots {
        return;
    }
    key: int = id(slots);
    if _match_slots.get(key) is not slots {
        _match_slots[key] = slots;
        _match_by_tag[key] = {};
    }
    per_tag: dict[int, list[Slot]] = _match_by_tag[key];
    matched: (list[Slot] | None) = per_tag.get(btag);
    if matched is None {
        matched = [];
        for s in slots {
            if (s.trig_tag != UNTYPED) and rt.is_a(btag, s.trig_tag) {
                matched.append(s);
            }
        }
        per_tag[btag] = matched;
    }
    for s in matched {
        s.fn(a, b);
        if scope.disengaged or scope.skip_node {
            return;
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

def _plan_for(
    rt: OspRuntime,
    wdesc: WalkerDesc,
    wtag: int,
    ndesc: NodeDesc,
    plans: dict,
    cls: type
) -> tuple {
    ctag: int = ndesc.type_tag;
    w_entry: list[Slot] = [];
    for s in wdesc.`entry {
        if s.trig_tag != UNTYPED and rt.is_a(ctag, s.trig_tag) {
            w_entry.append(s);
        }
    }
    w_exit: list[Slot] = [];
    for s in wdesc.`exit {
        if s.trig_tag != UNTYPED and rt.is_a(ctag, s.trig_tag) {
            w_exit.append(s);
        }
    }
    n_entry_u: list[Slot] = [];
    n_entry_t: list[Slot] = [];
    for s in ndesc.`entry {
        if s.trig_tag == UNTYPED {
            n_entry_u.append(s);
        } elif rt.is_a(wtag, s.trig_tag) {
            n_entry_t.append(s);
        }
    }
    n_exit_u: list[Slot] = [];
    n_exit_t: list[Slot] = [];
    for s in ndesc.`exit {
        if s.trig_tag == UNTYPED {
            n_exit_u.append(s);
        } elif rt.is_a(wtag, s.trig_tag) {
            n_exit_t.append(s);
        }
    }
    plan = (w_entry, n_entry_u, n_entry_t, n_exit_t, n_exit_u, w_exit, ndesc);
    plans[cls] = plan;
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
    wlk = scope.wlk;
    plans = wdesc.plans;
    if plans is None {
        plans = {};
        wdesc.plans = plans;
    }
    stack: list[list] = [[loc, 0, 0, None]];
    while stack {
        frame = stack[-1];
        phase: int = frame[1];
        if scope.disengaged {
            return False;
        }
        if phase == 0 {
            cur = frame[0];
            scope.path.append(cur);
            cls = `type(cur);
            plan = plans.get(cls);
            if plan is None {
                ndesc = rt.node_desc(rt.tag_of(cur));
                plan = _plan_for(rt, wdesc, wtag, ndesc, plans, cls);
            }
            frame[3] = plan;
            scope.pending_fence = 0;
            for s in plan[0] {
                s.fn(wlk, cur);
                if scope.disengaged or scope.skip_node {
                    break;
                }
            }
            if scope.disengaged {
                return False;
            }
            if not scope.skip_node {
                for s in plan[1] {
                    s.fn(cur, wlk);
                    if scope.disengaged or scope.skip_node {
                        break;
                    }
                }
                if scope.disengaged {
                    return False;
                }
            }
            if not scope.skip_node {
                for s in plan[2] {
                    s.fn(cur, wlk);
                    if scope.disengaged or scope.skip_node {
                        break;
                    }
                }
                if scope.disengaged {
                    return False;
                }
            }
            scope.skip_node = False;
            frame[1] = 1;
            frame[2] = scope.pending_fence;
        } elif phase == 1 {
            child: (int | None) = None;
            if scope.fenced {
                budget: int = frame[2];
                while (budget > 0) and (child is None) {
                    if scope.front {
                        candidate = scope.front.pop();
                        budget -= 1;
                        if (not scope.ignores) or (candidate not in scope.ignores) {
                            child = candidate;
                        }
                    } else {
                        budget = 0;
                    }
                }
                frame[2] = budget;
            } else {
                child = _dequeue(scope);
            }
            if child is not None {
                stack.append([child, 0, 0, None]);
            } else {
                frame[1] = 2;
            }
        } else {
            cur = frame[0];
            plan = frame[3];
            stack.pop();
            scope.pending_fence = 0;
            for s in plan[3] {
                s.fn(cur, wlk);
                if scope.disengaged or scope.skip_node {
                    break;
                }
            }
            if scope.disengaged {
                return False;
            }
            if not scope.skip_node {
                for s in plan[4] {
                    s.fn(cur, wlk);
                    if scope.disengaged or scope.skip_node {
                        break;
                    }
                }
                if scope.disengaged {
                    return False;
                }
            }
            if not scope.skip_node {
                for s in plan[5] {
                    s.fn(wlk, cur);
                    if scope.disengaged or scope.skip_node {
                        break;
                    }
                }
                if scope.disengaged {
                    return False;
                }
            }
            scope.skip_node = False;
            if scope.fenced and (scope.pending_fence > 0) and stack {
                stack[-1][2] += scope.pending_fence;
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
    wkey: int = id(wlk);
    prev_scope = _scope_of.get(wkey);
    _scope_of[wkey] = scope;
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
        if prev_scope is None {
            _scope_of.pop(wkey, None);
        } else {
            _scope_of[wkey] = prev_scope;
        }
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
