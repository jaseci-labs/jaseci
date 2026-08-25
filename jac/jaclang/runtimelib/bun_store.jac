obj BunStore {
    has _ready: bool = False,
        _sql: (any | None) = None;

    def postinit -> None;
}
