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
     },
     COMPOSE_EVENT_ATTRS: set[str] = {"onClick", "onChange", "onValueChange"};

def is_compose_primitive(name: str) -> bool {
    return name in COMPOSE_PRIMITIVES;
}

def is_compose_event_attr(name: str) -> bool {
    return name in COMPOSE_EVENT_ATTRS;
}
