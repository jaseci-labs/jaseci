glob ROLLOUT_WAIT_READY: str = "ready",
     ROLLOUT_WAIT_FULL: str = "full",
     ROLLOUT_WAIT_MODES: tuple = ("ready", "full"),
     PROGRESS_DEADLINE_REASON: str = "ProgressDeadlineExceeded";


def normalize_rollout_wait(mode: any) -> str {
    candidate = str(mode or ROLLOUT_WAIT_READY).strip().lower();
    if candidate not in ROLLOUT_WAIT_MODES {
        raise ValueError(
            f"invalid rollout wait mode '{mode}': expected one of "
            f"{', '.join(ROLLOUT_WAIT_MODES)}"
        );
    }
    return candidate;
}


def _replica_count(value: any) -> int {
    try {
        return max(int(value or 0), 0);
    } except (TypeError, ValueError) {
        return 0;
    }
}


def _stall_reason(status: any) -> str {
    for cond in (status?.conditions or []) {
        if str(cond?.type or "") != "Progressing" {
            continue;
        }
        if str(cond?.reason or "") != PROGRESS_DEADLINE_REASON {
            continue;
        }
        message = str(cond?.message or "").strip();
        return (
            f"{PROGRESS_DEADLINE_REASON}: {message}"
                if message
                else PROGRESS_DEADLINE_REASON
        );
    }
    return "";
}


obj RolloutStatus {
    has desired: int = 0,
        updated: int = 0,
        available: int = 0,
        total: int = 0,
        generation: int = 0,
        observed_generation: int = 0,
        stall: str = "";

    def is_observed -> bool {
        return self.observed_generation >= self.generation;
    }

    def updated_available -> int {
        outdated = max(self.total - self.updated, 0);
        return max(self.available - outdated, 0);
    }

    def is_complete -> bool {
        return self.updated >= self.desired
            and self.total <= self.updated
            and self.available >= self.desired;
    }

    def satisfies(mode: str) -> bool {
        if not self.is_observed() {
            return False;
        }
        if mode == ROLLOUT_WAIT_FULL or self.desired <= 0 {
            return self.is_complete();
        }
        return self.updated_available() >= 1;
    }

    def summary -> str {
        return f"{self.updated_available()}/{self.desired}";
    }
}


def read_rollout_status(deployment: any) -> RolloutStatus {
    meta = deployment?.metadata;
    spec = deployment?.spec;
    status = deployment?.status;
    return RolloutStatus(
        desired=_replica_count(spec?.replicas),
        updated=_replica_count(status?.updated_replicas),
        available=_replica_count(status?.available_replicas),
        total=_replica_count(status?.replicas),
        generation=_replica_count(meta?.generation),
        observed_generation=_replica_count(status?.observed_generation),
        stall=_stall_reason(status)
    );
}
