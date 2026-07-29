obj Component {
    has name: str = "",
        dirty: bool = True,
        alive: bool = True;

    def render(width: int) -> str {
        return "[" + self.name + "]";
    }

    def handle_input(key: str) -> str {
        return "base:" + key;
    }

    def invalidate {
        self.dirty = True;
    }

    def destroy {
        self.alive = False;
        self.dirty = False;
    }
}

obj Label(Component) {
    has text: str = "";

    override def render(width: int) -> str {
        self.dirty = False;
        body = self.text;
        if width > 0 and len(body) > width {
            body = body[:width];
        }
        return "L:" + body;
    }

    override def handle_input(key: str) -> str {
        if key == "x" {
            self.text = self.text + "!";
            self.invalidate();
            return "label-mut";
        }
        return "label:" + key;
    }
}

obj Button(Component) {
    has clicks: int = 0;

    override def render(width: int) -> str {
        self.dirty = False;
        return "B:" + self.name + ":" + str(self.clicks);
    }

    override def handle_input(key: str) -> str {
        if key == "enter" {
            self.clicks += 1;
            self.invalidate();
            return "click";
        }
        return "button:" + key;
    }
}

def _check(label: str, ok: bool) {
    if ok {
        print("PASS " + label);
    } else {
        print("FAIL " + label);
    }
}

glob kids: list[Component] = [];
with entry {
    kids.append(Label(name="a", text="hello"));
    kids.append(Button(name="go"));
    kids.append(Label(name="b", text="world"));
}

glob r0 = kids[0].render(80),
     r1 = kids[1].render(80),
     r2 = kids[2].render(80);

with entry {
    _check("d2_render_label0", r0 == "L:hello");
    _check("d2_render_button", r1 == "B:go:0");
    _check("d2_render_label1", r2 == "L:world");

    _check("d2_input_click", kids[1].handle_input("enter") == "click");
    _check("d2_button_dirty_after_click", kids[1].dirty == True);
}

glob r1b = kids[1].render(80);
with entry {
    _check("d2_render_after_click", r1b == "B:go:1");
    _check("d2_button_clean_after_render", kids[1].dirty == False);

    _check("d2_input_label_mut", kids[0].handle_input("x") == "label-mut");
    _check("d2_label_mut_text", kids[0].render(80) == "L:hello!");
}

glob wide = Label(name="w", text="abcdefghij");
with entry {
    _check("d2_width_trunc", wide.render(4) == "L:abcd");
}

glob focus: int = 0;
with entry {
    _check("d2_focus0", kids[focus].handle_input("z") == "label:z");
}
glob focus = 1;
with entry {
    _check("d2_focus1", kids[focus].handle_input("z") == "button:z");

    kids[0].destroy();
    _check("d2_destroyed_flag", kids[0].alive == False);
}

glob kept: list[Component] = [];
with entry {
    kept.append(kids[1]);
    kept.append(kids[2]);
}

glob kids = kept;
with entry {
    _check("d2_len_after_remove", len(kids) == 2);
    _check("d2_render_after_remove", kids[0].render(80) == "B:go:1");
}

glob same = True,
     last = kids[1].render(10);

with entry {
    for _i in range(50) {
        cur = kids[1].render(10);
        if cur != last {
            same = False;
        }
    }
    _check("d2_repeat_render_stable", same);
}
