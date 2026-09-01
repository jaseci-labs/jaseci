"""The native compiler kernel: materialize-once equivalence and seam guards.

The kernel (libjac_compiler) parses natively and hands Python a fully
materialized unitree. The first guard pins the one piece of role knowledge
the kernel exports by name (jc_shape3 covers exactly the roles any getter
shape-consults); the equivalence test runs only where a built kernel lib
is present, and compares the materialized tree against the store parser's
tree for the same source.
"""

import os;

glob SHAPE_EXPORTED: set[str] = {"BodyRole", "SpecRole", "AccessorsRole"};

def _frontend_dir -> str {
    import jaclang.compiler.frontend as fe;
    return os.path.dirname(os.path.abspath(fe.__file__));
}

def _shape_consulted_roles -> set[str] {
    import re;
    pat = re.compile(r"_role_shaped\(\s*(\w+)");
    found: set[str] = set();
    for rel in ("unitree.impl/roles.impl.jac", "impl/unitree.impl.jac") {
        path = os.path.join(_frontend_dir(), rel);
        if not os.path.isfile(path) {
            continue;
        }
        with open(path, encoding="utf-8") as f {
            for m in pat.finditer(f.read()) {
                if m.group(1) != "role" {
                    found.add(m.group(1));
                }
            }
        }
    }
    return found;
}

test "every shape-consulted role is exported by the kernel" {
    consulted = _shape_consulted_roles();
    assert consulted , "no _role_shaped call sites found; guard is stale";
    assert consulted <= SHAPE_EXPORTED , (
        f"roles {consulted - SHAPE_EXPORTED} are shape-consulted but not "
        "exported by jc_shape3 (jc_unit.jac); extend it and this guard."
    );
}

glob SNIPPET: str = """
obj Point {
    has x: int = 0,
        y: int = 1;

    def dist(other: Point) -> int;
}

impl Point.dist(other: Point) -> int {
    # a comment to carry through
    return abs(self.x - other.x) + abs(self.y - other.y);
}

with entry {
    p = Point(x=3, y=4);
    print(p.dist(Point()));
}
""";

def _profile(nd: any) -> list {
    out: list = [];
    stack = [nd];
    while stack {
        cur = stack.pop();
        row = [`type(cur).__name__];
        v = getattr(cur, "value", None);
        if isinstance(v, str) {
            row.append(v);
        }
        out.append(row);
        kids = list(cur.kid);
        kids.reverse();
        for k in kids {
            stack.append(k);
        }
    }
    return out;
}

test "kernel parse materializes the store parser's tree" {
    import from jaclang.compiler.native_compiler { ensure_loaded }
    kernel = ensure_loaded();
    if kernel is None {
        # No built kernel lib in this tree; nothing to compare against.
        assert True;
    } else {
        import from jaclang.compiler.frontend.parser.frontend { parse, parse_woven }
        (nat_mod, nat_err) = parse_woven(SNIPPET, "kernel_eq.jac", None, []);
        (py_mod, py_err) = parse(SNIPPET, "kernel_eq.jac");
        assert nat_err == py_err;
        assert kernel.skipped() == 0 , (
            "kernel skipped objects during materialization"
        );
        nat_prof = _profile(nat_mod);
        py_prof = _profile(py_mod);
        assert len(nat_prof) == len(py_prof);
        assert nat_prof == py_prof;
    }
}
