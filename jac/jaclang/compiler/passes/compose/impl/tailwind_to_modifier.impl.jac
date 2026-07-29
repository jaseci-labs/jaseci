"""Tailwind className → Compose Modifier (v1 subset)."""
import re;
import from jaclang.compiler.passes.compose { kotlin_ast as kt }


glob IGNORE_CLASSES: set[str] = {
    "btn", "card", "pane-head", "stat", "tok-chip"
};

glob _SEMANTIC_BG: dict[str, str] = {
    "bg": "JacDesign.background",
    "surface": "JacDesign.surface",
    "surface-2": "JacDesign.softMuted",
    "accent": "JacDesign.primary",
    "muted": "JacDesign.muted",
    "success": "JacDesign.success",
    "warning": "JacDesign.warning",
    "danger": "JacDesign.danger",
    "info": "JacDesign.info",
    "white": "Color.White"
};

glob _SEMANTIC_TEXT: dict[str, str] = {
    "fg": "JacDesign.onBackground",
    "muted": "JacDesign.muted",
    "accent": "JacDesign.primary",
    "accent-fg": "JacDesign.onPrimary",
    "white": "Color.White"
};

# Common Tailwind palette shades used by cl components (ARGB Compose Color).
glob _PALETTE: dict[str, str] = {
    "slate-50": "Color(0xFFF8FAFC)",
    "slate-100": "Color(0xFFF1F5F9)",
    "slate-200": "Color(0xFFE2E8F0)",
    "slate-300": "Color(0xFFCBD5E1)",
    "slate-400": "Color(0xFF94A3B8)",
    "slate-500": "Color(0xFF64748B)",
    "slate-600": "Color(0xFF475569)",
    "slate-700": "Color(0xFF334155)",
    "slate-800": "Color(0xFF1E293B)",
    "slate-900": "Color(0xFF0F172A)",
    "gray-50": "Color(0xFFF9FAFB)",
    "gray-100": "Color(0xFFF3F4F6)",
    "gray-200": "Color(0xFFE5E7EB)",
    "gray-300": "Color(0xFFD1D5DB)",
    "gray-400": "Color(0xFF9CA3AF)",
    "gray-500": "Color(0xFF6B7280)",
    "gray-600": "Color(0xFF4B5563)",
    "gray-700": "Color(0xFF374151)",
    "gray-800": "Color(0xFF1F2937)",
    "gray-900": "Color(0xFF111827)",
    "blue-50": "Color(0xFFEFF6FF)",
    "blue-100": "Color(0xFFDBEAFE)",
    "blue-500": "Color(0xFF3B82F6)",
    "blue-600": "Color(0xFF2563EB)",
    "blue-700": "Color(0xFF1D4ED8)",
    "teal-50": "Color(0xFFF0FDFA)",
    "teal-500": "Color(0xFF14B8A6)",
    "teal-600": "Color(0xFF0D9488)",
    "teal-700": "Color(0xFF0F766E)",
    "red-500": "Color(0xFFEF4444)",
    "red-600": "Color(0xFFDC2626)",
    "green-500": "Color(0xFF22C55E)",
    "green-600": "Color(0xFF16A34A)",
    "amber-500": "Color(0xFFF59E0B)",
    "amber-600": "Color(0xFFD97706)",
    "indigo-500": "Color(0xFF6366F1)",
    "indigo-600": "Color(0xFF4F46E5)",
    "white": "Color.White",
    "black": "Color.Black"
};

glob _TEXT_SIZE: dict[str, str] = {
    "text-xs": "12.sp",
    "text-sm": "14.sp",
    "text-base": "16.sp",
    "text-lg": "18.sp",
    "text-xl": "20.sp",
    "text-2xl": "24.sp",
    "text-3xl": "30.sp"
};

impl tw_unit_to_dp(n: float) -> str {
    px = n * 4.0;
    if px == float(int(px)) {
        return f"{int(px)}.dp";
    }
    return f"{px}.dp";
}

def _resolve_color(key: str) -> (str | None) {
    if key in _SEMANTIC_BG {
        return _SEMANTIC_BG[key];
    }
    if key in _SEMANTIC_TEXT {
        return _SEMANTIC_TEXT[key];
    }
    if key in _PALETTE {
        return _PALETTE[key];
    }
    # opacity suffix: slate-900/80
    if "/" in key {
        (base, op) = key.split("/", 1);
        color = _resolve_color(base);
        if color and op.isdigit() {
            alpha = float(op) / 100.0;
            return f"{color}.copy(alpha = {alpha}f)";
        }
    }
    return None;
}

def _add_mod(result: TailwindResult, name: str, arg: str) -> None {
    result.modifier.calls.append(
        kt.KtModifierCall(name=name, args=[kt.KtRaw(code=arg)])
    );
}

def _add_mod0(result: TailwindResult, name: str) -> None {
    result.modifier.calls.append(kt.KtModifierCall(name=name, args=[]));
}

def _parse_spacing(cls: str) -> (str | None, str | None) {
    # returns (kind, dp_str) e.g. ("p", "16.dp")
    m = re.match(r"^(p|px|py|pt|pr|pb|pl|m|mx|my|mt|mr|mb|ml)-([\d.]+)$", cls);
    if not m {
        return (None, None);
    }
    kind = m.group(1);
    dp = tw_unit_to_dp(float(m.group(2)));
    return (kind, dp);
}

def _apply_class(result: TailwindResult, cls: str, flags: dict[str, str]) -> None {
    if cls in IGNORE_CLASSES or cls.startswith("insp-") {
        return;
    }
    if cls.startswith("hover:") or cls.startswith("group-hover:")
    or cls.startswith("focus:") or cls.startswith("focus-visible:")
    or cls.startswith("last:") {
        result.unsupported.append(f"dropped:{cls}");
        return;
    }
    for prefix in ["sm:", "md:", "lg:", "xl:", "disabled:"] {
        if cls.startswith(prefix) {
            cls = cls[len(prefix):];
            break;
        }
    }
    if cls == "flex" {
        flags["flex"] = "1";
        return;
    }
    if cls == "flex-col" {
        flags["flex_col"] = "1";
        return;
    }
    if cls == "inline-flex" {
        flags["flex"] = "1";
        return;
    }
    if cls == "hidden" {
        result.layout = LayoutKind.HIDDEN;
        return;
    }
    if cls == "flex-1" {
        _add_mod(result, "weight", "1f");
        return;
    }
    if cls == "flex-wrap" {
        flags["wrap"] = "1";
        return;
    }
    if cls in {"shrink-0", "flex-shrink-0"} {
        return;
    }
    if cls == "items-center" {
        flags["items"] = "center";
        return;
    }
    if cls == "items-start" {
        flags["items"] = "start";
        return;
    }
    if cls == "items-end" {
        flags["items"] = "end";
        return;
    }
    if cls == "justify-between" {
        flags["justify"] = "SpaceBetween";
        return;
    }
    if cls == "justify-center" {
        flags["justify"] = "Center";
        return;
    }
    if cls == "justify-end" {
        flags["justify"] = "End";
        return;
    }
    m = re.match(r"^gap-([\d.]+)$", cls);
    if m {
        dp = tw_unit_to_dp(float(m.group(1)));
        result.arrangement = f"Arrangement.spacedBy({dp})";
        return;
    }
    m = re.match(r"^space-y-([\d.]+)$", cls);
    if m {
        dp = tw_unit_to_dp(float(m.group(1)));
        result.vertical_arrangement = f"Arrangement.spacedBy({dp})";
        return;
    }
    (kind, dp) = _parse_spacing(cls);
    if kind and dp {
        if kind == "p" {
            _add_mod(result, "padding", dp);
        } elif kind == "px" {
            _add_mod(result, "padding", f"horizontal = {dp}");
        } elif kind == "py" {
            _add_mod(result, "padding", f"vertical = {dp}");
        } elif kind == "pt" {
            _add_mod(result, "padding", f"top = {dp}");
        } elif kind == "pr" {
            _add_mod(result, "padding", f"end = {dp}");
        } elif kind == "pb" {
            _add_mod(result, "padding", f"bottom = {dp}");
        } elif kind == "pl" {
            _add_mod(result, "padding", f"start = {dp}");
        } else {
            # margins → padding (Compose has no margin)
            _add_mod(result, "padding", dp);
        }
        return;
    }
    if cls == "w-full" {
        _add_mod0(result, "fillMaxWidth");
        return;
    }
    if cls in {"h-full", "h-screen", "min-h-screen"} {
        _add_mod0(result, "fillMaxHeight");
        return;
    }
    m = re.match(r"^w-([\d.]+)$", cls);
    if m {
        _add_mod(result, "width", tw_unit_to_dp(float(m.group(1))));
        return;
    }
    m = re.match(r"^h-([\d.]+)$", cls);
    if m {
        _add_mod(result, "height", tw_unit_to_dp(float(m.group(1))));
        return;
    }
    m = re.match(r"^w-\[(\d+)px\]$", cls);
    if m {
        _add_mod(result, "width", f"{m.group(1)}.dp");
        return;
    }
    m = re.match(r"^rounded(-md|-lg|-full)?$", cls);
    if m {
        suf = m.group(1) or "";
        rad = "4.dp";
        if suf == "-md" {
            rad = "6.dp";
        } elif suf == "-lg" {
            rad = "8.dp";
        } elif suf == "-full" {
            rad = "50";
        }
        _add_mod(result, "clip", f"RoundedCornerShape({rad})");
        return;
    }
    if cls == "border" {
        flags["border_w"] = "1";
        return;
    }
    if cls == "border-2" {
        flags["border_w"] = "2";
        return;
    }
    if cls.startswith("bg-") {
        key = cls[3:];
        color = _resolve_color(key);
        if color {
            result.background_color = color;
            _add_mod(result, "background", color);
            return;
        }
        result.unsupported.append(cls);
        return;
    }
    if cls.startswith("text-") {
        key = cls[5:];
        if cls in _TEXT_SIZE {
            result.text_style.font_size = _TEXT_SIZE[cls];
            return;
        }
        color = _resolve_color(key);
        if color {
            result.text_style.color = color;
            return;
        }
        if cls == "text-center" {
            result.text_style.text_align = "TextAlign.Center";
            return;
        }
        if cls == "text-left" {
            result.text_style.text_align = "TextAlign.Start";
            return;
        }
        if cls == "text-right" {
            result.text_style.text_align = "TextAlign.End";
            return;
        }
        result.unsupported.append(cls);
        return;
    }
    if cls == "font-medium" {
        result.text_style.font_weight = "FontWeight.Medium";
        return;
    }
    if cls == "font-semibold" {
        result.text_style.font_weight = "FontWeight.SemiBold";
        return;
    }
    if cls == "font-bold" {
        result.text_style.font_weight = "FontWeight.Bold";
        return;
    }
    if cls == "font-mono" {
        result.text_style.font_family = "FontFamily.Monospace";
        return;
    }
    if cls == "truncate" {
        result.text_style.max_lines = 1;
        result.text_style.overflow = "TextOverflow.Ellipsis";
        return;
    }
    if cls.startswith("border-") {
        key = cls[7:];
        color = _resolve_color(key);
        if color {
            result.border_color = color;
            return;
        }
    }
    m = re.match(r"^grid-cols-(\d+)$", cls);
    if m {
        flags["grid"] = "1";
        result.grid_columns = int(m.group(1));
        return;
    }
    if cls == "grid" {
        flags["grid"] = "1";
        return;
    }
    result.unsupported.append(cls);
}

def _finalize(result: TailwindResult, flags: dict[str, str]) -> None {
    if "grid" in flags {
        result.layout = LayoutKind.LAZY_GRID;
    } elif "flex" in flags {
        if "flex_col" in flags {
            if "wrap" in flags {
                result.layout = LayoutKind.FLOW_COLUMN;
            } else {
                result.layout = LayoutKind.COLUMN;
            }
        } else {
            if "wrap" in flags {
                result.layout = LayoutKind.FLOW_ROW;
            } else {
                result.layout = LayoutKind.ROW;
            }
        }
    } else {
        result.layout = LayoutKind.COLUMN;
    }
    items = flags.get("items");
    if items == "center" {
        if result.layout == LayoutKind.ROW {
            result.vertical_alignment = "Alignment.CenterVertically";
        } else {
            result.horizontal_alignment = "Alignment.CenterHorizontally";
        }
    } elif items == "start" {
        result.horizontal_alignment = "Alignment.Start";
    } elif items == "end" {
        result.horizontal_alignment = "Alignment.End";
    }
    justify = flags.get("justify");
    if justify {
        result.horizontal_arrangement = f"Arrangement.{justify}";
    }
    # Emit border after color classes so `border border-slate-200` works in either order.
    if "border_w" in flags {
        width = flags["border_w"];
        color = result.border_color or "JacDesign.muted";
        _add_mod(result, "border", f"{width}.dp, {color}");
    }
}

impl TailwindTranslator.translate(class_name: str) -> TailwindResult {
    result = TailwindResult();
    flags: dict[str, str] = {};
    if not class_name {
        return result;
    }
    for raw in class_name.split() {
        if raw {
            _apply_class(result, raw, flags);
        }
    }
    _finalize(result, flags);
    return result;
}

impl translate_tailwind(class_name: str) -> TailwindResult {
    return TailwindTranslator().translate(class_name);
}
