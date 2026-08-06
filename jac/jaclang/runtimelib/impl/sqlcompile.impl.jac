glob _PENDING = 'pg-persistence: pending implementation (epic #7945)';


impl compile_query(
    q: GraphQuery, promotions: dict[str, list[str]], edges: bool = False
) -> CompiledPlan {
    raise NotImplementedError(_PENDING);
}


impl pushable(pred: QPred) -> bool {
    raise NotImplementedError(_PENDING);
}


impl pred_sql(
    alias: str, pred: QPred, params: list, promotions: dict[str, list[str]]
) -> str {
    raise NotImplementedError(_PENDING);
}
