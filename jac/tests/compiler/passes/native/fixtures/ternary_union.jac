"""Mixed-representation conditional expressions.

`a if cond else b` must unify the two branch representations before it can
build a phi, and the rule it uses is the one declared multi-member unions
already use: branches that share a lowering keep it, an all-pointer pair
keeps the first member's layout, and a genuinely mixed pair (pointer vs
i64) boxes to a tagged jacval.

Before the fix the mixed pairs emitted a phi whose incoming values had
different LLVM types (a List pointer phi fed an i64 constant), which the IR
parser rejects, so the whole module failed to lower and the workaround was
an `any`-typed local plus an if/else assignment.

`same_rep` and `all_ptr` pin the free half of the rule: a shared lowering
and an all-pointer pair must keep lowering exactly as they do today, with
no boxing anywhere in the function.

`probe` reads back through the boxed value so the tests check the payload
survived, not merely that the module compiled: an int arrives as itself, a
container arrives as the negation of its length.
"""

def probe(v: any) -> int {
    if isinstance(v, int) {
        return v;
    }
    return 0 - len(v);
}


def same_rep(n: int) -> int {
    x = n * 2 if n > 0 else n * 3;
    return x + 1;
}


def all_ptr(flag: int) -> int {
    v = [1, 2, 3] if flag > 0 else ["a", "b"];
    return len(v);
}


def mixed_rep(flag: int) -> int {
    v = [1, 2, 3] if flag > 0 else 7;
    return probe(v);
}


def call_arg(flag: int) -> int {
    return probe([1, 2, 3, 4] if flag > 0 else 9);
}


def nested(flag: int) -> int {
    v = [1, 2, 3] if flag > 1 else (["a", "b"] if flag > 0 else 5);
    return probe(v);
}
