import from jaclang.byllm.config_loader { get_byllm_config }
import from jaclang.byllm.schema { schema_to_hint_text, type_to_schema }

impl hoisting_enabled -> bool {
    try {
        return bool(
            get_byllm_config().get_optimizations_config().get(
                "invariant_prompt_hoisting", False
            )
        );
    } except Exception {
        return False;
    }
}

impl invariant_plan_of(fn_info: object) -> dict[str, bool] | None {
    if not (isinstance(fn_info, FunctionInfo) and hasattr(fn_info, "invariant_plan")) {
        return None;
    }
    plan = fn_info.invariant_plan;
    return plan if isinstance(plan, dict) else None;
}

def _bounded_put(store: dict[object, object], key: object, value: object) {
    if len(store) >= _CACHE_MAX {
        del store[next(iter(store))];
    }
    store[key] = value;
}

def _param_lines(fn_info: FunctionInfo, excluded_params: tuple[str]) -> list[str] {
    lines: list[str] = [];
    for param in (fn_info.params or []) {
        if param.name in excluded_params {
            continue;
        }
        type_name = type_to_str(param.type_info) if param.type_info is not None else "";
        label = f"{param.name} ({type_name})" if type_name else param.name;
        lines.append(f"{label}: {param.semstr}" if param.semstr else label);
    }
    return lines;
}

def _schema_hint_for(fn_info: FunctionInfo, resp_type: type | None) -> str {
    if resp_type is None or resp_type is str {
        return "";
    }
    try {
        return schema_to_hint_text(
            type_to_schema(resp_type=resp_type, info=fn_info.return_type)
        );
    } except Exception {
        return "";
    }
}

impl render_contract_block(
    fn_info: object,
    description: str,
    resp_type: type | None,
    include_schema_hint: bool,
    excluded_params: tuple[str] = (),
    tool_names: tuple[str] = (),
    extra_invariant_text: str | None = None
) -> str {
    plan = invariant_plan_of(fn_info);
    if plan is None or not isinstance(fn_info, FunctionInfo) {
        return "";
    }
    info = fn_info;
    key = (
        id(info),
        tuple(sorted(plan.items())),
        description,
        resp_type,
        include_schema_hint,
        excluded_params,
        tool_names,
        extra_invariant_text
    );
    hit = _CONTRACT_CACHE.get(key);
    if hit is not None {
        return hit[1];
    }

    sections: list[str] = [];
    if plan.get("description", True) and description {
        sections.append(f"Task: {description}");
    }
    if plan.get("params", False) {
        lines = _param_lines(info, excluded_params);
        if lines {
            sections.append("Inputs:\n" + "\n".join(lines));
        }
    }
    if plan.get("self", False) and isinstance(info, MethodInfo) {
        parent = info.parent_class;
        if parent is not None and parent.semstr {
            sections.append(f"Self: {parent.semstr}");
        }
    }
    if plan.get("return_type", False) and info.return_type is not None {
        sections.append(f"Returns: {type_to_str(info.return_type)}");
    }
    if plan.get("schema", False) and include_schema_hint {
        hint = _schema_hint_for(info, resp_type);
        if hint {
            sections.append(hint);
        }
    }
    if plan.get("tools", False) and tool_names {
        sections.append("Tools: " + ", ".join(tool_names));
    }
    if extra_invariant_text {
        sections.append(extra_invariant_text);
    }

    block = "\n\n".join(sections);
    _bounded_put(_CONTRACT_CACHE, key, (info, block));
    return block;
}

impl invariant_token_count(text: str, model_name: str = "") -> int {
    if not text {
        return 0;
    }
    key = (model_name, text);
    hit = _TOKEN_CACHE.get(key);
    if hit is not None {
        return hit;
    }
    count = max(1, len(text) // 4);
    try {
        import from jaclang.byllm._optdeps.litellm { HAS_LITELLM, litellm }
        if HAS_LITELLM {
            count = int(litellm.token_counter(model=model_name or "gpt-4o", text=text));
        }
    } except Exception {}
    _bounded_put(_TOKEN_CACHE, key, count);
    return count;
}

impl reset_invariant_cache -> None {
    _CONTRACT_CACHE.clear();
    _TOKEN_CACHE.clear();
}
