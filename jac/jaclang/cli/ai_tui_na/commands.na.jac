import from .state { TuiState }
import from .select_list { SelectItem }
import from .ipc_schema { CMD_STOP, CMD_RESET, CMD_QUIT, CMD_APPLY }
import from .input_types {
    Effect,
    EffectKind,
    effect_quit,
    effect_stop,
    effect_reset,
    effect_apply
}

glob _SETTINGS_PREFIX: str = "/settings ";

enum CmdKind {
    NONE = 0,
    OVERLAY = 1,
    SCROLL_BOTTOM = 2,
    SCROLL_TOP = 3,
    IPC_RESET = 4,
    IPC = 5,
}

enum CmdResult { NONE = 0, HANDLED = 1, QUIT = 2, OPEN_MODEL = 3, OPEN_FILE = 4, }

obj CmdDef {
    has value: str = "",
        slash_labels: list[str] = [],
        description: str = "",
        kind: CmdKind = CmdKind.NONE,
        ipc_name: str = "",
        slash_ac: bool = False,
        palette: bool = False,
        running_only: bool = False,
        palette_label: str = "";

    def execute_effects(state: TuiState) -> tuple[CmdResult, list[Effect]] {
        effects: list[Effect] = [];
        if self.kind == CmdKind.OVERLAY {
            if self.value == "open_model" {
                return (CmdResult.OPEN_MODEL, effects);
            }
            if self.value == "open_file" {
                return (CmdResult.OPEN_FILE, effects);
            }
            return (CmdResult.NONE, effects);
        }
        if self.kind == CmdKind.SCROLL_BOTTOM {
            state.scroll_to_bottom();
            return (CmdResult.HANDLED, effects);
        }
        if self.kind == CmdKind.SCROLL_TOP {
            state.viewport_top = 0;
            state.follow_tail = False;
            state.mark_layout_dirty();
            return (CmdResult.HANDLED, effects);
        }
        if self.kind == CmdKind.IPC_RESET {
            effects.append(effect_reset());
            state.reset_events();
            state.mark_layout_dirty();
            return (CmdResult.HANDLED, effects);
        }
        if self.kind == CmdKind.IPC {
            if self.ipc_name == CMD_QUIT {
                effects.append(effect_quit());
                return (CmdResult.QUIT, effects);
            }
            if self.ipc_name == CMD_STOP {
                effects.append(effect_stop());
            }
            state.mark_layout_dirty();
            return (CmdResult.HANDLED, effects);
        }
        return (CmdResult.NONE, effects);
    }
}

glob _CMD_TABLE_CACHE: dict[str, CmdDef] = {},
     _CMD_ORDER_CACHE: list[str] = [];

def _push_cmd(
    table: dict[str, CmdDef],
    order: list[str],
    value: str,
    slash_a: str,
    slash_b: str,
    slash_c: str,
    description: str,
    kind: CmdKind,
    ipc_name: str,
    slash_ac: bool,
    palette: bool,
    running_only: bool,
    palette_label: str
) {
    labels: list[str] = [];
    if len(slash_a) > 0 {
        labels.append(slash_a);
    }
    if len(slash_b) > 0 and slash_b != slash_a {
        labels.append(slash_b);
    }
    if len(slash_c) > 0 and slash_c != slash_a and slash_c != slash_b {
        labels.append(slash_c);
    }
    d = CmdDef(
        value=value,
        slash_labels=labels,
        description=description,
        kind=kind,
        ipc_name=ipc_name,
        slash_ac=slash_ac,
        palette=palette,
        running_only=running_only,
        palette_label=palette_label
    );
    table[value] = d;
    order.append(value);
    for label in labels {
        table[label] = d;
    }
}

def _cmd_table -> dict[str, CmdDef] {
    if len(_CMD_TABLE_CACHE) > 0 {
        return _CMD_TABLE_CACHE;
    }
    _push_cmd(
        _CMD_TABLE_CACHE,
        _CMD_ORDER_CACHE,
        "open_model",
        "/model",
        "/models",
        "",
        "Switch the active model",
        CmdKind.OVERLAY,
        "",
        True,
        True,
        False,
        "/model"
    );
    _push_cmd(
        _CMD_TABLE_CACHE,
        _CMD_ORDER_CACHE,
        "open_file",
        "/file",
        "/files",
        "",
        "Insert a project file reference",
        CmdKind.OVERLAY,
        "",
        True,
        True,
        False,
        "/files"
    );
    _push_cmd(
        _CMD_TABLE_CACHE,
        _CMD_ORDER_CACHE,
        "scroll_bottom",
        "",
        "",
        "",
        "Follow latest transcript rows",
        CmdKind.SCROLL_BOTTOM,
        "",
        False,
        True,
        False,
        "Scroll to bottom"
    );
    _push_cmd(
        _CMD_TABLE_CACHE,
        _CMD_ORDER_CACHE,
        "scroll_top",
        "",
        "",
        "",
        "Jump to oldest visible rows",
        CmdKind.SCROLL_TOP,
        "",
        False,
        True,
        False,
        "Scroll to top"
    );
    _push_cmd(
        _CMD_TABLE_CACHE,
        _CMD_ORDER_CACHE,
        "/stop",
        "/stop",
        "",
        "",
        "Stop the current turn",
        CmdKind.IPC,
        CMD_STOP,
        True,
        True,
        True,
        "/stop"
    );
    _push_cmd(
        _CMD_TABLE_CACHE,
        _CMD_ORDER_CACHE,
        "/clear",
        "/clear",
        "",
        "",
        "Clear transcript and reset session",
        CmdKind.IPC_RESET,
        CMD_RESET,
        True,
        True,
        False,
        "/clear"
    );
    _push_cmd(
        _CMD_TABLE_CACHE,
        _CMD_ORDER_CACHE,
        "/reset",
        "/reset",
        "",
        "",
        "Clear transcript and reset session",
        CmdKind.IPC_RESET,
        CMD_RESET,
        True,
        True,
        False,
        "/reset"
    );
    _push_cmd(
        _CMD_TABLE_CACHE,
        _CMD_ORDER_CACHE,
        "/quit",
        "/quit",
        "/exit",
        "/q",
        "Exit jac ai TUI",
        CmdKind.IPC,
        CMD_QUIT,
        True,
        True,
        False,
        "/quit"
    );
    return _CMD_TABLE_CACHE;
}

def _find_def(value: str) -> CmdDef | None {
    return _cmd_table().get(value);
}

def _resolve_slash_line(text: str) -> str {
    d = _cmd_table().get(text);
    if d is None {
        return "";
    }
    return d.value;
}

def command_dispatch_effects(cmd: str, state: TuiState) -> tuple[CmdResult, list[Effect]] {
    d = _find_def(cmd);
    if d is None {
        empty: list[Effect] = [];
        return (CmdResult.NONE, empty);
    }
    return d.execute_effects(state);
}

def slash_submit_effects(text: str, state: TuiState) -> tuple[CmdResult, list[Effect]] {
    if text.startswith(_SETTINGS_PREFIX) {
        args = text.removeprefix(_SETTINGS_PREFIX).strip();
        return (CmdResult.HANDLED, [effect_apply(args)]);
    }
    value = _resolve_slash_line(text);
    if not value {
        empty: list[Effect] = [];
        return (CmdResult.NONE, empty);
    }
    return command_dispatch_effects(value, state);
}

def apply_model_effects(model: str, state: TuiState) -> list[Effect] {
    state.mark_layout_dirty();
    return [effect_apply("model=" + model)];
}

def palette_commands(state: TuiState) -> list[SelectItem] {
    items: list[SelectItem] = [];
    table = _cmd_table();
    for value in _CMD_ORDER_CACHE {
        d = table[value];
        if not d.palette {
            continue;
        }
        if d.running_only and not state.status_blocks_prompt() {
            continue;
        }
        items.append(
            SelectItem(value=d.value, label=d.palette_label, description=d.description)
        );
    }
    return items;
}

def slash_ac_catalog(state: TuiState) -> list[SelectItem] {
    items: list[SelectItem] = [];
    table = _cmd_table();
    for value in _CMD_ORDER_CACHE {
        d = table[value];
        if not d.slash_ac {
            continue;
        }
        label = d.slash_labels[0];
        if d.kind == CmdKind.OVERLAY and d.palette_label {
            label = d.palette_label;
        }
        items.append(SelectItem(value=label, label=label, description=d.description));
    }
    return items;
}

def model_items(state: TuiState) -> list[SelectItem] {
    return [
        SelectItem(
            value=name,
            label=name,
            description=("current" if name == state.model_name else "")
        ) for name in state.model_presets
    ];
}

def file_items(state: TuiState) -> list[SelectItem] {
    return [SelectItem(value=path, label=path, description="") for path in state.files];
}
