"""Tests for ComposeGenPass — native Compose surface (M0 gate)."""
import from jaclang.compiler.passes.compose.compose_gen_pass { run_compose_gen_pass }
import from jaclang.compiler.passes.compose.compose_emit { ComposeEmit }
import from jaclang.compiler.passes.compose.compose_native_emit { ComposeNativeEmitter }
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import tempfile;

test "ComposeGenPass lowers Column/Text to native view IR" {
    src = '''
def:pub app -> Composable {
    return <Column>
        <Text>"hi"</Text>
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "app.cl.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        assert "app" in model.components;
        comp = model.components["app"];
        assert comp.compose_view is not None;
        assert comp.compose_view.name == "Column";
        assert len(comp.compose_view.children) == 1;
        emitter = ComposeNativeEmitter();
        kt = emitter.emit_component_view(comp);
        assert "Column(" in kt;
        assert 'Text(text = "hi")' in kt or 'Text("hi")' in kt;
    }
}

test "ComposeEmit writes native Kotlin for Column/Text screen" {
    src = '''
def:pub app -> Composable {
    return <Column>
        <Text>"hello compose"</Text>
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "app.cl.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.package_name = "dev.jac.test";
        model.routes = [];
        screens = ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        assert "@Composable" in screens;
        assert "fun HomeScreen" in screens or "fun appScreen" in screens or "Column(" in screens;
        assert "hello compose" in screens;
        assert "className" not in screens;
        assert "tailwind" not in screens.lower();
    }
}

test "ComposeGenPass records kotlin_ast leaves in reactive intent" {
    src = '''
def:pub Counter() -> Composable {
    count = 0;
    return <Column>
        <Text>{count}</Text>
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "counter.cl.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.compiler.passes.ecmascript.intent.leaves { is_kt_leaf }
        import from jaclang.compiler.passes.compose.kotlin_ast { KtLiteral }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        assert "Counter" in model.components;
        comp = model.components["Counter"];
        assert comp.compose_view is not None;
        text_child = comp.compose_view.children[0];
        assert hasattr(text_child, "element");
        dynamic = text_child.element.children[0];
        assert is_kt_leaf(dynamic.value);
    }
}

test "ComposeGenPass records has fields as mutableStateOf prelude" {
    src = '''
def:pub Counter() -> Composable {
    has count: int = 0,
        name: str = "hi";

    return <Column>
        <Text>{count}</Text>
        <Text>{name}</Text>
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "counter.cl.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.compiler.passes.compose.reactive_compose { ReactiveComposeEmitter }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        comp = model.components["Counter"];
        assert len(comp.state) == 2;
        assert comp.state[0].name == "count";
        assert comp.state[1].name == "name";
        prelude = ReactiveComposeEmitter().emit_prelude(comp);
        assert "mutableStateOf(0)" in prelude;
        assert 'mutableStateOf("hi")' in prelude;
        assert prelude.count("mutableStateOf") == 2;
    }
}

test "jac_to_kotlin lowers walker spawn to JacClient call" {
    import from jaclang.compiler.passes.compose.jac_to_kotlin { jac_expr_to_kt }
    import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }

    src = '''
def test_spawn -> None {
    name = "ada";
    result = root spawn greet(name=name);
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "spawn.jac";
        path.write_text(
            'walker greet { has name: str; can run with Root entry { report "hi"; } }\n'
            + src,
            encoding="utf-8"
        );
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        mod = Jac.program.compile(str(path));
        for ability in mod.get_all_sub_nodes(uni.Ability) {
            if ability.name_ref and ability.name_ref.sym_name == "test_spawn" {
                body = ability.body;
                if isinstance(body, uni.ImplDef) {
                    for stmt in body.body {
                        if isinstance(stmt, uni.Assignment) and len(stmt.target) == 1 {
                            if stmt.target[0].sym_name == "result" {
                                kt_node = jac_expr_to_kt(stmt.value);
                                src_kt = kt_to_source(kt_node);
                                assert "JacClient.greet" in src_kt;
                                assert "GreetRequest" in src_kt;
                                assert "name = name" in src_kt.replace(" ", "");
                            }
                        }
                    }
                }
            }
        }
    }
}

test "Compose view onClick handler lowers spawn to JacClient in kotlin_ast" {
    src = '''
def:pub app -> Composable {
    has greeting: str = "";

    return <Button onClick={lambda -> None {
        result = root spawn greet(name="world");
        greeting = result.reports[0];
    }}>
        <Text>{greeting}</Text>
    </Button>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "app.cl.jac";
        path.write_text(
            'walker greet { has name: str; can run with Root entry { report "hi"; } }\n'
            + src,
            encoding="utf-8"
        );
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        comp = model.components["app"];
        btn = comp.compose_view;
        on_click: any = None;
        for attr in btn.attrs {
            if attr.name == "onClick" {
                on_click = attr.value;
            }
        }
        assert on_click is not None;
        handler_src = kt_to_source(on_click);
        assert "JacClient" in handler_src;
    }
}

test "ComposeEmit emits state assignment in onClick handlers" {
    src = '''
def:pub Counter() -> Composable {
    has count: int = 0,
        name: str = "";

    return <Column>
        <Text>{count}</Text>
        <Button onClick={lambda -> None { count = count + 1; }}>
            <Text>"Increment"</Text>
        </Button>
        <Button onClick={lambda -> None { count = 0; }}>
            <Text>"Reset"</Text>
        </Button>
        <OutlinedTextField
            value={name}
            onValueChange={lambda (v: str) { name = v; }}
            placeholder="Name"
        />
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "counter.cl.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.package_name = "dev.jac.test";
        screens = ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        assert "val count = count + 1" not in screens;
        assert "val count = 0" not in screens;
        assert "val name = v" not in screens;
        assert "count = count + 1" in screens;
        assert "count = 0" in screens;
        assert "name = v" in screens;
        assert "var count by remember { mutableStateOf(0) }" in screens;
        assert 'var name by remember { mutableStateOf("") }' in screens;
    }
}

test "ComposeEmit emits state assignment in RPC onClick handler" {
    src = '''
def:pub app -> Composable {
    has greeting: str = "";

    return <Button onClick={lambda -> None {
        result = root spawn greet(name="world");
        greeting = result.reports[0];
    }}>
        <Text>{greeting}</Text>
    </Button>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "app.cl.jac";
        path.write_text(
            'walker greet { has name: str; can run with Root entry { report "hi"; } }\n'
            + src,
            encoding="utf-8"
        );
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.package_name = "dev.jac.test";
        screens = ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        assert "rememberCoroutineScope()" in screens;
        assert "scope.launch" in screens;
        assert "JacClient.greet" in screens;
        assert "val greeting = result" not in screens;
        assert "greeting = result.reports[0]" in screens;
    }
}

test "ComposeEmit reassigns non-reactive locals instead of shadowing them" {
    src = '''
def:pub app -> Composable {
    has greeting: str = "";

    return <Button onClick={lambda -> None {
        next_greeting = "Empty response";
        try {
            result = root spawn greet(name="world");
            if result.reports.len > 0 {
                next_greeting = result.reports[0];
            }
        } except Exception {
            next_greeting = "Request failed";
        }
        greeting = next_greeting;
    }}>
        <Text>{greeting}</Text>
    </Button>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "app.cl.jac";
        path.write_text(
            'walker greet { has name: str; can run with Root entry { report "hi"; } }\n'
            + src,
            encoding="utf-8"
        );
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.package_name = "dev.jac.test";
        screens = ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        # The non-reactive local is declared exactly once (val if never
        # reassigned, var if it is) and then mutated via bare assignments —
        # never re-declared as a shadowing `val` in a nested scope.
        next_decls = screens.count("val next_greeting =") + screens.count("var next_greeting =");
        assert next_decls == 1;
        assert screens.count("var next_greeting =") == 1;
        assert "next_greeting = result.reports[0]" in screens;
        assert "val next_greeting = result.reports[0]" not in screens;
        assert 'next_greeting = "Request failed"' in screens;
        assert 'val next_greeting = "Request failed"' not in screens;
        # A local assigned exactly once stays `val`.
        assert "val result = JacClient" in screens;
        # The reactive state receives the bare assignment carrying the final value.
        assert "greeting = next_greeting" in screens;
        assert "val greeting = next_greeting" not in screens;
    }
}

test "jac_to_kotlin maps Jac == to Kotlin ==" {
    import from jaclang.compiler.passes.compose.jac_to_kotlin { jac_expr_to_kt }
    import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }

    src = '''
def test_eq -> int {
    return 1 == 2;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "eq.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        mod = Jac.program.compile(str(path));
        for ability in mod.get_all_sub_nodes(uni.Ability) {
            if ability.name_ref and ability.name_ref.sym_name == "test_eq" {
                ret = ability.body;
                if isinstance(ret, uni.ImplDef) {
                    for stmt in ret.body {
                        if isinstance(stmt, uni.ReturnStmt) and stmt.expr {
                            kt_node = jac_expr_to_kt(stmt.expr);
                            src_kt = kt_to_source(kt_node);
                            assert "==" in src_kt;
                            assert "===" not in src_kt;
                        }
                    }
                }
            }
        }
    }
}

test "jac_to_kotlin maps floor div" {
    import from jaclang.compiler.passes.compose.jac_to_kotlin { jac_expr_to_kt }
    import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }
    import jaclang.jac0core.unitree as uni;

    src = '''
def test_div -> int {
    return 7 // 2;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "div.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        mod = Jac.program.compile(str(path));
        for ability in mod.get_all_sub_nodes(uni.Ability) {
            if ability.name_ref and ability.name_ref.sym_name == "test_div" {
                body = ability.body;
                if isinstance(body, uni.ImplDef) {
                    for stmt in body.body {
                        if isinstance(stmt, uni.ReturnStmt) and stmt.expr {
                            kt_node = jac_expr_to_kt(stmt.expr);
                            src_kt = kt_to_source(kt_node).replace(" ", "");
                            assert "7/2" in src_kt or "7//2" in src_kt;
                        }
                    }
                }
            }
        }
    }
}

test "typed Compose surface: opt-in type_check catches modifier/style typos" {
    # P0 #3 — a project with [client.android] type_check = true gets the typed
    # Modifier/Typography surface. A clean native component type-checks; a typo'd
    # modifier name / non-existent Typography style is caught in Jac, not Kotlin.
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    def _err_count(src: str) -> int {
        with tempfile.TemporaryDirectory() as tmp {
            path = Path(tmp) / "app.cl.jac";
            path.write_text(src, encoding="utf-8");
            program = Jac.program;
            program.compile(str(path), options=CompileOptions(type_check=True));
            return len(program.errors_had);
        }
    }

    clean = '''
def:pub app -> Composable {
    has count: int = 0;
    return <Column modifier={Modifier.fillMaxSize().fillMaxWidth()}>
        <Text style={Typography.titleLarge}>"Hi"</Text>
        <Button onClick={lambda -> None { count = count + 1; }}>
            <Text>"Inc"</Text>
        </Button>
    </Column>;
}
''';
    typo = '''
def:pub app -> Composable {
    return <Column modifier={Modifier.filMaxSize()}>
        <Text style={Typography.titleHuge}>"Hi"</Text>
    </Column>;
}
''';
    assert _err_count(clean) == 0;
    assert _err_count(typo) >= 2;
}
