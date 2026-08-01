"""Generate typed Compose widget stubs from AndroidX API-signature files.

The emitter lowers any capitalized tag to a near-identity @Composable call
(compose_native_emit), so the *emittable* vocabulary is already open. This
generator closes the other half: it turns the machine-readable metalava
signature files that AndroidX publishes (e.g. compose/material3/material3/
api/current.txt) into typed `def:pub` stubs, so the type-checkable surface
tracks upstream Compose without anyone hand-transcribing widgets.

It also classifies each parameter as modifier / event / slot / value. The slot
classification is authoritative metadata the emitter can consume to route
@Composable slot arguments into lambdas precisely, replacing the type-free
"any composable-valued attribute is a slot" heuristic in _slot_wrap.

Pure text-in/text-out (no I/O) so it is trivially testable; the thin file
driver lives in the build tooling, not here.

Metalava line shape this parses (one composable per line):

    method @androidx.compose.runtime.Composable public static void Button(
        kotlin.jvm.functions.Function0<kotlin.Unit> onClick,
        optional androidx.compose.ui.Modifier modifier,
        optional boolean enabled,
        kotlin.jvm.functions.Function1<? super ...RowScope,kotlin.Unit> content);
"""

obj SigParam {
    has name: str = "",
        kind: str = "value",   # "modifier" | "event" | "slot" | "value"
        ptype: str = "",       # the parsed Kotlin type (fully-qualified), so the
                               # checker can map it to a real Jac type — not just
                               # the coarse kind. Empty only for pre-type callers.
        has_default: bool = True;  # metalava marks defaulted params `optional`; a
                                   # param WITHOUT that marker is required in Kotlin.
                                   # Defaults True so pre-type callers (empty ptype)
                                   # stay lenient — only the metalava classifier,
                                   # which sees the marker, sets it False.
}

obj ComposeSig {
    has name: str = "",
        params: list[SigParam] = [];
}

obj ConstMember {
    # A named constant on a Compose object/companion namespace — e.g.
    # `Arrangement.Center`, `Alignment.CenterVertically`, `Color.Red`. The ptype
    # is the member's Kotlin type (fully-qualified), mapped by the checker via the
    # same _map_kotlin_type used for widget/modifier params.
    has name: str = "",
        ptype: str = "";
}

def _split_top_level(s: str) -> list[str] {
    # Split on commas that are NOT nested inside <...> or (...). Compose param
    # types carry commas inside generics (Function1<? super Scope,kotlin.Unit>),
    # so a naive split would shred them.
    parts: list[str] = [];
    depth = 0;
    cur = "";
    for ch in s {
        if ch == '<' or ch == '(' {
            depth += 1;
            cur += ch;
        } elif ch == '>' or ch == ')' {
            depth -= 1;
            cur += ch;
        } elif ch == ',' and depth == 0 {
            parts.append(cur);
            cur = "";
        } else {
            cur += ch;
        }
    }
    if cur.strip() {
        parts.append(cur);
    }
    return parts;
}

def _classify_param(raw: str) -> (SigParam | None) {
    p = raw.strip();
    if not p {
        return None;
    }
    # metalava prefixes defaulted params with `optional`; its absence means the
    # param is required in Kotlin. Capture it before stripping so the checker can
    # enforce required-ness instead of erasing it (every param defaulted).
    has_default = p.startswith("optional ");
    if has_default {
        p = p[9:].strip();
    }
    if p.startswith("vararg ") {
        p = p[7:].strip();
    }
    if " " not in p {
        # A bare type with no name (e.g. an extension receiver) — skip it; it is
        # not an addressable named argument on the Jac call side.
        return None;
    }
    # "Type name" — the name is the final whitespace-separated token; the type
    # is everything before it (and may itself contain spaces inside generics).
    split = p.rsplit(" ", 1);
    ptype = split[0].strip();
    pname = split[1].strip();
    if not pname {
        return None;
    }
    if ptype == "androidx.compose.ui.Modifier" {
        return SigParam(name=pname, kind="modifier", ptype=ptype, has_default=has_default);
    }
    is_lambda = "kotlin.jvm.functions.Function" in ptype;
    returns_unit = ptype.endswith("kotlin.Unit>");
    if is_lambda and returns_unit {
        # onClick / onValueChange / onCheckedChange → event; every other
        # Unit-returning lambda is a content slot (topBar, content, label, …).
        if (
            pname.startswith("on")
            and len(pname) > 2
            and pname[2] == pname[2].upper()
            and pname[2] != pname[2].lower()
        ) {
            return SigParam(name=pname, kind="event", ptype=ptype, has_default=has_default);
        }
        return SigParam(name=pname, kind="slot", ptype=ptype, has_default=has_default);
    }
    return SigParam(name=pname, kind="value", ptype=ptype, has_default=has_default);
}

def _parse_line(line: str) -> (ComposeSig | None) {
    stripped = line.strip();
    if "@androidx.compose.runtime.Composable" not in stripped {
        return None;
    }
    if " void " not in stripped {
        # Non-Unit @Composable (state producers etc.) are not UI widgets.
        return None;
    }
    open_paren = stripped.find("(");
    if open_paren < 0 {
        return None;
    }
    head = stripped[:open_paren];
    name = head.rsplit(" ", 1)[-1].strip() if " " in head else head.strip();
    if not name or name[0] != name[0].upper() or name[0] == name[0].lower() {
        # UI composables are PascalCase; lowercase names are helpers.
        return None;
    }
    close_paren = stripped.rfind(")");
    if close_paren <= open_paren {
        return None;
    }
    inner = stripped[open_paren + 1:close_paren];
    params: list[SigParam] = [];
    for raw in _split_top_level(inner) {
        cp = _classify_param(raw);
        if cp is not None {
            params.append(cp);
        }
    }
    return ComposeSig(name=name, params=params);
}

def _dedup_richest(sigs: list[ComposeSig]) -> list[ComposeSig] {
    # Collapse overloads (Jac has no overloading) by keeping the richest
    # signature — the one with the most parameters, i.e. the widest calling
    # surface to type-check against — then sort by name for stable output.
    best: dict[str, ComposeSig] = {};
    for sig in sigs {
        prev = best.get(sig.name);
        if prev is None or len(sig.params) > len(prev.params) {
            best[sig.name] = sig;
        }
    }
    out: list[ComposeSig] = [];
    for key in sorted(best.keys()) {
        out.append(best[key]);
    }
    return out;
}

def parse_signature_text(text: str) -> list[ComposeSig] {
    # Parse every @Composable UI method.
    sigs: list[ComposeSig] = [];
    for line in text.split("\n") {
        sig = _parse_line(line);
        if sig is not None {
            sigs.append(sig);
        }
    }
    return _dedup_richest(sigs);
}

def _parse_modifier_line(line: str) -> (ComposeSig | None) {
    # A Modifier extension function reads
    #   method public static androidx.compose.ui.Modifier <name>(
    #       androidx.compose.ui.Modifier, optional <T> <arg>, …);
    # i.e. a static method whose return type is Modifier and whose (unnamed)
    # first parameter is the Modifier receiver. This is the chainable
    # `Modifier.padding(..).fillMaxWidth()` surface, distinct from the
    # @Composable widgets parsed by _parse_line.
    stripped = line.strip();
    if "@androidx.compose.runtime.Composable" in stripped {
        return None;
    }
    open_paren = stripped.find("(");
    if open_paren < 0 {
        return None;
    }
    head = stripped[:open_paren];
    # The return-type token sits immediately before the method name; require it
    # to be Modifier so we ingest only chainable modifier extensions.
    parts = head.rsplit(" ", 2);
    if len(parts) < 2 or parts[len(parts) - 2] != "androidx.compose.ui.Modifier" {
        return None;
    }
    name = parts[len(parts) - 1].strip();
    if not name {
        return None;
    }
    close_paren = stripped.rfind(")");
    if close_paren <= open_paren {
        return None;
    }
    inner = stripped[open_paren + 1:close_paren];
    params: list[SigParam] = [];
    for raw in _split_top_level(inner) {
        # The bare `androidx.compose.ui.Modifier` receiver has no name, so
        # _classify_param drops it — leaving only the addressable arguments.
        cp = _classify_param(raw);
        if cp is not None {
            params.append(cp);
        }
    }
    return ComposeSig(name=name, params=params);
}

def parse_modifier_text(text: str) -> list[ComposeSig] {
    # Parse every Modifier extension function into a chainable-method surface.
    sigs: list[ComposeSig] = [];
    for line in text.split("\n") {
        sig = _parse_modifier_line(line);
        if sig is not None {
            sigs.append(sig);
        }
    }
    return _dedup_richest(sigs);
}

def _parse_const_class_name(line: str) -> (str | None) {
    # A namespace opener reads `... public final class <Qualified> {`. Return the
    # simple class name with a trailing `.Companion` stripped — Compose keeps
    # `Alignment`/`Color` constants on their companion object, but Kotlin (and Jac)
    # address them straight off the type: `Alignment.Center`, `Color.Red`.
    stripped = line.strip();
    if " class " not in stripped or not stripped.rstrip().endswith("{") {
        return None;
    }
    after = stripped.split(" class ", 1)[1].strip();
    # `<Qualified> {` — the name is the token before the brace.
    name = after.split("{", 1)[0].strip();
    if " " in name {
        return None;
    }
    if name.endswith(".Companion") {
        name = name[:len(name) - len(".Companion")];
    }
    # Reduce a qualified name (`androidx...ui.Alignment`) to its simple form.
    if "." in name {
        name = name.rsplit(".", 1)[-1];
    }
    return name if name else None;
}

def _parse_const_line(line: str) -> (ConstMember | None) {
    # A constant reads `property public final <Type> <Name>;` or
    # `field public static final <Type> <Name>;`. We take the last two
    # whitespace tokens (once the trailing `;` is dropped) as <Type> <Name> —
    # const types carry no internal spaces, unlike the generic-laden widget params.
    stripped = line.strip();
    if not (stripped.startswith("property ") or stripped.startswith("field ")) {
        return None;
    }
    if "(" in stripped {
        # A property getter/setter method form (`getCenter()`) — not a value.
        return None;
    }
    body = stripped.rstrip(";").strip();
    toks = body.split();
    if len(toks) < 2 {
        return None;
    }
    name = toks[len(toks) - 1];
    ptype = toks[len(toks) - 2];
    if not name or name == "INSTANCE" {
        return None;
    }
    return ConstMember(name=name, ptype=ptype);
}

def parse_const_text(text: str) -> dict[str, list[ConstMember]] {
    # Parse a metalava object/companion block into `namespace -> [ConstMember]`,
    # the typed const surface (Arrangement/Alignment/Color). Grouped by the
    # enclosing class so one file can carry several namespaces.
    out: dict[str, list[ConstMember]] = {};
    current: str = "";
    for line in text.split("\n") {
        cls = _parse_const_class_name(line);
        if cls is not None {
            current = cls;
            if current not in out {
                out[current] = [];
            }
            continue;
        }
        if not current {
            continue;
        }
        cm = _parse_const_line(line);
        if cm is not None {
            out[current].append(cm);
        }
    }
    # Drop namespaces that carried no constants (bare class braces).
    return {k: v for (k, v) in out.items() if v};
}

def slot_table(sigs: list[ComposeSig]) -> dict[str, list[str]] {
    # widget name -> its @Composable slot parameter names. Authoritative slot
    # metadata for the emitter (precise replacement for the _slot_wrap heuristic).
    table: dict[str, list[str]] = {};
    for sig in sigs {
        slots = [p.name for p in sig.params if p.kind == "slot"];
        if slots {
            table[sig.name] = slots;
        }
    }
    return table;
}

def _param_decl(p: SigParam) -> str {
    if p.kind == "modifier" {
        return f"{p.name}: (ModifierChain | None) = None";
    }
    if p.kind == "event" or p.kind == "slot" {
        return f"{p.name}: (any | None) = None";
    }
    return f"{p.name}: any = None";
}

def emit_widget_stubs(sigs: list[ComposeSig]) -> str {
    # Emit the generated `def:pub` block. Every parameter carries a default so
    # required-after-optional orderings (common in Compose: a trailing required
    # `content` slot after optional params) stay valid Jac — matching the
    # hand-written core stubs, which also default their required args.
    lines: list[str] = [
        "# ── GENERATED WIDGETS — do not edit below this marker ──",
        "# Regenerate from AndroidX signature files via compose_stub_gen.",
        "# Relies on the core types (Composable, ModifierChain) declared above."
    ];
    for sig in sigs {
        if not sig.params {
            lines.append(f"def:pub {sig.name}() -> Composable;");
            continue;
        }
        decls = [_param_decl(p) for p in sig.params];
        body = ",\n    ".join(decls);
        lines.append(f"def:pub {sig.name}(\n    {body}\n) -> Composable;");
    }
    return "\n".join(lines) + "\n";
}

def generate(signature_text: str) -> str {
    return emit_widget_stubs(parse_signature_text(signature_text));
}
