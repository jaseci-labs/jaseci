glob ct: any = None,
     reflect: any = None,
     target: any = None;


def fail(msg: str) {
    raise RuntimeError(f"comptime: {msg}");
}
