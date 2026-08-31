import os;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.cache.registry { all_stores, get_store, prune_all }

impl cache(action: str = "ls", name: str = "", include_exempt: bool = False) -> int {
    if action == "ls" {
        return _cache_ls();
    } elif action == "prune" {
        return _cache_prune();
    } elif action == "purge" {
        return _cache_purge(name, include_exempt);
    }
    console.error(f"Unknown action '{action}'.");
    console.print("Available actions: ls, prune, purge", style="muted");
    return 1;
}

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

def _dir_size(path: Path) -> int {
    total = 0;
    try {
        for (dirpath, _dirnames, filenames) in os.walk(path) {
            for fname in filenames {
                try {
                    total += os.path.getsize(os.path.join(dirpath, fname));
                } except OSError { }
            }
        }
    } except OSError { }
    return total;
}

def _cache_ls -> int {
    import from jaclang.project.config { get_config }

    rows: list[tuple[str, str, str, str, str, str]] = [];
    for store in all_stores() {
        rows.append((
            store.name,
            store.schema_version,
            str(store.entry_count()),
            _human_size(store.size_bytes()),
            str(store.root_dir()),
            "yes" if store.prune_exempt else ""
        ));
    }

    header = ("Store", "Schema", "Entries", "Size", "Path", "Exempt");
    widths = [len(h) for h in header];
    for row in rows {
        for (i, cell) in enumerate(row) {
            widths[i] = max(widths[i], len(cell));
        }
    }

    fmt_str = "{:<"
        + str(widths[0])
        + "}  {:<"
        + str(widths[1])
        + "}  {:>"
        + str(widths[2])
        + "}  {:>"
        + str(widths[3])
        + "}  {:<"
        + str(widths[4])
        + "}  {}";
    header_line = fmt_str.format(
        header[0], header[1], header[2], header[3], header[4], header[5]
    );
    console.print(header_line);
    console.print("-" * len(header_line));
    for row in rows {
        console.print(fmt_str.format(row[0], row[1], row[2], row[3], row[4], row[5]));
    }

    cfg = get_config();
    if cfg is not None {
        project_dir = cfg.get_cache_dir();
        console.print();
        console.print(
            f"Project cache: {project_dir} ({_human_size(_dir_size(project_dir))})"
        );
    }
    return 0;
}

def _cache_prune -> int {
    before: dict[str, int] = {};
    for store in all_stores() {
        before[store.name] = store.entry_count();
    }
    prune_all(force=True);
    for store in all_stores() {
        if store.prune_exempt {
            console.print(
                f"{store.name}: exempt ({before[store.name]} entries kept)"
            );
            continue;
        }
        console.print(
            f"{store.name}: {before[store.name]} -> {store.entry_count()} entries"
        );
    }
    return 0;
}

def _cache_purge(name: str, include_exempt: bool) -> int {
    if name {
        try {
            store = get_store(name);
        } except KeyError {
            known = ", ".join(s.name for s in all_stores());
            console.error(f"Unknown cache store '{name}'.");
            console.print(f"Available stores: {known}", style="muted");
            return 1;
        }
        freed = store.size_bytes();
        store.purge();
        console.print(f"Purged store '{name}' ({_human_size(freed)})");
        return 0;
    }

    purged: list[tuple[str, int]] = [];
    for store in all_stores() {
        if store.prune_exempt and not include_exempt {
            continue;
        }
        purged.append((store.name, store.size_bytes()));
        store.purge();
    }

    total_size = 0;
    for (sname, size) in purged {
        total_size += size;
        console.print(f"Purged store '{sname}' ({_human_size(size)})");
    }
    console.print(f"Freed {_human_size(total_size)} across {len(purged)} stores");
    return 0;
}
