#!/usr/bin/env python3
"""Regenerate the role accessors and constructors of the unitree (#8744 WS1b).

Inputs: jac/jaclang/compiler/frontend/unitree.jac (node declarations with
`has x: T { getter; }` role accessors and `def init(*, ...)` constructor
declarations) and jac/jaclang/compiler/frontend/roles.jac (ROLE_SLOTS: which
accessor of which class is a role edge, and its shape).

Output: jac/jaclang/compiler/frontend/unitree.impl/roles.impl.jac, holding one
getter per role slot (an edge reference with a literal edge type) and one
`init` per class
whose constructor is declared but not hand-written (scalars assigned, roles
linked, postinit called).

    python3 scripts/gen_roles.py            # rewrite the annex (then `jac fmt` it)
    python3 scripts/gen_roles.py --check    # exit 1 when the annex is stale

Plain Python: runs with no jaclang installed.
"""

from __future__ import annotations

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRONTEND = os.path.join(REPO, "jac", "jaclang", "compiler", "frontend")
UNITREE = os.path.join(FRONTEND, "unitree.jac")
ROLES = os.path.join(FRONTEND, "roles.jac")
ANNEX = os.path.join(FRONTEND, "unitree.impl", "roles.impl.jac")

HEADER = (
    "# Auto-generated role accessors and constructors (#8744 WS1b).\n"
    "# DO NOT EDIT MANUALLY - regenerate with `python3 scripts/gen_roles.py`."
)
BODY_IMPLOF = {"AstImplNeedingNode"}
OVERRIDES = {
    ("ImplDef", "decl_link"): (
        "(UniNode | None)",
        "found = [self<-:ImplOf:<-];\n    return found[0] if found else None;",
    )
}


def pascal(name: str) -> str:
    return "".join(p.capitalize() for p in name.split("_"))


def role_cls(name: str) -> str:
    return pascal(name) + "Role"


def split_top(text: str, sep: str) -> list[str]:
    parts, depth, cur = [], 0, []
    for c in text:
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == sep and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(c)
    parts.append("".join(cur))
    return [p for p in parts if p.strip()]


def load_slots() -> dict[str, list[tuple[str, str]]]:
    src = open(ROLES, encoding="utf-8").read()
    m = re.search(r"glob ROLE_SLOTS[^=]*=\s*\((.*?)\n\s*\);", src, re.S)
    if not m:
        raise SystemExit("gen_roles: ROLE_SLOTS not found in roles.jac")
    out: dict[str, list[tuple[str, str]]] = {}
    for row in re.findall(r'\("(\w+)", "(\w+)", "(\w+)"\)', m.group(1)):
        out.setdefault(row[0], []).append((row[1], row[2]))
    return out


def class_blocks(src: str):
    for m in re.finditer(
        r"^node (\w+)(\[[^\]]*\])?(\([^)]*\))? \{\n(.*?)^\}\n", src, re.S | re.M
    ):
        yield m.group(1), m.group(4)


def accessor_type(body: str, field: str) -> str | None:
    m = re.search(
        r"^\s*has " + re.escape(field) + r": (.+?) \{ getter; \}", body, re.M
    )
    return m.group(1) if m else None


def init_decl(body: str) -> str | None:
    m = re.search(r"^\s*def init\((.*?)\) -> None;", body, re.S | re.M)
    return m.group(1) if m else None


def generate() -> str:
    slots = load_slots()
    src = open(UNITREE, encoding="utf-8").read()
    role_names = sorted({f for rows in slots.values() for f, _ in rows})
    out = [
        "import from collections.abc { Sequence }",
        "import from jaclang.compiler.frontend.roles {\n    "
        + ",\n    ".join(["ImplOf"] + [role_cls(n) for n in role_names])
        + "\n}",
    ]
    inits: list[str] = []
    for cname, body in class_blocks(src):
        for (oc, of), (otyp, obody) in OVERRIDES.items():
            if oc == cname:
                out.append(f"impl {cname}.{of}.getter -> {otyp} {{\n    {obody}\n}}")
        own = slots.get(cname, [])
        for fname, kind in own:
            typ = accessor_type(body, fname)
            if typ is None:
                raise SystemExit(f"gen_roles: {cname}.{fname} has no getter declaration")
            rc = role_cls(fname)
            if cname in BODY_IMPLOF and fname == "body":
                lines = [
                    "    impl_of = [self->:ImplOf:->];",
                    "    if impl_of {",
                    "        return impl_of[0];",
                    "    }",
                    f"    return self._role_shaped({rc}, [self->:{rc}:->]);",
                ]
            elif kind == "many":
                lines = [f"    return [self->:{rc}:->];"]
            elif kind == "one" and _is_optional(typ):
                lines = [f"    found = [self->:{rc}:->];", "    return found[0] if found else None;"]
            elif kind == "one":
                lines = [f"    return [self->:{rc}:->][0];"]
            else:
                lines = [f"    return self._role_shaped({rc}, [self->:{rc}:->]);"]
            out.append(f"impl {cname}.{fname}.getter -> {typ} {{\n" + "\n".join(lines) + "\n}")
        if cname not in hand_written_reprs():
            fwd = next((b for b in _mro_list(src, cname) if b in hand_written_reprs()), None)
            body_line = (
                f"    return {fwd}.__repr__(self);"
                if fwd
                else '    return f"{type(self).__name__}";'
            )
            out.append(f"impl {cname}.__repr__ -> str {{\n{body_line}\n}}")
        params = init_decl(body)
        if params is None or cname in hand_written_inits():
            continue
        names = []
        for p in split_top(params, ","):
            p = p.strip()
            if p == "*":
                continue
            names.append(p.split(":", 1)[0].strip())
        rnames = set()
        for other, rows in slots.items():
            if other == cname or re.search(r"^node " + cname + r"[\[(].*\b" + other + r"\b", src, re.M):
                for f, _ in rows:
                    rnames.add(f)
        # roles reachable through any base: use the accessor declarations of the MRO
        # conservatively, a param is a role iff some class declares it as a slot
        all_role_fields = {f for rows in slots.values() for f, _ in rows}
        lines = [f"impl {cname}.init({params}) -> None {{"]
        role_args = []
        for n in names:
            if n == "kid":
                continue
            if n in all_role_fields and accessor_type(body, n) is not None or n in rnames:
                role_args.append(n)
            elif n in all_role_fields and _declared_as_role_upstream(src, cname, n, slots):
                role_args.append(n)
            else:
                lines.append(f"    self.{n} = {n};")
        lines.append(
            "    self._link(kid, {" + ", ".join(f"{role_cls(n)}: {n}" for n in role_args) + "});"
        )
        lines.append("    self.postinit();")
        lines.append("}")
        inits.append("\n".join(lines))
    out.append("")
    out.extend(inits)
    return "\n\n".join(out) + "\n"


def _is_optional(typ: str) -> bool:
    t = typ.strip()
    while t.startswith("(") and t.endswith(")"):
        t = t[1:-1].strip()
    return "None" in [a.strip() for a in split_top(t, "|")]


_HAND_WRITTEN: set[str] | None = None


def hand_written_inits() -> set[str]:
    """Classes whose init is written by hand in unitree.jac or any of its annexes."""
    global _HAND_WRITTEN
    if _HAND_WRITTEN is None:
        found: set[str] = set()
        paths = [UNITREE, os.path.join(FRONTEND, "impl", "unitree.impl.jac")]
        annex_dir = os.path.join(FRONTEND, "unitree.impl")
        for fn in sorted(os.listdir(annex_dir)):
            if fn.endswith(".jac") and fn != "roles.impl.jac":
                paths.append(os.path.join(annex_dir, fn))
        for path in paths:
            text = open(path, encoding="utf-8").read()
            found.update(re.findall(r"^impl (\w+)\.init\(", text, re.M))
        _HAND_WRITTEN = found
    return _HAND_WRITTEN


def _bases_of(src: str, cname: str) -> list[str]:
    m = re.search(r"^node " + re.escape(cname) + r"(?:\[[^\]]*\])?\(([^)]*)\)", src, re.M)
    if not m:
        return []
    return [x.strip() for x in m.group(1).split(",") if x.strip()]


def _mro_list(src: str, cname: str) -> list[str]:
    """Base classes in method-resolution order, approximated breadth-first."""
    out: list[str] = []
    queue = _bases_of(src, cname)
    while queue:
        b = queue.pop(0)
        if b not in out:
            out.append(b)
            queue.extend(_bases_of(src, b))
    return out


_HAND_REPR: set[str] | None = None


def hand_written_reprs() -> set[str]:
    global _HAND_REPR
    if _HAND_REPR is None:
        found: set[str] = set()
        paths = [UNITREE, os.path.join(FRONTEND, "impl", "unitree.impl.jac")]
        annex_dir = os.path.join(FRONTEND, "unitree.impl")
        for fn in sorted(os.listdir(annex_dir)):
            if fn.endswith(".jac") and fn != "roles.impl.jac":
                paths.append(os.path.join(annex_dir, fn))
        for path in paths:
            text = open(path, encoding="utf-8").read()
            found.update(re.findall(r"^impl (\w+)\.__repr__", text, re.M))
        _HAND_REPR = found
    return _HAND_REPR


def _mro_bases(src: str, cname: str, seen: set[str] | None = None) -> set[str]:
    seen = seen or set()
    m = re.search(r"^node " + re.escape(cname) + r"(?:\[[^\]]*\])?\(([^)]*)\)", src, re.M)
    if not m:
        return seen
    for b in [x.strip() for x in m.group(1).split(",") if x.strip()]:
        if b not in seen:
            seen.add(b)
            _mro_bases(src, b, seen)
    return seen


def _declared_as_role_upstream(src: str, cname: str, field: str, slots) -> bool:
    for base in _mro_bases(src, cname):
        if any(f == field for f, _ in slots.get(base, [])):
            return True
    return False


def main() -> int:
    content = generate()
    if "--check" in sys.argv:
        current = open(ANNEX, encoding="utf-8").read() if os.path.exists(ANNEX) else ""
        # `jac fmt` rewraps long generated lines after regeneration, so freshness
        # is judged whitespace-blind: any content drift still fails.
        if "".join(current.split()) != "".join(content.split()):
            print("gen_roles: roles.impl.jac is stale; run python3 scripts/gen_roles.py && jac fmt on the annex", file=sys.stderr)
            return 1
        print("gen_roles: roles.impl.jac is current")
        return 0
    with open(ANNEX, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"gen_roles: wrote {ANNEX} ({len(content)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
