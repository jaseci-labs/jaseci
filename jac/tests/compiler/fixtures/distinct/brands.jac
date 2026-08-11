"""Valid erased-distinct-type flows: brand, decay, cast, erasure."""

type UserId = distinct int;
type GroupId = distinct int;


def mk_user(raw: int) -> UserId {
    return UserId(raw);
}


def double_user(u: UserId) -> int {
    return u * 2;
}


def runtime_erased(raw: int) -> bool {
    return type(mk_user(raw)) is int;
}
