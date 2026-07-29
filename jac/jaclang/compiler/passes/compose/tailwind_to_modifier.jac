"""Tailwind className → Compose Modifier chain + layout hints."""
import from jaclang.compiler.passes.compose { kotlin_ast as kt }

enum LayoutKind {
    COLUMN = "Column",
    ROW = "Row",
    BOX = "Box",
    FLOW_ROW = "FlowRow",
    FLOW_COLUMN = "FlowColumn",
    LAZY_GRID = "LazyVerticalGrid",
    HIDDEN = "Hidden"
}

obj TextStyleParts {
    has font_size: (str | None) = None,
        font_weight: (str | None) = None,
        font_family: (str | None) = None,
        text_align: (str | None) = None,
        letter_spacing: (str | None) = None,
        max_lines: (int | None) = None,
        overflow: (str | None) = None,
        soft_wrap: (bool | None) = None,
        color: (str | None) = None,
        text_transform: (str | None) = None,
        font_feature: (str | None) = None;
}

obj TailwindResult {
    has layout: LayoutKind = LayoutKind.COLUMN,
        modifier: kt.KtModifierChain = kt.KtModifierChain(),
        text_style: TextStyleParts = TextStyleParts(),
        unsupported: list[str] = [],
        arrangement: (str | None) = None,
        horizontal_alignment: (str | None) = None,
        vertical_alignment: (str | None) = None,
        horizontal_arrangement: (str | None) = None,
        vertical_arrangement: (str | None) = None,
        grid_columns: (int | None) = None,
        border_color: (str | None) = None,
        background_color: (str | None) = None;
}

obj TailwindTranslator {
    def translate(class_name: str) -> TailwindResult;
}

def translate_tailwind(class_name: str) -> TailwindResult;
def tw_unit_to_dp(n: float) -> str;
