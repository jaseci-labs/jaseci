import os;
import from contextvars { ContextVar }
import from jaclang.compiler.backends.py.jcir_bc_gen_pass { JcirBytecodeGenPass }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.boundary_analysis_pass { BoundaryAnalysisPass }
import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
import from jaclang.compiler.passes.endpoint_effect_pass { EndpointEffectPass }
import from jaclang.compiler.passes.semantic_analysis_pass { SemanticAnalysisPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.placement.placement_solver { PlacementApplyPass }
import from jaclang.compiler.driver.source_failures { fail_loud_on_compiler_source }

def get_symtab_ir_sched -> list[type[Transform]] {
    if not _ir_sched_loading.get() {
        _tok = _ir_sched_loading.set(True);
        try {
            import jaclang.compiler.symbol_utils;
        } except ImportError as e {
            fail_loud_on_compiler_source(e);
        } finally {
            _ir_sched_loading.reset(_tok);
        }
    }
    return validate_schedule(
        [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass, PlacementApplyPass],
        origin='symtab-ir schedule'
    );
}

glob _ir_sched_loading = ContextVar('jac_ir_sched_loading', `default=False),
     _codegen_sched_loading = ContextVar('jac_codegen_sched_loading', `default=False),
     _analysis_sched_loading = ContextVar('jac_analysis_sched_loading', `default=False);

def pass_requires(p: type[Transform]) -> tuple {
    return getattr(p, 'REQUIRES', ()) or ();
}

def pass_provides(p: type[Transform]) -> tuple {
    return getattr(p, 'PROVIDES', ()) or ();
}

def validate_schedule(
    passes: list[type[Transform]],
    preprovided: (set[str] | None) = None,
    origin: str = 'schedule'
) -> list[type[Transform]] {
    provided: set[str] = set(preprovided) if preprovided is not None else set();
    for p in passes {
        for tag in pass_requires(p) {
            if tag not in provided {
                raise RuntimeError(
                    f"scheduling error: pass {p.__name__} requires analysis "
                    f"'{tag}' which is neither provided by an earlier pass in "
                    f"the {origin} nor already available -- the schedule was "
                    f"constructed missing a declared dependency."
                );
            }
        }
        for tag in pass_provides(p) {
            provided.add(tag);
        }
    }
    return passes;
}

class TypeshedUnavailableError(RuntimeError) {}

glob _native_sched_failure: dict[str, str] = {};

def _note_native_schedule_failure(err: (BaseException | None)) {
    if err is None {
        _native_sched_failure.pop('reason', None);
    } else {
        _native_sched_failure['reason'] = f"{type(err).__name__}: {err}";
    }
}

def native_schedule_failure -> str {
    return _native_sched_failure.get('reason', '');
}

def get_boundary_analysis_sched -> list[type[Transform]] {
    return validate_schedule(
        [BoundaryAnalysisPass, EndpointEffectPass], origin='boundary-analysis schedule'
    );
}

def get_bootstrap_ir_sched -> list[type[Transform]] {
    return validate_schedule(
        [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass, SemanticAnalysisPass],
        origin='bootstrap-ir schedule'
    );
}

def get_ir_gen_sched(
    is_internal: bool = False, gen_mtir: bool = True
) -> list[type[Transform]] {
    if _ir_sched_loading.get() {
        return get_bootstrap_ir_sched();
    }
    _tok = _ir_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
        import from jaclang.compiler.passes.sem_def_match_pass { SemDefMatchPass }
        import from jaclang.compiler.passes.jsx_intrinsic_guard_pass {
            JsxIntrinsicGuardPass
        }

        import jaclang.compiler.symbol_utils;
        import jaclang.compiler.expr_keys;
        import jaclang.compiler.passes.layout_pass;
        import jaclang.compiler.type_registry;
        import jaclang.compiler.intrinsic_registry;
        import jaclang.project.client_kind;

        passes: list[type[Transform]] = [
            ASTValidationPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass
        ];
        if gen_mtir {
            import from jaclang.compiler.passes.mtir_gen_pass { MTIRGenPass }
            passes.append(MTIRGenPass);
        }
        passes.append(JsxIntrinsicGuardPass);
        passes.append(PlacementApplyPass);
        return validate_schedule(passes, origin='ir-gen schedule');
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        if is_internal {
            return get_bootstrap_ir_sched();
        }
        raise;
    } finally {
        _ir_sched_loading.reset(_tok);
    }
}

def typeshed_stubs_available -> bool {
    import jaclang;
    return os.path.exists(
        os.path.join(
            os.path.dirname(str(jaclang.__file__)),
            'vendor',
            'typeshed',
            'stdlib',
            'builtins.pyi'
        )
    );
}

def require_typeshed_stubs -> None {
    if typeshed_stubs_available() {
        return;
    }
    raise TypeshedUnavailableError(
        "type inference is on the critical path of every compilation, but the "
        "vendored typeshed stdlib stubs are missing from this environment, so "
        "no module can be compiled. In a source checkout run "
        "'zig build fetch-typeshed'; in an installed environment reinstall the "
        "jac distribution, whose payload is required to carry the stubs."
    );
}

def get_analysis_sched -> list[type[Transform]] {
    if _analysis_sched_loading.get() {
        return [];
    }
    require_typeshed_stubs();
    _tok = _analysis_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }

        import from jaclang.compiler.types.type_evaluator { TypeEvaluator }

        import jaclang.compiler.passes.pyast_load_pass;
        import jaclang.compiler.passes.rc_facts_pass;
        import jaclang.compiler.types.type_utils;
        import jaclang.compiler.types.ts_decl_parser;
        import jaclang.compiler.symbol_utils;
        import jaclang.compiler.expr_keys;
        import jaclang.compiler.type_registry;
        import jaclang.compiler.driver.bccache;
        import jaclang.compiler.frontend.codeinfo;
        import jaclang.compiler.frontend.diagnostic_utils;
        import jaclang.compiler.driver.modresolver;
        import jaclang.project.tomlio;
        import jaclang.project.client_kind;
        import jaclang.project.config;
        import from jaclang.compiler.passes.static_analysis_pass { StaticAnalysisPass }
        import from jaclang.compiler.passes.access_check_pass { AccessCheckPass }
        import from jaclang.compiler.passes.capability_check_pass {
            ClientCapabilityCheckPass,
            NativeCapabilityCheckPass,
            PortabilityWarnPass
        }
        import from jaclang.compiler.passes.ownership_check_pass { OwnershipCheckPass }
        import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
        return validate_schedule(
            [
                TypeCheckPass,
                StaticAnalysisPass,
                AccessCheckPass,
                OwnershipCheckPass,
                NativeCapabilityCheckPass,
                ClientCapabilityCheckPass,
                PortabilityWarnPass,
                JacLintCheckPass
            ],
            preprovided={'cfg'},
            origin='analysis schedule'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        raise;
    } finally {
        _analysis_sched_loading.reset(_tok);
    }
}

glob _native_env_memo: dict[str, tuple[bool, str]] = {};

def native_pipeline_available -> tuple[bool, str] {
    cached = _native_env_memo.get('verdict');
    if cached is not None {
        return cached;
    }
    if (
        _analysis_sched_loading.get()
        or _ir_sched_loading.get()
        or _codegen_sched_loading.get()
    ) {
        return (True, '');
    }
    reason = '';
    try {
        import from jaclang.compiler.backends.native.llvm.binding.ffi { _find_shim }
        _find_shim();
    } except ModuleNotFoundError {
        reason = (
            'native pipeline unavailable: LLVM shim (libjacllvm) '
            + 'not found in this environment'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        return (False, 'native pipeline undecided: the compiler is still initializing');
    } except Exception {
        reason = (
            'native pipeline unavailable: LLVM shim (libjacllvm) '
            + 'not found in this environment'
        );
    }
    verdict = (not reason, reason);
    _native_env_memo['verdict'] = verdict;
    return verdict;
}

def _py_codegen_tail -> list[type[Transform]] {
    return [JcirGenPass, JcirBytecodeGenPass];
}

def get_py_code_gen(
    native: bool = True, provided: (set[str] | None) = None, graphmend: bool = True
) -> list[type[Transform]] {
    if _codegen_sched_loading.get() or _ir_sched_loading.get() {
        return _py_codegen_tail();
    }
    _tok = _codegen_sched_loading.set(True);
    try {
        import from jaclang.compiler.backends.es { EsastGenPass }

        passes: list[type[Transform]] = [EsastGenPass];
        if native {
            import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
            import from jaclang.compiler.backends.native {
                NaIRGenPass,
                NativeCompilePass
            }
            passes.extend([RcFactsPass, NaIRGenPass, NativeCompilePass]);
            _note_native_schedule_failure(None);
        }
        if graphmend {
            import from jaclang.compiler.passes.graphmend.graph_break_detect_pass {
                GraphBreakDetectPass
            }
            import from jaclang.compiler.passes.graphmend.trap_lowering_pass {
                TrapLoweringPass
            }
            import from jaclang.compiler.passes.graphmend.predicate_ctrl_flow_pass {
                PredicateCtrlFlowPass
            }
            import from jaclang.compiler.passes.graphmend.defer_side_effect_pass {
                DeferSideEffectPass
            }
            passes.extend(
                [
                    GraphBreakDetectPass,
                    TrapLoweringPass,
                    PredicateCtrlFlowPass,
                    DeferSideEffectPass
                ]
            );
        }
        passes.extend(_py_codegen_tail());
        return validate_schedule(
            passes, preprovided=provided, origin='codegen schedule'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        if native {
            _note_native_schedule_failure(e);
        }
        return _py_codegen_tail();
    } finally {
        _codegen_sched_loading.reset(_tok);
    }
}

def get_compile_sched(
    gen_mtir: bool = True, native: bool = True
) -> list[type[Transform]] {
    analyzed = get_ir_gen_sched(gen_mtir=gen_mtir)
        + get_analysis_sched()
        + get_boundary_analysis_sched();
    return validate_schedule(
        analyzed + get_py_code_gen(native=native, provided=providers_of(analyzed)),
        origin='compile schedule'
    );
}

def providers_of(passes: list[type[Transform]]) -> set[str] {
    out: set[str] = set();
    for p in passes {
        for tag in pass_provides(p) {
            out.add(tag);
        }
    }
    return out;
}

def get_format_sched(auto_lint: bool = False) -> list[type[Transform]] {
    import from jaclang.compiler.tools.comment_attach_pass { CommentAttachPass }
    import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacAutoLintPass }
    import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
    if auto_lint {
        return validate_schedule(
            [CommentAttachPass, JacAutoLintPass, DocIRGenPass, JacFormatPass],
            origin='format schedule'
        );
    }
    return validate_schedule(
        [CommentAttachPass, DocIRGenPass, JacFormatPass], origin='format schedule'
    );
}

def get_lint_sched -> list[type[Transform]] {
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
    return validate_schedule([JacLintCheckPass], origin='lint schedule');
}

def _jsx_intrinsic_guard_pass_type -> (type | None) {
    try {
        import from jaclang.compiler.passes.jsx_intrinsic_guard_pass {
            JsxIntrinsicGuardPass
        }
        return JsxIntrinsicGuardPass;
    } except ImportError {
        return None;
    }
}
