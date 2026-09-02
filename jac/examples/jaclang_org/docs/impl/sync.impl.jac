impl clone_url -> str {
    if "://" in GH_REPO or GH_REPO.startswith("git@") {
        return GH_REPO;
    }
    return "https://github.com/" + GH_REPO + ".git";
}

impl git_out(args: list[str], timeout_s: int = 120) -> tuple[int, bytes] {
    try {
        done = subprocess.run(
            ["git", "-C", CLONE_DIR] + args, capture_output=True, timeout=timeout_s
        );
    } except Exception {
        return (1, bytes());
    }
    return (done.returncode as int, done.stdout as bytes);
}

impl git_text(args: list[str], timeout_s: int = 120) -> tuple[int, str] {
    (rc, out) = git_out(args, timeout_s);
    return (rc, out.decode("utf-8", errors="replace").strip());
}

impl self_heal{
    log.warning("docs sync: resetting clone at " + CLONE_DIR);
    shutil.rmtree(CLONE_DIR, ignore_errors=True);
}

impl ensure_repo -> bool {
    if os.path.isdir(os.path.join(CLONE_DIR, ".git")) {
        return True;
    }
    shutil.rmtree(CLONE_DIR, ignore_errors=True);
    os.makedirs(os.path.dirname(CLONE_DIR), exist_ok=True);
    log.info("docs sync: cloning " + clone_url());
    try {
        done = subprocess.run(
            [
                "git",
                "clone",
                "--filter=tree:0",
                "--no-checkout",
                "--single-branch",
                "--branch",
                "main",
                clone_url(),
                CLONE_DIR
            ],
            capture_output=True,
            timeout=600
        );
    } except Exception as e {
        log.error("docs sync: clone failed — " + str(e));
        shutil.rmtree(CLONE_DIR, ignore_errors=True);
        return False;
    }
    if done.returncode != 0 {
        tail = (done.stderr as bytes).decode("utf-8", errors="replace")[-400:];
        log.error("docs sync: clone failed — " + tail);
        shutil.rmtree(CLONE_DIR, ignore_errors=True);
        return False;
    }
    (rc, _) = git_text(["fetch", "--tags", "--force", "origin", "main"], 300);
    if rc != 0 {
        self_heal();
        return False;
    }
    GIT_STATE["fetched_at"] = time.time();
    return True;
}

impl fetch_repo{
    now = time.time();
    if (now - GIT_STATE.get("fetched_at", 0.0)) < FETCH_GATE_S {
        return;
    }
    (rc, _) = git_text(
        ["fetch", "--tags", "--force", "--prune", "origin", "main"], 300
    );
    if rc != 0 {
        self_heal();
        raise RuntimeError("git fetch failed — clone reset for next tick");
    }
    GIT_STATE["fetched_at"] = now;
}

impl sync_ref(ref: str) -> str {
    return "origin/main" if ref == "main" else ref;
}

impl head_sha_of(ref: str) -> str {
    (rc, out) = git_text(["rev-parse", sync_ref(ref) + "^{commit}"]);
    return out if rc == 0 else "";
}

impl pick_releases(tags: list[str]) -> list[VersionSpec] {
    best: dict[tuple[int, int], tuple[int, str]] = {};
    for t in tags {
        m = re.`match(r"^v(\d+)\.(\d+)\.(\d+)$", t.strip());
        if not m {
            continue;
        }
        mm = (int(m.group(1)), int(m.group(2)));
        patch = int(m.group(3));
        if mm < RELEASE_FLOOR or mm >= RELEASE_CEIL {
            continue;
        }
        cur = best.get(mm);
        if cur is None or patch > cur[0] {
            best[mm] = (patch, t.strip());
        }
    }
    series = sorted(best.keys(), reverse=True);
    return [
        VersionSpec(label="v" + str(mm[0]) + "." + str(mm[1]), git_ref=best[mm][1])
        for mm in series
    ];
}

impl release_specs -> list[VersionSpec] {
    if not os.path.isdir(os.path.join(CLONE_DIR, ".git")) {
        return [];
    }
    (rc, out) = git_text(["tag", "--list"]);
    if rc != 0 {
        return [];
    }
    return pick_releases(out.split("\n"));
}

impl untar_members(data: bytes) -> dict[str, bytes] {
    out: dict[str, bytes] = {};
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as tf {
        for member in tf.getmembers() {
            if not member.isfile() {
                continue;
            }
            fh = tf.extractfile(member);
            if fh is None {
                continue;
            }
            rel = member.name;
            if rel.startswith("./") {
                rel = rel[2:];
            }
            out[rel] = fh.read();
        }
    }
    return out;
}

impl archive_members(ref: str) -> dict[str, bytes] {
    members: dict[str, bytes] = {};
    for path in [CORPUS_DIR, LEGACY_DIR, MKDOCS_FILE] {
        (rc, blob) = git_out(["archive", "--format=tar", sync_ref(ref), path], 300);
        if rc == 0 and blob {
            members.update(untar_members(blob));
        }
    }
    return members;
}

impl git_bundle(ref: str, label: str) -> DocBundle {
    members = archive_members(ref);
    if not members {
        raise RuntimeError("could not read docs for " + label + " (" + ref + ")");
    }
    log.info("docs sync: archived " + label + " · " + str(len(members)) + " files");
    bundle = DocBundle();
    corpus = CORPUS_DIR + "/";
    legacy = LEGACY_DIR + "/";
    is_corpus = any(
        [(rel.startswith(corpus) and rel.endswith(".md")) for rel in members.keys()]
    );
    for rel in members.keys() {
        if is_corpus {
            if not rel.startswith(corpus) {
                continue;
            }
            sub = rel[len(corpus):];
            if sub == "nav.json" {
                bundle.nav_json = text_of(members[rel]);
            } elif sub.endswith(".md") {
                bundle.pages[sub] = text_of(members[rel]);
            } elif sub.startswith("assets/") {
                bundle.assets[sub[len("assets/"):]] = members[rel];
            }
        } elif rel == MKDOCS_FILE {
            bundle.nav_text = text_of(members[rel]);
        } elif rel.startswith(legacy) {
            sub = rel[len(legacy):];
            if sub.endswith(".md") {
                bundle.pages[sub] = text_of(members[rel]);
            } elif sub.startswith("assets/") {
                bundle.assets[sub[len("assets/"):]] = members[rel];
            }
        }
    }
    return bundle;
}

impl local_bundle(src_root: str, label: str) -> DocBundle {
    log.info("docs sync: reading " + label + " from " + os.path.abspath(src_root));
    bundle = DocBundle();
    docs_root = os.path.join(src_root, *CORPUS_DIR.split("/"));
    if not os.path.isdir(docs_root) {
        docs_root = os.path.join(src_root, *LEGACY_DIR.split("/"));
    }
    for (cur, dirnames, filenames) in os.walk(docs_root) {
        for fname in sorted(filenames) {
            full = os.path.join(cur, fname);
            rel = os.path.relpath(full, docs_root).replace(os.sep, "/");
            if rel.startswith("assets/") {
                with open(full, "rb") as fb {
                    bundle.assets[rel[len("assets/"):]] = fb.read();
                }
            } elif fname.endswith(".md") {
                with open(full, encoding="utf-8") as ft {
                    bundle.pages[rel] = ft.read();
                }
            }
        }
    }
    nj = os.path.join(docs_root, "nav.json");
    mk = os.path.join(src_root, *MKDOCS_FILE.split("/"));
    if os.path.exists(nj) {
        with open(nj, encoding="utf-8") as fn {
            bundle.nav_json = fn.read();
        }
    } elif os.path.exists(mk) {
        with open(mk, encoding="utf-8") as fn {
            bundle.nav_text = fn.read();
        }
    }
    return bundle;
}

impl _manifest_pages(items: list) -> list[dict] {
    out: list[dict] = [];
    for `entry in items {
        if not isinstance(`entry, dict) {
            continue;
        }
        if "page" in `entry {
            out.append(`entry);
        } elif "items" in `entry {
            out.extend(_manifest_pages(`entry["items"] as list));
        }
    }
    return out;
}

impl parse_nav_manifest(text: str) -> dict[str, NavEntry] {
    nav: dict[str, NavEntry] = {};
    try {
        manifest = json.loads(text);
    } except ValueError {
        return nav;
    }
    if not isinstance(manifest, dict) {
        return nav;
    }
    order = 0;
    for `entry in _manifest_pages(manifest.get("nav", []) as list) {
        path = str(`entry.get("page", ""));
        title = str(`entry.get("title", "")).strip();
        if path {
            nav[path] = NavEntry(title=title, order=order);
            order += 1;
        }
    }
    return nav;
}

impl parse_nav(text: str) -> dict[str, NavEntry] {
    nav: dict[str, NavEntry] = {};
    in_nav = False;
    order = 0;
    for line in text.split("\n") {
        if line.startswith("nav:") {
            in_nav = True;
            continue;
        }
        if in_nav {
            if line.strip() and not line.startswith(" ") {
                break;
            }
            m = re.`match(
                r"\s*-\s+(?:\"?([^\":]+?)\"?\s*:\s*)?\"?([\w\-/\.]+\.md)\"?\s*$", line
            );
            if m {
                title = m.group(1) or "";
                path = m.group(2) as str;
                nav[path] = NavEntry(title=title.strip(), order=order);
                order += 1;
            }
        }
    }
    return nav;
}

impl clean_md(text: str) -> str {
    lines = text.split("\n");
    if len(lines) > 2 and lines[0].strip() == "---" {
        i = 1;
        while i < len(lines) and lines[i].strip() != "---" {
            i += 1;
        }
        lines = lines[i + 1:];
    }
    lines = [
        ln
        for ln in lines
        if "--8<--" not in ln
    ];
    return "\n".join(lines);
}

impl first_h1(text: str) -> str {
    fenced = False;
    for ln in text.split("\n") {
        if ln.strip().startswith("```") {
            fenced = not fenced;
        } elif not fenced and ln.startswith("# ") {
            return ln[2:].strip();
        }
    }
    return "";
}

impl rewrite_links(text: str, version: str, rel: str) -> str {
    cur_dir = os.path.dirname(rel);

    def md_repl(m: re.Match[str]) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "[" + g1 + "](" + rewrite_href(g2, version, cur_dir) + ")";
    }
    def img_repl(m: re.Match[str]) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "![" + g1 + "](" + rewrite_href(g2, version, cur_dir) + ")";
    }
    def src_repl(m: re.Match[str]) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        g3 = (m.group(3) or "") as str;
        return g1 + rewrite_href(g2, version, cur_dir) + g3;
    }
    def bare_repl(m: re.Match[str]) -> str {
        tail = ((m.group(1) or "") as str).strip("/");
        return ("/docs/" + version + "/" + tail).rstrip("/");
    }
    text = re.sub(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", img_repl, text);
    text = re.sub(r"(?<!\!)\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", md_repl, text);
    text = re.sub(r"(src=[\"'])([^\"']+)([\"'])", src_repl, text);
    text = re.sub(r"https?://docs\.jaseci\.org(/[\w\-/#\.]*)?", bare_repl, text);
    return text;
}

impl write_assets(assets: dict[str, bytes]) {
    dst_root = os.path.join(os.getcwd(), "assets", "docsmedia");
    for rel in assets.keys() {
        dst = os.path.join(dst_root, rel);
        os.makedirs(os.path.dirname(dst), exist_ok=True);
        with open(dst, "wb") as f {
            f.write(assets[rel]);
        }
    }
}

impl build_version(label: str, ref: str) -> tuple[DocVersion, DocBundle] {
    sha = "" if DOCS_LOCAL != "" else head_sha_of(ref);
    bundle = local_bundle(DOCS_LOCAL, label)
        if DOCS_LOCAL != ""
        else git_bundle(ref, label);
    files = bundle.pages;
    nav = parse_nav_manifest(bundle.nav_json)
        if bundle.nav_json != ""
        else parse_nav(bundle.nav_text);
    log.info("docs sync: growing " + label + " · " + str(len(files)) + " pages");

    ver = DocVersion(
        label=label, git_ref=ref, fetched_at=now_iso(), pages=len(files), sha=sha
    );

    names = sorted([k for k in files.keys()]);
    fallback = 9000;
    for rel in names {
        parts = rel.split("/");
        raw = clean_md(files[rel]);
        raw = rewrite_links(raw, label, rel);
        meta = nav.get(rel);
        title = meta.title if meta is not None else "";
        if not title {
            title = first_h1(raw) or _pretty(parts[-1][:-3]);
        }
        order = meta.order if meta is not None else fallback;
        fallback += 1;
        ver spawn place_page(
            segs=parts[:-1],
            name=parts[-1][:-3],
            title=title,
            order=order,
            md_lines=raw.split("\n"),
            toc=toc_of(raw)
        );
    }

    reading = ver.reading_order();
    for i in range(len(reading) - 1) {
        reading[i] +>:NextPage():+> reading[i + 1];
    }
    return (ver, bundle);
}

impl effective_specs -> list[VersionSpec] {
    if DOCS_LOCAL != "" {
        return [VersionSpec(label="dev", git_ref="local")];
    }
    return [VersionSpec(label="dev", git_ref="main")] + release_specs();
}

impl specs_drifted -> bool {
    have: dict[str, str] = {};
    for v in _version_list() {
        have[v.label] = v.git_ref;
    }
    for spec in effective_specs() {
        if have.get(spec.label) != spec.git_ref {
            return True;
        }
    }
    return False;
}

impl ingest_all{
    specs = effective_specs();
    log.info(
        "docs sync: full ingest from "
            + (("local tree " + DOCS_LOCAL) if DOCS_LOCAL != "" else clone_url())
            + " · "
            + str(len(specs))
            + " versions"
    );
    hub = DocsHub(built_at=now_iso());
    dev_assets: dict[str, bytes] = {};
    release_assets: dict[str, bytes] = {};
    for spec in specs {
        (ver, b) = build_version(spec.label, spec.git_ref);
        hub +>:HasVersion():+> ver;
        if spec.label == "dev" {
            dev_assets = b.assets;
        } elif not release_assets {
            release_assets = b.assets;
        }
    }
    if release_assets {
        write_assets(release_assets);
    }
    if dev_assets {
        write_assets(dev_assets);
    }
    root.shared +>:HasHub():+> hub;
    _sweep_stale(hub);
    log.info("docs sync: graph ready");
}

impl dev_stale -> bool {
    vers = _version("dev");
    if not vers {
        return True;
    }
    if DOCS_LOCAL != "" {
        return False;
    }
    head = head_sha_of("main");
    return head != "" and head != vers[0].sha;
}

impl refresh_dev(hub: DocsHub) {
    log.info("docs sync: main moved — refreshing dev");
    (ver, b) = build_version("dev", "main");
    hub +>:HasVersion():+> ver;
    write_assets(b.assets);
    _sweep_stale(hub);
    log.info("docs sync: dev refreshed");
}

impl docs_sync_tick{
    try {
        if DOCS_LOCAL == "" {
            if not ensure_repo() {
                return;
            }
            fetch_repo();
        }
        hub = _get_hub();
        if hub is None or specs_drifted() {
            ingest_all();
        } elif dev_stale() {
            refresh_dev(hub);
        }
    } except Exception as e {
        log.error("docs sync: failed — " + str(e));
    }
}
