glob GENERIC_SENTENCES: tuple = (
         "The result feeds a later step in the program.",
         "Produce a complete and precise result.",
         "Keep the output self-contained and unambiguous.",
         "Follow the declared return type exactly.",
         "Do not omit information a later step may need.",
         "Prefer specific concrete values over vague summaries."
     ),
     GENERIC_FILLER: tuple = (
         "thorough",
         "exact",
         "careful",
         "deliberate",
         "complete",
         "faithful"
     );

def _paren(text: str) -> str {
    out = text.strip();
    if out.endswith(".") {
        out = out[:-1];
    }
    if out and out[0].isupper() and (len(out) < 2 or out[1].islower()) {
        out = out[0].lower() + out[1:];
    }
    return out;
}

def _block(
    us: object,
    param_desc: str | None,
    consumer_desc: str | None,
    fields: list[str] | None
) -> str {
    param_name = str(getattr(us, "param_name", "") or "");
    consumer_name = str(getattr(us, "consumer_name", "") or "");
    parent_class = us?.consumer_parent_class;
    consumer_label = f"{parent_class}.{consumer_name}"
        if parent_class
        else consumer_name;
    line_param = f"The result is passed as `{param_name}`";
    if param_desc {
        line_param += f" ({_paren(param_desc)})";
    }
    line_consumer = f"to `{consumer_label}`";
    if consumer_desc {
        line_consumer += f" ({_paren(consumer_desc)})";
    }
    line_consumer += ".";
    lines = [USE_SITE_HEADER, line_param, line_consumer];
    if fields {
        lines.append("Fields read downstream: " + ", ".join(fields) + ".");
    }
    return "\n".join(lines);
}

def _generic(target_words: int) -> str {
    header_words = use_site_word_count(USE_SITE_HEADER);
    if target_words <= header_words {
        return USE_SITE_HEADER;
    }
    out: list[str] = [USE_SITE_HEADER];
    body: list[str] = [];
    used = header_words;
    idx = 0;
    while idx < 4 * len(GENERIC_SENTENCES) {
        sentence = str(GENERIC_SENTENCES[idx % len(GENERIC_SENTENCES)]);
        if used + use_site_word_count(sentence) > target_words {
            break;
        }
        body.append(sentence);
        used += use_site_word_count(sentence);
        idx += 1;
    }
    if body {
        out.append(" ".join(body));
    }
    residual = target_words - used;
    if residual > 0 {
        pad = [str(GENERIC_FILLER[k % len(GENERIC_FILLER)]) for k in range(residual)];
        out.append(
            ", ".join(pad[:-1] + [pad[-1] + "."]) if residual > 1 else pad[0] + "."
        );
    }
    return "\n".join(out);
}

impl use_site_word_count(text: str) -> int {
    return len(text.split());
}

impl resolve_use_site_mode -> str {
    import os;

    env_mode = os.environ.get("BYLLM_USE_SITE", "").strip().lower();
    if env_mode {
        return env_mode if env_mode in USE_SITE_MODES else "off";
    }
    try {
        cfg = get_byllm_config().get_optimizations_config();
        mode = str(cfg.get("use_site_specialization", "off")).strip().lower();
    } except Exception {
        return "off";
    }
    return mode if mode in USE_SITE_MODES else "off";
}

impl render_use_site_block(info: object, mode: str) -> str {
    if mode == "off" {
        return "";
    }
    us = info?.use_site;
    if us is None or not getattr(us, "resolved", False) {
        return "";
    }
    param_type = str(getattr(us, "param_type", "") or "");
    if mode == "signature" {
        return _block(us, param_type or None, None, None);
    }
    if mode == "semantic" {
        param_semstr = us?.param_semstr;
        fields = us?.fields_read;
        return _block(
            us,
            str(param_semstr) if param_semstr else (param_type or None),
            us?.consumer_semstr,
            list(fields) if fields else None
        );
    }
    if mode == "generic" {
        return _generic(use_site_word_count(render_use_site_block(info, "semantic")));
    }
    return "";
}

impl use_site_suffix(info: object) -> str {
    mode = resolve_use_site_mode();
    if mode == "off" {
        return "";
    }
    block = render_use_site_block(info, mode);
    return ("\n\n" + block) if block else "";
}
