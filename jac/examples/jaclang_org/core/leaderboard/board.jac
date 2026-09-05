import re;
import from core.progress { JobProgress }
import from core.timefmt { now_iso, seconds_since }
import from core.github { RepoMeta }
import from .scoring { RepoAnalysis, RepoFeatures, ScoreBreakdown, ScorePart }

import from core.github { parse_repo_url }
import from core.scoring_service { ScoredPayload, fetch_and_score }

obj BoardEntry {
    has full: str = "",
        owner: str = "",
        name: str = "",
        description: str = "",
        avatar_url: str = "",
        html_url: str = "",
        permalink: str = "",
        stars: int = 0,
        forks: int = 0,
        topics: list[str] = [],
        jac_files: int = 0,
        jac_lines: int = 0,
        jac_pct: int = 0,
        features: RepoFeatures = RepoFeatures(),
        breakdown: ScoreBreakdown = ScoreBreakdown(),
        score: int = 0,
        belt: str = "white",
        scored_sha: str = "",
        scored_by_pid: int = 0,
        submitted_at: str = "",
        scored_at: str = "";
}

obj SubmitResult {
    has ok: bool = False,
        error: str = "",
        cooldown: bool = False,
        `entry: BoardEntry | None = None,
        board: list[BoardEntry] = [];
}

obj BoardView {
    has entries: list[BoardEntry] = [];
}

obj BoardStatus {
    has scoring: bool = False,
        progress: JobProgress = JobProgress();
}

glob RESCORE_TTL_S: float = 21600.0;

node BoardHub {
    has created_at: str = "";
}

node RepoEntry {
    has full: str = "",
        owner: str = "",
        name: str = "",
        description: str = "",
        avatar_url: str = "",
        html_url: str = "",
        stars: int = 0,
        forks: int = 0,
        topics: list[str] = [],
        pushed_at: str = "",
        created_at: str = "",
        jac_files: int = 0,
        jac_lines: int = 0,
        jac_pct: int = 0,
        features: RepoFeatures = RepoFeatures(),
        score: int = 0,
        breakdown: ScoreBreakdown = ScoreBreakdown(),
        belt: str = "white",
        scored_sha: str = "",
        scored_by_pid: int = 0,
        submitted_at: str = "",
        scored_at: str = "";

    def view -> BoardEntry;
}

edge OnBoard {}

def _ensure_hub -> BoardHub;


def _find_entry(full_name: str) -> RepoEntry | None;

def _board_list -> list[BoardEntry];

obj Scorer {
    has job: JobProgress = JobProgress(),
        scoring: bool = False;

    async def score_repo(hub: BoardHub, owner: str, name: str) -> SubmitResult;
    async def submit(url: str) -> SubmitResult;
}

glob SCORER: Scorer = Scorer();

async def:pub submit_repo(url: str = "") -> SubmitResult {
    return await SCORER.submit(url);
}

def:pub leaderboard -> BoardView {
    return BoardView(entries=_board_list());
}

def:pub board_status -> BoardStatus {
    return BoardStatus(scoring=SCORER.scoring, progress=SCORER.job);
}
