import from pathlib { Path }
import from jaclang.runtimelib.serving.datatypes { Response, FileResponse }


obj AssetRoot {
    has url_prefix: str,
        local_dir: str,
        source: str;
}


def asset_root_table(
    project_root: Path, client_dist: Path, mounts: list[dict]
) -> list[AssetRoot] {
    table: list[AssetRoot] = [];

    for m in mounts {
        prefix = str(m.get("url_prefix", "")).strip("/");
        local = str(m.get("local_path", ""));
        if prefix and local {
            table.append(AssetRoot(url_prefix=prefix, local_dir=local, source="mount"));
        }
    }

    dist = str(client_dist);
    assets = str(project_root / "assets");
    public = str(project_root / "public");

    table.append(AssetRoot(url_prefix="static", local_dir=dist, source="dist"));
    table.append(AssetRoot(url_prefix="static", local_dir=assets, source="assets"));
    table.append(AssetRoot(url_prefix="", local_dir=dist, source="dist"));
    table.append(AssetRoot(url_prefix="", local_dir=public, source="public"));
    table.append(AssetRoot(url_prefix="", local_dir=assets, source="assets"));

    return table;
}


def _remainder(url_path: str, prefix: str) -> (str | None) {
    p = prefix.strip("/");
    if p == "" {
        rel = url_path.lstrip("/");
        if rel.startswith("static/") {
            return None;
        }
        return rel;
    }
    marker = "/" + p;
    if url_path == marker {
        return "";
    }
    if url_path.startswith(marker + "/") {
        return url_path[len(marker) + 1:];
    }
    return None;
}


def resolve_asset(
    table: list[AssetRoot], url_path: str
) -> (tuple[Path, AssetRoot] | None) {
    mount_claimed = False;
    for r in table {
        if mount_claimed and r.url_prefix == "" {
            continue;
        }
        rel = _remainder(url_path, r.url_prefix);
        if rel is None or rel == "" {
            continue;
        }
        if r.source == "mount" {
            mount_claimed = True;
        }
        base = Path(r.local_dir);
        target = base / rel;
        try {
            resolved = target.resolve();
            if not resolved.is_relative_to(base.resolve()) {
                continue;
            }
        } except OSError {
            continue;
        }
        if resolved.is_file() {
            return (resolved, r);
        }
    }
    return None;
}


def asset_response(target: Path, req_headers: dict[str, str]) -> Response {
    headers = {"Cache-Control": "public, max-age=3600, must-revalidate"};
    return FileResponse(path=str(target), headers=headers);
}
