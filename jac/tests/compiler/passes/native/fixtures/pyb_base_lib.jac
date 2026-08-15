"""A base class that stays Python-side.

The `abc` import keeps this module out of any native closure (the same
placement poison that keeps `Transform`/`UniPass` Python-side in the
compiler's own tree), so a native unit inheriting `PyBase` must reach its
members through the Python-object interop bridge rather than a native
layout.
"""
import from abc { ABC }

obj PyBase(ABC) {
    has label: str = "none",
        count: int = 0,
        trace: str = "";

    def postinit -> None {
        self.trace = self.trace + "|base";
        self.count = self.count + 10;
    }

    def bump(n: int) -> int {
        self.count += n;
        return self.count;
    }
}
