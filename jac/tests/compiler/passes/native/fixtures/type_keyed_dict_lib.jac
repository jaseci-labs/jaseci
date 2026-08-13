"""Companion module for `type_keyed_dict.jac`: two of the key classes.

`Node` and `ExtLeaf` are declared here so the main fixture keys its table with
at least one class it does not itself define. Class identity in the native
backend is program-wide, not per-module, so a key minted in one module has to
answer for the same class when the table is built and probed in another.
"""

obj Node {
    has n: int = 0;
}

obj ExtLeaf(Node) {
    has e: int = 4;
}
