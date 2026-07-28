"""A str param on a regular (non-extern) def is still an unannotated heap
contract position: the extern-decl exemption must not leak to app code."""


variant native;
def open_thing(title: str) -> int {
    return len(title);
}
