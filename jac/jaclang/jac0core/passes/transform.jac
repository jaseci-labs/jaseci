import time;
import from abc { ABC }
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.diagnostics {
    DiagnosticInfo,
    E9001,
    LINT_ALIASES,
    Severity
}
import from jaclang.jac0core.diagnostic_utils { resolve_diagnostic_tokens }
import from jaclang.jac0core.unitree { UniNode }
import type from jaclang.jac0core.program { JacProgram }

glob _NATIVE_PASS_TIER_MEMO: dict[type, str] = {},
     _NATIVE_SERVED_PASSES: set[str] = set();

def _require_native_pass_tier(pass_type: type) -> None;

obj Alert {
    has msg: str,
        loc: CodeLocInfo,
        from_pass: type[Transform],
        code: DiagnosticInfo | None = None,
        related: list[tuple[str, CodeLocInfo]] = [],
        help_text: str | None = None;

    def postinit -> None;
    def __str__ -> str;
    def __repr__ -> str;
    def as_log(*, colors: bool = False) -> str;
    def pretty_print(*, colors: bool = False) -> str;
}

obj DiagnosticPolicy {
    has suppress_codes: list[str] = [],
        suppress_categories: list[str] = [],
        lint_active: bool = False,
        lint_select: list[str] = [],
        lint_ignore: list[str] = [],
        _inline_cache: dict[(tuple[str, int], list[str])] = {};

    def is_suppressed(diag: DiagnosticInfo, loc: (CodeLocInfo | None) = None) -> bool;
    def _inline_suppressed(diag: DiagnosticInfo, loc: CodeLocInfo) -> bool;
}

obj BaseTransform[T_in, T_out](ABC) {
    has ir_in: T_in,
        prog: JacProgram,
        cancel_token: any = None,
        errors_had: list[Alert] = [],
        warnings_had: list[Alert] = [],
        time_taken: float = 0.0,
        ir_out: T_out postinit;

    def postinit -> None;
    def timed_transform(ir_in: T_in) -> T_out {
        start_time = time.time();
        ir_out = self.transform(ir_in=ir_in);
        self.time_taken = time.time() - start_time;
        return ir_out;
    }

    def pre_transform -> None;
    def post_transform -> None;
    def transform(ir_in: T_in) -> T_out {
        ;
    }

    def log_info(msg: str) -> None;
    def is_canceled -> bool;
}

obj Transform[T: UniNode, R: UniNode](BaseTransform[T, R]) {
    has cur_node: UniNode postinit,
        policy: (DiagnosticPolicy | None) = None;

    static has PROVIDES: tuple = (),
        REQUIRES: tuple = ();

    def postinit -> None;
    def emit(
        diag: DiagnosticInfo,
        node_override: (UniNode | None) = None,
        related: (list[tuple[str, UniNode]] | None) = None,
        help_text: (str | None) = None,
        **kwargs: any
    ) -> bool;

    def _is_suppressed(diag: DiagnosticInfo, loc: CodeLocInfo | None = None) -> bool;
    def ice(msg: str = 'Something went horribly wrong!') -> RuntimeError;
}
