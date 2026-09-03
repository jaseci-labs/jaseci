import from jaclang.compiler.driver.mtp { FunctionInfo, MethodInfo, type_to_str }

glob _CONTRACT_CACHE: dict[object, tuple] = {},
     _TOKEN_CACHE: dict[object, int] = {},
     _CACHE_MAX: int = 512;

def hoisting_enabled -> bool;

def invariant_plan_of(fn_info: object) -> dict[str, bool] | None;

def render_contract_block(
    fn_info: object,
    description: str,
    resp_type: type | None,
    include_schema_hint: bool,
    excluded_params: tuple[str] = (),
    tool_names: tuple[str] = (),
    extra_invariant_text: str | None = None
) -> str;

def invariant_token_count(text: str, model_name: str = "") -> int;

def reset_invariant_cache -> None;
