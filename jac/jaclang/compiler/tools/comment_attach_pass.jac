import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.codeinfo { NodeComments }
import from jaclang.compiler.passes { Transform }

obj CommentAttachPass(Transform) {
    def transform(ir_in: uni.Module) -> uni.Module;
    def _node_comments(nd: uni.UniNode) -> NodeComments;
    def _attach_trailing_own(tok: uni.Token, comment: uni.CommentToken) -> None;
    def _largest_ending_at(tok: uni.Token) -> uni.UniNode;
    def _largest_starting_at(tok: uni.Token) -> uni.UniNode;
}
