"""Client variant (lower precedence than .sv.jac)."""


variant client;
obj Widget {
    has id: int;
    def render -> str;
}
