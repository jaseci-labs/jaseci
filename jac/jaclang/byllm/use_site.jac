import from jaclang.byllm.config_loader { get_byllm_config }

glob USE_SITE_MODES: tuple = ("off", "signature", "semantic", "generic"),
     USE_SITE_HEADER: str = "## Downstream use";

def:pub resolve_use_site_mode -> str;

def:pub render_use_site_block(info: object, mode: str) -> str;

def:pub use_site_suffix(info: object) -> str;

def:pub use_site_word_count(text: str) -> int;
