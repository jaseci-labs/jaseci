#!/usr/bin/env python3
"""The zero-bytecode frame census: the #8288 arc's meter.

Counts Python frames entered inside jaclang modules while a jac program
compiles, bucketed by pipeline role. A merge into the integration branch
must never increase a pipeline bucket; the arc is complete when every
bucket outside the enumerated rim reads zero (and M4 then deletes the rim
entries themselves).

Buckets:
  parser    -- lexing/parsing/materialization; native-served in sealed
               images, so dev-mode counts here are expected and excluded
               from the trend line.
  passes    -- the sealed pass tier's modules. Rungs 3-4 drive this to 0.
  typesys   -- evaluator/checker/type-system. M2 drives this to 0.
  codegen   -- the JCIR emitter + bytecode seat. Emitter goes with the
               pass tier; the seat falls at M3.
  rim       -- driver, schedule, program plumbing. Shrinks through M1;
               M4 deletes what remains.
  other     -- everything else under jaclang (bootstrap, stdlib shims).

Bucket order is load-bearing: the first prefix that matches wins, and
`typesys` is tested before `passes` because the type checker lives at
`compiler/passes/main/type_checker_pass.jac`, inside the `compiler/passes/`
catch-all. It was bucketed as `passes` until that ordering was fixed, which
put the half of M2's work with the visitor in it on the pass tier's line and
left `typesys` reading only the evaluator's own frames. The baselines beside
this file predate the fix and have to be regenerated cold before they are
compared against; on chess the correction is +4,076 frames.

That correction is small, and the reason is worth knowing before `typesys` is
read as M2's whole cost: a pass's *traversal* is billed to
`jac0core/passes/uni_pass.jac`, because `UniPass.traverse` / `enter_node` /
`exit_node` are the frames that walk the tree no matter which pass is walking
it. A pass module's own count is only its `enter_*` / `exit_*` bodies -- 4,076
of chess's 50.8M `passes` frames for the checker. So `typesys` reaching zero
would mean the type system's *bodies* are gone, not the walk that drives them,
and `passes` cannot reach zero until every pass on the schedule is sealed,
type checker included. The trend line sums both, which is why it is the number
the arc is graded on.

Usage:
  .venv/bin/python jac/scripts/zb_frame_census.py TARGET.jac [--json OUT]

Cold-cache runs are the comparable ones:  rm -rf ~/.cache/jac/jir first.
"""

import collections
import json
import os
import sys

BUCKET_PREFIXES = [
    ("parser", (
        "jac0core/lexer",
        "jac0core/parser",
        "jac0core/unitree",
        "jac0core/impl/unitree",
        "compiler/native_materialize",
    )),
    # Tested before "passes": the checker sits under compiler/passes/main/,
    # which the pass tier's catch-all would otherwise claim.
    ("typesys", (
        "compiler/type_system/",
        "jac0core/type_system/",
        "compiler/passes/main/type_checker_pass",
        "compiler/passes/main/impl/type_checker_pass",
    )),
    ("passes", (
        "jac0core/passes/annex_pass",
        "jac0core/passes/module_codegen_pass",
        "jac0core/passes/uni_pass",
        "jac0core/passes/endpoint_effect_pass",
        "jac0core/passes/ast_validation_pass",
        "jac0core/passes/semantic_analysis_pass",
        "jac0core/passes/sym_tab_build_pass",
        "jac0core/passes/decl_impl_match_pass",
        "jac0core/passes/cfg_build",
        "jac0core/passes/dataflow",
        "compiler/passes/main/sem_def_match_pass",
        "compiler/passes/main/access_check_pass",
        "compiler/passes/main/jsx_intrinsic_guard_pass",
        "compiler/passes/main/capability_check_pass",
        "compiler/passes/main/boundary_analysis",
        "compiler/passes/",
    )),
    ("codegen", (
        "jac0core/passes/jcir_gen_pass",
        "jac0core/passes/jcir_bc_gen_pass",
        "jac0core/codegen_ir",
        "jac0core/codegen_shim",
        "jac0core/jcir_facts",
    )),
    ("rim", (
        "jac0core/program",
        "jac0core/compiler",
        "jac0core/transform",
        "jac0core/passes/transform",
        "jac0core/passes/pass_serve",
        "jac0core/compile_options",
        "jac0core/jir",
    )),
]


def bucket_of(rel: str) -> str:
    stem = rel
    for ext in (".jac", ".py", ".impl.jac"):
        if stem.endswith(ext):
            stem = stem[: -len(ext)]
    for name, prefixes in BUCKET_PREFIXES:
        for p in prefixes:
            if stem.startswith(p) or rel.startswith(p):
                return name
    return "other"


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--json"]
    out_path = None
    if "--json" in sys.argv:
        out_path = sys.argv[sys.argv.index("--json") + 1]
        args = [a for a in args if a != out_path]
    if not args:
        print(__doc__)
        return 2
    target = os.path.abspath(args[0])

    import jaclang  # noqa: F401  (bootstrap happens here, uncounted)

    jroot = os.path.dirname(os.path.abspath(jaclang.__file__)) + os.sep
    from jaclang.jac0core.program import JacProgram

    counts: collections.Counter = collections.Counter()
    mon = sys.monitoring
    tool = 3
    mon.use_tool_id(tool, "zb-frame-census")

    def on_start(code, _off):
        fn = code.co_filename
        if fn.startswith(jroot):
            counts[fn[len(jroot):]] += 1

    mon.register_callback(tool, mon.events.PY_START, on_start)
    prog = JacProgram()
    mon.set_events(tool, mon.events.PY_START)
    try:
        prog.compile(file_path=target, type_check=True)
    finally:
        mon.set_events(tool, mon.events.NO_EVENTS)
        mon.free_tool_id(tool)

    errors = len(prog.errors_had)
    buckets: collections.Counter = collections.Counter()
    per_module: dict = {}
    for rel, n in counts.items():
        b = bucket_of(rel)
        buckets[b] += n
        per_module.setdefault(b, {})[rel] = n

    trend = sum(buckets[b] for b in ("passes", "typesys", "codegen"))
    report = {
        "target": os.path.relpath(target),
        "errors": errors,
        "buckets": dict(buckets),
        "trend_line": trend,
        "total": sum(buckets.values()),
        "modules": {
            b: dict(sorted(m.items(), key=lambda kv: -kv[1])[:12])
            for b, m in per_module.items()
        },
    }
    print(f"target:     {report['target']}")
    print(f"errors:     {errors}")
    for b in ("parser", "passes", "typesys", "codegen", "rim", "other"):
        print(f"{b:>10}: {buckets.get(b, 0):>12,}")
    print(f"{'TREND':>10}: {trend:>12,}   (passes+typesys+codegen; must reach 0)")
    if out_path:
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=1, sort_keys=True)
        print(f"json:       {out_path}")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
