import hashlib;
import json;
import marshal;
import os;
import shutil;
import sys;
import zlib;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core { ext_registry }
import from jaclang.jac0core.compiler { patch_co_filenames_bytes }
import from jaclang.jac0core.jir {
    write_precompiled_jir,
    FLAG_PRECOMPILED,
    FLAG_BOOTSTRAP,
    HEADER_SIZE,
    SECTIONS_MAGIC,
    SEC_BYTECODE,
    SEC_DEBUG_SRC,
    FORMAT_VERSION,
    compute_precompile_module_key,
    precompiled_jir_matches_source,
    running_compiler_digest,
    PRECOMPILE_SENTINEL
}
import from jaclang.jac0core.sealed {
    MANIFEST_NAME,
    MANIFEST_FORMAT,
    JIR_FORMAT_VERSION as SEALED_JIR_FORMAT_VERSION,
    PRECOMPILE_SENTINEL as SEALED_SENTINEL,
    _HEADER_SIZE as SEALED_HEADER_SIZE,
    _SECTIONS_MAGIC as SEALED_SECTIONS_MAGIC,
    _SEC_BYTECODE as SEALED_SEC_BYTECODE,
    _SEC_DEBUG_SRC as SEALED_SEC_DEBUG_SRC
}

glob RESULT_NAME: str = "PRECOMPILE_RESULT.json";

def compiler_identity -> str {
    digest = running_compiler_digest();
    if digest.startswith("0:") {
        raise RuntimeError(
            "Precompile aborted: no compiler sources found under the running "
            "jaclang package, so this build cannot state which compiler it is. "
            "Every seeded .jir would then be reusable by any other compiler at "
            "this version -- the #8178 failure mode. Check that jac0core/ and "
            "compiler/ ship with the running jaclang."
        );
    }
    return digest;
}

def find_package_dir(source_dir: str) -> str | None {
    src = Path(source_dir).resolve();
    if not src.is_dir() {
        console.error(f"Error: {source_dir} is not a directory");
        return None;
    }
    excluded: list = [
        "tests",
        "test",
        "scripts",
        "docs",
        ".git",
        ".github",
        "node_modules"
    ];

    for child in sorted(src.iterdir()) {
        if child.is_dir() and child.name not in excluded {
            init_py = child / "__init__.py";
            init_jac = child / "__init__.jac";
            if init_py.is_file() or init_jac.is_file() {
                return str(child);
            }
        }
    }
    return None;
}

def _nested_project_dirs(package_dir: str) -> list[str] {
    pkg = Path(package_dir);
    roots: list[str] = [];
    for toml in pkg.rglob("jac.toml") {
        d = toml.parent;
        if d != pkg {
            roots.append(str(d) + os.sep);
        }
    }
    return roots;
}

def find_jac_files(package_dir: str) -> list[str] {
    result: list[str] = [];
    pkg = Path(package_dir);
    for jac_file in sorted(pkg.rglob("*.jac")) {
        if not jac_file.is_file() {
            continue;
        }
        rel_path = jac_file.relative_to(pkg);
        rel = str(rel_path);

        if any(
            part.startswith(".") or part == "__pycache__" for part in rel_path.parts
        ) {
            continue;
        }

        if (
            ".test." in rel
            or "/test/" in rel
            or "/tests/" in rel
            or rel.startswith("test/")
            or rel.startswith("tests/")
            or rel.startswith(".")
            or ".impl." in jac_file.name
        ) {
            continue;
        }
        result.append(str(jac_file));
    }
    return result;
}

glob _sealable_cache: dict[str, list[str]] = {},
     _placement_cache: dict[str, dict[str, set[str]]] = {};

def sealable_sources(package_dir: str) -> list[str] {
    key = os.path.abspath(package_dir);
    cached = _sealable_cache.get(key);
    if cached is not None {
        return cached;
    }
    boot_prefix = str(Path(package_dir) / "jac0core") + os.sep;
    nested = _nested_project_dirs(package_dir);
    candidates = [
        p
        for p in find_jac_files(package_dir)
        if not p.startswith(boot_prefix) and not any(p.startswith(n) for n in nested)
    ];
    if Path(package_dir).name == "jaclang" {
        import from jaclang.jac0core.placement_facts { toolchain_native_by_policy }
        result = [
            p
            for p in candidates
            if not toolchain_native_by_policy(package_dir, p)
        ];
    } else {
        import from jaclang.jac0core.placement_facts {
            discover_spaces,
            spaces_are_client_only
        }
        import from jaclang.jac0core.program { JacProgram }
        discovery = JacProgram();
        facts = discover_spaces(candidates, discovery);
        _placement_cache[key] = facts;
        if discovery.errors_had {
            console.print(
                f"  Placement discovery hit {len(discovery.errors_had)} "
                "error(s); sealing every candidate so each failure surfaces "
                "per-file instead of being skipped."
            );
            result = candidates;
        } else {
            skipped = [
                p
                for p in candidates
                if spaces_are_client_only(facts[os.path.abspath(p)])
            ];
            result = [
                p
                for p in candidates
                if p not in skipped
            ];
            if skipped {
                names = ", ".join(
                    str(Path(p).relative_to(Path(key))) for p in skipped[:8]
                );
                console.print(
                    f"  Skipping {len(skipped)} client-only module(s): {names}"
                );
            }
        }
        discovery.release_compile_closure();
    }
    _sealable_cache[key] = result;
    return result;
}

def placement_facts_map(package_dir: str) -> dict[str, list[str]] {
    key = os.path.abspath(package_dir);
    sealable_sources(package_dir);
    facts = _placement_cache.get(key);
    if not facts {
        return {};
    }
    out: dict[str, list[str]] = {};
    for (ap, spaces) in facts.items() {
        rel = Path(ap).relative_to(Path(key)).as_posix();
        out[rel] = sorted(spaces);
    }
    return out;
}

def precompile_unit(
    jac_path: str, pkg_root: str, embed_src: bool = False
) -> bytes | None {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.program { JacProgram }

    compiler = Jac.get_compiler();

    program = JacProgram();
    code = compiler.get_bytecode(full_target=jac_path, target_program=program);
    compiler.internal_program.release_compile_closure();
    program.release_compile_closure();
    if code is None {
        return None;
    }
    patched = patch_co_filenames_bytes(
        marshal.dumps(code), pkg_root, PRECOMPILE_SENTINEL
    );
    extra: dict[int, bytes] | None = None;
    if embed_src {
        extra = {SEC_DEBUG_SRC: zlib.compress(Path(jac_path).read_bytes(), 9)};
    }
    return write_precompiled_jir(
        patched, compute_precompile_module_key(jac_path), FLAG_PRECOMPILED, extra
    );
}

def seal_bootstrap(pkg_dir: Path, out_dir: Path, embed_src: bool) -> int {
    import from jaclang.jac0 {
        compile_jac as jac0_compile,
        discover_impl_files as jac0_impls
    }
    boot_dir = pkg_dir / "jac0core";
    failed = 0;
    if not boot_dir.is_dir() {
        return failed;
    }
    for jac_file in sorted(boot_dir.rglob("*.jac")) {
        if ext_registry.is_annex(str(jac_file)) {
            continue;
        }
        if any(
            part.startswith(".") or part == "__pycache__"
            for part in jac_file.relative_to(boot_dir).parts
        ) {
            continue;
        }
        try {
            impl_paths = jac0_impls(str(jac_file));
            impl_sources: list[tuple[str, str]] = [];
            for impl_path in impl_paths {
                impl_sources.append(
                    (Path(impl_path).read_text(encoding="utf-8"), impl_path)
                );
            }
            py_source = jac0_compile(
                jac_file.read_text(encoding="utf-8"),
                str(jac_file),
                impl_sources=impl_sources or None
            );
            code = compile(py_source, str(jac_file), "exec");
            bc = patch_co_filenames_bytes(
                marshal.dumps(code), str(pkg_dir), PRECOMPILE_SENTINEL
            );
            extra: dict[int, bytes] | None = None;
            if embed_src {
                extra = {SEC_DEBUG_SRC: zlib.compress(jac_file.read_bytes(), 9)};
            }
            jir_rel = jac_file.relative_to(pkg_dir).with_suffix(".jir");
            jir_path = out_dir / jir_rel;
            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(write_precompiled_jir(bc, "", FLAG_BOOTSTRAP, extra));
        } except Exception as e {
            console.error(f"BOOTSTRAP FAIL: {jac_file.name} - {e}");
            failed += 1;
        }
    }
    return failed;
}

glob NATIVE_SEAL_ROOTS: tuple = (
         "jac0core/unitree.jac",
         "jac0core/passes/annex_pass.jac",
         "jac0core/passes/ast_validation_pass.jac",
         "jac0core/passes/module_codegen_pass.jac",
         "jac0core/passes/semantic_analysis_pass.jac",
         "jac0core/passes/uni_pass.jac",
         "jac0core/passes/endpoint_effect_pass.jac",
         "compiler/passes/main/sem_def_match_pass.jac",
         "compiler/native_materialize.jac",

     ),
     NATIVE_SEAL_CLOSURE: tuple = (
         "jac0core/constant.jac",
         "jac0core/diagnostics.jac",
         "jac0core/parser/lexer.jac",
         "jac0core/parser/parser.jac",
         "jac0core/parser/tokens.jac",
         "jac0core/passes/annex_pass.jac",
         "jac0core/passes/annex_weave.jac",
         "jac0core/passes/ast_validation_pass.jac",
         "jac0core/passes/endpoint_effect_pass.jac",
         "jac0core/passes/module_codegen_pass.jac",
         "jac0core/passes/semantic_analysis_pass.jac",
         "jac0core/passes/uni_pass.jac",
         "jac0core/srcloc.jac",
         "jac0core/unitree.jac",
         "compiler/native_materialize.jac",
         "compiler/passes/main/sem_def_match_pass.jac",
         "runtimelib/na_stdlib/keyword.jac",

     );

glob _UNITREE_SEAM_WAIVERS: tuple = (
         "jac0core/unitree.jac::ModulePath.resolve_relative_path",
         "jac0core/unitree.jac::ModulePath.native_bundled_path",
         "jac0core/unitree.jac::Ability.event_trigger_type_names",
         "jac0core/unitree.jac::UniNode.gen.__get__",
         "jac0core/unitree.jac::Module.annexable_by.__get__",
         "jac0core/unitree.jac::Import.__jac_detected.__get__",
         "jac0core/unitree.jac::Import.is_service_import.__get__",
         "jac0core/unitree.jac::DeleteStmt.py_ast_targets.__get__",
         "jac0core/unitree.jac::BuiltinType.lit_value.__get__",
         "jac0core/unitree.jac::Ellipsis.lit_value.__get__",

     ),
     _MODULE_CODEGEN_SEAM_WAIVERS: tuple = (
         "jac0core/passes/module_codegen_pass.jac::ModuleCodegenPass.iter_context_stmts",
         "jac0core/passes/module_codegen_pass.jac::ModuleCodegenPass.iter_module_imports",
         "jac0core/passes/module_codegen_pass.jac::ModuleCodegenPass.iter_nested_imports",
         "jac0core/passes/module_codegen_pass.jac::ModuleCodegenPass.has_native_context_stmts",
         "jac0core/passes/module_codegen_pass.jac::ModuleCodegenPass.shared_archetypes_for_context",
         "jac0core/passes/module_codegen_pass.jac::client_capability_violations",

     ),
     _UNI_PASS_SEAM_WAIVERS: tuple = (
         "jac0core/passes/uni_pass.jac::UniPass.get_all_sub_nodes",
         "jac0core/passes/uni_pass.jac::UniPass.find_parent_of_type",

     ),
     _ENDPOINT_EFFECT_SEAM_WAIVERS: tuple = (
         "jac0core/passes/endpoint_effect_pass.jac::EndpointEffectPass.enter_ability",
         "jac0core/passes/endpoint_effect_pass.jac::EndpointEffectPass.enter_archetype",

     ),
     _SEMANTIC_ANALYSIS_SEAM_WAIVERS: tuple = (
         "jac0core/passes/semantic_analysis_pass.jac::SemanticAnalysisPass.enter_has_var",

     ),
     NATIVE_SEAL_DEMOTION_WAIVERS: dict[str, tuple] = {
         "compiler/native_materialize.jac": _UNITREE_SEAM_WAIVERS,
         "jac0core/unitree.jac": _UNITREE_SEAM_WAIVERS,
         "jac0core/passes/annex_pass.jac": _UNITREE_SEAM_WAIVERS,
         "jac0core/passes/module_codegen_pass.jac": (
             _UNITREE_SEAM_WAIVERS + _MODULE_CODEGEN_SEAM_WAIVERS
         ),
         "jac0core/passes/uni_pass.jac": (
             _UNITREE_SEAM_WAIVERS + _UNI_PASS_SEAM_WAIVERS
         ),
         "jac0core/passes/endpoint_effect_pass.jac": (
             _UNITREE_SEAM_WAIVERS + _ENDPOINT_EFFECT_SEAM_WAIVERS
         ),
         "jac0core/passes/ast_validation_pass.jac": _UNITREE_SEAM_WAIVERS,
         "jac0core/passes/semantic_analysis_pass.jac": (
             _UNITREE_SEAM_WAIVERS + _SEMANTIC_ANALYSIS_SEAM_WAIVERS
         ),
         "compiler/passes/main/sem_def_match_pass.jac": _UNITREE_SEAM_WAIVERS
     };

def _seal_module_label(path: str, pkg_path: (Path | None)) -> str {
    if pkg_path is not None {
        try {
            return Path(path).resolve().relative_to(
                Path(pkg_path).resolve()
            ).as_posix();
        } except ValueError { }
    }
    return os.path.basename(path);
}

def _seal_demotions(
    census: dict, pkg_path: (Path | None) = None
) -> list[tuple[str, str, str]] {
    found: list[tuple[str, str, str]] = [];
    for (path, rec) in sorted(census.items()) {
        where = _seal_module_label(path, pkg_path);
        for seam in (rec.get("seams") or []) {
            text = str(seam);
            (name, sep, why) = text.partition(": ");
            bare = name if sep else text;
            reason = why if sep else text;
            found.append((f"{where}::{bare}", bare, f"{where}: {reason}"));
        }
        if rec.get("outcome") == "demoted" {
            code = rec.get("code") or "?";
            detail = rec.get("detail") or "";
            found.append(
                (
                    f"{where}::<module>",
                    "<module>",
                    f"{where}: whole module demoted [{code}] {detail}"
                )
            );
        }
    }
    return found;
}

def seal_waiver_names(rel: str, waivers: (dict | None) = None) -> tuple[set, set] {
    table = NATIVE_SEAL_DEMOTION_WAIVERS if waivers is None else waivers;
    qualified = set(table.get(rel, ()));
    bare = {q.split("::")[-1] for q in qualified};
    return (qualified, bare);
}

def seal_demotion_report(
    rel: str,
    census: dict,
    waivers: (dict | None) = None,
    pkg_path: (Path | None) = None
) -> tuple[str, list[str], list[str]] {
    (allowed, _bare) = seal_waiver_names(rel, waivers);
    found = _seal_demotions(census, pkg_path);
    names = {q for (q, _b, _why) in found};
    offending = [
        (q, why)
        for (q, _b, why) in found
        if q not in allowed
    ];
    waived = sorted(
        n
        for n in names
        if n in allowed
    );
    stale = sorted(
        a
        for a in allowed
        if a not in names
    );
    if not offending {
        return ("", waived, stale);
    }
    lines = [
        f"NATIVE SEAL: {rel} demoted {len(offending)} method(s) the native "
        "backend could not lower. A sealed artifact has no Python left to fall "
        "back to, so every demotion ships as an abort stub that kills the "
        "process at the first call with no diagnostic."
    ];
    for (n, why) in offending {
        lines.append(f"    {n}  <-  {why}");
    }
    lines.append(
        "  Fix the native lowering, or waive a knowingly-unreachable method by "
        "adding its exact <module>::<Type>.<method> name above to "
        "NATIVE_SEAL_DEMOTION_WAIVERS[\""
            + rel
            + "\"] in jaclang/utils/precompile_bytecode.jac. The module half is "
            + "required: a bare method name would also waive a same-named "
            + "method demoting in a different module of the closure. Set "
            + "JAC_NA_DEBUG=1 to print the full diagnostic behind each demotion."
    );
    return ("\n".join(lines), waived, stale);
}

def seal_abort_stubs(llvm_ir_text: str) -> list[str] {
    import re;
    name_re = re.compile(r'@(?:"([^"]+)"|([A-Za-z0-9_.$\-]+))\s*\(');
    abort_re = re.compile(
        r'^(?:tail\s+|musttail\s+|notail\s+)?call\s+void\s+@"?abort"?\s*\(\s*\)'
    );
    stubs: list[str] = [];
    lines = llvm_ir_text.splitlines();
    total = len(lines);
    i = 0;
    while i < total {
        head = lines[i].strip();
        i += 1;
        if not head.startswith("define") {
            continue;
        }
        matched = name_re.search(head);
        if matched is None {
            continue;
        }
        body: list[str] = [];
        while i < total {
            cur = lines[i].strip();
            i += 1;
            if cur == "}" {
                break;
            }
            if cur and cur != "{" {
                body.append(cur);
            }
        }
        if (
            len(body) == 3
            and body[0].endswith(":")
            and abort_re.match(body[1]) is not None
            and body[2] == "unreachable"
        ) {
            stub_name = matched.group(1) or matched.group(2);
            if stub_name.endswith(".__jac_demoted") {
                stub_name = stub_name[:-len(".__jac_demoted")];
            }
            stubs.append(stub_name);
        }
    }
    return sorted(set(stubs));
}

def purge_native_ir_cache(root_src: str, deps: (list[str] | None) = None) -> int {
    import glob as _glob;
    import from jaclang.jac0core.jir { get_native_cache_dir }
    base = os.path.dirname(os.path.abspath(root_src));
    dirs: list[str] = [];
    stems: list[str] = [];
    for raw in [root_src] + list(deps or []) {
        if not raw {
            continue;
        }
        resolved = raw if os.path.isabs(raw) else os.path.join(base, raw);
        stems.append(os.path.splitext(os.path.basename(resolved))[0]);
        try {
            cache_dir = str(get_native_cache_dir(resolved));
            if cache_dir not in dirs {
                dirs.append(cache_dir);
            }
        } except Exception { }
    }
    removed = 0;
    for cache_dir in dirs {
        for stem in sorted(set(stems)) {
            for suffix in ("ir_cache", "ir_meta") {
                for stale in _glob.glob(
                    os.path.join(cache_dir, f"{stem}.*.{suffix}")
                ) {
                    try {
                        os.remove(stale);
                        removed += 1;
                    } except OSError { }
                }
            }
        }
    }
    return removed;
}

def seal_native_canary(lib_path: str, exports: list[str]) -> str {
    import ctypes;
    import traceback;
    import from jaclang.jac0core.compile_options { env_na_debug }
    import from jaclang.jac0core.native_dylib { DylibEngine }

    debug = env_na_debug();
    name = os.path.basename(lib_path);
    sys.stderr.write(f"    canary: dlopen {name}\n");
    sys.stderr.flush();
    try {
        eng = DylibEngine(lib_path);
    } except Exception as _open_exc {
        if debug {
            traceback.print_exc(file=sys.stderr);
        }
        return f"dlopen failed: {type(_open_exc).__name__}: {_open_exc}";
    }
    missing = sorted(
        {
            s
            for s in (list(exports) + ["__jac_shared_init"])
            if eng.get_function_address(s) == 0
        }
    );
    if missing {
        shown = ", ".join(missing[:8]);
        return (
            f"{len(missing)} advertised export(s) are not in the linked "
            f"artifact: {shown}"
        );
    }
    sys.stderr.write(f"    canary: __jac_shared_init + jac_str_new in {name}\n");
    sys.stderr.flush();
    try {
        eng.initialize();
    } except Exception as _init_exc {
        if debug {
            traceback.print_exc(file=sys.stderr);
        }
        return f"__jac_shared_init raised {type(_init_exc).__name__}: {_init_exc}";
    }
    probe = eng.get_function_address("jac_str_new");
    if not probe {
        return "";
    }
    try {
        made = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(
            probe
        )(
            b"jac", 3
        );
    } except Exception as _call_exc {
        if debug {
            traceback.print_exc(file=sys.stderr);
        }
        return f"jac_str_new raised {type(_call_exc).__name__}: {_call_exc}";
    }
    if not made {
        return (
            "jac_str_new returned NULL: the artifact loaded but its runtime is "
            "not live"
        );
    }
    return "";
}

glob _PARITY_CANARY_LINES: tuple = (
         "import os;",
         "glob G: int = 42, H: str = 'control-flow harness (Branch 4)';",
         "enum E { A = 1, B = 2 }",
         "obj Canary {",
         "    has a: int = 0, b: (str | None) = None, c: list[int] = [];",
         "    def m(p: int = 3) -> int;",
         "}",
         "impl Canary.m(p: int = 3) -> int {",
         "    if p > 1 and p < 10 or not p {",
         "        for i in range(p) {",
         "            self.a += i * 2 - 1;",
         "        }",
         "    } elif p == 0 {",
         "        while self.a {",
         "            self.a -= 1;",
         "        }",
         "    } else {",
         "        try {",
         "            self.b = f'v={p} w={self.a}';",
         "        } except Exception as e {",
         "            raise;",
         "        }",
         "    }",
         "    return self.a if self.a else -1;",
         "}",
         "test \"canary t\" { assert Canary(a=5).m(2) >= -1; }",
         "test { assert Canary(a=1).m() >= -1; }",
         "test box_holds { assert Canary(a=2).m() >= -1; }",
         "with entry { print({'k': [1, 2.5, True, None]}); }",

     ),
     _PARITY_CORPUS_LINES: tuple = (
         "# leading comment: crossing envelopes must carry comments, and a",
         "# prior parse's envelope objects must never bleed into this tree",
         "import os;",
         "import from dataclasses { dataclass }",
         "glob G: int = 42, H: (str | None) = None;",
         "enum Hue { RED = 1, GREEN = 2 }",
         "node Spot { has label: str = ''; }",
         "edge Road { has miles: int = 0; }",
         "walker Tour {",
         "    can step with Spot entry;",
         "}",
         "impl Tour.step with Spot entry {",
         "    visit [-->];",
         "}",
         "obj Box { has x: int = 0, y: list[int] = [], z: dict[str, int] = {}; ",
         "    def m(p: int = 1) -> int; }",
         "impl Box.m(p: int = 1) -> int {",
         "    if p > 1 and p < 9 or not p { for i in range(p) { self.x += i; } }",
         "    elif p == 0 { while self.x { self.x -= 1; } }",
         "    else { try { raise ValueError('v'); } except ValueError as e { } }",
         "    return self.x if self.x else -1;",
         "}",
         "enum Mood;",
         "impl Mood {",
         "    UP = 1,",
         "    DOWN: int = 2,",
         "    FLAT = 3",
         "}",
         "def pick(v: any) -> int {",
         "    match v {",
         "        case [1, 2]: return 1;",
         "        case {'k': 2}: return 2;",
         "        case _: return 0;",
         "    }",
         "}",
         "def:pub View(t: str) -> JsxElement {",
         "    return <div id='a'>{t}</div>;",
         "}",
         "async def later -> None {}",
         "def guess(t: str) -> int by fake_llm();",
         "enum Tone: int {",
         "    comptime for N in ('LOW', 'HIGH') {",
         "        ${ct.name(N)} = ${len(N)},",
         "    }",
         "}",
         "def imp_scope -> int {",
         "    import from math { floor };",
         "    return floor(1.5);",
         "}",
         "@dataclass",
         "class _PyStyle {",
         "    label: str = '';",
         "    count: int = 0;",
         "    def bump(self: _PyStyle) -> int {",
         "        self.count += 1;",
         "        return self.count;",
         "    }",
         "}",
         "test \"box holds\" { assert Box(x=1).m() >= -1; }",
         "test { assert Box(x=2).m() >= -1; }",
         "test \"...\" { assert Box(x=3).m() >= -1; }",
         "with entry { b = Box(x=5); print(f'v={b.m(2)}', {'s': [1, 2.5, True, None]}); }  # trailing",

     );

glob _PARITY_IDENT_PROBES: tuple = (
         '"abc"',
         '"ABC"',
         '"a1"',
         '"a b"',
         '" ab"',
         '"ab "',
         "'abc'",
         '"a-b"',
         '"..."'
     );

def _parity_test_names(mod: any) -> list[str] {
    import jaclang.jac0core.unitree as uni;
    out: list[str] = [];
    for nd in mod._in_mod_nodes {
        if isinstance(nd, uni.Test) {
            out.append(str(getattr(nd.__dict__.get("name"), "value", "<none>")));
        }
    }
    return out;
}


def _parity_ident_probe(np: any) -> str {
    import from jaclang.jac0core.parser.lexer { tokenize_full }
    import from jaclang.jac0core.parser.parser { Parser }

    nl = chr(10);
    rows: list[str] = [
        "    ident-derivation probe: a described test whose ident derives "
        "must not consume a generated ordinal, so the trailing bare test "
        "must be _jac_gen_1 on both tiers"
    ];
    for pi in range(len(_PARITY_IDENT_PROBES)) {
        desc = _PARITY_IDENT_PROBES[pi];
        path = f"__seal_parity_probe_{pi}__.jac";
        src = nl.join(["test " + desc + " { assert 1; }", "test { assert 1; }"]);
        n_names: list[str] = [];
        try {
            (n_mod, _ne, _npd, _nc, _nld, _nle) = np.parse(src, path);
            n_names = _parity_test_names(n_mod);
        } except Exception as probe_exc {
            n_names = [f"<{type(probe_exc).__name__}: {probe_exc}>"];
        }
        (toks, _pc, _pld, _ple) = tokenize_full(src, path);
        p_names = _parity_test_names(
            Parser(tokens=toks, file_path=path, source_code=src).parse()
        );
        verdict = "ok" if n_names == p_names else "DIVERGED";
        rows.append(
            f"      test {desc:<8} native {n_names} vs bytecode {p_names}"
            f"  {verdict}"
        );
    }
    return nl.join(rows);
}


def _parity_diff_at(left: any, right: any) -> int {
    limit = min(len(left), len(right));
    for i in range(limit) {
        if left[i] != right[i] {
            return i;
        }
    }
    return limit;
}


def _parity_window(items: list, at: int, span: int, sep: str = " ") -> str {
    lo = max(0, at - span);
    hi = min(len(items), at + span + 1);
    out = sep.join([str(x) for x in items[lo:hi]]);
    if lo > 0 {
        out = f"...{out}";
    }
    if hi < len(items) {
        out = f"{out}...";
    }
    return out;
}


def _parity_pairwise(left: list, right: list, cap: int) -> tuple[(list[str], int)] {
    shown: list[str] = [];
    total = 0;
    for i in range(max(len(left), len(right))) {
        l_at = str(left[i]) if i < len(left) else "<end>";
        r_at = str(right[i]) if i < len(right) else "<end>";
        if l_at == r_at {
            continue;
        }
        total += 1;
        if len(shown) < cap {
            shown.append(f"[{i + 1}] native {l_at!r} vs bytecode {r_at!r}");
        }
    }
    return (shown, total, );
}


def _parity_text_report(canary_path: str, native_up: str, py_up: str) -> str {
    nl = chr(10);
    off = _parity_diff_at(native_up, py_up);
    line = native_up.count(nl, 0, off) + 1;
    col = off - native_up.rfind(nl, 0, off);
    n_toks = native_up.split();
    p_toks = py_up.split();
    at = _parity_diff_at(n_toks, p_toks);
    (shown, total) = _parity_pairwise(n_toks, p_toks, 6);
    out = [
        f"{canary_path}: unparse diverged at line {line}, col {col} "
        f"(char {off} of {len(native_up)} native / {len(py_up)} bytecode)",
        f"    {total} differing token(s) of {len(n_toks)} native / "
        f"{len(p_toks)} bytecode",
        f"    native   {_parity_window(n_toks, at, 8)}",
        f"    bytecode {_parity_window(p_toks, at, 8)}"
    ];
    for entry in shown {
        out.append(f"    {entry}");
    }
    if total > len(shown) {
        out.append(f"    ... and {total - len(shown)} more");
    }
    return nl.join(out);
}


def _parity_sym_report(canary_path: str, n_syms: list, p_syms: list) -> str {
    nl = chr(10);
    at = _parity_diff_at(n_syms, p_syms);
    n_show = n_syms[at] if at < len(n_syms) else "<end>";
    p_show = p_syms[at] if at < len(p_syms) else "<end>";
    return nl.join(
        [
            f"{canary_path}: symbol names diverged at entry {at + 1} of "
            f"{len(n_syms)} native / {len(p_syms)} bytecode: "
            f"native {n_show!r} vs bytecode {p_show!r}",
            f"    native   {_parity_window(n_syms, at, 3, sep=', ')}",
            f"    bytecode {_parity_window(p_syms, at, 3, sep=', ')}"
        ]
    );
}


def seal_parse_parity_canary(lib_path: str, layout_dict: dict) -> str {
    import traceback;
    import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }
    import from jaclang.jac0core.compile_options { env_na_debug }
    import from jaclang.jac0core.parser.lexer { tokenize_full }
    import from jaclang.jac0core.parser.materialize { bind_native_parser }
    import from jaclang.jac0core.parser.parser { Parser }

    nl = chr(10);
    sys.stderr.write(f"    canary: parse parity in {os.path.basename(lib_path)}\n");
    sys.stderr.flush();
    try {
        np = bind_native_parser(lib_path, layout_dict);
    } except Exception as bind_exc {
        if env_na_debug() {
            traceback.print_exc(file=sys.stderr);
        }
        return f"binding failed: {type(bind_exc).__name__}: {bind_exc}";
    }
    corpora = [
        (nl.join(list(_PARITY_CANARY_LINES)), "__seal_parity_harness__.jac", ),
        (nl.join(list(_PARITY_CORPUS_LINES)), "__seal_parity_corpus__.jac", ),

    ];

    corpora = corpora
        + [(src, p.replace(".jac", "_round2_.jac"), ) for (src, p) in corpora];
    for (canary_src, canary_path) in corpora {
        try {
            (native_mod, n_errs, _pd, _cm, _ld, n_lex_errs) = np.parse(
                canary_src, canary_path
            );
        } except Exception as parse_exc {
            if env_na_debug() {
                traceback.print_exc(file=sys.stderr);
            }
            return (
                f"native parse of {canary_path} raised "
                f"{type(parse_exc).__name__}: {parse_exc}"
            );
        }
        (tokens, _c, _lex_d, lex_errs) = tokenize_full(canary_src, canary_path);
        pyp = Parser(tokens=tokens, file_path=canary_path, source_code=canary_src);
        py_mod = pyp.parse();
        if n_errs != pyp.error_count or n_lex_errs != lex_errs {
            return (
                f"{canary_path}: error counts diverged "
                f"(native {n_errs}/{n_lex_errs}, bytecode "
                f"{pyp.error_count}/{lex_errs})"
            );
        }
        if len(native_mod._in_mod_nodes) != len(py_mod._in_mod_nodes) {
            return (
                f"{canary_path}: node counts diverged "
                f"({len(native_mod._in_mod_nodes)} != "
                f"{len(py_mod._in_mod_nodes)})"
            );
        }
        native_up = unparse_node(native_mod);
        py_up = unparse_node(py_mod);
        n_syms: list[str] = [];
        p_syms: list[str] = [];
        try {
            n_syms = _sym_name_fingerprint(native_mod);
            p_syms = _sym_name_fingerprint(py_mod);
        } except Exception as sym_exc {
            return (
                f"{canary_path}: symbol fingerprint raised "
                f"{type(sym_exc).__name__}: {sym_exc}"
            );
        }
        if native_up != py_up or n_syms != p_syms {
            if env_na_debug() {
                sys.stderr.write(
                    f"--- {canary_path}: native unparse ---{nl}{native_up}{nl}"
                    f"--- {canary_path}: bytecode unparse ---{nl}{py_up}{nl}"
                );
                sys.stderr.flush();
            }
            detail: list[str] = [];
            if native_up != py_up {
                detail.append(_parity_text_report(canary_path, native_up, py_up));
            }
            if n_syms != p_syms {
                detail.append(_parity_sym_report(canary_path, n_syms, p_syms));
            }
            try {
                detail.append(_parity_ident_probe(np));
            } except Exception as probe_exc {
                detail.append(
                    f"    ident-derivation probe unavailable: "
                    f"{type(probe_exc).__name__}: {probe_exc}"
                );
            }
            return nl.join(detail);
        }
    }
    return _merge_probe_parity(np);
}

glob _MERGE_PROBE_MAIN: tuple = (
         "obj Widget {",
         "    has size: int = 1;",
         "    def grow(n: int) -> int;",
         "}",
         "with entry { print(Widget(size=2)); }",

     ),
     _MERGE_PROBE_ANNEX: tuple = (
         "impl Widget.grow(n: int) -> int {",
         "    self.size += n;",
         "    return self.size;",
         "}",
         "test \"widget grows\" { assert Widget().grow(2) == 3; }",

     );

def _merge_probe_parity(np: any) -> str {
    import from jaclang.jac0core.parser.lexer { tokenize_full }
    import from jaclang.jac0core.parser.parser { Parser }
    import from jaclang.jac0core.passes.annex_pass { JacAnnexPass }
    import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }

    nl = chr(10);
    main_src = nl.join(list(_MERGE_PROBE_MAIN));
    annex_src = nl.join(list(_MERGE_PROBE_ANNEX));
    main_path = "__seal_merge_probe__.jac";
    annex_path = "__seal_merge_probe__.impl.jac";
    sys.stderr.write("    canary: mat_merge_probe (native annex merge)\n");
    sys.stderr.flush();
    (merged, m_errs, a_errs) = np.merge_probe(
        main_src, main_path, annex_src, annex_path
    );
    if m_errs or a_errs {
        return (
            f"merge probe: the probe sources did not parse cleanly "
            f"(main {m_errs}, annex {a_errs} error(s))"
        );
    }
    (mt, _mc, _mld, _mle) = tokenize_full(main_src, main_path);
    py_main = Parser(tokens=mt, file_path=main_path, source_code=main_src).parse();
    (at, _ac, _ald, _ale) = tokenize_full(annex_src, annex_path);
    py_annex = Parser(tokens=at, file_path=annex_path, source_code=annex_src).parse();
    JacAnnexPass._merge_annex(py_main, py_annex);
    if len(merged.body) != len(py_main.body) {
        return (
            f"merge probe: woven body lengths diverged (native "
            f"{len(merged.body)} vs bytecode {len(py_main.body)})"
        );
    }
    native_up = unparse_node(merged);
    py_up = unparse_node(py_main);
    if native_up != py_up {
        return _parity_text_report("mat_merge_probe", native_up, py_up);
    }
    return "";
}

def _sym_name_fingerprint(mod: any) -> list[str] {
    import jaclang.jac0core.unitree as uni;
    out: list[str] = [];
    for nd in mod._in_mod_nodes {
        entry = "";
        if isinstance(nd, uni.AstSymbolNode) {
            try {
                entry = f"{type(nd).__name__}:{nd.sym_name}";
            } except Exception as sym_exc {
                entry = f"{type(nd).__name__}:<{type(sym_exc).__name__}>";
            }
        }
        if "body" in nd.__dict__ {
            nd_body = nd.__dict__.get("body");
            body_shape = f"list:{len(nd_body)}"
                if isinstance(nd_body, (list, tuple))
                else ("none" if nd_body is None else f"node:{type(nd_body).__name__}");
            entry = f"{entry or type(nd).__name__}|body={body_shape}";
        }
        if isinstance(nd, uni.NameAtom) {
            nd_spec = nd.__dict__.get("name_spec");
            spec_shape = "self"
                if nd_spec is nd
                else (
                    "none"
                        if nd_spec is None
                        else f"{type(nd_spec).__name__}:{getattr(nd_spec, 'value', '')}"
                );
            entry = f"{entry or type(nd).__name__}|spec={spec_shape}";
        }
        if entry {
            out.append(entry);
        }
    }
    return out;
}

def _native_lib_filename(stem: str) -> str {
    if sys.platform.startswith("win") {
        return f"jac_{stem}.dll";
    }
    if sys.platform == "darwin" {
        return f"libjac_{stem}.dylib";
    }
    return f"libjac_{stem}.so";
}

def seal_native_artifacts(
    pkg_path: Path,
    precompiled_dir: Path,
    modules: (tuple | None) = None,
    waivers: (dict | None) = None
) -> (dict[str, dict] | None) {
    artifacts: dict[str, dict] = {};
    stale_native = precompiled_dir / "native";
    if stale_native.is_dir() {
        shutil.rmtree(stale_native, ignore_errors=True);
    }

    if sys.platform.startswith("win") {
        return artifacts;
    }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.codeinfo { native_layout_to_dict }
    import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
    import from jaclang.compiler.passes.native.shared_emit { emit_shared_library }
    import jaclang.compiler.passes.native.llvm.binding as llvm;

    pkg_name = pkg_path.name;
    _seal_layouts: dict[str, dict] = {};
    _mat_manifest: (dict[str, any] | None) = None;
    _gen_root_src: (Path | None) = None;
    for rel in (NATIVE_SEAL_ROOTS if modules is None else modules) {
        src: Path = pkg_path / str(rel);
        if rel == "compiler/native_materialize.jac" {
            unitree_layout = _seal_layouts.get("jac0core/unitree.jac");
            if unitree_layout is None {
                console.error(
                    "NATIVE SEAL: the materializer root is generated from "
                    "the unitree layout; seal jac0core/unitree.jac first "
                    "(NATIVE_SEAL_ROOTS order, or include it in the "
                    "modules argument)."
                );
                return None;
            }
            import from jaclang.utils.gen_native_materialize {
                generate as generate_materialize_root
            }

            _mat_manifest = generate_materialize_root(
                unitree_layout, src, _UNITREE_SEAM_WAIVERS
            );
            for _mat_warn in (_mat_manifest.pop("warnings", None) or []) {
                console.warning(
                    f"NATIVE SEAL: the materializer erased a slot: {_mat_warn}. "
                    "The Python side must reconstruct it (postinit or a lazy "
                    "accessor) or the materialized tree loses that value."
                );
            }
            _gen_root_src = src;
        }
        if not src.is_file() {
            console.error(f"NATIVE SEAL: missing source {src}");
            return None;
        }
        prog = JacProgram();
        na_census_begin();
        try {
            ir = prog.compile(
                file_path=str(src),
                options=CompileOptions(
                    aot_mode=True,
                    type_check=False,
                    force_codespace='native',
                    force_target_program=True,
                    na_gc_mode='cycles',
                    no_ir_cache=True
                )
            );
        } finally {
            census = na_census_end();
        }
        closure_deps: list[str] = [];
        if ir is not None and ir.gen.interop_manifest is not None {
            closure_deps = list(ir.gen.interop_manifest.native_transitive_sources);
        }
        if prog.errors_had {
            for _err in prog.errors_had {
                console.error(f"NATIVE SEAL: {_err.pretty_print()}");
            }
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        if ir is None or ir.gen.llvm_ir is None or ir.gen.native_layout is None {
            console.error(f"NATIVE SEAL: no native IR/layout for {rel}");
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        manifest = ir.gen.interop_manifest;
        if manifest is not None and manifest.native_imports {
            console.error(
                f"NATIVE SEAL: {rel} has Python-side imports; artifact would "
                "need in-process callbacks and cannot be sealed AOT."
            );
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        (demotion_error, waived, stale_waivers) = seal_demotion_report(
            rel, census, waivers, pkg_path
        );
        if demotion_error {
            console.error(demotion_error);
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        for name in waived {
            console.warning(
                f"NATIVE SEAL: {rel} ships {name} as an abort stub -- waived by "
                "NATIVE_SEAL_DEMOTION_WAIVERS. Calling it in a sealed build "
                "aborts the process."
            );
        }
        for name in stale_waivers {
            console.warning(
                f"NATIVE SEAL: {rel} waives {name}, which did not demote; drop "
                "the stale entry from NATIVE_SEAL_DEMOTION_WAIVERS."
            );
        }
        llvm_ir_text = str(ir.gen.llvm_ir);

        (_qualified, allowed_bare) = seal_waiver_names(rel, waivers);

        allowed_stub_names: set[str] = set(allowed_bare);
        reg = ir.gen.layout_registry;
        if reg is not None {
            for bare in allowed_bare {
                (owner, dot, meth) = bare.partition(".");
                if not dot {
                    continue;
                }
                for (cls, mro) in reg.mro_order.items() {
                    if owner in mro {
                        allowed_stub_names.add(f"{cls}.{meth}");
                    }
                }
            }
        }
        shipped_stubs = [
            s
            for s in seal_abort_stubs(llvm_ir_text)
            if s not in allowed_stub_names
        ];
        if shipped_stubs {
            console.error(
                f"NATIVE SEAL: {rel} would link {len(shipped_stubs)} abort "
                f"stub(s) into its artifact: {', '.join(shipped_stubs)}. This is "
                "read off the IR that actually ships, so it holds even when the "
                "native census recorded nothing (a stale native IR cache serves "
                "a demoted dependency without re-running codegen). The cached IR "
                "for this closure has been purged; re-run the seal to recompile "
                "it and get the per-method diagnostic."
            );
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        layout = ir.gen.native_layout;

        _clib_syms = set((ir.gen._clib_symbol_lib or {}).keys());
        exports = sorted(
            fn_name
            for fn_name in layout.functions.keys()
            if fn_name not in _clib_syms
        );
        if not exports {
            console.error(f"NATIVE SEAL: {rel} exports no module functions");
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }

        layout_dict = native_layout_to_dict(layout);
        _seal_layouts[rel] = layout_dict;
        if rel == "compiler/native_materialize.jac" and _mat_manifest is not None {
            layout_dict["materialize_manifest"] = _mat_manifest;
        }
        _stub_syms = set(seal_abort_stubs(llvm_ir_text));
        accessor_syms: set[str] = set();
        for _sd in layout_dict["structs"].values() {
            _live = {
                _fname: {
                    _kind: _sym
                    for (_kind, _sym) in _kinds.items()
                    if _sym not in _stub_syms
                } for (_fname, _kinds) in (_sd.get("accessors") or {}).items()
            };
            _sd["accessors"] = {
                _fname: _kinds
                for (_fname, _kinds) in _live.items()
                if _kinds
            };
            for _kinds in _sd["accessors"].values() {
                accessor_syms.update(_kinds.values());
            }
        }
        exports = sorted(set(exports) | accessor_syms);
        triple = llvm.get_default_triple();
        out_dir = precompiled_dir / "native" / triple;
        out_dir.mkdir(parents=True, exist_ok=True);
        stem = ext_registry.base_stem(os.path.basename(rel));
        lib_path = out_dir / _native_lib_filename(stem);
        transitive = list(manifest.native_transitive_sources) if manifest else [];
        (ok, err) = emit_shared_library(
            str(ir.gen.llvm_ir),
            transitive,
            exports,
            str(lib_path),
            clib_paths=list(ir.gen._clib_paths or []),
            clib_symbol_lib=dict(ir.gen._clib_symbol_lib or {})
        );
        if not ok {
            console.error(f"NATIVE SEAL: {rel}: {err}");
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        canary = seal_native_canary(str(lib_path), exports);
        if canary {
            console.error(
                f"NATIVE SEAL: {rel}: the emitted artifact "
                f"{lib_path.name} failed its load canary: {canary}. The seal "
                "refuses artifacts it cannot load and call; set JAC_NA_DEBUG=1 "
                "for the traceback."
            );
            lib_path.unlink(missing_ok=True);
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        layout_path = out_dir / f"{stem}.layout.json";
        layout_path.write_text(
            json.dumps(layout_dict, sort_keys=True) + "\n", encoding="utf-8"
        );
        if rel == "compiler/native_materialize.jac" {
            parity = seal_parse_parity_canary(str(lib_path), layout_dict);
            if parity {
                console.error(
                    f"NATIVE SEAL: {rel}: the emitted artifact "
                    f"{lib_path.name} failed its parse parity canary. The "
                    "seal refuses artifacts whose parses do not match the "
                    "bytecode parser; set JAC_NA_DEBUG=1 for the full "
                    f"unparsed texts and the traceback.{chr(10)}{parity}"
                );
                lib_path.unlink(missing_ok=True);
                layout_path.unlink(missing_ok=True);
                purge_native_ir_cache(str(src), closure_deps);
                return None;
            }
        }
        parts = [
            p
            for p in os.path.dirname(rel).split("/")
            if p
        ];
        fullname = ".".join([pkg_name] + parts + [stem]);
        artifacts[fullname] = {
            "lib": lib_path.relative_to(precompiled_dir).as_posix(),
            "layout": layout_path.relative_to(precompiled_dir).as_posix(),
            "triple": triple,
            "lib_sha256": hashlib.sha256(lib_path.read_bytes()).hexdigest(),
            "layout_sha256": hashlib.sha256(layout_path.read_bytes()).hexdigest()
        };
        if _gen_root_src is not None and rel == "compiler/native_materialize.jac" {
            _gen_root_src.unlink(missing_ok=True);
            _gen_root_src = None;
        }
        console.print(
            f"  Native artifact: {fullname} -> {lib_path.name} "
            f"({lib_path.stat().st_size:,} bytes, {len(exports)} exports)"
        );
    }
    return artifacts;
}

def jir_to_module(pkg_name: str, rel_jir: str) -> tuple[str, str, bool] {
    source_rel = rel_jir[:-4] + ".jac";
    name = os.path.basename(source_rel);
    parts = [
        p
        for p in os.path.dirname(source_rel).split("/")
        if p
    ];
    is_pkg = name in ext_registry.INIT_FILES;
    if is_pkg {
        fullname = ".".join([pkg_name] + parts);
    } else {
        fullname = ".".join([pkg_name] + parts + [ext_registry.base_stem(name)]);
    }
    return (source_rel, fullname, is_pkg);
}

def app_metadata(pkg_path: Path, pkg_name: str) -> dict {
    if not (pkg_path / "jac.toml").is_file() {
        return {};
    }
    import from jaclang.project.config { get_config_for_path }
    import from jaclang.project.kinds { resolve_project_kind, resolve_entry }
    import from jaclang.runtimelib.sealed_serve { CLIENT_DIST_REL, NATIVE_DIR_REL }

    config = get_config_for_path(pkg_path);
    if config is None {
        return {};
    }
    entry_path = resolve_entry(config, str(pkg_path));
    kind = resolve_project_kind(config, entry_path);

    entry: dict[str, str] = {};
    if entry_path and Path(entry_path).is_file() {
        rel = Path(entry_path).resolve().relative_to(pkg_path.resolve()).as_posix();
        stem = ext_registry.base_stem(os.path.basename(entry_path));
        entry = {"module": f"{pkg_name}.{stem}", "path": rel};
    }

    caps: list[str] = [];
    if kind in ["service", "service-mesh", "web-app", "desktop", "mobile"] {
        caps.append("has-server");
    }
    if entry {
        caps.append("has-entry");
    }
    if (pkg_path / CLIENT_DIST_REL).is_dir()
        or kind in ["web-app", "desktop", "mobile"] {
        caps.append("has-client");
    }
    if (pkg_path / NATIVE_DIR_REL).is_dir() {
        caps.append("has-native");
    }
    if kind in ["py-package", "js-package"] or not entry {
        caps.append("attachable");
    }

    meta = {"kind": kind, "capabilities": caps, "entry": entry};
    native_dir = pkg_path / NATIVE_DIR_REL;
    if native_dir.is_dir() {
        triples = sorted(
            [
                d.name
                for d in native_dir.iterdir()
                if d.is_dir()
            ]
        );
        if triples {
            caps.append("platform-locked");
            meta["triples"] = triples;
        }
    }
    return meta;
}

def collect_payloads(pkg_path: Path) -> dict[str, str] {
    import from jaclang.runtimelib.sealed_serve {
        SERVE_MANIFEST_REL,
        CLIENT_DIST_REL,
        NATIVE_DIR_REL
    }
    payloads: dict[str, str] = {};
    sm = pkg_path / SERVE_MANIFEST_REL;
    if sm.is_file() {
        payloads[Path(SERVE_MANIFEST_REL).as_posix()] = hashlib.sha256(
            sm.read_bytes()
        ).hexdigest();
    }
    for payload_dir in [pkg_path / CLIENT_DIST_REL, pkg_path / NATIVE_DIR_REL] {
        if not payload_dir.is_dir() {
            continue;
        }
        for f in sorted(payload_dir.rglob("*")) {
            if f.is_file() {
                payloads[f.relative_to(pkg_path).as_posix()] = hashlib.sha256(
                    f.read_bytes()
                ).hexdigest();
            }
        }
    }
    return payloads;
}

def seal_finalize(
    pkg_path: Path, precompiled_dir: Path, pkg_name: str, pyver: str, embed_src: bool
) -> int {
    writes = (
        FORMAT_VERSION,
        HEADER_SIZE,
        SECTIONS_MAGIC,
        SEC_BYTECODE,
        SEC_DEBUG_SRC,
        PRECOMPILE_SENTINEL
    );
    reads = (
        SEALED_JIR_FORMAT_VERSION,
        SEALED_HEADER_SIZE,
        SEALED_SECTIONS_MAGIC,
        SEALED_SEC_BYTECODE,
        SEALED_SEC_DEBUG_SRC,
        SEALED_SENTINEL
    );
    if reads != writes {
        console.error(
            f"JIR format drift: jir.jac writes {writes} but sealed.py "
            f"reads {reads}. Update jaclang/jac0core/sealed.py."
        );
        return 1;
    }

    missing = [
        str(Path(p).relative_to(pkg_path))
        for p in sealable_sources(str(pkg_path))
        if not (
            precompiled_dir / pyver / Path(p).relative_to(pkg_path).with_suffix(".jir")
        ).is_file()
    ];
    if missing {
        console.error(
            f"Seal incomplete: {len(missing)} sealable module(s) have no JIR "
            f"(first: {missing[:5]}). The compile pass failed or was skipped."
        );
        return 1;
    }

    identity = compiler_identity();
    foreign: list[str] = [];
    for p in sealable_sources(str(pkg_path)) {
        rel = Path(p).relative_to(pkg_path);
        jir = precompiled_dir / pyver / rel.with_suffix(".jir");
        if not precompiled_jir_matches_source(jir.read_bytes(), p, identity) {
            foreign.append(str(rel));
        }
    }
    if foreign {
        console.error(
            f"Seal aborted: {len(foreign)} module(s) carry a JIR this compiler "
            f"did not produce (first: {foreign[:5]}). Their module keys name a "
            "different compiler content digest, so the seed served bytecode "
            "built by another compiler at this same version (#8178). Delete "
            f"{precompiled_dir} and re-run the precompile."
        );
        return 1;
    }
    console.print(f"  Compiler identity: {identity} (verified over every JIR)");

    out_dir = precompiled_dir / pyver;

    stale_boot = precompiled_dir / "bootstrap";
    if stale_boot.is_dir() {
        shutil.rmtree(stale_boot, ignore_errors=True);
    }

    console.print("  Freezing jac0core bootstrap layer...");
    boot_failed = seal_bootstrap(pkg_path, out_dir, embed_src);
    if boot_failed > 0 {
        console.error(f"Seal aborted: {boot_failed} bootstrap module(s) failed.");
        return 1;
    }

    native_seal: (dict[str, any] | None) = None;
    if pkg_name == "jaclang" {
        console.print("  Sealing AOT native artifacts...");
        native_artifacts = seal_native_artifacts(pkg_path, precompiled_dir);
        if native_artifacts is None {
            console.error("Seal aborted: native artifact build failed.");
            return 1;
        }
        if sys.platform.startswith("win") {
            native_seal = {"artifacts": {}, "roots": [], "skip_reason": "platform:win"};
        } else {
            native_seal = {
                "artifacts": native_artifacts,
                "roots": sorted(native_artifacts.keys()),
                "skip_reason": None
            };
        }
    }

    manifest_modules: dict[str, dict] = {};
    n_boot = 0;
    for jir in sorted(out_dir.rglob("*.jir")) {
        rel_jir = jir.relative_to(out_dir).as_posix();
        (source_rel, fullname, is_pkg) = jir_to_module(pkg_name, rel_jir);
        entry = {
            "module": fullname,
            "jir": rel_jir,
            "package": is_pkg,
            "sha256": hashlib.sha256(jir.read_bytes()).hexdigest()
        };
        if rel_jir.startswith("jac0core/") {
            entry["bootstrap"] = True;
            n_boot += 1;
        }
        manifest_modules[source_rel] = entry;
    }
    console.print(f"  Manifest modules: {len(manifest_modules)} ({n_boot} bootstrap)");

    payloads = collect_payloads(pkg_path);
    if payloads {
        console.print(f"  Payload files: {len(payloads)}");
    }
    app_meta = app_metadata(pkg_path, pkg_name);
    if app_meta {
        console.print(
            f"  App: kind={app_meta.get('kind')} caps={app_meta.get('capabilities')}"
        );
    }
    placement = placement_facts_map(str(pkg_path)) if pkg_name != "jaclang" else {};
    if placement {
        console.print(f"  Placement facts: {len(placement)} modules");
        app_meta = dict(app_meta);
        app_meta["placement"] = placement;
    }
    write_manifest(
        precompiled_dir,
        pkg_name,
        pyver,
        manifest_modules,
        payloads,
        app_meta,
        native_seal
    );
    console.print(f"  Manifest: {precompiled_dir / MANIFEST_NAME}");
    return 0;
}

def write_manifest(
    precompiled_dir: Path,
    pkg_name: str,
    pyver: str,
    modules: dict[str, dict],
    payloads: (dict[str, str] | None) = None,
    app_meta: (dict | None) = None,
    native_seal: (dict[str, any] | None) = None
) {
    import from importlib.metadata { version as pkg_version }
    try {
        jac_ver = pkg_version("jaclang");
    } except Exception {
        jac_ver = "0.0.0";
    }
    manifest: dict[str, any] = {
        "format": MANIFEST_FORMAT,
        "package": pkg_name,
        "python_tag": pyver,
        "jir_format_version": FORMAT_VERSION,
        "jaclang_version": jac_ver,
        "compiler_digest": compiler_identity(),
        "modules": modules
    };
    if payloads {
        manifest["payloads"] = payloads;
    }
    if app_meta {
        manifest.update(app_meta);
    }
    if native_seal is not None {
        if native_seal.get("artifacts") {
            manifest["native_artifacts"] = native_seal["artifacts"];
        }

        manifest["native"] = {
            "roots": native_seal.get("roots") or [],
            "skip_reason": native_seal.get("skip_reason")
        };
    }
    (precompiled_dir / MANIFEST_NAME).write_text(
        json.dumps(manifest, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );
}

def main {
    args = sys.argv[1:];
    seal = "--seal" in args;
    seal_compile = "--seal-compile" in args;
    finalize_only = "--seal-finalize" in args;
    embed_src = "--debug-src" in args;
    exclude_jac0core = seal or seal_compile;
    args = [
        a
        for a in args
        if not a.startswith("--")
    ];
    if not args {
        console.print(
            "Usage: jac run utils/precompile_bytecode.jac<package-source-dir> [--seal|--seal-finalize] [--debug-src]"
        );
        console.print("\nExamples:");
        console.print("  jac run utils/precompile_bytecode.jac./jac");
        console.print("  jac run utils/precompile_bytecode.jac./jac/jaclang/scale");
        console.print("\n--seal: precompile, freeze the jac0core bootstrap, and emit");
        console.print("        MANIFEST.json (JIR-authoritative image; .jac sources");
        console.print(
            "        stay on disk for tracebacks, never compiled at runtime)."
        );
        console.print(
            "--seal-compile: compile only (exclude jac0core), no finalize -- the"
        );
        console.print("        payload build's crash-tolerant first pass.");
        console.print(
            "--seal-finalize: run ONLY the seal step over an already-precompiled tree"
        );
        console.print(
            "        (verify completeness, build the manifest, freeze) -- resilient"
        );
        console.print(
            "        to the best-effort compile crashing on a native module."
        );
        console.print(
            "--debug-src: embed zlib source text in each .jir (dev tracebacks)."
        );
        sys.exit(1);
    }

    source_dir = args[0];
    package_dir = find_package_dir(source_dir);
    if package_dir is None {
        console.error(f"Could not find a Python package in {source_dir}");
        sys.exit(1);
    }

    pkg_name = Path(package_dir).name;
    if (seal or seal_compile or finalize_only)
        and pkg_name != "jaclang"
        and not (Path(package_dir) / "jac.toml").is_file() {
        console.error(
            f"Seal aborted: {package_dir} has no jac.toml. An app seal reads "
            "placement, nested-project scoping, and app metadata from the "
            "project config; sealing without it would compile every module "
            "including client code. Stage a sanitized jac.toml first."
        );
        sys.exit(1);
    }
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    precompiled_dir = Path(package_dir) / "_precompiled";

    if finalize_only {
        console.print(f"Sealing {pkg_name} for {pyver} (finalize)...");
        sys.exit(
            seal_finalize(
                Path(package_dir), precompiled_dir, pkg_name, pyver, embed_src
            )
        );
    }

    console.print(f"Precompiling {pkg_name} for {pyver}...");
    console.print(f"  Package directory: {package_dir}");
    console.print(f"  Compiler identity: {compiler_identity()}");

    jac_files = (
        sealable_sources(package_dir)
            if exclude_jac0core
            else find_jac_files(package_dir)
    );
    console.print(f"  Found {len(jac_files)} .jac files");

    if not jac_files and not exclude_jac0core {
        console.print("  No .jac files to precompile.");
        sys.exit(0);
    }

    out_dir = precompiled_dir / pyver;
    out_dir.mkdir(parents=True, exist_ok=True);
    (precompiled_dir / RESULT_NAME).unlink(missing_ok=True);

    for stale_dir in sorted(precompiled_dir.iterdir()) {
        if stale_dir.is_dir() and stale_dir.name != pyver {
            shutil.rmtree(stale_dir, ignore_errors=True);
        }
    }
    pkg_path = Path(package_dir);
    expected: set[str] = {
        str(Path(p).relative_to(pkg_path).with_suffix(".jir")) for p in jac_files
    };
    for old_jir in sorted(out_dir.rglob("*.jir")) {
        if str(old_jir.relative_to(out_dir)) not in expected {
            old_jir.unlink();
        }
    }

    import from jaclang.jac0core.jir { read_debug_source }

    compiled = 0;
    reused = 0;
    failed = 0;

    for jac_path in jac_files {
        rel = Path(jac_path).relative_to(pkg_path);
        jir_rel = rel.with_suffix(".jir");
        jir_path = out_dir / jir_rel;

        done = compiled + reused + failed;
        label = str(rel)[:60].ljust(60);
        sys.stderr.write(f"\r  [{done + 1}/{len(jac_files)}] {label}");
        sys.stderr.flush();

        try {
            if jir_path.is_file() {
                existing = jir_path.read_bytes();
                if precompiled_jir_matches_source(existing, jac_path)
                    and embed_src == (read_debug_source(existing) is not None) {
                    reused += 1;
                    continue;
                }
            }

            jir_bytes = precompile_unit(jac_path, package_dir, embed_src);
            if jir_bytes is None {
                console.print(f"  SKIP (no bytecode): {rel}");
                jir_path.unlink(missing_ok=True);
                failed += 1;
                continue;
            }

            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(jir_bytes);
            compiled += 1;
        } except Exception as e {
            console.error(f"FAIL: {rel} - {e}");
            jir_path.unlink(missing_ok=True);
            failed += 1;
        }
    }

    sys.stderr.write("\n");
    sys.stderr.flush();

    console.print(
        f"\nDone! Compiled {compiled}/{len(jac_files)} modules"
            + f" ({reused} reused, {failed} failed)"
    );
    console.print(f"  Output: {precompiled_dir}");
    console.print(f"  Python version: {pyver}");

    (precompiled_dir / RESULT_NAME).write_text(
        json.dumps(
            {
                "total": len(jac_files),
                "compiled": compiled,
                "reused": reused,
                "failed": failed
            }
        )
            + "\n",
        encoding="utf-8"
    );

    if seal {
        sys.exit(seal_finalize(pkg_path, precompiled_dir, pkg_name, pyver, embed_src));
    }
}

with entry:__main__ {
    main();
}
