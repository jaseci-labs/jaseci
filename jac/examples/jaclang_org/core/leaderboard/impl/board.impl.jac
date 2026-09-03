impl _ensure_hub -> BoardHub {
    hubs = [root.shared-->[?:BoardHub]];
    if hubs {
        return hubs[0];
    }
    fresh = (root.shared ++> BoardHub(created_at=now_iso())) as BoardHub;
    grant(fresh, level=AccessLevel.CONNECT);
    return fresh;
}

impl parse_repo_url(url: str) -> tuple[str, str] | None {
    u = url.strip().rstrip("/");
    m = re.`match(
        r"^(?:https?://)?(?:www\.)?github\.com/([\w.\-]+)/([\w.\-]+?)(?:\.git)?$", u
    );
    if m is None {
        m = re.`match(r"^([\w.\-]+)/([\w.\-]+)$", u);
    }
    if m is None {
        return None;
    }
    return (m.group(1) as str, m.group(2) as str);
}

impl _find_entry(full_name: str) -> RepoEntry | None {
    found = [root.shared-->[?:BoardHub]->:OnBoard:->[?:RepoEntry, full==full_name]];
    return found[0] if found else None;
}

impl RepoEntry.view -> BoardEntry {
    return BoardEntry(
        full=self.full,
        owner=self.owner,
        name=self.name,
        description=self.description,
        avatar_url=self.avatar_url,
        html_url=self.html_url,
        permalink=(self.html_url + "/tree/" + self.scored_sha)
            if self.scored_sha != ""
            else self.html_url,
        stars=self.stars,
        forks=self.forks,
        topics=self.topics,
        jac_files=self.jac_files,
        jac_lines=self.jac_lines,
        jac_pct=self.jac_pct,
        features=self.features,
        breakdown=self.breakdown,
        score=self.score,
        belt=self.belt,
        scored_sha=self.scored_sha,
        scored_by_pid=self.scored_by_pid,
        submitted_at=self.submitted_at,
        scored_at=self.scored_at
    );
}

impl _board_list -> list[BoardEntry] {
    entries = [
        e.view() for e in [root.shared-->[?:BoardHub]->:OnBoard:->[?:RepoEntry]]
    ];
    entries.sort(key=lambda (b: BoardEntry) { -b.score; });
    return entries;
}

impl Scorer.score_repo(hub: BoardHub, owner: str, name: str) -> SubmitResult {
    def clean(raw: any) -> dict {
        out: dict = {};
        if isinstance(raw, dict) {
            for k in raw.keys() {
                if not str(k).startswith("_") {
                    out[k] = raw[k];
                }
            }
        }
        return out;
    }
    def as_features(raw: any) -> RepoFeatures {
        return raw if isinstance(raw, RepoFeatures) else RepoFeatures(**clean(raw));
    }
    def as_breakdown(raw: any) -> ScoreBreakdown {
        if isinstance(raw, ScoreBreakdown) {
            return raw;
        }
        d = clean(raw);
        d["details"] = [
            x if isinstance(x, ScorePart) else ScorePart(**clean(x))
            for x in (d.get("details") or [])
        ];
        return ScoreBreakdown(**d);
    }
    def as_analysis(raw: any) -> RepoAnalysis {
        if isinstance(raw, RepoAnalysis) {
            return raw;
        }
        d = clean(raw);
        d["features"] = as_features(d.get("features") or {});
        return RepoAnalysis(**d);
    }
    self.job.note("handing " + owner + "/" + name + " to the scoring app");
    p = await fetch_and_score(owner, name);
    if not p.ok {
        return SubmitResult(error=p.error);
    }
    meta = p.meta if isinstance(p.meta, RepoMeta) else RepoMeta(**clean(p.meta));
    an = as_analysis(p.an);
    sc = as_breakdown(p.breakdown);
    full = meta.full_name or (owner + "/" + name);
    self.job.note(
        "service pid "
            + str(p.service_pid)
            + " scored "
            + full
            + " — writing it to the board"
    );
    `entry = _find_entry(full);
    if `entry is None {
        `entry = (
            hub +>:OnBoard():+> RepoEntry(full=full, submitted_at=now_iso())
        ) as RepoEntry;
        grant(`entry, level=AccessLevel.READ);
    }
    `entry.owner = meta.owner or owner;
    `entry.name = meta.name or name;
    `entry.description = meta.description;
    `entry.avatar_url = meta.avatar_url;
    `entry.html_url = meta.html_url or ("https://github.com/" + full);
    `entry.stars = meta.stars;
    `entry.forks = meta.forks;
    `entry.topics = meta.topics;
    `entry.pushed_at = meta.pushed_at;
    `entry.created_at = meta.created_at;
    `entry.jac_files = an.jac_files;
    `entry.jac_lines = an.jac_lines;
    `entry.jac_pct = an.jac_pct();
    `entry.features = an.features;
    `entry.score = sc.total;
    `entry.breakdown = sc;
    `entry.belt = sc.belt;
    `entry.scored_sha = p.sha;
    `entry.scored_by_pid = p.service_pid;
    `entry.scored_at = now_iso();
    self.job.note(
        full
            + " scored "
            + str(`entry.score)
            + " — "
            + `entry.belt
            + " belt (service pid "
            + str(p.service_pid)
            + ")"
    );
    return SubmitResult(ok=True, `entry=`entry.view());
}

impl Scorer.submit(url: str) -> SubmitResult {
    parsed = parse_repo_url(url);
    if parsed is None {
        return SubmitResult(error="bad_url");
    }
    if self.scoring {
        return SubmitResult(error="busy");
    }
    hub = _ensure_hub();
    full = parsed[0] + "/" + parsed[1];
    existing = _find_entry(full);
    waited = seconds_since(existing.scored_at) if existing is not None else -1.0;
    if existing is not None and waited >= 0.0 and waited < RESCORE_TTL_S {
        return SubmitResult(
            ok=True, cooldown=True, `entry=existing.view(), board=_board_list()
        );
    }
    self.scoring = True;
    self.job.begin("scoring");
    self.job.note("queued " + full);
    res = SubmitResult(error="internal");
    try {
        res = await self.score_repo(hub, parsed[0], parsed[1]);
    } except Exception as e {
        res = SubmitResult(error="internal");
        self.job.note("scoring failed — " + str(e));
    } finally {
        self.scoring = False;
        if res.ok {
            self.job.finish();
        } else {
            self.job.fail(res.error);
        }
    }
    if res.ok {
        res.board = _board_list();
    }
    return res;
}
