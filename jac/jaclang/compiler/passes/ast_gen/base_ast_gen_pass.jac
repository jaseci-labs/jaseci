import from typing { TypeVar }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
glob ChildPassT = TypeVar('ChildPassT', bound='BaseAstGenPass[Any]');

obj BaseAstGenPass[AstNodeT](UniPass) {
    def _merge_module_bodies(nd: uni.Module) -> list;
    def _init_child_passes(pass_class: type[ChildPassT]) -> list[ChildPassT];
    def _flatten_ast_list(
        items: list[AstNodeT | list[AstNodeT] | None]
    ) -> list[AstNodeT];
}
