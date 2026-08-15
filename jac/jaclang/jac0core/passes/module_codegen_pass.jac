import from collections.abc { Sequence }
import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    Assignment,
    AtomTrailer,
    ConcurrentExpr,
    ContextAwareNode,
    ElementStmt,
    Enum,
    FuncCall,
    ImplDef,
    Import,
    Module,
    Name,
    UniNode
}
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.codeinfo {
    NATIVE_COMPTIME_TYPE_MARKERS,
    TYPE_PARAM_CONSTRUCTORS
}
import from jaclang.jac0core.passes.transform { Transform }

obj ModuleCodegenPass(Transform[Module, Module]) {
    static def unwrap_body(nd: Archetype | Enum | Ability) -> (Sequence | None) {
        body = nd.body;
        if (isinstance(body, ImplDef) and isinstance(body.body, `list)) {
            return body.body;
        }
        if isinstance(body, `list) {
            return body;
        }
        return None;
    }

    static def iter_woven_segments(module: Module) -> list[tuple[Sequence, bool]] {
        own_path = module.loc.mod_path;
        annex_stmts = [
            stmt
            for stmt in module.body
            if stmt.loc.mod_path and stmt.loc.mod_path != own_path
        ];
        head_stmts = [
            stmt
            for stmt in module.body
            if not (stmt.loc.mod_path and stmt.loc.mod_path != own_path)
        ];
        return [(annex_stmts, True), (head_stmts, True)];
    }

    static def iter_context_stmts(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[ElementStmt] {
        result: list[ElementStmt] = [];
        for (body, _strip) in ModuleCodegenPass.iter_woven_segments(module) {
            for stmt in body {
                if ctx is None {
                    result.append(stmt);
                } elif (
                    isinstance(stmt, ContextAwareNode) and stmt.code_context == ctx
                ) {
                    result.append(stmt);
                } elif (
                    not isinstance(stmt, ContextAwareNode) and ctx == CodeContext.SERVER
                ) {
                    result.append(stmt);
                }
            }
        }
        return result;
    }

    static def iter_module_imports(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[Import] {
        return [
            stmt
            for stmt in ModuleCodegenPass.iter_context_stmts(module, ctx)
            if isinstance(stmt, Import)
        ];
    }

    static def iter_nested_imports(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[Import] {
        result: list[Import] = [];
        seen: set[int] = set();
        for stmt in ModuleCodegenPass.iter_context_stmts(module, ctx) {
            if isinstance(stmt, Import) {
                continue;
            }
            for imp in stmt.get_all_sub_nodes(typ=Import) {
                if id(imp) not in seen {
                    seen.add(id(imp));
                    result.append(imp);
                }
            }
        }
        return result;
    }

    static def has_native_context_stmts(module: Module) -> bool {
        return bool(ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE));
    }

    static def is_type_alias_decl(assign: Assignment) -> bool {
        if assign.type_tag is None or assign.value is None {
            return False;
        }
        tag = assign.type_tag.tag;
        if isinstance(tag, AtomTrailer) {
            tag = tag.right;
        }
        return isinstance(tag, Name) and tag.value in NATIVE_COMPTIME_TYPE_MARKERS;
    }

    static def is_type_param_decl(assign: Assignment) -> bool {
        if assign.value is None or not isinstance(assign.value, FuncCall) {
            return False;
        }
        callee = assign.value.target;
        if isinstance(callee, AtomTrailer) {
            callee = callee.right;
        }
        return isinstance(callee, Name) and callee.value in TYPE_PARAM_CONSTRUCTORS;
    }

    static def is_comptime_type_decl(assign: Assignment) -> bool {
        return ModuleCodegenPass.is_type_alias_decl(assign)
            or ModuleCodegenPass.is_type_param_decl(assign);
    }

    static def archetype_refs(nd: UniNode) -> list[str] {
        names: list[str] = [];
        for nm in nd.get_all_sub_nodes(Name) {
            sym = nm.sym;
            if (sym is not None) and sym.defn {
                cand = sym.defn[0].name_of;
                if (isinstance(cand, (Archetype, Enum)) and (cand.name is not None)) {
                    names.append(cand.name.value);
                }
            }
        }
        return names;
    }

    static def shared_archetypes_for_context(
        module: Module, ctx: CodeContext, include_enums: bool = False
    ) -> list[Archetype] {
        shared: dict[(str, Archetype)] = {};
        for arch in module.get_all_sub_nodes(Archetype) {
            if (arch.name is not None) and isinstance(arch.parent, Module) {
                shared[arch.name.value] = arch;
            }
        }
        if include_enums {
            for en in module.get_all_sub_nodes(Enum) {
                if (en.name is not None) and isinstance(en.parent, Module) {
                    shared[en.name.value] = en;
                }
            }
        }
        if not shared {
            return [];
        }
        worklist: list[str] = [];
        for stmt in ModuleCodegenPass.iter_context_stmts(module, ctx) {
            worklist.extend(ModuleCodegenPass.archetype_refs(stmt));
        }
        result: dict[(str, Archetype)] = {};
        visited: set[str] = set();
        while worklist {
            name = worklist.pop();
            if name in visited {
                continue;
            }
            visited.add(name);
            arch = shared.get(name);
            if arch is None {
                continue;
            }
            result[name] = arch;
            worklist.extend(ModuleCodegenPass.archetype_refs(arch));
        }
        return list(result.values());
    }
}

def client_capability_violations(mod: Module) -> list {
    out: list = [];

    reject: list = [(ConcurrentExpr, "flow/wait concurrency")];
    for _stmt in ModuleCodegenPass.iter_context_stmts(mod, CodeContext.CLIENT) {
        if getattr(_stmt, 'codespace_dual', False) {
            continue;
        }
        for (node_t, kind_name) in reject {
            for _nd in _stmt.get_all_sub_nodes(typ=node_t) {
                out.append((_nd, kind_name));
            }
        }
    }
    return out;
}
