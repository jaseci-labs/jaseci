import os;

glob _USAGE_LOG_ENV: str = "BYLLM_USAGE_LOG";

def usage_log_path -> str;

def build_usage_record(
    mt_run: object, model_name: str, usage: object, latency_ms: float
) -> dict[str, object];

def log_completion(
    mt_run: object, model_name: str, usage: object, latency_ms: float
) -> None;
