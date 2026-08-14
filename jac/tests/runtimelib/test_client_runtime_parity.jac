"""Signature parity across the `@jac/runtime` implementations.

One public API, three runtimes (React, Solid, react-native) plus two cores. App
code imports the same names on every target, so a name that takes different
parameters per backend is a silent portability bug.

`test_solid_backend.jac` already asserted each function *exists*
(`assert "function AuthGuard(" in js;`) -- which stayed green throughout #8023,
while React's `AuthGuard(redirect)` and Solid's `AuthGuard(redirect, children)`
disagreed. Name parity is not contract parity.

These compare the declared parameter lists: for every name in more than one
runtime, parameters must match in order, name, type, and default. Reading
declarations rather than emitted JS keeps it to a parse, no codegen.
"""

import re;
import jaclang;
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }

glob _RT = Path(jaclang.__file__).parent / "runtimelib",
     # The three router/component runtimes: one public surface, three targets.
     _ROUTER_RUNTIMES: dict[str, Path] = {
         "react": _RT / "client_runtime.jac",
         "solid": _RT / "solid_runtime.jac",
         "react-native": _RT / "client" / "client_runtime_native.jac"
     },
     # The two cores underneath them (auth, walker calls, form plumbing).
     _RUNTIME_CORES: dict[str, Path] = {
         "web": _RT / "client_runtime_core.jac",
         "native": _RT / "client" / "client_runtime_core.jac"
     };

"""Source text of a node, whitespace-collapsed, or None.

Types like `(str | dict)` have no stable rendering, so the source slice is the
comparable form."""
def _node_text(src: str, nd: any) -> (str | None) {
    if nd is None {
        return None;
    }
    return re.sub(r"\s+", " ", src[nd.loc.pos_start:nd.loc.pos_end]).strip();
}

"""True for `def:pub` -- the names app code can actually import."""
def _is_public(abl: any) -> bool {
    access = abl?.access;
    if access is None {
        return False;
    }
    tag = access?.tag;
    return tag?.value == "pub";
}

"""Map every `def:pub` in a runtime module to `[(name, type, default)]`.

Non-public helpers are excluded on purpose: parsing pulls in the `impl/` annex,
and targets may name internal arguments after whatever library they wrap
(react-form's `field` vs solid-form's `fieldApi`). Parity covers the public
surface, not private plumbing."""
def _signatures(path: Path) -> dict[str, list] {
    src = path.read_text(encoding="utf-8");
    prog = JacProgram();
    mod = prog.parse_str(src, str(path));
    assert not prog.errors_had , (
        f"{path.name} failed to parse: {[str(e) for e in prog.errors_had]}"
    );
    out: dict[str, list] = {};
    for abl in mod.get_all_sub_nodes(uni.Ability) {
        name = abl.name_ref?.value;
        if not name or not _is_public(abl) {
            continue;
        }
        params = [];
        for prm in (abl.signature.params or []) {
            type_node = prm.type_tag.tag if prm.type_tag else None;
            params.append(
                (prm.name.value, _node_text(src, type_node), _node_text(src, prm.value))
            );
        }
        out[name] = params;
    }
    return out;
}

"""Render one signature for a failure message."""
def _render(name: str, params: list) -> str {
    parts = [];
    for (pname, ptype, pdefault) in params {
        text = pname;
        if ptype {
            text += f": {ptype}";
        }
        if pdefault {
            text += f" = {pdefault}";
        }
        parts.append(text);
    }
    return f"{name}({', '.join(parts)})";
}

"""Names declared by two or more `runtimes` must have identical parameter lists.
Returns the compared names, so callers can assert the run was not vacuous."""
def _assert_parity(runtimes: dict[str, Path], label: str) -> set {
    tables = {};
    for (target, path) in runtimes.items() {
        tables[target] = _signatures(path);
    }
    shared = set();
    for name in set().union(*[set(t.keys()) for t in tables.values()]) {
        if len(
            [
                t
                for t in tables.values()
                if name in t
            ]
        )
            > 1 {
            shared.add(name);
        }
    }
    mismatches = [];
    for name in sorted(shared) {
        declared = {
            target: table[name]
            for (target, table) in tables.items()
            if name in table
        };
        if len({str(sig) for sig in declared.values()}) > 1 {
            lines = [
                f"  {target}: {_render(name, sig)}"
                for (target, sig) in declared.items()
            ];
            mismatches.append(f"{name}\n" + "\n".join(lines));
        }
    }
    assert not mismatches , (
        f"{label}: {len(mismatches)} symbol(s) declared with different "
        f"signatures across targets. `@jac/runtime` is one public API; a name "
        f"that takes different parameters per target is a portability bug.\n\n"
        + "\n\n".join(mismatches)
    );
    return shared;
}

test "router runtimes declare one signature per shared symbol" {
    shared = _assert_parity(_ROUTER_RUNTIMES, "router runtimes");
    # Anti-vacuity: a parity test that silently compares nothing is exactly the
    # failure this file exists to correct. Pin the symbols that must be covered.
    for name in ["AuthGuard", "JacForm", "useRouter", "navigate"] {
        assert name in shared , (
            f"'{name}' is no longer declared in more than one router runtime, so "
            f"parity is no longer being checked for it. If it moved, update "
            f"_ROUTER_RUNTIMES; do not drop the assertion."
        );
    }
}

test "runtime cores declare one signature per shared symbol" {
    shared = _assert_parity(_RUNTIME_CORES, "runtime cores");
    for name in ["jacIsLoggedIn", "jacLogin", "jacSignup", "jacLogout"] {
        assert name in shared , (
            f"'{name}' is no longer declared in both runtime cores, so parity is "
            f"no longer being checked for it. If it moved, update _RUNTIME_CORES; "
            f"do not drop the assertion."
        );
    }
}

test "AuthGuard takes redirect and children on every target" {
    # The specific contract #8023 turned on, pinned by name so a regression
    # reports itself rather than arriving as an anonymous parity diff. React and
    # react-native once declared `redirect` alone and discarded any wrapped page.
    for (target, path) in _ROUTER_RUNTIMES.items() {
        params = _signatures(path).get("AuthGuard");
        assert params is not None , f"{target} does not declare AuthGuard";
        assert [p[0] for p in params] == ["redirect", "children"] , (
            f"{target} declares {_render('AuthGuard', params)}; every target must "
            f"accept both `redirect` and `children` so a wrapped page renders."
        );
        assert params[0][2] == '"/login"' , (
            f"{target} AuthGuard redirect default drifted: {params[0][2]}"
        );
        assert params[1][2] == "None" , (
            f"{target} AuthGuard children default drifted: {params[1][2]}"
        );
    }
}
