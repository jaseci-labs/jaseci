"""Compose primitive surface — open vocabulary of Material3/foundation tags."""

glob COMPOSE_PRIMITIVES: set[str] = {
    "Column",
    "Row",
    "Box",
    "Scaffold",
    "LazyColumn",
    "LazyRow",
    "Text",
    "Icon",
    "Image",
    "Button",
    "FloatingActionButton",
    "OutlinedTextField",
    "TextField",
    "Card",
    "TopAppBar",
    "Checkbox",
    "Switch",
    "HorizontalDivider",
    "CircularProgressIndicator",
    "Spacer",
    "Surface",
    "Raw"
};

glob COMPOSE_EVENT_ATTRS: set[str] = {
    "onClick",
    "onChange",
    "onValueChange"
};

def is_compose_primitive(name: str) -> bool {
    return name in COMPOSE_PRIMITIVES;
}

def is_compose_event_attr(name: str) -> bool {
    return name in COMPOSE_EVENT_ATTRS;
}
