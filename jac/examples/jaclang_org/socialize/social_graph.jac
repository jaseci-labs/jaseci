import re;
import base64;
import datetime;
import logging;
import from shared.timefmt { now_iso, seconds_since }
import from leaderboard.board { parse_repo_url }
import from scoring_service { ScoredPayload, fetch_and_score }

def _now -> str {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None).isoformat() + "Z";
}

glob MAX_DISPLAY_NAME: int = 50,
     MAX_BIO: int = 280,
     MAX_LOCATION: int = 60,
     MAX_WEBSITE: int = 200,
     MAX_AVATAR_BYTES: int = 393216,
     RESCORE_TTL_S: float = 21600.0,
     FEATURE_KEYS: list[str] = ["osp", "ai", "cl", "sv", "na", "tests"],
     RETRYABLE_SCORE_ERRORS: list[str] = ["fetch_failed", "internal"];

obj ProfileBundle {
    has profile: Profile,
        followers: list[Profile],
        following: list[Profile],
        tweets: list[Tweet],
        projects: list[Project] = [];
}

obj ChannelBundle {
    has channel: Channel,
        member_count: int,
        is_member: bool,
        posts: list[Tweet] = [];
}

obj TrendingTag {
    has tag: str,
        count: int;
}

obj FieldCheck {
    has ok: bool = True,
        error: str = "",
        value: str = "";
}

obj AvatarCheck {
    has ok: bool = False,
        error: str = "",
        mime: str = "",
        data: str = "";
}

obj ProfileResult {
    has ok: bool = False,
        error: str = "",
        bundle: ProfileBundle | None = None;
}

obj AvatarResult {
    has ok: bool = False,
        error: str = "",
        avatar_v: str = "",
        avatar_url: str = "";
}

obj ProjectResult {
    has ok: bool = False,
        error: str = "",
        project: Project | None = None;
}

edge Follow {}
edge Post {}
edge Member {}
edge ChannelPost {}
edge HasAvatar {}
edge Owns {}

node Profile {
    has username: str = "",
        display_name: str = "",
        bio: str = "",
        location: str = "",
        website: str = "",
        github: str = "",
        avatar_v: str = "",
        created_at: str = "";

    def avatar_url -> str {
        av = [self->:HasAvatar:->[?:Avatar]];
        if not av {
            return "";
        }
        return "data:" + av[0].mime + ";base64," + av[0].data;
    }

    def projects -> list[Project] {
        found = [self->:Owns:->[?:Project]];
        found.sort(key=lambda (p: Project) { (-p.score, p.added_at); });
        return found;
    }

    def to_bundle -> ProfileBundle {
        tweets = [self-->[?:Tweet]];
        tweets.sort(key=lambda (t: Tweet) { t.created_at; }, reverse=True);
        return ProfileBundle(
            profile=self,
            followers=[self<-:Follow:<-[?:Profile]],
            following=[self->:Follow:->[?:Profile]],
            tweets=tweets,
            projects=self.projects()
        );
    }
}

node Avatar {
    has mime: str = "image/jpeg",
        data: str = "",
        updated_at: str = "";
}

node Project {
    has full: str = "",
        owner: str = "",
        name: str = "",
        owner_username: str = "",
        description: str = "",
        html_url: str = "",
        avatar_url: str = "",
        stars: int = 0,
        forks: int = 0,
        topics: list[str] = [],
        features: list[str] = [],
        jac_files: int = 0,
        jac_lines: int = 0,
        jac_pct: int = 0,
        score: int = 0,
        belt: str = "",
        scored_sha: str = "",
        status: str = "pending",
        error: str = "",
        added_at: str = "",
        scored_at: str = "";

    def permalink -> str {
        if self.scored_sha != "" {
            return self.html_url + "/tree/" + self.scored_sha;
        }
        return self.html_url;
    }
}

node Tweet {
    has content: str = "",
        author_username: str = "",
        created_at: str = "",
        likes: list[str] = [],
        comments: list[dict[str, str]] = [];
}

node Channel {
    has name: str = "",
        description: str = "",
        creator_username: str = "",
        created_at: str = "";

    def to_bundle(with_posts: bool) -> ChannelBundle {
        mine = [root-->[?:Profile]];
        is_member: bool = len(mine) > 0 and len([edge mine[0]->:Member:->self]) > 0;
        posts: list[Tweet] = [];
        if with_posts {
            posts = [self-->[?:Tweet]];
            posts.sort(key=lambda (t: Tweet) { t.created_at; }, reverse=True);
        }
        return ChannelBundle(
            channel=self,
            member_count=len([self<-:Member:<-[?:Profile]]),
            is_member=is_member,
            posts=posts
        );
    }
}

def clean_github(raw: str) -> FieldCheck {
    v = raw.strip();
    if v == "" {
        return FieldCheck(value="");
    }
    m = re.`match(r"^(?:https?://)?(?:www\.)?github\.com/([A-Za-z0-9-]+)/?$", v);
    if m is not None {
        v = m.group(1) as str;
    }
    v = v.lstrip("@");
    if re.`match(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", v) is None {
        return FieldCheck(
            ok=False, error="GitHub handle can only contain letters, digits and hyphens"
        );
    }
    return FieldCheck(value=v);
}

def clean_website(raw: str) -> FieldCheck {
    v = raw.strip();
    if v == "" {
        return FieldCheck(value="");
    }
    if re.`match(r"^https?://", v, re.IGNORECASE) is None {
        v = "https://" + v;
    }
    if len(v) > MAX_WEBSITE or re.`match(r"^https?://[^\s/$.?#][^\s]*$", v) is None {
        return FieldCheck(ok=False, error="Website must be a valid http(s) URL");
    }
    return FieldCheck(value=v);
}

def clean_text(raw: str, limit: int, label: str) -> FieldCheck {
    v = raw.strip();
    if len(v) > limit {
        return FieldCheck(
            ok=False, error=f"{label} must be {limit} characters or fewer"
        );
    }
    return FieldCheck(value=v);
}

def decode_avatar(data_url: str) -> AvatarCheck {
    m = re.`match(
        r"^data:image/(jpeg|png|webp);base64,([A-Za-z0-9+/=\s]+)$", data_url.strip()
    );
    if m is None {
        return AvatarCheck(error="Avatar must be a JPEG, PNG or WebP image");
    }
    kind = m.group(1) as str;
    payload = re.sub(r"\s+", "", m.group(2) as str);
    try {
        raw = base64.b64decode(payload, validate=True);
    } except Exception {
        return AvatarCheck(error="Avatar image data is not valid base64");
    }
    if len(raw) > MAX_AVATAR_BYTES {
        return AvatarCheck(error="Avatar must be under 384 KB after resizing");
    }
    looks_right = (
        (kind == "jpeg" and raw[0:3] == b"\xff\xd8\xff")
        or (kind == "png" and raw[0:4] == b"\x89PNG")
        or (kind == "webp" and raw[0:4] == b"RIFF" and raw[8:12] == b"WEBP")
    );
    if not looks_right {
        return AvatarCheck(error="Avatar bytes do not match the declared image type");
    }
    return AvatarCheck(ok=True, mime="image/" + kind, data=payload);
}

def find_profile_by_username(username: str) -> Profile | None {
    wanted = username.strip().lower();
    if wanted == "" {
        return None;
    }
    for r in allroots() {
        for p in [r-->[?:Profile]] {
            if p.username.lower() == wanted {
                return p;
            }
        }
    }
    return None;
}

def _field(source: any, key: str, fallback: any) -> any {
    if source is None {
        return fallback;
    }
    if isinstance(source, dict) {
        value = source.get(key, fallback);
    } else {
        value = getattr(source, key, fallback);
    }
    return fallback if value is None else value;
}

def apply_score(proj: Project, payload: any) {
    if not _field(payload, "ok", False) {
        proj.status = "error";
        proj.error = str(_field(payload, "error", "internal") or "internal");
        return;
    }
    meta = _field(payload, "meta", None);
    an = _field(payload, "an", None);
    breakdown = _field(payload, "breakdown", None);
    proj.owner = str(_field(meta, "owner", "") or proj.owner);
    proj.name = str(_field(meta, "name", "") or proj.name);
    proj.full = proj.owner + "/" + proj.name;
    proj.description = str(_field(meta, "description", ""));
    proj.avatar_url = str(_field(meta, "avatar_url", ""));
    proj.html_url = str(
        _field(meta, "html_url", "") or ("https://github.com/" + proj.full)
    );
    proj.stars = int(_field(meta, "stars", 0));
    proj.forks = int(_field(meta, "forks", 0));
    proj.topics = [str(t) for t in (_field(meta, "topics", []) or [])];
    proj.jac_files = int(_field(an, "jac_files", 0));
    proj.jac_lines = int(_field(an, "jac_lines", 0));
    jac_bytes = int(_field(an, "jac_bytes", 0));
    other_bytes = int(_field(an, "other_code_bytes", 0));
    denom = jac_bytes + other_bytes;
    if denom > 0 {
        proj.jac_pct = int(round(100.0 * jac_bytes / denom));
    } else {
        proj.jac_pct = 100 if proj.jac_files > 0 else 0;
    }
    feats = _field(an, "features", None);
    proj.features = [
        k
        for k in FEATURE_KEYS
        if bool(_field(feats, k, False))
    ];
    proj.score = int(_field(breakdown, "total", 0));
    proj.belt = str(_field(breakdown, "belt", "white") or "white");
    proj.scored_sha = str(_field(payload, "sha", ""));
    proj.scored_at = now_iso();
    proj.status = "scored";
    proj.error = "";
}

def score_project(proj: Project) {
    try {
        apply_score(proj, fetch_and_score(proj.owner, proj.name));
    } except Exception as e {
        logging.getLogger(__name__).exception(
            "scoring %s for %s failed: %s", proj.full, proj.owner_username, e
        );
        proj.status = "error";
        proj.error = "internal";
    }
}

walker setup_profile {
    has username: str = "",
        bio: str = "",
        reports: list[ProfileBundle] = [];

    can run with Root entry {
        visit [-->[?:Profile]] else {
            fresh = here ++> Profile(created_at=_now());
            grant(fresh, level=AccessLevel.CONNECT);
            visit fresh;
        }
    }

    can apply with Profile entry {
        if self.username {
            here.username = self.username;
        }
        if self.bio {
            here.bio = self.bio;
        }
        report here.to_bundle();
    }
}

walker update_profile {
    has display_name: str = "",
        bio: str = "",
        location: str = "",
        website: str = "",
        github: str = "",
        reports: list[ProfileResult] = [];

    can run with Root entry {
        visit [-->[?:Profile]] else {
            report ProfileResult(error="Set up your profile first");
        }
    }

    can apply with Profile entry {
        checks = [
            clean_text(self.display_name, MAX_DISPLAY_NAME, "Display name"),
            clean_text(self.bio, MAX_BIO, "Bio"),
            clean_text(self.location, MAX_LOCATION, "Location"),
            clean_website(self.website),
            clean_github(self.github)
        ];
        for c in checks {
            if not c.ok {
                report ProfileResult(error=c.error);
                disengage;
            }
        }
        here.display_name = checks[0].value;
        here.bio = checks[1].value;
        here.location = checks[2].value;
        here.website = checks[3].value;
        here.github = checks[4].value;
        report ProfileResult(ok=True, bundle=here.to_bundle());
    }
}

walker get_profile {
    has reports: list[ProfileBundle] = [];

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can give with Profile entry {
        report here.to_bundle();
    }
}

walker:pub get_user_profile {
    has username: str = "",
        reports: list[ProfileResult] = [];

    can run with Root entry {
        found = find_profile_by_username(self.username);
        if found is None {
            report ProfileResult(error="No such user");
        } else {
            report ProfileResult(ok=True, bundle=found.to_bundle());
        }
    }
}

walker set_avatar {
    has data_url: str = "",
        reports: list[AvatarResult] = [];

    can run with Root entry {
        visit [-->[?:Profile]] else {
            report AvatarResult(error="Set up your profile first");
        }
    }

    can apply with Profile entry {
        check = decode_avatar(self.data_url);
        if not check.ok {
            report AvatarResult(error=check.error);
            disengage;
        }
        stamp = now_iso();
        existing = [here->:HasAvatar:->[?:Avatar]];
        if existing {
            existing[0].mime = check.mime;
            existing[0].data = check.data;
            existing[0].updated_at = stamp;
        } else {
            fresh = here +>:HasAvatar():+> Avatar(
                mime=check.mime, data=check.data, updated_at=stamp
            );
            grant(fresh, level=AccessLevel.READ);
        }
        here.avatar_v = stamp;
        report AvatarResult(ok=True, avatar_v=stamp, avatar_url=here.avatar_url());
    }
}

walker clear_avatar {
    has reports: list[AvatarResult] = [];

    can run with Root entry {
        visit [-->[?:Profile]] else {
            report AvatarResult(error="Set up your profile first");
        }
    }

    can apply with Profile entry {
        for av in [here->:HasAvatar:->[?:Avatar]] {
            del av;
        }
        here.avatar_v = "";
        report AvatarResult(ok=True);
    }
}

walker:pub get_avatars {
    has usernames: list[str] = [],
        found: dict[str, str] = {},
        reports: list[dict[str, str]] = [];

    can run with Root entry {
        wanted: dict[str, bool] = {};
        for u in self.usernames {
            wanted[u.lower()] = True;
        }
        for r in allroots() {
            for p in [r-->[?:Profile]] {
                if p.username.lower() in wanted and p.avatar_v != "" {
                    self.found[p.username] = p.avatar_url();
                }
            }
        }
        report self.found;
    }
}

walker:pub get_all_profiles {
    has results: list[Profile] = [],
        reports: list[list[Profile]] = [];

    can run with Root entry {
        for r in allroots() {
            visit [r-->[?:Profile]];
        }
    }

    can gather with Profile entry {
        self.results.append(here);
    }

    can deliver with Root exit {
        report self.results;
    }
}

walker:pub get_all_projects {
    has results: list[Project] = [],
        seen: dict[str, bool] = {},
        reports: list[list[Project]] = [];

    can run with Root entry {
        for r in allroots() {
            for p in [r-->[?:Profile]] {
                for proj in p.projects() {
                    pid = jid(proj);
                    if pid not in self.seen {
                        self.seen[pid] = True;
                        self.results.append(proj);
                    }
                }
            }
        }
        self.results.sort(key=lambda (p: Project) { (-p.score, p.added_at); });
        report self.results;
    }
}

walker add_project {
    has url: str = "",
        reports: list[ProjectResult] = [];

    can run with Root entry {
        visit [-->[?:Profile]] else {
            report ProjectResult(error="Set up your profile first");
        }
    }

    can make with Profile entry {
        parsed = parse_repo_url(self.url);
        if parsed is None {
            report ProjectResult(error="bad_url");
            disengage;
        }
        full = parsed[0] + "/" + parsed[1];
        for existing in [here->:Owns:->[?:Project]] {
            if existing.full.lower() == full.lower() {
                report ProjectResult(error="duplicate", project=existing);
                disengage;
            }
        }
        proj = here +>:Owns():+> Project(
            full=full,
            owner=parsed[0],
            name=parsed[1],
            owner_username=here.username,
            html_url="https://github.com/" + full,
            added_at=now_iso()
        );
        grant(proj, level=AccessLevel.READ);
        score_project(proj);
        if proj.status == "error" and proj.error not in RETRYABLE_SCORE_ERRORS {
            reason = proj.error;
            del proj;
            report ProjectResult(error=reason);
            disengage;
        }
        report ProjectResult(
            ok=proj.status == "scored", error=proj.error, project=proj
        );
    }
}

walker find_project {
    has project_id: str = "";

    can run with Root entry {
        if self.project_id {
            target = jobj(self.project_id);
            if isinstance(target, Project) {
                visit [target];
            }
        }
    }
}

walker remove_project(find_project) {
    has reports: list[ProjectResult] = [];

    can act with Project entry {
        if jid(here) == self.project_id {
            me = [root-->[?:Profile]];
            if me and [edge me[0]->:Owns:->here] {
                del here;
                report ProjectResult(ok=True);
            } else {
                report ProjectResult(error="forbidden");
            }
            disengage;
        }
    }
}

walker rescore_project(find_project) {
    has reports: list[ProjectResult] = [];

    can act with Project entry {
        if jid(here) == self.project_id {
            me = [root-->[?:Profile]];
            if not (me and [edge me[0]->:Owns:->here]) {
                report ProjectResult(error="forbidden");
                disengage;
            }
            waited = seconds_since(here.scored_at);
            if here.status == "scored" and waited >= 0.0 and waited < RESCORE_TTL_S {
                report ProjectResult(ok=True, error="cooldown", project=here);
                disengage;
            }
            score_project(here);
            report ProjectResult(
                ok=here.status == "scored", error=here.error, project=here
            );
            disengage;
        }
    }
}

walker get_trending {
    has counts: dict[str, int] = {},
        seen: dict[str, bool] = {},
        reports: list[list[TrendingTag]] = [];

    can run with Root entry {
        for r in allroots() {
            visit [r-->[?:Profile]-->[?:Tweet]];
        }
    }

    can tally with Tweet entry {
        tid = jid(here);
        if tid in self.seen {
            return;
        }
        self.seen[tid] = True;
        for word in here.content.split() {
            if word.startswith("#") and len(word) > 1 {
                tag = word.lower().rstrip(".,!?;:");
                self.counts[tag] = self.counts.get(tag, 0) + 1;
            }
        }
    }

    can deliver with Root exit {
        tags = [TrendingTag(tag=t, count=self.counts[t]) for t in self.counts];
        tags.sort(key=lambda (x: TrendingTag) { x.count; }, reverse=True);
        report tags[:8];
    }
}

walker load_feed {
    has search_query: str = "",
        feed: list[Tweet] = [],
        reports: list[list[Tweet]] = [];

    can run with Root entry {
        mine = [-->[?:Profile]];
        if mine {
            me = mine[0];
            visit [me-->[?:Tweet]];
            visit [me->:Follow:->[?:Profile]-->[?:Tweet]];
        }
    }

    can gather with Tweet entry {
        self.feed.append(here);
    }

    can deliver with Root exit {
        result = self.feed;
        if self.search_query {
            q = self.search_query.lower().strip();
            result = [
                t
                for t in result
                if q in t.content.lower()
            ];
        }
        result.sort(key=lambda (t: Tweet) { t.created_at; }, reverse=True);
        report result;
    }
}

walker get_channels {
    has seen: dict[str, bool] = {},
        results: list[ChannelBundle] = [],
        reports: list[list[ChannelBundle]] = [];

    can run with Root entry {
        for r in allroots() {
            visit [r-->[?:Profile]-->[?:Channel]];
        }
    }

    can gather with Channel entry {
        cid = jid(here);
        if cid not in self.seen {
            self.seen[cid] = True;
            self.results.append(here.to_bundle(False));
        }
    }

    can deliver with Root exit {
        self.results.sort(
            key=lambda (c: ChannelBundle) { c.channel.created_at; }, reverse=True
        );
        report self.results;
    }
}

walker create_tweet {
    has content: str;

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can make with Profile entry {
        new = here +>:Post():+> Tweet(
            content=self.content, author_username=here.username, created_at=_now()
        );
        grant(new, level=AccessLevel.WRITE);
        report new;
    }
}

walker create_channel {
    has name: str,
        description: str = "";

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can make with Profile entry {
        new = here +>:Member():+> Channel(
            name=self.name,
            description=self.description,
            creator_username=here.username,
            created_at=_now()
        );
        grant(new, level=AccessLevel.CONNECT);
        report new.to_bundle(False);
    }
}

walker find_profile {
    has target_id: str = "";

    can run with Root entry {
        if self.target_id {
            target = jobj(self.target_id);
            if isinstance(target, Profile) {
                visit [target];
            }
        }
    }
}

walker follow_user(find_profile) {
    can act with Profile entry {
        if jid(here) == self.target_id {
            me = [root-->[?:Profile]][0];
            me +>:Follow():+> here;
            report {"success": True};
            disengage;
        }
    }
}

walker unfollow_user(find_profile) {
    can act with Profile entry {
        if jid(here) == self.target_id {
            me = [root-->[?:Profile]][0];
            edges = [edge me->:Follow:->here];
            if edges {
                del edges[0];
            }
            report {"success": True};
            disengage;
        }
    }
}

walker find_tweet {
    has tweet_id: str = "",
        actor: str = "";

    can run with Root entry {
        mine = [-->[?:Profile]];
        if mine {
            self.actor = mine[0].username;
        }
        if self.tweet_id {
            target = jobj(self.tweet_id);
            if isinstance(target, Tweet) {
                visit [target];
            }
        }
    }
}

walker like_tweet(find_tweet) {
    can act with Tweet entry {
        if jid(here) == self.tweet_id {
            if self.actor in here.likes {
                here.likes = [
                    u
                    for u in here.likes
                    if u != self.actor
                ];
                report {"liked": False, "likes": here.likes};
            } else {
                here.likes = here.likes + [self.actor];
                report {"liked": True, "likes": here.likes};
            }
            disengage;
        }
    }
}

walker delete_tweet(find_tweet) {
    can act with Tweet entry {
        if jid(here) == self.tweet_id and here.author_username == self.actor {
            del here;
            report {"success": True};
            disengage;
        }
    }
}

walker add_comment(find_tweet) {
    has content: str = "";

    can act with Tweet entry {
        if jid(here) == self.tweet_id {
            comment = {
                "username": self.actor,
                "content": self.content,
                "created_at": _now()
            };
            here.comments = here.comments + [comment];
            report {"success": True, "comment": comment};
            disengage;
        }
    }
}

walker find_channel {
    has channel_id: str = "";

    can run with Root entry {
        if self.channel_id {
            target = jobj(self.channel_id);
            if isinstance(target, Channel) {
                visit [target];
            }
        }
    }
}

walker join_channel(find_channel) {
    can act with Channel entry {
        if jid(here) == self.channel_id {
            me = [root-->[?:Profile]][0];
            if not [edge me->:Member:->here] {
                me +>:Member():+> here;
            }
            report {"success": True};
            disengage;
        }
    }
}

walker leave_channel(find_channel) {
    can act with Channel entry {
        if jid(here) == self.channel_id {
            me = [root-->[?:Profile]][0];
            edges = [edge me->:Member:->here];
            if edges {
                del edges[0];
            }
            report {"success": True};
            disengage;
        }
    }
}

walker get_channel_detail(find_channel) {
    has reports: list[ChannelBundle] = [];

    can act with Channel entry {
        if jid(here) == self.channel_id {
            report here.to_bundle(True);
            disengage;
        }
    }
}

walker create_channel_tweet(find_channel) {
    has content: str = "";

    can act with Channel entry {
        if jid(here) == self.channel_id {
            me = [root-->[?:Profile]][0];
            if [edge me->:Member:->here] {
                new = here +>:ChannelPost():+> Tweet(
                    content=self.content, author_username=me.username, created_at=_now()
                );
                grant(new, level=AccessLevel.WRITE);
                report new;
            }
            disengage;
        }
    }
}
