glob UNTYPED: int = -1;

obj Slot {
    has trig_tag: int,
        fn: Callable[([any, any], any)];
}

obj WalkerDesc {
    has type_tag: int,
        `entry: list[Slot],
        `exit: list[Slot];
}

obj NodeDesc {
    has type_tag: int,
        `entry: list[Slot],
        `exit: list[Slot];
}

"""One walk. `next` is the legacy FIFO queue (`visit x;` appends, `next_head`
is its consumed prefix). `front` is the front-splice stack: `visit:0: xs;`
pushes xs reversed, so `front.pop()` yields the next fenced child in order
and a splice costs O(len(xs)) rather than a copy of the whole queue. A
dequeue drains `front` before `next`, which is the order the old single
list gave when front-splices were inserted at index 0."""
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
        for t in filtered {
            scope.next.append(t);
        }
        return True;
    }
    if insert_loc == 0 {
        i = len(filtered) - 1;
        while i >= 0 {
            scope.front.append(filtered[i]);
            i -= 1;
        }
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

"""The walk owns its scope, so the ability loops take it as a parameter and
read `disengaged`/`skip_node` off it directly; nothing here consults the
walk stack per ability."""
def run_typed(
    rt: OspRuntime, scope: WalkScope, slots: list[Slot], a: any, b: any
) -> None {
    btag: int = rt.tag_of(b);
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
    stack_loc: list[int] = [loc];
    stack_ph: list[int] = [0];
    stack_bud: list[int] = [0];
    while stack_loc {
        cur = stack_loc.pop();
        phase = stack_ph.pop();
        budget = stack_bud.pop();
        if scope.disengaged {
            return False;
        }
        if phase == 0 {
            scope.path.append(cur);
            ndesc = rt.node_desc(rt.tag_of(cur));
            scope.pending_fence = 0;
            run_typed(rt, scope, wdesc.`entry, scope.wlk, cur);
            if scope.disengaged {
                return False;
            }
            if not scope.skip_node {
                run_untyped(scope, ndesc.`entry, cur, scope.wlk);
                if scope.disengaged {
                    return False;
                }
            }
            if not scope.skip_node {
                run_typed(rt, scope, ndesc.`entry, cur, scope.wlk);
                if scope.disengaged {
                    return False;
                }
            }
            scope.skip_node = False;

            stack_loc.append(cur);
            stack_ph.append(1);
            stack_bud.append(scope.pending_fence);
        } elif phase == 1 {
            child: (int | None) = None;
            if scope.fenced {
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
            } else {
                child = _dequeue(scope);
            }
            if child is not None {
                stack_loc.append(cur);
                stack_ph.append(1);
                stack_bud.append(budget);

                stack_loc.append(child);
                stack_ph.append(0);
                stack_bud.append(0);
            } else {
                stack_loc.append(cur);
                stack_ph.append(2);
                stack_bud.append(0);
            }
        } else {
            ndesc = rt.node_desc(rt.tag_of(cur));
            scope.pending_fence = 0;
            run_typed(rt, scope, ndesc.`exit, cur, scope.wlk);
            if scope.disengaged {
                return False;
            }
            if not scope.skip_node {
                run_untyped(scope, ndesc.`exit, cur, scope.wlk);
                if scope.disengaged {
                    return False;
                }
            }
            if not scope.skip_node {
                run_typed(rt, scope, wdesc.`exit, scope.wlk, cur);
                if scope.disengaged {
                    return False;
                }
            }
            scope.skip_node = False;
            if scope.fenced and (scope.pending_fence > 0) and stack_bud {
                stack_bud[-1] += scope.pending_fence;
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
