"""Client codegen never runs on a module whose checker facts were not derived.

`jac build main.jac --client web` was clean on a cold cache and failed on the
very next run with `E5101: Client codegen emitted 'init', which the module
never binds`, and a served page threw `ReferenceError: enumerate is not
defined` a dozen times over. The bundle showed the shape exactly:
`_jac.builtin.iter(enumerate(rows))` -- the outer call lowered, the inner one
left as a bare name.

`FuncCall.call_kind` is stamped by the checker, and the ECMAScript backend
routes a call to the builtin emitter only when it reads `"builtin"` there. A
dependency ingested through `JacProgram.load_dependency_module` compiles under
the symtab-only schedule (no analysis, no boundary pass) and is parked in the
program hub under the same key a full compile uses, so once a warm run let the
client-boundary walk serve its facts from the cache instead of tree-compiling,
the bundle builder found that analysis-free module in the hub and emitted from
it: every builtin came out bare and the client-to-native import binding was
never generated.

The client codegen seam now demands the facts and re-derives them when they
are missing, and the emitted-bundle audit reports a bare builtin (`E5103`)
rather than shipping it, so this class cannot go silent again.
"""

import os;
import shutil;
import tempfile;
import from jaclang.client.client_bundle { _ensure_js_generated }
import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { Module }


glob _HELPER_SRC: str = (
         "def:pub label_of(i: int) -> str {\n" "    return f\"row-{i}\";\n" "}\n"
     ),
     _WIDGET_SRC: str = (
         "import from .helper { label_of }\n"
         "\n"
         "def:pub Widget(rows: list[str]) -> any {\n"
         "    out: list[str] = [];\n"
         "    for (i, r) in enumerate(rows) {\n"
         "        out.append(label_of(i) + r);\n"
         "    }\n"
         "    for k in range(3) {\n"
         "        out.append(str(k));\n"
         "    }\n"
         "    return <div>{out}</div>;\n"
         "}\n"
     );


"""Write a two-module client project; return (project dir, widget path)."""
def _project -> tuple[str, str] {
    base = tempfile.mkdtemp(prefix="jac_codegen_facts_");
    with open(os.path.join(base, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"codegenfacts\"\nkind = \"web-app\"\n");
    }
    with open(os.path.join(base, "helper.jac"), "w") as f {
        f.write(_HELPER_SRC);
    }
    widget = os.path.join(base, "widget.jac");
    with open(widget, "w") as f {
        f.write(_WIDGET_SRC);
    }
    return (base, widget);
}


"""Compile under the schedule dependency ingestion uses: symbols, no analysis."""
def _ingest_as_dependency(prog: JacProgram, path: str) -> Module {
    return prog.compile(
        path, options=CompileOptions(no_cgen=True, symtab_ir_only=True, iface_ok=True)
    );
}


def _codes(prog: JacProgram) -> list[str] {
    return [
        e.code.code
        for e in prog.errors_had
        if e.code
    ];
}


test "a second client build lowers exactly what the first one did" {
    (base, widget) = _project();
    try {
        cold = JacProgram();
        cold_mod = cold.compile(widget, options=CompileOptions(no_cgen=True));
        run_pass(EsastGenPass, cold_mod, cold);
        assert _codes(cold) == [] , _codes(cold);

        warm = JacProgram();
        warm_mod = _ingest_as_dependency(warm, widget);
        assert "TypeOf" not in warm.analysis.analyses_run.get(id(warm_mod), set()) , (
            "the dependency schedule is supposed to leave the module unanalyzed;"
            " this test no longer reproduces the warm shape"
        );

        emitted = _ensure_js_generated(warm_mod, warm);
        assert _codes(warm) == [] , _codes(warm);
        assert "TypeOf" in warm.analysis.analyses_run.get(id(emitted), set()) , (
            "client codegen ran on a module whose checker facts were never derived"
        );
        assert emitted.gen.js == cold_mod.gen.js , (
            "the warm bundle differs from the cold one:\n"
            f"cold:\n{cold_mod.gen.js}\n\nwarm:\n{emitted.gen.js}"
        );
        assert "_jac.builtin.enumerate(" in emitted.gen.js , emitted.gen.js;
        assert "_jac.builtin.range(" in emitted.gen.js , emitted.gen.js;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "an unlowered builtin in the bundle is an error, never silence" {
    (base, widget) = _project();
    try {
        prog = JacProgram();
        mod = _ingest_as_dependency(prog, widget);
        run_pass(EsastGenPass, mod, prog);
        codes = _codes(prog);
        assert "E5103" in codes , (
            f"a bare builtin call shipped without a diagnostic: {codes}\n"
            f"{mod.gen.js}"
        );
        named = [
            str(e)
            for e in prog.errors_had
            if e.code and e.code.code == "E5103"
        ];
        assert any(["enumerate" in m for m in named]) , named;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
