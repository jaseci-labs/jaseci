"""Tests for [apps] workspaces: parsing, membership, ownership, overlays, plans."""

import os;
import tomllib;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.project.apps { AppConfig, implicit_app, parse_apps }
import from jaclang.project.config { JacConfig }
import from jaclang.project.kinds {
    KIND_SPECS,
    normalize_client_target,
    plan_app_run,
    plan_workspace,
    resolve_app_kind
}
import from jaclang.project.client_kind {
    resolve_client_kind,
    resolve_client_kind_context
}
import jaclang.project.client_kind_paths as pure_mod;
import jaclang.project.config as config_mod;

glob WORKSPACE_TOML = (
         '[project]\nname = "acme"\ndefault-app = "web"\n\n'
         '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
         '[apps.mobile]\nkind = "mobile"\npath = "mobile"\nclient = "rn"\n'
         'client_kind = "mobui"\nplatform = "ios"\n\n'
         '[apps.social_graph]\nkind = "service"\n'
         'entry-point = "core/social_graph.jac"\nroute = "/api/social"\n\n'
         '[apps.web.serve]\nport = 8100\n\n'
         '[apps.social_graph.scale]\nhttp_activation = true\n\n'
         '[apps.mobile.dependencies.npm]\nlucide-react-native = "^0.4"\n\n'
         '[serve]\nport = 8090\n\n'
         '[dependencies.npm]\nreact = "^19"\n'
     ),
     MAIN_JAC = 'with entry {\n    print("hi");\n}\n';

"""Write a three-app workspace (web, mobile, file-rooted social_graph) under root."""
def write_workspace(root: Path, toml: str = WORKSPACE_TOML) -> Path {
    root.mkdir(parents=True, exist_ok=True);
    (root / "jac.toml").write_text(toml);
    (root / "web" / "pages").mkdir(parents=True, exist_ok=True);
    (root / "web" / "main.jac").write_text(MAIN_JAC);
    (root / "web" / "pages" / "home.jac").write_text(MAIN_JAC);
    (root / "mobile").mkdir(exist_ok=True);
    (root / "mobile" / "main.jac").write_text(MAIN_JAC);
    (root / "core").mkdir(exist_ok=True);
    (root / "core" / "social_graph.jac").write_text("walker:pub Hello {}\n");
    (root / "core" / "shared.jac").write_text("def helper -> int {\n    return 1;\n}\n");
    return root;
}

# ===========================================================================
# Parsing
# ===========================================================================
test "parse a three-app workspace" {
    cfg = JacConfig.from_toml_str(WORKSPACE_TOML);
    assert cfg.is_workspace;
    assert list(cfg.apps.keys()) == ["web", "mobile", "social_graph"];
    assert cfg.default_app == "web";
    assert cfg.project.default_app == "web";
    web = cfg.apps["web"];
    assert web.kind == "web-app";
    assert web.path == "web";
    assert not web.implicit;
    assert not web.is_file_rooted();
    assert web.effective_client() == "web";
    assert web.overlays == {"serve": {"port": 8100}};
    mobile = cfg.apps["mobile"];
    assert mobile.client == "react-native" , "client aliases are normalized";
    assert mobile.client_kind == "mobui";
    assert mobile.platform == "ios";
    assert mobile.overlays["dependencies"]["npm"]["lucide-react-native"] == "^0.4";
    sg = cfg.apps["social_graph"];
    assert sg.is_file_rooted();
    assert sg.entry_point == "core/social_graph.jac";
    assert sg.route == "/api/social";
    assert sg.overlays == {"scale": {"http_activation": True}};
    assert cfg.serve.port == 8090 , "app overlays never leak into the base config";
    assert "scale" not in cfg.plugins;
}

test "no [apps] means one implicit app" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "hello"\nkind = "cli"\nentry-point = "app.jac"\n'
    );
    assert not cfg.is_workspace;
    assert list(cfg.apps.keys()) == ["hello"];
    app = cfg.apps["hello"];
    assert app.implicit;
    assert app.kind == "cli";
    assert app.entry_point == "app.jac";
    assert app.path == "";
    assert not app.is_file_rooted();
    assert app.client_kind == "web";
    assert cfg.resolve_app("") is app;
    assert cfg.default_app == "";
    bare = JacConfig.from_toml_str("[serve]\nport = 1\n");
    assert list(bare.apps.keys()) == ["main"];
    assert implicit_app(bare).name == "main";
}

test "[apps] next to [project] kind, entry-point or client_kind is a hard error" {
    for key in ['kind = "cli"', 'entry-point = "main.jac"', 'client_kind = "mobui"'] {
        raised = False;
        try {
            JacConfig.from_toml_str(
                '[project]\nname = "x"\n' + key + '\n\n[apps.web]\nkind = "web-app"\n'
            );
        } except ValueError as e {
            raised = True;
            assert "[apps]" in str(e) , str(e);
        }
        assert raised , f"expected ValueError for [project] {key} alongside [apps]";
    }
}

test "default-app must name an app and needs [apps]" {
    raised = False;
    try {
        JacConfig.from_toml_str(
            '[project]\nname = "x"\ndefault-app = "zzz"\n\n[apps.web]\nkind = "web-app"\n'
        );
    } except ValueError as e {
        raised = True;
        assert "default-app" in str(e) , str(e);
    }
    assert raised , "expected ValueError for an unknown default-app";
    raised = False;
    try {
        JacConfig.from_toml_str('[project]\nname = "x"\ndefault-app = "x"\n');
    } except ValueError as e {
        raised = True;
        assert "[apps]" in str(e) , str(e);
    }
    assert raised , "expected ValueError for default-app without [apps]";
}

test "app validation rejects bad kinds, clients, client kinds, names and keys" {
    cases = [
        ('[apps.web]\nkind = "nope"\n', "kind="),
        ('[apps.web]\nkind = "web-app"\nclient = "flutter"\n', "client target"),
        ('[apps.web]\nkind = "web-app"\nclient_kind = "tv"\n', "client_kind"),
        ('[apps."a/b"]\nkind = "cli"\n', "cannot contain"),
        ('[apps."main.jac"]\nkind = "cli"\n', ".jac"),
        ('[apps.web]\npath = "web"\n', "required key 'kind'"),
        ('[apps.web]\nkind = "web-app"\ncolour = "red"\n', "unknown key"),
        ('[apps.web]\nkind = "web-app"\nroute = "api"\n', "must start with"),
        ('[apps.web]\nkind = "web-app"\npath = "/abs/web"\n', "relative")
    ];
    for (body, needle) in cases {
        raised = False;
        try {
            parse_apps({}, tomllib.loads(body)["apps"]);
        } except ValueError as e {
            raised = True;
            assert needle in str(e) , f"{body!r}: {e}";
        }
        assert raised , f"expected ValueError for {body!r}";
    }
}

test "dashed and underscored app keys are both accepted" {
    apps = parse_apps(
        {},
        tomllib.loads(
            '[apps.a]\nkind = "service"\nentry_point = "a.jac"\nclient-kind = "web"\n'
        )["apps"]
    );
    assert apps["a"].entry_point == "a.jac";
    assert apps["a"].client_kind == "web";
}

# ===========================================================================
# Routes
# ===========================================================================
test "route defaults to /api/<name> and collisions are hard errors" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n'
        '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
        '[apps.api]\nkind = "service"\nentry-point = "api.jac"\n'
    );
    assert cfg.apps["web"].effective_route() == "/api/web";
    assert cfg.apps["api"].effective_route() == "/api/api";
    raised = False;
    try {
        JacConfig.from_toml_str(
            '[project]\nname = "acme"\n\n'
            '[apps.web]\nkind = "web-app"\npath = "web"\nroute = "/api/x"\n\n'
            '[apps.api]\nkind = "service"\nentry-point = "api.jac"\nroute = "/api/x"\n'
        );
    } except ValueError as e {
        raised = True;
        assert "/api/x" in str(e) , str(e);
        assert "web" in str(e) and "api" in str(e) , str(e);
    }
    assert raised , "expected ValueError for a route collision";
    no_server = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n'
        '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
        '[apps.tool]\nkind = "cli"\npath = "tool"\nroute = "/api/web"\n'
    );
    assert list(no_server.apps.keys()) == ["web", "tool"] , (
        "apps without a server never claim routes"
    );
}

# ===========================================================================
# Membership
# ===========================================================================
test "membership: dir-rooted, file-rooted and shared" {
    with TemporaryDirectory() as td {
        root = write_workspace(Path(td) / "acme");
        cfg = JacConfig.load(root / "jac.toml");
        assert cfg.app_for_path(str(root / "web" / "pages" / "home.jac")).name == "web";
        assert cfg.app_for_path(str(root / "mobile" / "main.jac")).name == "mobile";
        sg_owner = cfg.app_for_path(str(root / "core" / "social_graph.jac"));
        assert sg_owner is not None and sg_owner.name == "social_graph";
        assert cfg.app_for_path(str(root / "core" / "shared.jac")) is None;
        assert cfg.app_for_path(str(root / "jac.toml")) is None;
        assert cfg.app_for_path(str(Path(td) / "elsewhere.jac")) is None;
        sg = cfg.apps["social_graph"];
        assert sg.root_dir(str(root)) == "";
        assert sg.entry_path(str(root)) == str(root / "core" / "social_graph.jac");
        assert sg.contains(str(root), str(root / "core" / "social_graph.jac"));
        assert not sg.contains(str(root), str(root / "core" / "shared.jac"));
        web = cfg.apps["web"];
        assert web.root_dir(str(root)) == str(root / "web");
        assert web.entry_path(str(root)) == str(root / "web" / "main.jac");
    }
}

test "membership: nearest root wins" {
    with TemporaryDirectory() as td {
        root = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n'
            '[apps.site]\nkind = "web-app"\npath = "web"\n\n'
            '[apps.admin]\nkind = "web-app"\npath = "web/admin"\n'
        );
        (root / "web" / "admin").mkdir();
        (root / "web" / "admin" / "main.jac").write_text(MAIN_JAC);
        cfg = JacConfig.load(root / "jac.toml");
        assert cfg.app_for_path(str(root / "web" / "admin" / "main.jac")).name == "admin";
        assert cfg.app_for_path(str(root / "web" / "main.jac")).name == "site";
        assert cfg.app_for_path(str(root / "web" / "pages" / "home.jac")).name == "site";
    }
}

test "membership: the implicit app owns the whole project root" {
    with TemporaryDirectory() as td {
        root = Path(td) / "hello";
        (root / "lib").mkdir(parents=True);
        (root / "jac.toml").write_text('[project]\nname = "hello"\nkind = "cli"\n');
        (root / "lib" / "x.jac").write_text(MAIN_JAC);
        cfg = JacConfig.load(root / "jac.toml");
        owner = cfg.app_for_path(str(root / "lib" / "x.jac"));
        assert owner is not None and owner.implicit;
        assert owner.root_dir(str(root)) == str(root);
        assert cfg.app_for_path(str(Path(td) / "other.jac")) is None;
        bare = JacConfig(project_root=root);
        assert not bare.apps;
        bare_owner = bare.app_for_path(str(root / "lib" / "x.jac"));
        assert bare_owner is not None and bare_owner.implicit , (
            "a config built without an [apps] table still owns its root"
        );
        assert bare.app_for_path(str(Path(td) / "other.jac")) is None;
    }
}

# ===========================================================================
# Ownership (decision 2)
# ===========================================================================
test "owner: explicit file-rooted service app, member app, ambiguity" {
    with TemporaryDirectory() as td {
        root = write_workspace(Path(td) / "acme");
        cfg = JacConfig.load(root / "jac.toml");
        assert [a.name for a in cfg.serving_apps()] == ["web", "social_graph"];
        (owner, ambiguous) = cfg.owner_app_for_path(
            str(root / "core" / "social_graph.jac")
        );
        assert owner is not None and owner.name == "social_graph";
        assert not ambiguous;
        (owner, ambiguous) = cfg.owner_app_for_path(str(root / "core" / "shared.jac"));
        assert owner is None , "two serving apps and no explicit owner";
        assert ambiguous;
        (owner, ambiguous) = cfg.owner_app_for_path(str(root / "mobile" / "main.jac"));
        assert owner is not None and owner.name == "mobile";
        assert not ambiguous;
    }
}

test "owner: the sole serving app owns shared modules implicitly" {
    with TemporaryDirectory() as td {
        root = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n'
            '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
            '[apps.mobile]\nkind = "mobile"\npath = "mobile"\n'
        );
        cfg = JacConfig.load(root / "jac.toml");
        (owner, ambiguous) = cfg.owner_app_for_path(str(root / "core" / "shared.jac"));
        assert owner is not None and owner.name == "web";
        assert not ambiguous;
    }
}

test "owner: no serving apps means no owner and no ambiguity" {
    with TemporaryDirectory() as td {
        root = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n'
            '[apps.tool]\nkind = "cli"\npath = "web"\n\n'
            '[apps.mobile]\nkind = "mobile"\npath = "mobile"\n'
        );
        cfg = JacConfig.load(root / "jac.toml");
        assert cfg.serving_apps() == [];
        (owner, ambiguous) = cfg.owner_app_for_path(str(root / "core" / "shared.jac"));
        assert owner is None;
        assert not ambiguous;
    }
}

# ===========================================================================
# resolve_app
# ===========================================================================
test "resolve_app: explicit, default, sole, ambiguous" {
    cfg = JacConfig.from_toml_str(WORKSPACE_TOML);
    assert cfg.resolve_app("mobile").name == "mobile";
    assert cfg.resolve_app("").name == "web" , "default-app wins";
    raised = False;
    try {
        cfg.resolve_app("nope");
    } except ValueError as e {
        raised = True;
        assert "nope" in str(e) and "web" in str(e) , str(e);
    }
    assert raised , "expected ValueError for an unknown app";
    two = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n'
        '[apps.a]\nkind = "cli"\npath = "a"\n\n[apps.b]\nkind = "cli"\npath = "b"\n'
    );
    raised = False;
    try {
        two.resolve_app("");
    } except ValueError as e {
        raised = True;
        assert "default-app" in str(e) , str(e);
    }
    assert raised , "expected ValueError when no default app in a multi-app workspace";
    one = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n[apps.a]\nkind = "cli"\npath = "a"\n'
    );
    assert one.resolve_app("").name == "a" , "a sole app is the default";
    assert JacConfig().resolve_app("").implicit , "a bare config still resolves";
}

# ===========================================================================
# effective_for_app
# ===========================================================================
test "effective_for_app layers base, app overlays, profile and local" {
    config_mod._config = None;
    with TemporaryDirectory() as td {
        root = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n'
            '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
            '[apps.mobile]\nkind = "mobile"\npath = "mobile"\n\n'
            '[apps.web.serve]\nport = 8100\nsession = "web-sess"\n'
            'conflict_max_attempts = 3\n\n'
            '[apps.web.byllm]\nmodel = "web-model"\n\n'
            '[apps.mobile.dependencies.npm]\nlucide-react-native = "^0.4"\n\n'
            '[serve]\nport = 8090\nsession = "base-sess"\n\n'
            '[dependencies.npm]\nreact = "^19"\n\n'
            '[byllm]\nmodel = "base-model"\ntemperature = 0.1\n\n'
            '[environments.prod]\n[environments.prod.serve]\nsession = "prod-sess"\n'
        );
        (root / "jac.prod.toml").write_text(
            '[serve]\nconflict_max_attempts = 9\n'
        );
        (root / "jac.local.toml").write_text('[serve]\nconflict_backoff_ms = 7\n');
        cfg = JacConfig.discover(root, profile="prod");
        assert cfg is not None;
        assert cfg.active_profile == "prod";
        assert cfg.serve.port == 8090;
        assert cfg.serve.session == "prod-sess";
        web = cfg.effective_for_app("web");
        assert web.serve.port == 8100 , "app overlay beats base";
        assert web.serve.session == "prod-sess" , "[environments.prod] beats the overlay";
        assert web.serve.conflict_max_attempts == 9 , "jac.prod.toml beats the overlay";
        assert web.serve.conflict_backoff_ms == 7 , "jac.local.toml still applies";
        assert web.plugins["byllm"] == {"model": "web-model", "temperature": 0.1} , (
            "capability tables deep-merge"
        );
        assert web.active_profile == "prod";
        assert web.is_workspace;
        assert list(web.apps.keys()) == ["web", "mobile"];
        assert web.project_root == cfg.project_root;
        assert [p.name for p in web.config_files] == [
            "jac.toml",
            "jac.prod.toml",
            "jac.local.toml"
        ];
        assert cfg.serve.port == 8090 , "the source config is untouched";
        mobile = cfg.effective_for_app("mobile");
        assert mobile.serve.port == 8090;
        assert mobile.plugin_dependencies["npm"]["lucide-react-native"] == "^0.4";
        assert mobile.plugin_dependencies["npm"]["react"] == "^19";
        assert "lucide-react-native" not in cfg.plugin_dependencies["npm"];
        again = web.effective_for_app("web");
        assert again.serve.port == 8100 and again.serve.conflict_backoff_ms == 7 , (
            "effective_for_app is idempotent"
        );
        raised = False;
        try {
            cfg.effective_for_app("nope");
        } except ValueError {
            raised = True;
        }
        assert raised , "expected ValueError for an unknown app";
    }
}

test "effective_for_app replays a directly applied profile" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n[apps.web]\nkind = "web-app"\npath = "web"\n\n'
        '[apps.web.serve]\nport = 8100\n\n[serve]\nport = 8090\n\n'
        '[environments.dev]\n[environments.dev.serve]\nsession = "dev"\n'
    );
    cfg.apply_profile("dev");
    web = cfg.effective_for_app("web");
    assert web.serve.port == 8100;
    assert web.serve.session == "dev";
}

test "effective_for_app of the implicit app is a plain clone" {
    cfg = JacConfig.from_toml_str('[project]\nname = "hello"\n\n[serve]\nport = 8090\n');
    clone = cfg.effective_for_app("hello");
    assert clone is not cfg;
    assert clone.serve.port == 8090;
    assert clone.resolve_app("").implicit;
}

# ===========================================================================
# Kinds and plans
# ===========================================================================
test "client targets normalize and kind specs carry client_target and has_server" {
    assert normalize_client_target("") == "web";
    assert normalize_client_target("rn") == "react-native";
    assert normalize_client_target("React_Native") == "react-native";
    assert normalize_client_target("static") == "static";
    raised = False;
    try {
        normalize_client_target("flutter");
    } except ValueError {
        raised = True;
    }
    assert raised , "expected ValueError for an unknown client target";
    assert KIND_SPECS["web-app"].client_target == "web";
    assert KIND_SPECS["web-app"].has_server;
    assert KIND_SPECS["service"].client_target == "";
    assert KIND_SPECS["service"].has_server;
    assert KIND_SPECS["service-mesh"].has_server;
    assert KIND_SPECS["web-static"].client_target == "static";
    assert not KIND_SPECS["web-static"].has_server;
    assert KIND_SPECS["mobile"].client_target == "mobile";
    assert KIND_SPECS["desktop"].client_target == "desktop";
    assert KIND_SPECS["js-package"].client_target == "web";
    assert KIND_SPECS["js-package"].codespace == "client";
    for kind in ["cli", "cli-native", "native-binary", "native-lib", "py-package"] {
        assert KIND_SPECS[kind].client_target == "";
        assert not KIND_SPECS[kind].has_server;
    }
}

test "resolve_app_kind infers only for the implicit app" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "x"\n\n[dependencies]\njac-client = "*"\n'
    );
    app = cfg.resolve_app("");
    assert app.implicit and app.kind == "";
    assert resolve_app_kind(cfg, app, "") == "web-app";
    assert cfg.resolved_kind(app) == "web-app";
    plain = JacConfig.from_toml_str('[project]\nname = "x"\n');
    assert resolve_app_kind(plain, plain.resolve_app(""), "") == "cli";
    explicit = AppConfig(name="svc", kind="service", entry_point="svc.jac");
    assert resolve_app_kind(cfg, explicit, "") == "service";
    assert explicit.effective_client() == "";
}

test "plan_workspace produces one plan per app" {
    with TemporaryDirectory() as td {
        root = write_workspace(Path(td) / "acme");
        cfg = JacConfig.load(root / "jac.toml");
        plans = plan_workspace(cfg, str(root));
        assert [p.app for p in plans] == ["web", "mobile", "social_graph"];
        by_app = {p.app: p for p in plans};
        web = by_app["web"];
        assert web.kind == "web-app";
        assert web.action == "serve";
        assert web.entry_path == str(root / "web" / "main.jac");
        assert web.flags["port"] == 8100 , "the app's serve overlay feeds the plan";
        assert web.flags["dev"] is True;
        assert web.command_line().startswith("jac run web");
        mobile = by_app["mobile"];
        assert mobile.action == "build";
        assert mobile.flags["client"] == "react-native";
        assert mobile.flags["platform"] == "ios";
        assert mobile.entry_path == str(root / "mobile" / "main.jac");
        sg = by_app["social_graph"];
        assert sg.kind == "service";
        assert sg.entry_path == str(root / "core" / "social_graph.jac");
        assert sg.flags["port"] == 8090 , "no overlay: the base [serve] port applies";
        assert sg.flags["no_client"] is True;
        assert sg.command_line().startswith("jac run social_graph");
    }
}

test "plan_app_run for the implicit app keeps the single-app command line" {
    with TemporaryDirectory() as td {
        root = Path(td) / "hello";
        root.mkdir();
        (root / "jac.toml").write_text('[project]\nname = "hello"\nkind = "cli"\n');
        (root / "main.jac").write_text(MAIN_JAC);
        cfg = JacConfig.load(root / "jac.toml");
        plan = plan_app_run(cfg, str(root), cfg.resolve_app(""));
        assert plan.app == "";
        assert plan.kind == "cli";
        assert plan.command_line() == "jac run main.jac";
        assert plan.entry_path == str(root / "main.jac");
        assert plan_workspace(cfg, str(root))[0].entry_path == plan.entry_path;
    }
}

test "plan_app_run honors an entry override and names named-app outputs" {
    with TemporaryDirectory() as td {
        root = write_workspace(
            Path(td) / "acme",
            '[project]\nname = "acme"\n\n[apps.bin]\nkind = "native-binary"\npath = "web"\n'
        );
        cfg = JacConfig.load(root / "jac.toml");
        plan = plan_app_run(cfg, str(root), cfg.apps["bin"]);
        assert plan.flags["output"] == str(root / "dist" / "bin" / "main");
        override = plan_app_run(
            cfg, str(root), cfg.apps["bin"], entry_override=str(root / "web" / "pages" / "home.jac")
        );
        assert override.entry_path == str(root / "web" / "pages" / "home.jac");
        assert override.flags["output"] == str(root / "dist" / "bin" / "home");
    }
}

test "plan_app_run raises when a needs-entry app has no entry file" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "acme"\n\n[apps.web]\nkind = "web-app"\npath = "web"\n'
    );
    with TemporaryDirectory() as td {
        raised = False;
        try {
            plan_app_run(cfg, td, cfg.apps["web"]);
        } except ValueError as e {
            raised = True;
            assert "web" in str(e) , str(e);
        }
        assert raised , "expected ValueError for a missing entry file";
    }
}

# ===========================================================================
# Client kind lane
# ===========================================================================
test "client kind answers from the owning app" {
    config_mod.set_config(None);
    with TemporaryDirectory() as td {
        root = write_workspace(Path(td) / "acme");
        try {
            assert resolve_client_kind(str(root / "mobile" / "main.jac")) == "mobui";
            assert resolve_client_kind(str(root / "web" / "main.jac")) == "web";
            assert resolve_client_kind(str(root / "core" / "shared.jac")) == "web";
            (kind, enforce_root) = resolve_client_kind_context(
                str(root / "mobile" / "main.jac")
            );
            assert kind == "mobui";
            assert enforce_root is not None;
            assert Path(enforce_root).resolve() == (root / "mobile").resolve();
            (kind, _) = resolve_client_kind_context(
                str(root / "web" / "main.jac"), explicit_kind="mobui"
            );
            assert kind == "mobui" , "an explicit kind still wins";
        } finally {
            config_mod.set_config(None);
        }
    }
}

test "the pure client-kind lane names no project config" {
    src = Path(pure_mod.__file__).read_text();
    assert "jaclang.project.config" not in src , (
        "client_kind_paths grew a project-config dependency; that puts the "
        "config lane back into every pass closure that imports it. Resolution "
        "belongs in client_kind."
    );
}
