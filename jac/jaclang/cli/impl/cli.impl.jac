import os;
import sys;

impl start_cli -> None {
    import from jaclang.cli.console { console }
    import from jaclang.cli.manifest_route { handle_manifest_route }

    raw_argv = sys.argv[1:];

    dev_source = os.environ.get('JAC_DEV_SOURCE');
    if dev_source {
        notice = (
            f"🛠  jac dev mode — using compiler source at {dev_source}"
                if console.use_emoji
                else f"[dev] jac dev mode - using compiler source at {dev_source}"
        );
        console.print(notice, style='info', file=sys.stderr);
        try {
            import from jaclang.dist.dev_reseal { maybe_reseal }
            maybe_reseal(raw_argv);
        } except Exception as e {
            console.print(
                f"jac: dev reseal unavailable ({e})", style='warn', file=sys.stderr
            );
        }
    }

    handle_manifest_route(raw_argv);
}

impl jac_version -> str {
    import from jaclang.cli.manifest_route { resolve_cli_version }

    return resolve_cli_version();
}
