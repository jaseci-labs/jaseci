import logging;
import re;
import time;
import from jaclang.scale._optdeps.pymongo { HAS_PYMONGO }

glob logger = logging.getLogger(__name__),
     MONGO_DOWN_TTL_S: float = 30.0,
     _mongo_down: dict[str, float] = {};


def redact_mongo_uri(uri: (str | None)) -> str {
    return re.sub(r"://[^/@]*@", "://***@", str(uri or ""));
}


def mark_mongo_down {
    _mongo_down['until'] = time.monotonic() + MONGO_DOWN_TTL_S;
}


def mongo_recently_down -> bool {
    return time.monotonic() < _mongo_down.get('until', 0.0);
}


def mongo_reachable(client: (any | None)) -> bool {
    if not HAS_PYMONGO or client is None {
        return False;
    }
    if mongo_recently_down() {
        return False;
    }
    try {
        client.admin.command('ping');
        return True;
    } except Exception as e {
        logger.debug(f"MongoDB ping failed: {e}");
        mark_mongo_down();
        return False;
    }
}


def warn_mongo_unreachable(uri: (str | None), timeout_ms: int, fallback: str) {
    logger.warning(
        "cannot reach MongoDB at "
            + redact_mongo_uri(uri)
            + f"; falling back to {fallback}. Set MONGODB_TIMEOUT_MS to change the "
            + f"{timeout_ms}ms probe budget, or unset MONGODB_URI to skip Mongo entirely."
    );
}
