glob STRICT_ENV: str = "JAC_SCALE_CONFIG_STRICT";

def known_scale_options -> dict[str, any];
def validate_scale_config(raw: dict[str, any] | None) -> list[str];
def warn_unknown_scale_keys(raw: dict[str, any] | None) -> None;
def _walk(
    section: dict[str, any],
    options: dict[str, any],
    path: str,
    findings: list[str]
) -> None;
def _unknown_key_message(path: str, key: str, known: list[str]) -> str;
def _strict_mode -> bool;
