import json;
import logging;
import from datetime { datetime, timezone }
import from threading { Lock }

glob logger = logging.getLogger(__name__),
     _log_lock = Lock(),
     USAGE_LOG_ENV: str = "BYLLM_USAGE_LOG",
     USAGE_LOG_MAX_LINE: int = 4096;

def:pub usage_log_path -> str;

def:pub emit_usage_record(
    mt_run: object, usage: object, model_name: str, latency_ms: (float | None) = None
) -> None;
