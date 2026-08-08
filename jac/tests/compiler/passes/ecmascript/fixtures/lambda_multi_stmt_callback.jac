"""Multi-statement lambda passed as a callback argument (client parity probe).

The client target lowers multi-statement lambdas to inline ArrowFunctionExpression
nodes with a BlockStatement body — no cross-scope hoist — so callback positions such
as ``map``/``sort`` ``key=`` work the same as assignment RHS.
"""

def:pub map_multi_stmt_callback -> int {
    total = 0;
    for v in map(
        lambda (x: int) -> int {
            y = x + 1;
            return y * 2;
        },
        [1, 2, 3]
    ) {
        total = total + v;
    }
    return total;
}

def:pub sort_multi_stmt_key -> int {
    items = [31, 12, 23];
    items.sort(
        key=lambda (x: int) -> int {
            t = x % 10;
            return t;
        }
    );
    return items[0] * 100 + items[1] * 10 + items[2];
}
