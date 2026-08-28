import from jaclang.compiler.frontend.unitree { Module, TreeWalker, UniNode }
import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
import from jaclang.runtime.osp_kernel { osp_skip_rest }

walker UniPass(ModuleCodegenPass, TreeWalker) {
    can enter_walk with UniNode entry;
    can exit_walk with UniNode exit;
    def postinit -> None;
    def before_pass -> None;
    def after_pass -> None;
    def recalculate_parents(nd: UniNode) -> None;
    def transform(ir_in: Module) -> Module;
    def traverse(nd: UniNode) -> UniNode;
}
