import json;
import time;
import from jaclang.byllm.invariant { invariant_token_count }

def _num(usage: object, key: str) -> float {
    if usage is None {
        return 0.0;
    }
    val = usage.get(key) if isinstance(usage, dict) else getattr(usage, key, None);
    if val is None and key == "cache_read_input_tokens" {
        details = (
            usage.get("prompt_tokens_details")
                if isinstance(usage, dict)
                else usage?.prompt_tokens_details
        );
        if details is not None {
            val = (
                details.get("cached_tokens")
                    if isinstance(details, dict)
                    else details?.cached_tokens
            );
        }
    }
    try {
        return float(val or 0);
    } except Exception {
        return 0.0;
    }
}

def _scope_of(mt_run: object) -> str {
    try {
        caller = mt_run?.mtir?.caller;
        if caller is None {
            return "";
        }
        module = getattr(caller, "__module__", "") or "";
        name = getattr(caller, "__qualname__", "") or getattr(caller, "__name__", "");
        return f"{module}.{name}" if module else str(name);
    } except Exception {
        return "";
    }
}

impl usage_log_path -> str {
    return os.environ.get(_USAGE_LOG_ENV, "").strip();
}

impl build_usage_record(
    mt_run: object, model_name: str, usage: object, latency_ms: float
) -> dict[str, object] {
    invariant_text = str(mt_run?._invariant_text or "");
    return {
        "ts": time.time(),
        "scope": _scope_of(mt_run),
        "model": model_name,
        "hoisted": bool(mt_run?._hoisted),
        "prompt_tokens": int(_num(usage, "prompt_tokens")),
        "completion_tokens": int(_num(usage, "completion_tokens")),
        "cache_read_input_tokens": int(_num(usage, "cache_read_input_tokens")),
        "cache_creation_input_tokens": int(_num(usage, "cache_creation_input_tokens")),
        "invariant_tokens": invariant_token_count(invariant_text, model_name),
        "cost": _num(usage, "cost"),
        "latency_ms": round(latency_ms, 3)
    };
}

impl log_completion(
    mt_run: object, model_name: str, usage: object, latency_ms: float
) -> None {
    path = usage_log_path();
    if not path {
        return;
    }
    try {
        record = build_usage_record(mt_run, model_name, usage, latency_ms);
        with open(path, "a", encoding="utf-8") as handle {
            handle.write(json.dumps(record) + "\n");
        }
    } except Exception {}
}
