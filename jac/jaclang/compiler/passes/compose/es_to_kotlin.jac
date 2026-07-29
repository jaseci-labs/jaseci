"""estree Expression / Statement → kotlin_ast (Compose emit path)."""
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.compose { kotlin_ast as kt }

obj EsToKotlin {
    def convert_expr(nd: (es.Expression | None)) -> (kt.KtNode | None);
    def convert_stmt(nd: (es.Statement | None)) -> (kt.KtNode | None);
    def convert_stmts(stmts: list[es.Statement]) -> list[kt.KtNode];
    def _property_key_expr(
        key: (es.Expression | es.Identifier | es.Literal | None)
    ) -> (kt.KtNode | None);
    def _convert_call_args(
        arguments: list[(es.Expression | es.SpreadElement)]
    ) -> list[kt.KtNode];
    def _convert_function_params(params: list[es.Pattern]) -> list[kt.KtParam];
    def _convert_lambda_params(params: list[es.Pattern]) -> list[str];
    def _convert_function_body(
        body: (es.BlockStatement | es.Expression | None),
        expression: bool = False
    ) -> tuple[list[kt.KtNode], (kt.KtNode | None)];
    def _stmt_to_nodes(nd: (es.Statement | None)) -> list[kt.KtNode];
    def _convert_jac_spawn(nd: es.CallExpression) -> (kt.KtNode | None);
    def _object_to_named_args(nd: (es.Expression | None)) -> list[kt.KtNamedArg];
    def _member_path(nd: (es.Expression | None)) -> list[str];
    def _convert_jac_runtime_call(
        nd: es.CallExpression
    ) -> (kt.KtNode | None);
}

def es_expr_to_kt(nd: (es.Expression | None)) -> (kt.KtNode | None);
def es_stmt_to_kt(nd: (es.Statement | None)) -> (kt.KtNode | None);
