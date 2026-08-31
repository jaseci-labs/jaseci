import os;
import sys;

def _human_size(size_bytes: int) -> str {
    size = float(size_bytes);
    for unit in ["B", "KB", "MB", "GB", "TB"] {
        if size < 1024.0 or unit == "TB" {
            return f"{size:.1f} {unit}" if unit != "B" else f"{int(size)} B";
        }
        size /= 1024.0;
    }
    return f"{size_bytes} B";
}

def _handle_purge {
    if "-h" in sys.argv or "--help" in sys.argv {
        print("usage: jac purge [-h] [--all]\n");
        print(
            "Empty jac's global cache stores (modules, bootstrap, kernels, stubs, ...).\n"
        );
        print("Prune-exempt stores (models) are kept unless --all is given.");
        sys.`exit(0);
    }

    import from jaclang.cache.registry { all_stores, purge_all }

    include_exempt = "--all" in sys.argv;
    purged: list[tuple[str, int]] = [];
    for store in all_stores() {
        if store.prune_exempt and not include_exempt {
            continue;
        }
        purged.append((store.name, store.size_bytes()));
    }
    purge_all(include_exempt=include_exempt);

    total_size = 0;
    for (name, size) in purged {
        total_size += size;
        print(f"Purged store '{name}' ({_human_size(size)})");
    }
    print(f"Freed {_human_size(total_size)} across {len(purged)} stores");
    sys.`exit(0);
}

def _run_bundled_app -> (int | None) {
    off = os.environ.get("JAC_APP_OVERLAY_OFF");
    length = os.environ.get("JAC_APP_OVERLAY_LEN");
    if not off or not length {
        return None;
    }
    import from jaclang.dist.jab { materialize_jab_bytes }
    import from jaclang.cli.commands.execution { run_jab_image }

    try {
        with open(sys.executable, "rb") as f {
            f.seek(int(off));
            data = f.read(int(length));
        }
        img_root = materialize_jab_bytes(data);
    } except Exception as e {
        print(
            f"jac: this binary's embedded app image is unreadable ({e})",
            file=sys.stderr
        );
        return 1;
    }
    return run_jab_image(img_root, None, sys.argv[1:], False, "<app binary>");
}

def start_cli -> None {
    app_rc = _run_bundled_app();
    if app_rc is not None {
        sys.`exit(app_rc);
    }

    if len(sys.argv) >= 2 and sys.argv[1] == "purge" {
        _handle_purge();
        return;
    }

    import from jaclang.cli.cli { start_cli as _start_cli }
    _start_cli();
}
