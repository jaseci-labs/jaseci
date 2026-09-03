impl usage_log_path -> str {
    import os;

    return os.environ.get(USAGE_LOG_ENV, "").strip();
}

def _consumer_label(us: object) -> str | None {
    if us is None {
        return None;
    }
    name = str(getattr(us, "consumer_name", "") or "");
    parent = str(getattr(us, "consumer_parent_class", "") or "");
    label = f"{parent}.{name}" if (parent and name) else name;
    return label or None;
}

def _cost_of(usage: object) -> float | None {
    raw = usage.get("cost") if isinstance(usage, dict) else usage?.cost;
    if raw is None {
        return None;
    }
    try {
        return float(raw);
    } except Exception {
        return None;
    }
}

impl emit_usage_record(
    mt_run: object, usage: object, model_name: str, latency_ms: (float | None) = None
) -> None {
    path = usage_log_path();
    if not path {
        return;
    }
    try {
        import importlib;
        import from datetime { datetime, timezone }

        _llm_mod = importlib.import_module("jaclang.byllm.llm");
        import from jaclang.byllm.use_site {
            resolve_use_site_mode,
            use_site_word_count
        }
        import from jaclang.compiler.driver.mtp { scope_of }

        scope: (str | None) = None;
        caller_name: (str | None) = None;
        us: object = None;
        mtir = mt_run?.mtir;
        if mtir is not None {
            caller: any = mtir?.caller;
            if caller is not None {
                caller_name = caller?.__name__;
                try {
                    scope = scope_of(caller);
                } except Exception {
                    scope = None;
                }
            }
            us = mtir?.ir_info?.use_site;
        }
        block = str(getattr(mt_run, "_use_site_block", "") or "");
        fields = list(us?.fields_read or []) if us is not None else [];
        reason = str(getattr(us, "reason", "") or "") if us is not None else "";
        record: dict = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "invocation_id": mt_run?._invocation_id,
            "parent_invocation_id": mt_run?._parent_invocation_id,
            "scope": scope,
            "caller_name": caller_name,
            "model": model_name,
            "latency_ms": latency_ms,
            "use_site_mode": resolve_use_site_mode(),
            "use_site_resolved": bool(getattr(us, "resolved", False)),
            "use_site_reason": reason or None,
            "use_site_tokens": use_site_word_count(block),
            "consumer_name": _consumer_label(us),
            "consumer_param": us?.param_name or None,
            "fields_read": [str(f) for f in fields],
            "prompt_tokens": _llm_mod._usage_int(usage, "prompt_tokens"),
            "completion_tokens": _llm_mod._usage_int(usage, "completion_tokens"),
            "total_tokens": _llm_mod._usage_int(usage, "total_tokens"),
            "cache_read_input_tokens": _llm_mod._usage_int(
                usage, "cache_read_input_tokens"
            ),
            "cache_creation_input_tokens": _llm_mod._usage_int(
                usage, "cache_creation_input_tokens"
            ),
            "cost": _cost_of(usage)
        };
        line = json.dumps(record, `default=str) + "\n";
        if len(line.encode("utf-8")) > USAGE_LOG_MAX_LINE {
            record["fields_read"] = record["fields_read"][:8];
            record["use_site_reason"] = (record["use_site_reason"] or "")[:120] or None;
            line = json.dumps(record, `default=str) + "\n";
        }
        with _log_lock {
            with open(path, "a", encoding="utf-8") as fh {
                fh.write(line);
            }
        }
    } except Exception as e {
        logger.debug(f"byllm usage log write failed: {e}");
    }
}
