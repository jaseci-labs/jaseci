import os;
import from difflib { get_close_matches }
import from jaclang.scale.config.plugin_config { JacScalePluginConfig }

impl known_scale_options -> dict[str, any] {
    schema = JacScalePluginConfig.get_config_schema();
    options = schema.get("options", {});
    return options if isinstance(options, dict) else {};
}

impl validate_scale_config(raw: dict[str, any] | None) -> list[str] {
    findings: list[str] = [];
    if not isinstance(raw, dict) or not raw {
        return findings;
    }
    options = dict(known_scale_options());
    deploy_cfg = raw.get("deploy");
    if isinstance(deploy_cfg, dict) {
        target = deploy_cfg.get("target");
        if isinstance(target, str) and target and target not in options {
            options[target] = {
                "type": "dict",
                "description": "Config section owned by the registered deploy target plugin"
            };
        }
    }
    _walk(raw, options, "scale", findings);
    return findings;
}

impl _walk(
    section: dict[str, any], options: dict[str, any], path: str, findings: list[str]
) -> None {
    for (key, value) in section.items() {
        key_s = str(key);
        if key_s not in options {
            findings.append(
                _unknown_key_message(path, key_s, [str(k) for k in options.keys()])
            );
            continue;
        }
        spec = options.get(key_s);
        if not isinstance(spec, dict) or not isinstance(value, dict) {
            continue;
        }
        nested = spec.get("nested");
        if isinstance(nested, dict) {
            _walk(value, nested, f"{path}.{key_s}", findings);
            continue;
        }
        nested_each = spec.get("nested_each");
        if isinstance(nested_each, dict) {
            for (child_key, child_val) in value.items() {
                if isinstance(child_val, dict) {
                    _walk(
                        child_val, nested_each, f"{path}.{key_s}.{child_key}", findings
                    );
                }
            }
        }
    }
}

impl _unknown_key_message(path: str, key: str, known: list[str]) -> str {
    matches = get_close_matches(key, known, n=1, cutoff=0.6);
    hint = f"; did you mean '{matches[0]}'?" if matches else ".";
    return (
        f"jac.toml [{path}] has unknown key '{key}'{hint} "
        "Unknown keys are ignored, so defaults apply instead."
    );
}

impl _strict_mode -> bool {
    return os.environ.get(STRICT_ENV, "").strip().lower() in ("1", "true", "yes", "on");
}

impl warn_unknown_scale_keys(raw: dict[str, any] | None) -> None {
    findings = validate_scale_config(raw);
    if not findings {
        return;
    }
    if _strict_mode() {
        raise ValueError(
            f"Unknown [scale] keys in jac.toml ({STRICT_ENV} is set):\n"
                + "\n".join(findings)
        );
    }
    import logging;
    log = logging.getLogger(__name__);
    for msg in findings {
        log.warning(msg);
    }
}
