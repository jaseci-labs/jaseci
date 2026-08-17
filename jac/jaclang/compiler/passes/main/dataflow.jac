"""Worklist dataflow over a CFG, shared by the ownership and rc-facts passes.

Both consumers join sets of symbol identities, so the lattice element is
`set[SymId]` -- an alias for `set[int]` -- rather than a bare `set`. That is
not a cosmetic annotation: a bare `set` is element-erased, and the native lane
has no storage for an erased element, so every join here lowered to nothing
and demoted both solvers (and, by cascade, every consumer method that called
one) out of the sealed artifact. Keeping the element type concrete is what
lets this module ride natively inside its consumers' closures.

It stays a closure member rather than a seal root of its own: with only two
functions, an artifact rooted here would be all plumbing and no served
surface.
"""

import from collections.abc { Callable }
import from typing { TypeAlias }
import from jaclang.jac0core.unitree { UniCFGNode }

glob SymId: TypeAlias = int,
     DataflowTransfer: TypeAlias = Callable[[UniCFGNode, set[SymId]], set[SymId]];

def _state_at(state: dict[int, set[SymId]], key: int) -> set[SymId] {
    _cur = state.get(key);
    if _cur is None {
        _empty: set[SymId] = set();
        return _empty;
    }
    return _cur;
}

def solve_forward(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]] {
    state: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        _seed: set[SymId] = set();
        state[id(n)] = _seed;
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        new_state: set[SymId] = set();
        for pred in n.bb_in {
            for x in transfer(pred, _state_at(state, id(pred))) {
                new_state.add(x);
            }
        }
        if new_state != _state_at(state, id(n)) {
            state[id(n)] = new_state;
            for nb in n.bb_out {
                worklist.append(nb);
            }
        }
    }
    return state;
}

def solve_backward(
    cfg_nodes: list[UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]] {
    state: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        _seed: set[SymId] = set();
        state[id(n)] = _seed;
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        joined: set[SymId] = set();
        for succ in n.bb_out {
            for x in _state_at(state, id(succ)) {
                joined.add(x);
            }
        }
        new_state = transfer(n, joined);
        if new_state != _state_at(state, id(n)) {
            state[id(n)] = new_state;
            for nb in n.bb_in {
                worklist.append(nb);
            }
        }
    }
    return state;
}
