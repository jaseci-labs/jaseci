"""Native `codecs` floor (Mechanism B -- pure Jac, no FFI).

Incremental UTF-8 decoding with CPython's `errors='replace'` semantics:
a multibyte sequence split across two feeds stays buffered until complete,
structurally invalid bytes become U+FFFD, and a truncated-but-valid prefix
at end-of-input becomes U+FFFD only when the stream is finished
(`decode(b"", final=True)`), mirroring CPython's incrementaldecoder contract
(`decode(data)` then `decode(b"", True)`).

Provided surface:
- `getincrementaldecoder(encoding) -> IncrementalDecoder` factory
  (CPython-shaped: `getincrementaldecoder("utf-8")(errors="replace")`
  instantiates `IncrementalDecoder`).
- `IncrementalDecoder.decode(data, final=False) -> str` and `.reset()`.
  DIVERGENCE: CPython's `errors=` is fixed at construction and `decode`
  takes no `final`; here `final` is an extra keyword and `errors` may be
  overridden per call ("strict" raises ValueError, anything else replaces).
- `decode(data, encoding="utf-8", errors="strict")` one-shot module helper.

Only UTF-8 is implemented; requesting another encoding raises ValueError.
Strict-mode errors raise `ValueError` (CPython raises UnicodeDecodeError,
a ValueError subclass, so `except ValueError` behaves identically).

Per-byte structural validation follows the UTF-8 DFA ranges: legal start
bytes C2..F4, continuations 80..BF, overlong and surrogate forms rejected
(E0 after A0..BF required, ED after 80..9F required, F0 after 90..BF,
F4 after 80..8F). Under 'replace', an invalid maximal subpart yields ONE
U+FFFD per rejected sequence start (close to, but not byte-lawyer exact
with, CPython's maximal-subpart rule for exotic inputs).
"""

obj:pub IncrementalDecoder {
    has errors: str = "strict",
        _pending: bytes = b"";

    def init(errors: str = "strict") {
        self.errors = errors;
    }

    def reset() {
        self._pending = b"";
    }

    def decode(data: bytes, final: bool = False) -> str {
        buf: bytes = self._pending;
        if len(data) > 0 {
            if len(buf) == 0 {
                buf = data;
            } else {
                buf = buf + data;
            }
        }
        out: str = "";
        n: int = len(buf);
        i: int = 0;
        while i < n {
            b0: int = buf[i];
            need: int = 0;
            lo: int = 0x80;
            hi: int = 0xBF;
            ok: bool = True;
            if b0 < 0x80 {
                out += chr(b0);
                i += 1;
                continue;
            } elif b0 >= 0xC2 and b0 <= 0xDF {
                need = 1;
            } elif b0 == 0xE0 {
                need = 2;
                lo = 0xA0;
            } elif b0 >= 0xE1 and b0 <= 0xEC {
                need = 2;
            } elif b0 == 0xED {
                need = 2;
                hi = 0x9F;
            } elif b0 >= 0xEE and b0 <= 0xEF {
                need = 2;
            } elif b0 == 0xF0 {
                need = 3;
                lo = 0x90;
            } elif b0 >= 0xF1 and b0 <= 0xF3 {
                need = 3;
            } elif b0 == 0xF4 {
                need = 3;
                hi = 0x8F;
            } else {
                ok = False;
            }
            if not ok {
                if not self._replace() {
                    raise ValueError("invalid start byte at " + str(i));
                }
                out += "\uFFFD";
                i += 1;
                continue;
            }
            if i + need > n - 1 {
                # incomplete sequence at buffer end: buffer it unless final
                if final {
                    if not self._replace() {
                        raise ValueError(
                            "incomplete multibyte sequence at end of input"
                        );
                    }
                    # one replacement for the whole truncated tail
                    out += "\uFFFD";
                    i = n;
                    continue;
                }
                break;
            }
            cp: int = b0 & 0xFF;
            j: int = 1;
            good: bool = True;
            while j <= need {
                bj: int = buf[i + j];
                lim_lo: int = lo;
                lim_hi: int = hi;
                if j > 1 {
                    lim_lo = 0x80;
                    lim_hi = 0xBF;
                }
                if bj < lim_lo or bj > lim_hi {
                    good = False;
                    break;
                }
                cp = cp * 64 + (bj & 0x3F);
                j += 1;
            }
            if not good {
                if not self._replace() {
                    raise ValueError("invalid continuation byte");
                }
                # one replacement for the rejected subpart; resume at the
                # first offending byte (CPython maximal-subpart behavior)
                out += "\uFFFD";
                i += j;
                continue;
            }
            out += chr(cp);
            i += need + 1;
        }
        if final or i >= n {
            self._pending = b"";
        } else {
            self._pending = buf[i:n];
        }
        return out;
    }

    def _replace() -> bool {
        return self.errors != "strict";
    }

    def getstate -> tuple[(int, int)] {
        return (len(self._pending), 0);
    }
}


def _check_utf8(name: str) {
    low: str = name.lower().replace("-", "_");
    if low != "utf_8" and low != "utf8" and low != "cp65001" {
        raise ValueError("unknown encoding: " + name + " (na codecs floor: utf-8 only)");
    }
}


def:pub getincrementaldecoder(encoding: str) -> any {
    _check_utf8(encoding);
    return IncrementalDecoder;
}


def:pub lookup(encoding: str) -> bool {
    try {
        _check_utf8(encoding);
    } except ValueError {
        return False;
    }
    return True;
}


def:pub decode(data: bytes, encoding: str = "utf-8", errors: str = "strict") -> str {
    _check_utf8(encoding);
    dec: IncrementalDecoder = IncrementalDecoder(errors=errors);
    return dec.decode(data, final=True);
}
