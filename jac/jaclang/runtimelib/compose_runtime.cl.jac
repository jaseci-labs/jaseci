"""Jetpack Compose client surface — typed primitives for the native Android target.

These declarations exist for type-checking and IDE support. The ComposeGenPass
lowers them near-identity to Kotlin @Composable calls; it never invokes them, so
the method bodies are intentionally absent (type stubs).

P0 #3 — typed surface:
  Composable, Modifier (builder), Dp, and Typography are real types now (not
  `any`), so a project that opts into `[client.android] type_check = true` gets
  real mistakes caught in Jac — a typo'd modifier name (`.filMaxSize()`), a
  non-existent Typography style, a wrong primitive arg shape — before Gradle.

  Known gap (hard blocker for enabling by default): the idiomatic `24.dp`
  suffix and `x.len` are Kotlin-isms that jac_to_kotlin lowers specially, but
  Jac has no extension properties, so the type checker rejects `int.dp` /
  `list.len`. Until Jac gains extension members, type_check therefore defaults
  to false and the canonical compose_android example (which uses `.dp`/`.len`)
  stays unchecked. Components written in valid Jac (no `.dp`/`.len`) can opt in.

Note on naming: `Modifier` and `Typography` are Kotlin singletons (a value you
chain from / read members of). Jac can't reuse one name for both a type and a
global, so the builder types are `ModifierChain` / `TypographyStyles` and the
globals `Modifier` / `Typography` hold instances of them — `Modifier.fillMaxSize()`
and `Typography.titleLarge` resolve against the typed instance.
"""

# ── Core marker / value types ────────────────────────────────────────────────

obj Composable {
    # Opaque marker — the return type of every @Composable primitive. Carries no
    # runtime state; it exists so `def f -> Composable` type-checks and so callers
    # can't accidentally use a composable result as data.
}

obj Dp {
    has value: float = 0.0;
}

# ── Modifier builder ─────────────────────────────────────────────────────────
# Mirrors androidx.compose.ui.Modifier: a chainable builder where every method
# returns the builder. One method per name (Jac has no overloading); the padding
# family is expressed with optional named params instead of overloads.
obj ModifierChain {
    def fillMaxSize(fraction: float = 1.0) -> ModifierChain;
    def fillMaxWidth(fraction: float = 1.0) -> ModifierChain;
    def fillMaxHeight(fraction: float = 1.0) -> ModifierChain;
    def wrapContentSize(align: (str | None) = None) -> ModifierChain;
    def width(w: Dp) -> ModifierChain;
    def height(h: Dp) -> ModifierChain;
    def size(s: Dp) -> ModifierChain;
    def padding(
        all: (Dp | None) = None,
        horizontal: (Dp | None) = None,
        vertical: (Dp | None) = None,
        start: (Dp | None) = None,
        top: (Dp | None) = None,
        end: (Dp | None) = None,
        bottom: (Dp | None) = None
    ) -> ModifierChain;
    def clip(shape: (str | None) = None) -> ModifierChain;
    def background(color: (str | None) = None) -> ModifierChain;
    def border(width: Dp, color: (str | None) = None) -> ModifierChain;
    def clickable(enabled: bool = True, onClick: (any | None) = None) -> ModifierChain;
}

# The empty Modifier instance every chain starts from: Modifier.fillMaxSize()…
glob Modifier: ModifierChain = ModifierChain();

# Typography styles — member access (Typography.titleLarge) resolves against real
# fields instead of `any`, so a typo'd style name fails in Jac.
obj TypographyStyles {
    has displayLarge: any = None,
        displayMedium: any = None,
        displaySmall: any = None,
        headlineLarge: any = None,
        headlineMedium: any = None,
        headlineSmall: any = None,
        titleLarge: any = None,
        titleMedium: any = None,
        titleSmall: any = None,
        bodyLarge: any = None,
        bodyMedium: any = None,
        bodySmall: any = None,
        labelLarge: any = None,
        labelMedium: any = None,
        labelSmall: any = None;
}
glob Typography: TypographyStyles = TypographyStyles();

# Kotlin singletons surfaced as typed globals (member access is checked).
glob Arrangement: any;
glob Alignment: any;
glob MaterialTheme: any;
glob Icons: any;

# ── Layout primitives ────────────────────────────────────────────────────────

def:pub Column(
    modifier: (ModifierChain | None) = None,
    verticalArrangement: any = None,
    horizontalAlignment: any = None
) -> Composable;

def:pub Row(
    modifier: (ModifierChain | None) = None,
    horizontalArrangement: any = None,
    verticalAlignment: any = None
) -> Composable;

def:pub Box(
    modifier: (ModifierChain | None) = None, contentAlignment: any = None
) -> Composable;

def:pub Scaffold(
    modifier: (ModifierChain | None) = None,
    topBar: any = None,
    bottomBar: any = None
) -> Composable;

def:pub LazyColumn(modifier: (ModifierChain | None) = None) -> Composable;

def:pub LazyRow(modifier: (ModifierChain | None) = None) -> Composable;

def:pub Spacer(modifier: (ModifierChain | None) = None) -> Composable;

def:pub Surface(
    modifier: (ModifierChain | None) = None, color: any = None
) -> Composable;

# ── Content primitives ───────────────────────────────────────────────────────

def:pub Text(
    text: any = "", style: any = None, color: any = None
) -> Composable;

def:pub Icon(
    imageVector: any = None,
    contentDescription: any = None,
    modifier: (ModifierChain | None) = None,
    tint: any = None
) -> Composable;

def:pub Image(
    painter: any = None,
    contentDescription: any = None,
    modifier: (ModifierChain | None) = None
) -> Composable;

def:pub Button(
    onClick: any = None,
    modifier: (ModifierChain | None) = None,
    enabled: bool = True
) -> Composable;

def:pub FloatingActionButton(
    onClick: any = None, modifier: (ModifierChain | None) = None
) -> Composable;

def:pub OutlinedTextField(
    value: any = "",
    onValueChange: any = None,
    modifier: (ModifierChain | None) = None,
    placeholder: any = None,
    label: any = None
) -> Composable;

def:pub TextField(
    value: any = "",
    onValueChange: any = None,
    modifier: (ModifierChain | None) = None,
    placeholder: any = None,
    label: any = None
) -> Composable;

def:pub Card(modifier: (ModifierChain | None) = None) -> Composable;

def:pub TopAppBar(
    title: any = None, modifier: (ModifierChain | None) = None
) -> Composable;

def:pub Checkbox(
    checked: bool = False,
    onCheckedChange: any = None,
    modifier: (ModifierChain | None) = None
) -> Composable;

def:pub Switch(
    checked: bool = False,
    onCheckedChange: any = None,
    modifier: (ModifierChain | None) = None
) -> Composable;

def:pub HorizontalDivider(modifier: (ModifierChain | None) = None) -> Composable;

def:pub CircularProgressIndicator(
    modifier: (ModifierChain | None) = None
) -> Composable;

"""Raw Kotlin escape hatch — emit composable source verbatim (lose-nothing)."""
def:pub Raw(kotlin: str = "") -> Composable;
