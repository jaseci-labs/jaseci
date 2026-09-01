"""NEGATIVE fixture: the call result feeds an addition — never a tail
call (there IS work after the call)."""
def tc_summy(n: int) -> int {
    if n == 0 {
        return 0;
    }
    return 1 + tc_summy(n - 1);
}
