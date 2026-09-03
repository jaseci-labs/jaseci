import from jaclang.comptime { name as ct_name }
import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.project.config { JacConfig }
import type from jaclang.project.apps { AppConfig }
import from jaclang.client.mobile_setup_env {
    mobile_setup_platform_env_restore,
    mobile_setup_platform_env_swap
}
import os;

import from jaclang.client.targets.registry { ClientTarget, app_client_target }
import from pathlib { Path }

comptime SPEC_SETUP: CommandSpec = CommandSpec(
         name="setup",
         help="Set up an app's client target (one-time initialization)",
         args=[
             Arg.create(
                 "target",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help=(
                     "App name from [apps], or a client target name (mobile, pwa, "
                     "desktop, ...); omit to set up the default app's client target"
                 )
             ),
             Arg.create(
                 "platform",
                 typ=str,
                 `default=None,
                 help="Platform for mobile setup (android, ios, all)",
                 choices=["android", "ios", "all"],
                 short="p"
             ),

         ],
         examples=[
             ("jac setup", "Set up the default app's client target"),
             (
                 "jac setup mobile",
                 "Set up the app named 'mobile', or the mobile target of the default app"
             ),
             ("jac setup mobile --platform ios", "Set up the iOS scaffold only"),
             ("jac setup mobile --platform all", "Set up both Android and iOS (macOS)")
         ],
         group="project",
         handler_name=ct_name(setup)
     );

def setup(target: str = "", platform: str | None = None) -> int {
    import from jaclang.cli.console { console }
    import from jaclang.client.targets.registry { get_target_factory }
    import from jaclang.project.config { get_config }
    import from jaclang.project.kinds { normalize_client_target }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        return 1;
    }
    available_targets = get_target_factory().get_available_target_names();

    app = config.app(target) if target else None;
    if app is not None {
        target_name = app_client_target(app);
    } else {
        try {
            app = config.resolve_app("");
        } except ValueError as e {
            if not target {
                console.error(str(e));
                return 1;
            }
            app = None;
        }
        if target {
            try {
                target_name = normalize_client_target(target);
            } except ValueError {
                console.error(f"Unknown setup target: '{target}'");
                console.print(
                    f"Apps: {', '.join(config.apps.keys())}; "
                    f"targets: {', '.join(available_targets)}",
                    style="muted"
                );
                return 1;
            }
        } elif app is not None {
            target_name = app_client_target(app);
        } else {
            console.error("No app to set up: name an app or a client target.");
            return 1;
        }
    }
    if target_name not in available_targets {
        console.error(f"Unknown setup target: '{target_name}'");
        console.print(
            f"Available targets: {', '.join(available_targets)}", style="muted"
        );
        return 1;
    }
    return run_client_setup(app, target_name, platform);
}

def run_client_setup(
    app: AppConfig | None, target_name: str, platform: str | None
) -> int {
    import from jaclang.cli.console { console }
    import from jaclang.client.targets.registry { get_target_factory }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        return 1;
    }
    project_dir = config.project_root or Path.cwd();
    factory = get_target_factory();
    try {
        target_obj = factory.create(target_name, project_dir);
    } except ValueError as e {
        console.error(str(e));
        console.print(
            f"Available targets: {', '.join(factory.get_available_target_names())}",
            style="muted"
        );
        return 1;
    }

    label = f"'{target_name}'";
    if app is not None and not app.implicit {
        label = f"'{target_name}' for app '{app.name}'";
        import from jaclang.runtime.runtime { JacRuntime as Jac }
        Jac.set_full_target_path(app.entry_path(str(project_dir)));
    }
    setup_platform = platform or (app.platform if app is not None else "") or None;
    prev_setup_platform_env = None;
    if target_name == "mobile" and setup_platform {
        prev_setup_platform_env = mobile_setup_platform_env_swap(str(setup_platform));
    }
    try {
        console.print(f"Setting up target {label} in: {project_dir}", style="muted");
        target_obj.setup(project_dir);

        if target_name == "pwa" {
            pwa_icons_dir = project_dir / "pwa_icons";
            if not pwa_icons_dir.exists() {
                console.error(
                    f"Setup completed but pwa_icons directory not found at: {pwa_icons_dir}"
                );
                console.print(
                    "This may indicate the setup function failed silently.",
                    style="muted"
                );
                return 1;
            }
        }

        console.success(f"Target {label} setup complete!");
        return 0;
    } except NotImplementedError as e {
        console.error(f"Target '{target_name}' setup is not yet implemented.");
        return 1;
    } except Exception as e {
        import traceback;
        console.error(f"Setup failed: {e}");
        console.print(traceback.format_exc(), style="muted");
        return 1;
    } finally {
        if target_name == "mobile" and setup_platform {
            mobile_setup_platform_env_restore(prev_setup_platform_env);
        }
    }
}

def _place_bundle(bundle_path: Path, out_dir: Path) -> Path {
    import shutil;
    out_dir.mkdir(parents=True, exist_ok=True);
    if bundle_path.is_dir() {
        shutil.copytree(bundle_path, out_dir, dirs_exist_ok=True);
        return out_dir;
    }
    dest = out_dir / bundle_path.name;
    shutil.copy2(bundle_path, dest);
    return dest;
}

def run_client_build(
    app: AppConfig,
    client: str,
    platform: str | None,
    entry_override: str = "",
    output: str = ""
) -> int {
    import from jaclang.cli.console { console }
    import from jaclang.client.targets.registry { get_target_factory }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        return 1;
    }

    project_dir = config.project_root or Path.cwd();
    try {
        target_name = app_client_target(app, client);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }

    factory = get_target_factory();
    try {
        target = factory.create(target_name, project_dir);
    } except ValueError as e {
        console.error(str(e));
        console.print(
            f"Available targets: {', '.join(factory.get_available_target_names())}",
            style="muted"
        );
        return 1;
    }

    if _target_setup_missing(target_name, target, project_dir) {
        console.warning(
            f"Target '{target_name}' requires setup. Run 'jac setup {target_name}' first."
        );
    }

    try {
        entry_path = (
            Path(entry_override)
                if entry_override
                else Path(app.entry_path(str(project_dir)))
        );
        if not entry_path.is_absolute() {
            entry_path = project_dir / entry_path;
        }
        if not entry_path.is_file() {
            console.error(
                f"No entry file for app '{app.name}' (expected {entry_path}).",
                hint="Set [apps.<name>] entry-point, or name a file: jac build <file>"
            );
            return 1;
        }

        import from jaclang.runtime.runtime { JacRuntime as Jac }
        Jac.set_full_target_path(str(entry_path));
        bundle_path = target.build(
            entry_path, project_dir, platform or app.platform or None
        );
        if output {
            bundle_path = _place_bundle(Path(bundle_path), Path(output));
        }

        console.success(f"Build complete: {bundle_path}");
        return 0;
    } except NotImplementedError as e {
        console.error(f"Target '{target_name}' is not yet implemented.");
        return 1;
    } except Exception as e {
        import traceback;
        console.error(f"Build failed: {e}\n{traceback.format_exc()}");
        return 1;
    }
}

def run_client_start(
    app: AppConfig,
    client: str,
    host: str,
    platform: str,
    port: int,
    api_port: int,
    dev: bool,
    no_client: bool
) -> int | None {
    import from jaclang.cli.console { console }
    import from jaclang.client.targets.registry { get_target_factory }
    import from jaclang.client.client_diagnostics { is_debug_mode }

    config = get_config();
    if not config {
        return None;
    }

    project_dir = config.project_root or Path.cwd();
    try {
        target_name = app_client_target(app, client);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }

    if target_name == "web" {
        return None;
    }

    entry_path = Path(app.entry_path(str(project_dir)));
    if not entry_path.is_file() {
        console.error(
            f"No entry file for app '{app.name}' (expected {entry_path}).",
            hint="Set [apps.<name>] entry-point in jac.toml."
        );
        return 1;
    }

    import from jaclang.runtime.runtime { JacRuntime as Jac }
    Jac.set_full_target_path(str(entry_path));

    if not dev and is_debug_mode(config) {
        console.warning(
            "Debug mode is enabled. For production, consider setting debug=false in [client] section of jac.toml"
        );
    }

    factory = get_target_factory();
    try {
        target = factory.create(target_name, project_dir);
    } except ValueError as e {
        console.error(str(e));
        console.print(
            f"Available targets: {', '.join(factory.get_available_target_names())}",
            style="muted"
        );
        return 1;
    }

    start_port = port or 8000;
    start_api = api_port or 0;
    app_platform = platform or app.platform or "auto";

    if _target_setup_missing(target_name, target, project_dir) {
        console.error(
            f"Target '{target_name}' not set up. Run 'jac setup {target_name}' first."
        );
        return 1;
    }
    try {
        if target_name == "mobile" {
            os.environ["JAC_MOBILE_PLATFORM"] = str(app_platform);
        }
        if dev {
            if target_name == "mobile" {
                os.environ["JAC_MOBILE_DEV_HOST"] = str(host);
            }

            target.dev(entry_path, project_dir, port=start_port, api_port=start_api);
        } else {
            target.start(entry_path, project_dir, api_port=start_port);
        }
        return 0;
    } except Exception as e {
        import traceback;
        console.error(f"Target '{target_name}' failed: {e}");
        console.print(traceback.format_exc(), style="muted");
        return 1;
    }
}

def get_config -> JacConfig | None {
    import from jaclang.project.config { get_config as _get_config }
    return _get_config();
}

def _npm_context -> tuple | None {
    import from jaclang.project.providers { get_provider_registry }
    import from jaclang.cli.console { console }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project."
        );
        return None;
    }

    provider = get_provider_registry().get_by_flag("--npm");
    if provider is None {
        console.error(
            "--npm dependency support is unavailable",
            hint="The client framework ships with jaclang; reinstall jaclang if this persists."
        );
        return None;
    }
    return (config, provider);
}

def run_npm_add(packages: list, dev: bool, install_global: bool = False) -> int {
    import from jaclang.project.providers { InstallContext }
    import from jaclang.cli.console { console }

    if install_global {
        return run_npm_add_global(packages, dev);
    }

    npm_ctx = _npm_context();
    if npm_ctx is None {
        return 1;
    }
    (config, provider) = npm_ctx;
    install_ctx = InstallContext();

    try {
        if not packages {
            console.print(
                f"\n📦 Installing all {provider.name} packages from jac.toml",
                style="bold"
            );
            with console.status(
                f"Installing {provider.name} packages...", spinner="dots"
            ) as status {
                provider.install_all(config, provider.resolve(config), install_ctx);
            }
            console.success(f"Installed all {provider.name} packages");
        } else {
            console.print(
                f"\n📦 Adding {len(packages)} {provider.name} package(s)", style="bold"
            );
            for pkg_spec in packages {
                (name, version) = provider.parse_spec(pkg_spec);
                with console.status(
                    f"Installing {name}...", spinner="dots"
                ) as status {
                    provider.add_package(config, name, version, dev, install_ctx);
                }
                console.print(f"  ✔ {name}", style="success");
            }
            section = f"dependencies.{provider.name}" + (".dev" if dev else "");
            console.print(f"\n  ✔ Updated jac.toml [{section}]", style="muted");
        }
        return 0;
    } except Exception as e {
        console.error(f"Failed to install packages: {e}");
        return 1;
    }
}

def run_npm_add_global(packages: list, dev: bool) -> int {
    import subprocess;
    import from jaclang.cli.console { console }
    import from jaclang.client.bun_installer { get_bun, bun_unavailable_message }
    import from jaclang.project.tool_paths { node_root }

    if not packages {
        console.error(
            "Provide at least one npm package to install globally.",
            hint="e.g. 'jac install --npm --global eslint'"
        );
        return 1;
    }
    bun = get_bun();
    if bun is None {
        console.error(bun_unavailable_message());
        return 1;
    }
    dest = node_root("global");
    assert dest is not None , "the global npm root is always resolvable";
    dest.mkdir(parents=True, exist_ok=True);
    pkg_json = dest / "package.json";
    if not pkg_json.exists() {
        pkg_json.write_text(
            '{\n  "name": "jac-global-tools",\n  "private": true\n}\n', encoding="utf-8"
        );
    }
    cmd: list = [bun, "add"];
    if dev {
        cmd.append("--dev");
    }
    cmd.extend(packages);
    console.print(
        f"\n📦 Installing {len(packages)} npm tool(s) globally into {dest}", style="bold"
    );
    result = subprocess.run(cmd, cwd=str(dest));
    if result.returncode != 0 {
        console.error("Global npm install failed.");
        return 1;
    }
    console.success(
        f"Installed {len(packages)} npm tool(s) globally — "
        "run with 'jac x --global <tool>'"
    );
    return 0;
}

def run_npm_remove(packages: list, dev: bool) -> int {
    import from jaclang.project.providers { InstallContext }
    import from jaclang.cli.console { console }

    npm_ctx = _npm_context();
    if npm_ctx is None {
        return 1;
    }
    (config, provider) = npm_ctx;
    if not packages {
        console.error("No packages specified.");
        return 1;
    }
    install_ctx = InstallContext();

    try {
        for name in packages {
            console.info(f"Removing {name} ({provider.name})...");
            if not provider.remove_package(config, name, dev, install_ctx) {
                deps_key = "dev-dependencies" if dev else "dependencies";
                raise RuntimeError(f'Package "{name}" not found in {deps_key}');
            }
        }
        console.success(f"Removed {len(packages)} package(s)");
        return 0;
    } except Exception as e {
        console.error(f"Error removing packages: {e}");
        return 1;
    }
}

def _target_setup_missing(
    target_name: str, target: ClientTarget, project_dir: Path
) -> bool {
    if not target.requires_setup {
        return False;
    }

    if target_name == "mobile" {
        android_dir = project_dir / "android";
        ios_dir = project_dir / "ios";
        return not android_dir.exists() and not ios_dir.exists();
    }

    return False;
}
