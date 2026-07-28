"""Client variant with its own declarations."""


variant client;
obj Display {
    has label: str;
    def render -> str;
}
