import hashlib;
import json;
import marshal;
import os;
import shutil;
import sys;
import time;
import zlib;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core { ext_registry }
import from jaclang.compiler.driver.jir { patch_co_filenames_bytes }
import from jaclang.compiler.driver.jir {
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
    HEADER_SIZE as SEALED_HEADER_SIZE,
    SECTIONS_MAGIC as SEALED_SECTIONS_MAGIC,
    SEC_BYTECODE as SEALED_SEC_BYTECODE,
    SEC_DEBUG_SRC as SEALED_SEC_DEBUG_SRC
}

glob RESULT_NAME: str = "PRECOMPILE_RESULT.json";

def compiler_identity -> str {
    digest = running_compiler_digest();
    if digest.startswith("0:") {
        raise RuntimeError(
            "Precompile aborted: no compiler sources found under the running "
            "jaclang package, so this build cannot state which compiler it is. "
            "Every seeded .jir would then be reusable by any other compiler at "
            "this version -- the #8178 failure mode. Check that the seed tree and "
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
    excluded: list[str] = [
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
    import from jaclang.bootstrap_manifest { is_seed_source }
    base = os.path.abspath(package_dir);
    nested = _nested_project_dirs(package_dir);
    candidates = [
        p
        for p in find_jac_files(package_dir)
        if not is_seed_source(os.path.relpath(p, base).replace(os.sep, "/"))
            and not any(p.startswith(n) for n in nested)
    ];
    if Path(package_dir).name == "jaclang" {
        import from jaclang.compiler.placement.placement_facts {
            toolchain_native_by_policy
        }
        result = [
            p
            for p in candidates
            if not toolchain_native_by_policy(package_dir, p)
        ];
    } else {
        import from jaclang.compiler.placement.placement_facts {
            discover_spaces,
            spaces_are_client_only
        }
        import from jaclang.compiler.driver.program { JacProgram }
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

def _emit_unit_diagnostics(jac_path: str, programs: list) {
    import from jaclang.compiler.driver.source_failures {
        compiler_source_failure_details
    }
    stashed = compiler_source_failure_details(jac_path);
    if stashed {
        stash_lines = stashed.splitlines();
        for line in stash_lines[:40] {
            console.error(line);
        }
        if len(stash_lines) > 40 {
            console.error(f"  ... and {len(stash_lines) - 40} more line(s)");
        }
        return;
    }
    norm = os.path.normpath(jac_path);
    stem = norm[:-4] if norm.endswith(".jac") else norm;
    base = os.path.basename(stem) + ".";
    lines: list[str] = [];
    seen: set[str] = set();
    for prog in programs {
        for alert in prog.errors_had {
            try {
                alert_path = os.path.normpath(alert.loc.mod_path);
            } except Exception {
                continue;
            }
            if not (
                alert_path == norm
                or alert_path.startswith(stem + ".")
                or os.path.basename(alert_path).startswith(base)
            ) {
                continue;
            }
            pretty = alert.pretty_print();
            if pretty not in seen {
                seen.add(pretty);
                lines.append(pretty);
            }
        }
    }
    for line in lines[:10] {
        console.error(line);
    }
    if len(lines) > 10 {
        console.error(f"  ... and {len(lines) - 10} more error(s)");
    }
}

def precompile_unit(
    jac_path: str, pkg_root: str, embed_src: bool = False
) -> bytes | None {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.program { JacProgram }

    compiler = Jac.get_compiler();

    program = JacProgram();
    code = compiler.get_bytecode(full_target=jac_path, target_program=program);
    if code is None {
        _emit_unit_diagnostics(jac_path, [program, compiler.selfhost.program]);
    }
    compiler.selfhost.program.release_compile_closure();
    program.release_compile_closure();
    if code is None {
        return None;
    }
    patched = patch_co_filenames_bytes(
        marshal.dumps(code), pkg_root, PRECOMPILE_SENTINEL
    );
    extra: dict[int, bytes] | None = None;
    if embed_src {
        extra = {int(SEC_DEBUG_SRC): zlib.compress(Path(jac_path).read_bytes(), 9)};
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
    failed = 0;
    if pkg_dir.name != "jaclang" {
        return failed;
    }
    import from jaclang.bootstrap_manifest { seed_abs_entries }
    (seed_dirs, seed_files) = seed_abs_entries(str(pkg_dir));
    seed_sources: list[Path] = [
        Path(p)
        for p in seed_files
        if str(p).endswith(".jac")
    ];
    for d in seed_dirs {
        seed_sources.extend(Path(d).rglob("*.jac"));
    }
    for jac_file in sorted(seed_sources) {
        if ext_registry.is_annex(str(jac_file)) {
            continue;
        }
        if any(
            part.startswith(".") or part == "__pycache__"
            for part in jac_file.relative_to(pkg_dir).parts
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
                extra = {int(SEC_DEBUG_SRC): zlib.compress(jac_file.read_bytes(), 9)};
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

glob NATIVE_SEAL_FUSED_ROOT: str = "compiler/fused_seal_root.jac",
     NATIVE_SEAL_LIB_STEM: str = "compiler";

glob NATIVE_SEAL_SERVED_MODULES: tuple[str, ...] = (
         "compiler/frontend/unitree.jac",
         "compiler/passes/ast_validation_pass.jac",
         "compiler/backends/py/module_codegen_pass.jac",
         "compiler/passes/semantic_analysis_pass.jac",
         "compiler/passes/sym_tab_build_pass.jac",
         "compiler/passes/decl_impl_match_pass.jac",
         "compiler/passes/uni_pass.jac",
         "compiler/passes/endpoint_effect_pass.jac",
         "compiler/passes/sem_def_match_pass.jac",
         "compiler/passes/access_check_pass.jac",
         "compiler/passes/jsx_intrinsic_guard_pass.jac",
         "compiler/passes/cfg_build_pass.jac",
         "compiler/passes/rc_facts_pass.jac",
         "compiler/backends/py/jcir_gen_pass.jac",
         "compiler/native_materialize.jac",

     ),
     NATIVE_SEAL_SERVED_IMPORTS: dict[str, str] = {
         "compiler/frontend/unitree.jac": "UniNode",
         "compiler/passes/ast_validation_pass.jac": "ASTValidationPass",
         "compiler/backends/py/module_codegen_pass.jac": "ModuleCodegenPass",
         "compiler/passes/semantic_analysis_pass.jac": "SemanticAnalysisPass",
         "compiler/passes/sym_tab_build_pass.jac": "SymTabBuildPass",
         "compiler/passes/decl_impl_match_pass.jac": "DeclImplMatchPass",
         "compiler/passes/uni_pass.jac": "UniPass",
         "compiler/passes/endpoint_effect_pass.jac": "EndpointEffectPass",
         "compiler/passes/sem_def_match_pass.jac": "SemDefMatchPass",
         "compiler/passes/access_check_pass.jac": "AccessCheckPass",
         "compiler/passes/jsx_intrinsic_guard_pass.jac": "JsxIntrinsicGuardPass",
         "compiler/passes/cfg_build_pass.jac": "CFGBuildPass",
         "compiler/passes/rc_facts_pass.jac": "RcFactsPass",
         "compiler/backends/py/jcir_gen_pass.jac": "JcirGenPass",
         "compiler/native_materialize.jac": "mat_parse"
     },
     NATIVE_SEAL_REFUSED_MODULES: dict[str, str] = {
         "compiler/passes/capability_check_pass.jac": (
             "one own seam left (native_capability_violations, the "
             "pass-tier crossing into ModuleCodegenPass.iter_context_stmts) "
             "and it cannot be waived: the seal's abort-stub linkage check "
             "reads the IR that ships and NativeCapabilityCheckPass."
             "transform -- the module's live entry point -- links the stub "
             "directly, so the fused artifact would abort on its first "
             "native run. Joins the fused root when transform stops calling "
             "the demoted function natively."
         )
     },
     NATIVE_SEAL_CLOSURE: tuple[str, ...] = (
         "compiler/backends/py/codegen_ir.jac",
         "compiler/frontend/codeinfo.jac",
         "compiler/frontend/constant.jac",
         "compiler/frontend/diagnostic_utils.jac",
         "compiler/frontend/diagnostics.jac",
         "compiler/frontend/helpers.jac",
         "compiler/backends/py/jcir_facts.jac",
         "compiler/frontend/parser/lexer.jac",
         "compiler/frontend/parser/parser.jac",
         "compiler/frontend/parser/tokens.jac",
         "compiler/passes/annex_weave.jac",
         "compiler/passes/ast_validation_pass.jac",
         "compiler/passes/decl_impl_match_pass.jac",
         "compiler/passes/endpoint_effect_pass.jac",
         "compiler/backends/py/jcir_gen_pass.jac",
         "compiler/backends/py/module_codegen_pass.jac",
         "compiler/passes/prefix_drive.jac",
         "compiler/passes/semantic_analysis_pass.jac",
         "compiler/passes/sym_tab_build_pass.jac",
         "compiler/passes/transform.jac",
         "compiler/passes/pass_rim.jac",
         "compiler/passes/pass_serve.jac",
         "compiler/passes/uni_pass.jac",
         "runtime/scalars.jac",
         "compiler/frontend/srcloc.jac",
         "compiler/frontend/unitree.jac",
         "compiler/expr_keys.jac",
         "compiler/native_materialize.jac",
         "compiler/passes/access_check_pass.jac",
         "compiler/passes/cfg_build_pass.jac",
         "compiler/passes/dataflow.jac",
         "compiler/passes/jsx_intrinsic_guard_pass.jac",
         "compiler/passes/rc_facts_pass.jac",
         "compiler/passes/sem_def_match_pass.jac",
         "compiler/type_registry.jac",
         "compiler/types/type_utils.jac",
         "compiler/types/types.jac",
         "project/client_kind_paths.jac",
         "client/targets/react_native/html_tag_map.jac",
         "runtime/na_stdlib/_hashlib_native.jac",
         "runtime/na_stdlib/contextvars.jac",
         "runtime/na_stdlib/fnmatch.jac",
         "runtime/na_stdlib/hashlib.jac",
         "runtime/na_stdlib/keyword.jac",
         "runtime/na_stdlib/logging.jac",
         "runtime/na_stdlib/pathlib.jac",
         "runtime/na_stdlib/textwrap.jac",

     );

glob NATIVE_SEAL_UNITREE_ROOT: str = "compiler/frontend/unitree.jac",
     NATIVE_SEAL_MATERIALIZE_ROOT: str = "compiler/native_materialize.jac";

glob _UNITREE_SEAM_WAIVERS: tuple[str, ...] = (
         "compiler/frontend/unitree.jac::ModulePath.resolve_relative_path",
         "compiler/frontend/unitree.jac::ModulePath.native_bundled_path",
         "compiler/frontend/unitree.jac::Module.annexable_by.__get__",
         "compiler/frontend/unitree.jac::Import.__jac_detected.__get__",
         "compiler/frontend/unitree.jac::Import.is_service_import.__get__",
         "compiler/frontend/unitree.jac::Ellipsis.lit_value.__get__",

     ),
     _TYPE_UTILS_SEAM_WAIVERS: tuple[str, ...] = (
         "compiler/types/type_utils.jac::class_implements_protocol",

     ),
     _HELPERS_SEAM_WAIVERS: tuple[str, ...] = (
         "compiler/frontend/helpers.jac::read_file_with_encoding",
         "compiler/frontend/helpers.jac::normalize_exclude_patterns",
         "compiler/frontend/helpers.jac::read_jacignore_patterns",

     ),
     _CODEINFO_SEAM_WAIVERS: tuple[str, ...] = (
         "compiler/frontend/codeinfo.jac::CodeGenTarget.doc_ir.__get__",
         "compiler/frontend/codeinfo.jac::_func_layout_to_dict",
         "compiler/frontend/codeinfo.jac::_inferred_native_path",
         "compiler/frontend/codeinfo.jac::effective_default_codespace",
         "compiler/frontend/codeinfo.jac::effective_native_closure_cap",
         "compiler/frontend/codeinfo.jac::install_native_static_init",
         "compiler/frontend/codeinfo.jac::is_bundled_native_module",
         "compiler/frontend/codeinfo.jac::is_client_by_location",
         "compiler/frontend/codeinfo.jac::is_native_by_location",
         "compiler/frontend/codeinfo.jac::native_layout_to_dict",
         "compiler/frontend/codeinfo.jac::native_stdlib_root",
         "compiler/frontend/codeinfo.jac::native_wasm_stem",
         "compiler/frontend/codeinfo.jac::resolve_native_module",

     ),
     _RIM_SERVE_SEAM_WAIVERS: tuple[str, ...] = (
         "compiler/passes/pass_rim.jac::PassRim.__new__",
         "compiler/passes/pass_rim.jac::require_native_pass_tier",
         "compiler/passes/pass_serve.jac::_bind_artifact",
         "compiler/passes/pass_serve.jac::_serve_error",
         "compiler/passes/pass_serve.jac::bind_sealed_pass_artifacts",

     ),
     _CLOSURE_SEAM_WAIVERS: tuple[str, ...] = (
         _UNITREE_SEAM_WAIVERS
         + _TYPE_UTILS_SEAM_WAIVERS
         + _HELPERS_SEAM_WAIVERS
         + _CODEINFO_SEAM_WAIVERS
         + _RIM_SERVE_SEAM_WAIVERS
     ),
     _CAPABILITY_SEAM_WAIVERS: tuple[str, ...] = (
         ("compiler/passes/capability_check_pass.jac::" "native_capability_violations"),

     ),
     _CFG_BUILD_SEAM_WAIVERS: tuple[str, ...] = (
         "compiler/passes/cfg_build_pass.jac::cfg_dot_from_file",
         "compiler/passes/cfg_build_pass.jac::CoalesceBBPass._node_label",

     ),
     NATIVE_SEAL_DEMOTION_WAIVERS: dict[str, tuple[str, ...]] = {
         "compiler/fused_seal_root.jac": (
             _CLOSURE_SEAM_WAIVERS + _CFG_BUILD_SEAM_WAIVERS
         ),
         "compiler/passes/capability_check_pass.jac": (
             _CLOSURE_SEAM_WAIVERS + _CAPABILITY_SEAM_WAIVERS
         )
     };

glob NATIVE_SEAL_WAIVER_FAMILIES: tuple[tuple[str, tuple[str, ...], str], ...] = (
         (
             "pass construction rim",
             _RIM_SERVE_SEAM_WAIVERS,
             "The tier tripwire and the serving binder ride every pass's "
             "MRO since the tripwire moved onto PassRim.__new__ (#8682), "
             "so pass_rim/pass_serve join each pass root's native unit. "
             "Both are host-side machinery: they read the sealed-image "
             "registry and bind artifacts through bytecode the image "
             "always carries (neither module is a native root). Their "
             "native slots are unreachable in a sealed image -- natively "
             "served passes construct through the artifact, and the "
             "bytecode lane the guard protects is exactly the lane that "
             "still has Python."
         ),
         (
             "unitree Python-only surface",
             _UNITREE_SEAM_WAIVERS,
             "Import resolution, filesystem and jac.toml reads, the "
             "CPython ast bridge, the `type`-object literal map and the `...` "
             "value. Each is infrastructure no native unit can host. "
             "They clear as the driver hands the tree data instead of "
             "handles: import detection stamped onto the node (the #8242 "
             "`absorbed_mod` pattern), codegen state crossing as records, "
             "and a native value for `Ellipsis`. `UniNode.gen.__get__` sat "
             "here until `codeinfo` joined the closure; with the module in "
             "the unit the lazy `CodeGenTarget` construction lowers and the "
             "waiver is gone. `MultiString.lit_value` asked `isinstance(part, "
             "bytes)` of a `str | bytes` value, which the two sharing the "
             "string tag cannot answer (the old lowering said False for every "
             "bytes). Whether a literal is bytes is a fact about its prefix "
             "rather than about the decoded value, so the getter reads the "
             "prefix through `is_bytes_literal` and each arm decodes to a "
             "concrete type; that waiver is gone too."
         ),
         (
             "type utils erased operands and unreachable layouts",
             _TYPE_UTILS_SEAM_WAIVERS,
             "One named backend gap: a method call on the `any`-typed "
             "`evaluator` parameter (`class_implements_protocol`), kept "
             "untyped so the keystone closure does not admit the evaluator. "
             "The MRO, completion and member-collection family cleared when "
             "the version guards moved here and `sys.hexversion` folded."
         ),
         (
             "helpers file reads and the unitree cycle",
             _HELPERS_SEAM_WAIVERS,
             "`read_file_with_encoding` passes an encoding "
             "keyword to `open()`, which the native lane refuses out loud "
             "since #8255; `normalize_exclude_patterns` and "
             "`read_jacignore_patterns` are string methods on "
             "element-erased list members. The `sys.version_info` family "
             "moved to `type_utils`, where `unitree` imports at module "
             "scope and the guards lower. `pretty_print_source_location` and "
             "`format_related_spans` sat here until their old-style `%` "
             "formatting (the `MOD on i8*` gap) became plain padding; the "
             "console gutter lowers now and `Alert.pretty_print` with it."
         ),
         (
             "codeinfo Python-only machinery and named backend gaps",
             _CODEINFO_SEAM_WAIVERS,
             "The module the emptied `PLACEMENT_INFERENCE_HELD` entry was "
             "holding out of every unit (#8323 B4). Its data model lowers "
             "whole; every seam is filesystem, config or Python-codegen "
             "machinery no native unit can host, or a named backend gap. "
             "Python-only: `native_stdlib_root`, `is_native_by_location`, "
             "`is_client_by_location` (a `jaclang.__file__` read), "
             "`effective_default_codespace` and `effective_native_closure_"
             "cap` (`project.config` reads), `_inferred_native_path` and "
             "`resolve_native_module` (the placement scan, the driver's "
             "ground), `is_bundled_native_module` (cascade), "
             "`CodeGenTarget.doc_ir.__get__` (lazy `doc_ir` import), "
             "`install_native_static_init` (writes an `any`-typed engine "
             "handle). Backend gaps: `native_layout_to_dict` and "
             "`_func_layout_to_dict` (`any` box of an optional), "
             "`native_wasm_stem` (`os.path.splitext`). None is reachable "
             "from a parse; each Python-only entry clears when its answer "
             "crosses as driver-stamped data, the #8274 pattern."
         ),
         (
             "capability pass-tier crossing",
             _CAPABILITY_SEAM_WAIVERS,
             "`native_capability_violations` calls "
             "`ModuleCodegenPass.iter_context_stmts`, a method on a sealed "
             "module's class, and the crossing clears when the module joins "
             "the fused unit rather than when the callee is fixed -- the "
             "callee reached zero seams in wave 6. The waiver does NOT "
             "make the module sealable: the seal's abort-stub linkage "
             "check measured `NativeCapabilityCheckPass.transform` "
             "-- the live entry point -- linking this stub directly, which "
             "is why the module sits in `NATIVE_SEAL_REFUSED_MODULES` with "
             "that finding as its blocker. The accounting stays so the "
             "audit keeps measuring the refused module."
         ),
         (
             "cfg_build graph tooling and erased basic-block storage",
             _CFG_BUILD_SEAM_WAIVERS,
             "`cfg_dot_from_file` opens a file and drives a whole "
             "`JacProgram` -- the `jac dot` tool, never the compile "
             "schedule -- and `CoalesceBBPass` exists only to serve it. "
             "`enter_node` and `_node_label` are that pass's own surface: "
             "the first subscripts `basic_blocks`, a "
             "`dict[int, dict[str, list[UniCFGNode]]]` whose inner entry "
             "reaches the emitter as a bare pointer, and the second "
             "cascades on `unparse_node`. They clear together when a "
             "container stored inside a container keeps its layout. "
             "`_find_next_cfg_stmt_after` was here until it learned to "
             "read the body through the classes that own one; it lowers "
             "now and its waiver is gone."
         ),

     );

def _seal_duration(seconds: float) -> str {
    if seconds < 1.0 {
        return f"{seconds * 1000:.0f}ms";
    }
    if seconds < 60.0 {
        return f"{seconds:.1f}s";
    }
    return f"{int(seconds) // 60}m{int(seconds) % 60:02d}s";
}


obj SealProgress {
    has quiet: bool = False,
        _phase: str = "",
        _t0: float = 0.0,
        _run_t0: float = 0.0,
        _open: bool = False;

    def postinit {
        self._run_t0 = time.monotonic();
    }

    def start(phase: str, detail: str = "") {
        """Open a phase and say so before it runs, not after.

        A seal is a long opaque pipeline -- compile, gate, link, canary,
        write -- and every refusal it hands back names one of those phases.
        Announcing a phase on entry is the only honest live signal available
        here: the phase's own diagnostics go to stderr and would smear
        anything redrawn in place, so nothing is redrawn. `ok`/`fail`/`again`
        then close the line with the phase's result and what it cost, and a
        seal that takes minutes reads as a log rather than as a hang.
        """;
        self._phase = phase;
        self._t0 = time.monotonic();
        self._open = True;
        if self.quiet {
            return;
        }
        mark = "▸" if console.use_emoji else ">";
        console.print(f"  {mark} {phase.ljust(8)} {detail}", style="highlight");
    }

    def note(text: str) {
        if not self.quiet {
            console.print(f"      {text}", style="muted");
        }
    }

    def ok(note: str = "") {
        if not self._open {
            return;
        }
        self._open = False;
        if self.quiet {
            return;
        }
        took = _seal_duration(time.monotonic() - self._t0);
        mark = "✔" if console.use_emoji else "ok";
        console.print(
            f"    {mark} {note}  {took}" if note else f"    {mark} {took}",
            style="success"
        );
    }

    def fail {
        if not self._open {
            return;
        }
        self._open = False;
        if self.quiet {
            return;
        }
        took = _seal_duration(time.monotonic() - self._t0);
        mark = "✖" if console.use_emoji else "FAIL";
        console.print(f"    {mark} refused after {took}", style="error");
    }

    def refuse(message: str) {
        self.fail();
        console.error(message);
    }

    def again(reason: str) {
        if self._open {
            self._open = False;
            if not self.quiet {
                took = _seal_duration(time.monotonic() - self._t0);
                mark = "↺" if console.use_emoji else "retry";
                console.print(f"    {mark} retrying after {took}", style="warning");
            }
        }
        console.warning(reason);
    }

    def facts(rows: list[tuple[str, str]]) {
        if self.quiet or not rows {
            return;
        }
        width = max(len(str(k)) for (k, _v) in rows);
        for (k, v) in rows {
            console.print(f"  {str(k).ljust(width)}  {v}");
        }
    }

    def elapsed -> str {
        return _seal_duration(time.monotonic() - self._run_t0);
    }
}


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
    coverage: dict[str, dict[str, any]], pkg_path: (Path | None) = None
) -> list[tuple[str, str, str]] {
    found: list[tuple[str, str, str]] = [];
    for (path, rec) in sorted(coverage.items()) {
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

def seal_waiver_names(
    rel: str, waivers: (dict[str, tuple[str, ...]] | None) = None
) -> tuple[set[str], set[str]] {
    table = NATIVE_SEAL_DEMOTION_WAIVERS if waivers is None else waivers;
    qualified = set(table.get(rel, ()));
    bare = {q.split("::")[-1] for q in qualified};
    return (qualified, bare);
}

def seal_demotion_report(
    rel: str,
    coverage: dict[str, dict[str, any]],
    waivers: (dict[str, tuple[str, ...]] | None) = None,
    pkg_path: (Path | None) = None
) -> tuple[str, list[str], list[str]] {
    (allowed, _bare) = seal_waiver_names(rel, waivers);
    found = _seal_demotions(coverage, pkg_path);
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
            + "\"] in jaclang/dist/precompile_bytecode.jac. The module half is "
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
            and abort_re.`match(body[1]) is not None
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
    import from jaclang.compiler.driver.jir { get_native_cache_dir }
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
                for stale in _glob.`glob(
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
    import from jaclang.compiler.driver.compile_options { env_na_debug }
    import from jaclang.runtime.native_dylib { DylibEngine }

    debug = env_na_debug();
    name = os.path.basename(lib_path);
    console.print(f"      dlopen {name}", style="muted");
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
    console.print(f"      __jac_shared_init in {name}", style="muted");
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
    console.print(f"      jac_str_new in {name}", style="muted");
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

glob _PARITY_CANARY_LINES: tuple[str, ...] = (
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
     _PARITY_CORPUS_LINES: tuple[str, ...] = (
         "# leading comment: crossing envelopes must carry comments, and a",
         "# prior parse's envelope objects must never bleed into this tree",
         "import os;",
         "def strstmt_probe -> int {",
         "    'a string statement heads this body';",
         "    return 1;",
         "}",
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
         "sem Hue.RED = \"the warm end of the corpus\";",
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
         "    LOW = 3,",
         "    HIGH = 4,",
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

glob _PARITY_IDENT_PROBES: tuple[str, ...] = (
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
    import jaclang.compiler.frontend.unitree as uni;
    out: list[str] = [];
    for nd in mod._in_mod_nodes {
        if isinstance(nd, uni.Test) {
            out.append(str(getattr(nd.__dict__.get("name"), "value", "<none>")));
        }
    }
    return out;
}


def _parity_ident_probe(np: any) -> str {
    import from jaclang.compiler.frontend.parser.lexer { tokenize_full }
    import from jaclang.compiler.frontend.parser.parser { Parser }

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


def _parity_window(items: list[str], at: int, span: int, sep: str = " ") -> str {
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


def _parity_pairwise(
    left: list[str], right: list[str], cap: int
) -> tuple[(list[str], int)] {
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
    for `entry in shown {
        out.append(f"    {`entry}");
    }
    if total > len(shown) {
        out.append(f"    ... and {total - len(shown)} more");
    }
    return nl.join(out);
}


def _parity_sym_report(canary_path: str, n_syms: list[str], p_syms: list[str]) -> str {
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


def seal_parse_parity_canary(lib_path: str, layout_dict: dict[str, any]) -> str {
    import traceback;
    import from jaclang.compiler.tools.unparse_pass { unparse_node }
    import from jaclang.compiler.driver.compile_options { env_na_debug }
    import from jaclang.compiler.frontend.parser.lexer { tokenize_full }
    import from jaclang.compiler.frontend.parser.materialize { bind_native_parser }
    import from jaclang.compiler.frontend.parser.parser { Parser }

    nl = chr(10);
    console.print(f"      parse parity in {os.path.basename(lib_path)}", style="muted");
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

def seal_prefix_parity_canary(lib_path: str, layout_dict: dict[str, any]) -> str {
    import traceback;
    import from jaclang.compiler.tools.unparse_pass { unparse_node }
    import from jaclang.compiler.driver.compile_options { env_na_debug }
    import from jaclang.compiler.frontend.parser.lexer { tokenize_full }
    import from jaclang.compiler.frontend.parser.materialize { bind_native_parser }
    import from jaclang.compiler.frontend.parser.parser { Parser }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
    import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
    import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
    import from jaclang.compiler.passes.semantic_analysis_pass { SemanticAnalysisPass }
    import from jaclang.compiler.passes.sem_def_match_pass { SemDefMatchPass }
    import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
    import from jaclang.compiler.passes.jsx_intrinsic_guard_pass {
        JsxIntrinsicGuardPass
    }

    nl = chr(10);
    console.print(
        f"      prefix parity in {os.path.basename(lib_path)}", style="muted"
    );
    try {
        np = bind_native_parser(lib_path, layout_dict);
    } except Exception as bind_exc {
        if env_na_debug() {
            traceback.print_exc(file=sys.stderr);
        }
        return f"binding failed: {type(bind_exc).__name__}: {bind_exc}";
    }
    if not np.serves_prefix() {
        return "the artifact exports no mat_parse_and_run_prefix entry";
    }
    _pfx_harness_lines = [
        (
            'test "box holds" { assert Canary(a=2).m() >= -1; }'
                if ln.startswith("test box_holds")
                else ln
        ) for ln in _PARITY_CANARY_LINES
    ];
    _pfx_alerting_lines = [
        "def m(p: int) -> int {",
        "    break;",
        "    return p;",
        "}",

    ];
    corpora = [
        (nl.join(_pfx_harness_lines), "__seal_prefix_harness__.jac", 0, ),
        (nl.join(list(_PARITY_CORPUS_LINES)), "__seal_prefix_corpus__.jac", 0, ),
        (nl.join(_pfx_alerting_lines), "__seal_prefix_alerting__.jac", 1, ),

    ];
    import from jaclang.compiler.passes.prefix_drive {
        PREFIX_NATIVE_FRONTIER as _pfx_frontier
    }
    import from jaclang.compiler.placement.prefix_flip {
        PREFIX_IR_GEN_NO_CGEN as _pfx_pin
    }
    _pfx_claim = len(_pfx_pin);
    for (canary_src, canary_path, min_rows) in corpora {
        try {
            r = np.parse_and_run_prefix(canary_src, canary_path, _pfx_claim, "", 0, 0);
        } except Exception as run_exc {
            if env_na_debug() {
                traceback.print_exc(file=sys.stderr);
            }
            return (
                f"prefix crossing of {canary_path} raised "
                f"{type(run_exc).__name__}: {run_exc}"
            );
        }
        (native_mod, n_errs, _pd, _cm, _ld, n_lex) = (
            r[0],
            r[1],
            r[2],
            r[3],
            r[4],
            r[5],

        );
        (executed, clause, detail, rows) = (r[6], r[7], r[8], r[9], );
        if n_errs or n_lex {
            _pd_head: list[str] = [];
            try {
                for _pd_row in (list(_pd) + list(_ld))[:3] {
                    _pd_head.append(
                        f"{_pd_row.loc.line}:{_pd_row.loc.col_start} "
                        f"{str(_pd_row.message)[:90]}"
                    );
                }
            } except Exception as _pd_exc {
                _pd_head.append(f"<diag rows unreadable: {_pd_exc}>");
            }
            return (
                f"{canary_path}: the seal corpus did not parse "
                f"({n_errs}/{n_lex}): {'; '.join(_pd_head)}"
            );
        }
        if executed != _pfx_frontier {
            return (
                f"{canary_path}: the crossing executed {executed}, but the "
                f"native frontier claims {_pfx_frontier} ({clause}: {detail})"
            );
        }
        if len(rows) < min_rows {
            return (
                f"{canary_path}: the alerting corpus produced {len(rows)} "
                f"row(s); a canary that cannot see an alert is decoration"
            );
        }
        (tokens, _c, _lx, lex_errs) = tokenize_full(canary_src, canary_path);
        pyp = Parser(tokens=tokens, file_path=canary_path, source_code=canary_src);
        py_mod = pyp.parse();
        if pyp.error_count or lex_errs {
            return f"{canary_path}: the staged parse of the corpus errored";
        }
        prog = JacProgram();
        staged_rows: list[tuple] = [];
        _pfx_all_passes = (
            ASTValidationPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass,
            JsxIntrinsicGuardPass,

        );
        for (pass_ord, cls) in enumerate(_pfx_all_passes[:_pfx_frontier]) {
            inst: any = cls(ir_in=py_mod);
            for e in inst.errors_had {
                staged_rows.append(
                    (
                        1,
                        e.code.code if e.code is not None else "",
                        e.msg,
                        e.loc.first_line,
                        e.loc.col_start,
                        e.loc.pos_start,
                        e.loc.pos_end,
                        pass_ord,

                    )
                );
            }
            for w in inst.warnings_had {
                staged_rows.append(
                    (
                        0,
                        w.code.code if w.code is not None else "",
                        w.msg,
                        w.loc.first_line,
                        w.loc.col_start,
                        w.loc.pos_start,
                        w.loc.pos_end,
                        pass_ord,

                    )
                );
            }
        }
        native_rows = [
            (rr[0], rr[1], rr[2], rr[4], rr[5], rr[6], rr[7], rr[8], ) for rr in rows
        ];
        if native_rows != staged_rows {
            return (
                f"{canary_path}: the alert streams diverged "
                f"(prefix {len(native_rows)} row(s), staged "
                f"{len(staged_rows)}): {native_rows[:3]} != {staged_rows[:3]}"
            );
        }
        native_up = unparse_node(native_mod);
        py_up = unparse_node(py_mod);
        if native_up != py_up {
            return _parity_text_report(canary_path, native_up, py_up);
        }
        n_syms: list[str] = [];
        p_syms: list[str] = [];
        try {
            n_syms = _sym_name_fingerprint(native_mod);
            p_syms = _sym_name_fingerprint(py_mod);
        } except Exception as sym_exc {
            return (
                f"{canary_path}: post-pass symbol fingerprint raised "
                f"{type(sym_exc).__name__}: {sym_exc}"
            );
        }
        if n_syms != p_syms {
            return _parity_sym_report(canary_path, n_syms, p_syms);
        }
        n_tab: list[str] = [];
        p_tab: list[str] = [];
        try {
            n_tab = _sym_table_fingerprint(native_mod);
            p_tab = _sym_table_fingerprint(py_mod);
        } except Exception as tab_exc {
            return (
                f"{canary_path}: post-pass symbol table fingerprint raised "
                f"{type(tab_exc).__name__}: {tab_exc}"
            );
        }
        if n_tab != p_tab {
            return _parity_table_report(canary_path, n_tab, p_tab);
        }
    }
    return "";
}

glob _MERGE_PROBE_MAIN: tuple[str, ...] = (
         "obj Widget {",
         "    has size: int = 1;",
         "    def grow(n: int) -> int;",
         "}",
         "with entry { print(Widget(size=2)); }",

     ),
     _MERGE_PROBE_ANNEX: tuple[str, ...] = (
         "impl Widget.grow(n: int) -> int {",
         "    self.size += n;",
         "    return self.size;",
         "}",
         "test \"widget grows\" { assert Widget().grow(2) == 3; }",

     );

def _merge_probe_parity(np: any) -> str {
    import from jaclang.compiler.frontend.parser.lexer { tokenize_full }
    import from jaclang.compiler.frontend.parser.parser { Parser }
    import from jaclang.compiler.passes.annex_weave { merge_annex_into }
    import from jaclang.compiler.tools.unparse_pass { unparse_node }

    nl = chr(10);
    main_src = nl.join(list(_MERGE_PROBE_MAIN));
    annex_src = nl.join(list(_MERGE_PROBE_ANNEX));
    main_path = "__seal_merge_probe__.jac";
    annex_path = "__seal_merge_probe__.impl.jac";
    console.print("      mat_merge_probe (native annex merge)", style="muted");
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
    merge_annex_into(py_main, py_annex);
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

glob _JCIR_PROBE_LINES: tuple[str, ...] = (
         "\"\"\"Container probe.\"\"\"",
         "# a comment the crossing must not move",
         "glob seeded: int = 1;",
         "",
         "def widen(n: int) -> int {",
         "    total = n + seeded;  # a trailing comment",
         "    return total;",
         "}",
         "",
         "test \"a string named probe\" { assert widen(1) == 2; }",
         "",
         "with entry { widened = widen(2); }",

     );

def _jcir_code_field_diffs(a: any, b: any, at: str, out: list[str]) -> list[str] {
    import types;
    for attr in (
        "co_name",
        "co_qualname",
        "co_filename",
        "co_firstlineno",
        "co_argcount",
        "co_posonlyargcount",
        "co_kwonlyargcount",
        "co_nlocals",
        "co_stacksize",
        "co_flags",
        "co_code",
        "co_names",
        "co_varnames",
        "co_freevars",
        "co_cellvars",
        "co_linetable",
        "co_exceptiontable"
    ) {
        av = getattr(a, attr, None);
        bv = getattr(b, attr, None);
        if av != bv {
            out.append(f"{at}.{attr}: reference {av!r} vs crossing {bv!r}");
        }
    }
    if len(a.co_consts) != len(b.co_consts) {
        out.append(f"{at}.co_consts length {len(a.co_consts)} vs {len(b.co_consts)}");
        return out;
    }
    for (i, (x, y)) in enumerate(zip(a.co_consts, b.co_consts)) {
        if (isinstance(x, types.CodeType) and isinstance(y, types.CodeType)) {
            _jcir_code_field_diffs(x, y, f"{at}.consts[{i}]", out);
        } elif (x != y or type(x) is not type(y)) {
            out.append(f"{at}.consts[{i}]: reference {x!r} vs crossing {y!r}");
        }
    }
    return out;
}

def seal_jcir_container_canary(lib_path: str) -> str {
    import ast as pyast;
    import traceback;
    import from jaclang.compiler.backends.py.codegen_shim { transcribe }
    import from jaclang.compiler.driver.compile_options { CompileOptions, env_na_debug }
    import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
    import from jaclang.compiler.driver.program { JacProgram }

    nl = chr(10);
    probe_path = "__seal_jcir_probe__.jac";
    probe_src = nl.join(list(_JCIR_PROBE_LINES));
    console.print(
        f"      jcir container crossing in {os.path.basename(lib_path)}", style="muted"
    );
    blobs: list[bytes] = [];
    trees: list[any] = [];
    for _round in (0, 1) {
        prog = JacProgram();
        try {
            mod = prog.compile(
                use_str=probe_src,
                file_path=probe_path,
                options=CompileOptions(
                    force_codespace="server",
                    skip_native_engine=True,
                    no_ir_cache=True,
                    suppress_codes=["E5092"]
                )
            );
        } except Exception as probe_exc {
            if env_na_debug() {
                traceback.print_exc(file=sys.stderr);
            }
            return (
                f"the probe did not compile: "
                f"{type(probe_exc).__name__}: {probe_exc}"
            );
        }
        if prog.errors_had {
            return (
                f"the probe did not compile cleanly: "
                f"{[str(e) for e in prog.errors_had][:3]}"
            );
        }
        blobs.append(JcirGenPass(ir_in=mod).ir_bytes());
        trees.append(mod.gen.py_ast[0]);
    }
    if blobs[0] != blobs[1] {
        return (
            f"the container is not byte stable: two emissions of the probe "
            f"produced {len(blobs[0])} and {len(blobs[1])} bytes that differ. "
            "The container is what crosses the boundary and what a cache keys "
            "on, so an unstable encoding cannot ship."
        );
    }
    (mods, diags) = transcribe(blobs[0]);
    if diags {
        return f"the probe container carried unexpected diagnostics: {diags}";
    }
    if len(mods) != 1 or mods[0][0] != probe_path {
        return f"the probe container carried {len(mods)} module(s), not the probe";
    }
    want = pyast.dump(trees[0], include_attributes=True);
    got = pyast.dump(mods[0][1], include_attributes=True);
    if want != got {
        i = 0;
        n = min(len(want), len(got));
        while (i < n and want[i] == got[i]) {
            i += 1;
        }
        lo = max(0, i - 120);
        return (
            f"the crossing lost fidelity at offset {i}{nl}"
            f"want: ...{want[lo:i + 200]}{nl}"
            f"got:  ...{got[lo:i + 200]}"
        );
    }
    ref_code = compile(trees[0], probe_path, "exec");
    got_code = compile(mods[0][1], probe_path, "exec");
    code_diffs = _jcir_code_field_diffs(ref_code, got_code, "<module>", []);
    if code_diffs {
        return (
            f"{len(code_diffs)} code object field(s) diverged across the "
            f"crossing:{nl}"
            + nl.join(f"    {d}" for d in code_diffs[:10])
        );
    }
    return "";
}

def _sym_name_fingerprint(mod: any) -> list[str] {
    import jaclang.compiler.frontend.unitree as uni;
    out: list[str] = [];
    for nd in mod._in_mod_nodes {
        `entry = "";
        if isinstance(nd, uni.AstSymbolNode) {
            try {
                `entry = f"{type(nd).__name__}:{nd.sym_name}";
            } except Exception as sym_exc {
                `entry = f"{type(nd).__name__}:<{type(sym_exc).__name__}>";
            }
        }
        if "body" in nd.__dict__ {
            nd_body = nd.__dict__.get("body");
            body_shape = f"list:{len(nd_body)}"
                if isinstance(nd_body, (list, tuple))
                else ("none" if nd_body is None else f"node:{type(nd_body).__name__}");
            `entry = f"{`entry or type(nd).__name__}|body={body_shape}";
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
            `entry = f"{`entry or type(nd).__name__}|spec={spec_shape}";
        }
        if `entry {
            out.append(`entry);
        }
    }
    return out;
}

def _sym_table_fingerprint(mod: any) -> list[str] {
    import jaclang.compiler.frontend.unitree as uni;
    out: list[str] = [];
    for nd in mod._in_mod_nodes {
        if isinstance(nd, uni.UniScopeNode) {
            scope_names: dict[str, any] = dict(nd.names_in_scope or {});
            over_names: dict[str, any] = dict(nd.names_in_scope_overload or {});
            rebind_names: dict[str, any] = dict(nd.implicit_rebinds or {});
            names = ",".join(sorted(scope_names.keys()));
            over = ",".join(sorted(over_names.keys()));
            reb = ",".join(sorted(rebind_names.keys()));
            kids = len(list(nd.kid_scope or []));
            has_parent = "y" if nd.parent_scope is not None else "n";
            sem_parts: list[str] = [];
            for nm in sorted(scope_names.keys()) {
                scope_sym = scope_names[nm];
                if isinstance(scope_sym, uni.Symbol) and scope_sym.semstr {
                    sem_parts.append(f"{nm}={scope_sym.semstr}");
                }
            }
            sems = ",".join(sem_parts);
            out.append(
                f"scope {type(nd).__name__}:{nd.scope_name} names=[{names}] "
                f"over=[{over}] rebind=[{reb}] kids={kids} parent={has_parent} "
                f"sems=[{sems}]"
            );
        }
        if isinstance(nd, uni.NameAtom) {
            sym = nd.__dict__.get("_sym");
            if not isinstance(sym, uni.Symbol) {
                out.append(f"name {type(nd).__name__} sym=none");
            } else {
                out.append(
                    f"name {type(nd).__name__} sym={sym.sym_name}:"
                    f"{sym.access} defn={len(sym.defn)} uses={len(sym.uses)}"
                );
            }
        }
    }
    return out;
}


def _parity_table_report(canary_path: str, n_tab: list[str], p_tab: list[str]) -> str {
    nl = chr(10);
    at = _parity_diff_at(n_tab, p_tab);
    n_show = n_tab[at] if at < len(n_tab) else "<end>";
    p_show = p_tab[at] if at < len(p_tab) else "<end>";
    return nl.join(
        [
            f"{canary_path}: the symbol table diverged at entry {at + 1} of "
            f"{len(n_tab)} native / {len(p_tab)} bytecode: "
            f"native {n_show!r} vs bytecode {p_show!r}",
            f"    native   {_parity_window(n_tab, at, 2, sep=' | ')}",
            f"    bytecode {_parity_window(p_tab, at, 2, sep=' | ')}"
        ]
    );
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

def seal_export_symbols(
    layout_dict: dict[str, any], clib_symbols: any = None
) -> list[str] {
    clib = set(clib_symbols or ());
    names = {
        fn_name
        for fn_name in (layout_dict.get("functions") or {})
        if fn_name not in clib
    };
    structs: dict[str, dict[str, any]] = layout_dict.get("structs") or {};
    for struct_def in structs.values() {
        accessors: dict[str, dict[str, str]] = struct_def.get("accessors") or {};
        for kinds in accessors.values() {
            names.update(kinds.values());
        }
    }
    return sorted(names);
}

glob PRECOMPILED_KEEP_DIRS: tuple[str, ...] = ("native", );

def prune_stale_precompiled_dirs(precompiled_dir: Path, pyver: str) -> int {
    removed = 0;
    for stale_dir in sorted(precompiled_dir.iterdir()) {
        if not stale_dir.is_dir()
            or stale_dir.name == pyver
            or stale_dir.name in PRECOMPILED_KEEP_DIRS {
            continue;
        }
        shutil.rmtree(stale_dir, ignore_errors=True);
        removed += 1;
    }
    return removed;
}

def prune_native_outputs(precompiled_dir: Path, keep: set[str]) -> int {
    native_root = precompiled_dir / "native";
    if not native_root.is_dir() {
        return 0;
    }
    removed = 0;
    for found in sorted(native_root.rglob("*")) {
        if not found.is_file() {
            continue;
        }
        rel_out = found.relative_to(precompiled_dir).as_posix();
        if rel_out in keep {
            continue;
        }
        found.unlink(missing_ok=True);
        removed += 1;
    }
    for found in sorted(native_root.rglob("*"), reverse=True) {
        if found.is_dir() and not any(found.iterdir()) {
            found.rmdir();
        }
    }
    return removed;
}

def _seal_module_fullname(pkg_name: str, rel: str) -> str {
    stem = ext_registry.base_stem(os.path.basename(rel));
    parts = [
        p
        for p in os.path.dirname(rel).split("/")
        if p
    ];
    return ".".join([pkg_name] + parts + [stem]);
}

def generate_fused_seal_root(pkg_path: Path) -> Path {
    src = pkg_path / NATIVE_SEAL_FUSED_ROOT;
    lines: list[str] = [
        "'''GENERATED at seal time by jaclang/dist/precompile_bytecode.jac.",
        "",
        "The fused native seal root (#8707): importing every served module",
        "folds the whole compiler closure into a single native unit, so the",
        "seal emits one shared library and one layout for all of them.",
        "'''"
    ];
    for rel in NATIVE_SEAL_SERVED_MODULES {
        fullname = _seal_module_fullname(pkg_path.name, rel);
        symbol = NATIVE_SEAL_SERVED_IMPORTS[rel];
        lines.append("import from " + fullname + " { " + symbol + " }");
    }
    src.write_text("\n".join(lines) + "\n", encoding="utf-8");
    return src;
}

def derive_unitree_layout(pkg_path: Path) -> (dict[str, any] | None) {
    import gc;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.frontend.codeinfo { native_layout_to_dict }

    src = pkg_path / NATIVE_SEAL_UNITREE_ROOT;
    if not src.is_file() {
        console.error(f"NATIVE SEAL: missing source {src}");
        return None;
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(src),
        options=CompileOptions(
            aot_mode=True,
            force_codespace='native',
            force_target_program=True,
            na_gc_mode='cycles',
            no_ir_cache=True
        )
    );
    if prog.errors_had {
        for _err in prog.errors_had {
            console.error(f"NATIVE SEAL: {_err.pretty_print()}");
        }
        return None;
    }
    if ir is None or ir.gen.native_layout is None {
        console.error(f"NATIVE SEAL: no native layout for {NATIVE_SEAL_UNITREE_ROOT}");
        return None;
    }
    layout = native_layout_to_dict(ir.gen.native_layout);
    del ir;
    del prog;
    gc.collect();
    return layout;
}

def seal_one_root(
    pkg_path: Path,
    precompiled_dir: Path,
    rel: str,
    waivers: (dict[str, tuple[str, ...]] | None) = None,
    lib_stem: (str | None) = None,
    extra_layout_entries: (dict[str, any] | None) = None,
    full_canaries: bool = False,
    ir_out: (str | None) = None,
    progress: (SealProgress | None) = None
) -> (dict[str, any] | None) {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.frontend.codeinfo { native_layout_to_dict }
    import from jaclang.compiler.driver.na_coverage {
        na_coverage_begin,
        na_coverage_end
    }
    import from jaclang.compiler.backends.native.shared_emit { emit_shared_library }
    import jaclang.compiler.backends.native.llvm.binding as llvm;

    src: Path = pkg_path / str(rel);
    if not src.is_file() {
        console.error(f"NATIVE SEAL: missing source {src}");
        return None;
    }
    triple = llvm.get_default_triple();
    assert isinstance(triple, str);
    out_dir = precompiled_dir / "native" / triple;
    stem = lib_stem or ext_registry.base_stem(os.path.basename(rel));
    fullname = _seal_module_fullname(pkg_path.name, rel);
    lib_path = out_dir / _native_lib_filename(stem);
    layout_path = out_dir / f"{stem}.layout.json";
    say = progress or SealProgress();
    for _seal_attempt in range(2) {
        say.start("compile", f"lowering {rel} and its native closure");
        prog = JacProgram();
        na_coverage_begin();
        try {
            ir = prog.compile(
                file_path=str(src),
                options=CompileOptions(
                    aot_mode=True,
                    force_codespace='native',
                    force_target_program=True,
                    na_gc_mode='cycles',
                    no_ir_cache=True
                )
            );
        } finally {
            coverage = na_coverage_end();
        }
        closure_deps: list[str] = [];
        if ir is not None and ir.gen.interop_manifest is not None {
            closure_deps = list(ir.gen.interop_manifest.native_transitive_sources);
        }
        if prog.errors_had {
            say.fail();
            for _err in prog.errors_had {
                console.error(f"NATIVE SEAL: {_err.pretty_print()}");
            }
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        if ir is None or ir.gen.llvm_ir is None or ir.gen.native_layout is None {
            say.refuse(f"NATIVE SEAL: no native IR/layout for {rel}");
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        say.ok(f"{len(closure_deps) + 1} source(s) in the closure");
        manifest = ir.gen.interop_manifest;
        if manifest is not None and manifest.native_imports {
            say.refuse(
                f"NATIVE SEAL: {rel} has Python-side imports; artifact would "
                "need in-process callbacks and cannot be sealed AOT."
            );
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        say.start("gate", "demotion report -- nothing may fall back to Python");
        (demotion_error, waived, stale_waivers) = seal_demotion_report(
            rel, coverage, waivers, pkg_path
        );
        if demotion_error {
            purge_native_ir_cache(str(src), closure_deps);
            if _seal_attempt == 0 {
                say.again(
                    f"NATIVE SEAL: {rel} reported un-waived demotions that may "
                    "be verdicts served from dependency IR cached outside the "
                    "seal; the cached IR for this closure has been purged and "
                    "the closure recompiles fresh."
                );
                continue;
            }
            say.refuse(demotion_error);
            return None;
        }
        say.ok(f"{len(waived)} demotion(s) waived" if waived else "no demotions");
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
        say.start("gate", "abort-stub scan over the IR that actually ships");
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
        if not shipped_stubs {
            say.ok("no abort stubs");
            break;
        }
        purge_native_ir_cache(str(src), closure_deps);
        if _seal_attempt == 0 {
            say.again(
                f"NATIVE SEAL: {rel} would link abort stub(s) "
                f"({', '.join(shipped_stubs)}) served from cached "
                "dependency IR compiled outside the seal; the cached IR "
                "for this closure has been purged and the closure "
                "recompiles fresh."
            );
            continue;
        }
        say.refuse(
            f"NATIVE SEAL: {rel} would link {len(shipped_stubs)} abort "
            f"stub(s) into its artifact: {', '.join(shipped_stubs)}. This "
            "is read off the IR that actually ships, and it held even "
            "after the closure's cached IR was purged and recompiled "
            "fresh, so the demotion is deterministic; fix the backend "
            "gap or waive it in NATIVE_SEAL_DEMOTION_WAIVERS."
        );
        return None;
    }
    say.start("layout", "reading the artifact's exported surface");
    layout = ir.gen.native_layout;
    if layout is None {
        say.refuse(f"NATIVE SEAL: no native layout for {rel}");
        purge_native_ir_cache(str(src), closure_deps);
        return None;
    }

    _clib_syms = set((ir.gen._clib_symbol_lib or {}).keys());
    exports = sorted(
        fn_name
        for fn_name in layout.functions.keys()
        if fn_name not in _clib_syms
    );
    if not exports {
        say.refuse(f"NATIVE SEAL: {rel} exports no module functions");
        purge_native_ir_cache(str(src), closure_deps);
        return None;
    }

    layout_dict = native_layout_to_dict(layout);
    for (extra_key, extra_val) in (extra_layout_entries or {}).items() {
        layout_dict[extra_key] = extra_val;
    }
    _stub_syms = set(seal_abort_stubs(llvm_ir_text));
    _layout_structs: dict[str, dict[str, any]] = layout_dict["structs"];
    for _sd in _layout_structs.values() {
        _sd_accessors: dict[str, dict[str, str]] = _sd.get("accessors") or {};
        _live = {
            _fname: {
                _kind: _sym
                for (_kind, _sym) in _kinds.items()
                if _sym not in _stub_syms
            } for (_fname, _kinds) in _sd_accessors.items()
        };
        _sd["accessors"] = {
            _fname: _kinds
            for (_fname, _kinds) in _live.items()
            if _kinds
        };
    }
    exports = seal_export_symbols(layout_dict, _clib_syms);
    say.ok(f"{len(exports)} export(s), {len(_layout_structs)} struct(s)");
    out_dir.mkdir(parents=True, exist_ok=True);
    if ir_out {
        Path(ir_out).parent.mkdir(parents=True, exist_ok=True);
        Path(ir_out).write_text(llvm_ir_text, encoding="utf-8");
        say.note(f"IR written to {ir_out}");
    }
    say.start("link", f"emitting {lib_path.name}");
    lib_path.unlink(missing_ok=True);
    layout_path.unlink(missing_ok=True);
    (ok, err) = emit_shared_library(
        str(ir.gen.llvm_ir),
        manifest,
        exports,
        str(lib_path),
        clib_paths=list(ir.gen._clib_paths or []),
        clib_symbol_lib=dict(ir.gen._clib_symbol_lib or {})
    );
    if not ok {
        say.refuse(f"NATIVE SEAL: {rel}: {err}");
        purge_native_ir_cache(str(src), closure_deps);
        return None;
    }
    say.ok(f"{lib_path.stat().st_size:,} bytes");
    say.start("canary", f"loading and calling into {lib_path.name}");
    canary = seal_native_canary(str(lib_path), exports);
    if canary {
        say.refuse(
            f"NATIVE SEAL: {rel}: the emitted artifact "
            f"{lib_path.name} failed its load canary: {canary}. The seal "
            "refuses artifacts it cannot load and call; set JAC_NA_DEBUG=1 "
            "for the traceback."
        );
        lib_path.unlink(missing_ok=True);
        purge_native_ir_cache(str(src), closure_deps);
        return None;
    }
    say.ok("dlopen, exports, shared init");
    say.start("write", f"{layout_path.name} beside the artifact");
    layout_path.write_text(
        json.dumps(layout_dict, sort_keys=True) + "\n", encoding="utf-8"
    );
    say.ok(f"{layout_path.stat().st_size:,} bytes");
    if full_canaries {
        say.start("canary", "container crossing and parse/prefix parity");
        crossing = seal_jcir_container_canary(str(lib_path));
        if crossing {
            say.refuse(
                f"NATIVE SEAL: {rel}: the emitted artifact "
                f"{lib_path.name} failed its container crossing canary. "
                "The seal refuses a JCIR producer whose container is not "
                "byte stable or whose crossing is lossy; set "
                f"JAC_NA_DEBUG=1 for the traceback.{chr(10)}{crossing}"
            );
            lib_path.unlink(missing_ok=True);
            layout_path.unlink(missing_ok=True);
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        parity = seal_parse_parity_canary(str(lib_path), layout_dict);
        if not parity {
            parity = seal_prefix_parity_canary(str(lib_path), layout_dict);
        }
        if parity {
            say.refuse(
                f"NATIVE SEAL: {rel}: the emitted artifact "
                f"{lib_path.name} failed its parity canaries. The seal "
                "refuses artifacts whose parse or prefix does not match "
                "the staged route; set JAC_NA_DEBUG=1 for the full "
                f"unparsed texts and the traceback.{chr(10)}{parity}"
            );
            _keep_dir = os.environ.get("JAC_SEAL_KEEP_REFUSED", "");
            if _keep_dir {
                import shutil as _keep_sh;
                _keep_sh.copy2(str(lib_path), _keep_dir);
                _keep_sh.copy2(str(layout_path), _keep_dir);
            }
            lib_path.unlink(missing_ok=True);
            layout_path.unlink(missing_ok=True);
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        say.ok("byte-stable container, parse and prefix match");
    }
    artifact_entry: dict[str, any] = {
        "lib": lib_path.relative_to(precompiled_dir).as_posix(),
        "layout": layout_path.relative_to(precompiled_dir).as_posix(),
        "triple": triple,
        "lib_sha256": hashlib.sha256(lib_path.read_bytes()).hexdigest(),
        "layout_sha256": hashlib.sha256(layout_path.read_bytes()).hexdigest()
    };
    say.note(
        f"{fullname} -> {lib_path.name} "
        f"({lib_path.stat().st_size:,} bytes, {len(exports)} exports)"
    );
    return artifact_entry;
}

def seal_native_artifacts(
    pkg_path: Path,
    precompiled_dir: Path,
    waivers: (dict[str, tuple[str, ...]] | None) = None,
    ir_out: (str | None) = None,
    progress: (SealProgress | None) = None
) -> (dict[str, any] | None) {
    if sys.platform.startswith("win") {
        stale_native = precompiled_dir / "native";
        if stale_native.is_dir() {
            shutil.rmtree(stale_native, ignore_errors=True);
        }
        return {};
    }
    import atexit;
    import from jaclang.dist.gen_native_materialize {
        generate as generate_materialize_root
    }
    say = progress or SealProgress();

    say.start("stage", "generating the materializer and the fused seal root");
    unitree_layout = derive_unitree_layout(pkg_path);
    if unitree_layout is None {
        say.fail();
        return None;
    }
    say.note(f"unitree layout: {len(unitree_layout.get('structs') or {})} struct(s)");
    mat_src = pkg_path / NATIVE_SEAL_MATERIALIZE_ROOT;
    mat_result: dict[str, any] = generate_materialize_root(
        unitree_layout, mat_src, _UNITREE_SEAM_WAIVERS
    );
    atexit.register(mat_src.unlink, missing_ok=True);
    say.note(f"{mat_src.name} generated");
    for mat_warn in (mat_result.pop("warnings", None) or []) {
        console.warning(
            f"NATIVE SEAL: the materializer erased a slot: {mat_warn}. "
            "The Python side must reconstruct it (postinit or a lazy "
            "accessor) or the materialized tree loses that value."
        );
    }
    fused_src = generate_fused_seal_root(pkg_path);
    atexit.register(fused_src.unlink, missing_ok=True);
    say.ok(
        f"{fused_src.name} fuses {len(NATIVE_SEAL_SERVED_MODULES)} served module(s)"
    );
    try {
        artifact_entry = seal_one_root(
            pkg_path,
            precompiled_dir,
            NATIVE_SEAL_FUSED_ROOT,
            waivers=waivers,
            lib_stem=NATIVE_SEAL_LIB_STEM,
            extra_layout_entries={"materialize_manifest": mat_result},
            full_canaries=True,
            ir_out=ir_out,
            progress=say
        );
    } finally {
        fused_src.unlink(missing_ok=True);
        mat_src.unlink(missing_ok=True);
    }
    if artifact_entry is None {
        return None;
    }
    prune_native_outputs(
        precompiled_dir, {str(artifact_entry["lib"]), str(artifact_entry["layout"])}
    );
    modules = sorted(
        _seal_module_fullname(pkg_path.name, served_rel)
        for served_rel in NATIVE_SEAL_SERVED_MODULES
    );
    return {"artifact": artifact_entry, "modules": modules};
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

def app_metadata(pkg_path: Path, pkg_name: str) -> dict[str, any] {
    if not (pkg_path / "jac.toml").is_file() {
        return {};
    }
    import from jaclang.project.config { get_config_for_path }
    import from jaclang.project.kinds { resolve_project_kind, resolve_entry }
    import from jaclang.server.sealed_serve { CLIENT_DIST_REL, NATIVE_DIR_REL }

    config = get_config_for_path(pkg_path);
    if config is None {
        return {};
    }
    entry_path = resolve_entry(config, str(pkg_path));
    kind = resolve_project_kind(config, entry_path);

    `entry: dict[str, str] = {};
    if entry_path and Path(entry_path).is_file() {
        rel = Path(entry_path).resolve().relative_to(pkg_path.resolve()).as_posix();
        stem = ext_registry.base_stem(os.path.basename(entry_path));
        `entry = {"module": f"{pkg_name}.{stem}", "path": rel};
    }

    caps: list[str] = [];
    if kind in ["service", "service-mesh", "web-app", "desktop", "mobile"] {
        caps.append("has-server");
    }
    if `entry {
        caps.append("has-entry");
    }
    if (pkg_path / CLIENT_DIST_REL).is_dir()
        or kind in ["web-app", "desktop", "mobile"] {
        caps.append("has-client");
    }
    if (pkg_path / NATIVE_DIR_REL).is_dir() {
        caps.append("has-native");
    }
    if kind in ["py-package", "js-package"] or not `entry {
        caps.append("attachable");
    }

    meta = {"kind": kind, "capabilities": caps, "entry": `entry};
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
    import from jaclang.server.sealed_serve {
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

    console.print("  Freezing the bootstrap seed layer...");
    boot_failed = seal_bootstrap(pkg_path, out_dir, embed_src);
    if boot_failed > 0 {
        console.error(f"Seal aborted: {boot_failed} bootstrap module(s) failed.");
        return 1;
    }

    native_seal: (dict[str, any] | None) = None;
    if pkg_name == "jaclang" {
        console.print("  Sealing the fused AOT native artifact...");
        native_record = seal_native_artifacts(pkg_path, precompiled_dir);
        if native_record is None {
            console.error("Seal aborted: native artifact build failed.");
            return 1;
        }
        if sys.platform.startswith("win") {
            native_seal = {
                "artifact": None,
                "modules": [],
                "skip_reason": "platform:win"
            };
        } else {
            native_seal = {
                "artifact": native_record["artifact"],
                "modules": native_record["modules"],
                "skip_reason": None
            };
        }
    }

    manifest_modules: dict[str, dict[str, any]] = {};
    n_boot = 0;
    for jir in sorted(out_dir.rglob("*.jir")) {
        rel_jir = jir.relative_to(out_dir).as_posix();
        (source_rel, fullname, is_pkg) = jir_to_module(pkg_name, rel_jir);
        `entry = {
            "module": fullname,
            "jir": rel_jir,
            "package": is_pkg,
            "sha256": hashlib.sha256(jir.read_bytes()).hexdigest()
        };
        import from jaclang.bootstrap_manifest { is_seed_source }
        if is_seed_source(source_rel) {
            `entry["bootstrap"] = True;
            n_boot += 1;
        }
        manifest_modules[source_rel] = `entry;
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
    modules: dict[str, dict[str, any]],
    payloads: (dict[str, str] | None) = None,
    app_meta: (dict[str, any] | None) = None,
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
        manifest["native"] = {
            "artifact": native_seal.get("artifact"),
            "modules": native_seal.get("modules") or [],
            "skip_reason": native_seal.get("skip_reason")
        };
    }
    (precompiled_dir / MANIFEST_NAME).write_text(
        json.dumps(manifest, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );
}

def precompile_exit(code: int) {
    sys.stdout.flush();
    sys.stderr.flush();
    os._exit(code);
}

def main {
    args = sys.argv[1:];
    seal = "--seal" in args;
    seal_compile = "--seal-compile" in args;
    finalize_only = "--seal-finalize" in args;
    embed_src = "--debug-src" in args;
    exclude_seed = seal or seal_compile;
    args = [
        a
        for a in args
        if not a.startswith("--")
    ];
    if not args {
        console.print(
            "Usage: jac run dist/precompile_bytecode.jac<package-source-dir> [--seal|--seal-finalize] [--debug-src]"
        );
        console.print("\nExamples:");
        console.print("  jac run dist/precompile_bytecode.jac./jac");
        console.print("  jac run dist/precompile_bytecode.jac./jac/jaclang/scale");
        console.print("\n--seal: precompile, freeze the bootstrap seed tier, and emit");
        console.print("        MANIFEST.json (JIR-authoritative image; .jac sources");
        console.print(
            "        stay on disk for tracebacks, never compiled at runtime)."
        );
        console.print(
            "--seal-compile: compile only (exclude the seed tier), no finalize -- the"
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
        sys.`exit(1);
    }

    source_dir = args[0];
    package_dir = find_package_dir(source_dir);
    if package_dir is None {
        console.error(f"Could not find a Python package in {source_dir}");
        sys.`exit(1);
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
        sys.`exit(1);
    }
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    precompiled_dir = Path(package_dir) / "_precompiled";

    if finalize_only {
        console.print(f"Sealing {pkg_name} for {pyver} (finalize)...");
        precompile_exit(
            seal_finalize(
                Path(package_dir), precompiled_dir, pkg_name, pyver, embed_src
            )
        );
    }

    console.print(f"Precompiling {pkg_name} for {pyver}...");
    console.print(f"  Package directory: {package_dir}");
    console.print(f"  Compiler identity: {compiler_identity()}");

    jac_files = (
        sealable_sources(package_dir) if exclude_seed else find_jac_files(package_dir)
    );
    console.print(f"  Found {len(jac_files)} .jac files");

    if not jac_files and not exclude_seed {
        console.print("  No .jac files to precompile.");
        sys.`exit(0);
    }

    out_dir = precompiled_dir / pyver;
    out_dir.mkdir(parents=True, exist_ok=True);
    (precompiled_dir / RESULT_NAME).unlink(missing_ok=True);

    prune_stale_precompiled_dirs(precompiled_dir, pyver);
    pkg_path = Path(package_dir);
    expected: set[str] = {
        str(Path(p).relative_to(pkg_path).with_suffix(".jir")) for p in jac_files
    };
    for old_jir in sorted(out_dir.rglob("*.jir")) {
        if str(old_jir.relative_to(out_dir)) not in expected {
            old_jir.unlink();
        }
    }

    import from jaclang.compiler.driver.jir { read_debug_source }

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
        precompile_exit(
            seal_finalize(pkg_path, precompiled_dir, pkg_name, pyver, embed_src)
        );
    }

    precompile_exit(1 if failed else 0);
}

with entry:__main__ {
    main();
}
