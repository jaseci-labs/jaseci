import from jaclang.compiler.passes.main.layout_pass {
    ACCESSOR_SLOT_SUFFIX,
    ArchetypeLayout
}
import from jaclang.compiler.type_system.types { FunctionType }
import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.diagnostics { E5060, E5090, E5092 }
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
import jaclang.jac0core.unitree as uni;
import os;
import sys;
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }

obj NaIRGenCore(NaIRGenState) {
    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _register_imported_struct_types -> None;
    def _extract_import_module_name(imp: uni.Import) -> (str | None);
    def _native_dep_reals(own_real: str, entry_base: str) -> set[str];
    def _load_native_dep(full: str, real: str, own_real: str) -> (uni.Module | None);
    def _permuted_walk_order(mods: list) -> list;
    def _register_dep_module_struct_names(imported_mod: uni.Module) -> list;
    def _register_dep_module_layouts(imported_mod: uni.Module, _ordered: list) -> None;
    def _walk_imported_module_abilities(
        imported_mod: uni.Module, with_fn_verdicts: bool = True
    ) -> None;

    def _forward_declare_archetype_methods(lay: ArchetypeLayout) -> None;
    def _register_imported_globals(nd: uni.GlobalVars, source_path: str = "") -> None;
    def _forward_declare_imported_ability(
        nd: uni.Ability, unavailable: (set | None) = None, imp_layout: any = None
    ) -> None;

    def _imported_function_demotions(imported_mod: uni.Module) -> (set | None);
    def _predemote_capability_unit(
        full_name: str, func: ir.Function, viols: list, keep_func: bool = False
    ) -> bool;

    def _rename_demoted_symbol(name: str, func: ir.Function) -> None;
    def _process_clib_imports(module: uni.Module) -> None;
    def _resolve_clib_lib_name(components: list[str], level: int) -> str;
    def _llvm_type_str(ty: ir.Type) -> str;
    def _export_native_layout -> None;
    def _exported_accessors(arch_name: str) -> dict[(str, dict[(str, str)])];
    def _ret_tuple_hints(ret_tb: any, ret_tuple: any) -> (list | None);
    def _tb_non_none_one(t: any) -> any;
    def _elem_keys_of_type(t: any) -> (list | None);
    def _ensure_emitters -> None;
    def _primitive_method_names(type_name: str) -> set[str];
    def _dispatch_primitive_method(
        type_name: str,
        method_name: str,
        target: ir.Value,
        args: list[ir.Value],
        type_key: str,
        kwargs: (dict | None) = None,
        kw_node: (uni.UniNode | None) = None
    ) -> (ir.Value | None);

    def _dispatch_builtin(
        func_name: str,
        args: list[ir.Value],
        kwargs: (dict | None) = None,
        kw_node: (uni.UniNode | None) = None,
        type_key: str = "",
        arg_nodes: (list | None) = None
    ) -> (ir.Value | None);

    def _split_call_kwargs(nd: uni.FuncCall) -> dict;
}
