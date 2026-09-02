import io;
import json;
import logging;
import os;
import re;
import shutil;
import subprocess;
import tarfile;
import time;
import from shared.github { text_of }
import from shared.timefmt { now_iso }
import from .graph {
    DocsHub,
    DocVersion,
    HasHub,
    HasVersion,
    NextPage,
    _get_hub,
    _pretty,
    _sweep_stale,
    _version,
    _version_list,
    place_page,
    rewrite_href,
    toc_of
}

obj VersionSpec {
    has label: str = "",
        git_ref: str = "";
}

obj DocBundle {
    has pages: dict[str, str] = {},
        nav_text: str = "",
        nav_json: str = "",
        assets: dict[str, bytes] = {};
}

obj NavEntry {
    has title: str = "",
        order: int = 9000;
}

glob GH_REPO: str = os.environ.get("JAC_DOCS_GH_REPO", "jaseci-labs/jac"),
     CORPUS_DIR: str = "jac/jaclang/cli/docs",
     LEGACY_DIR: str = "docs/docs",
     MKDOCS_FILE: str = "docs/mkdocs.yml",
     DOCS_LOCAL: str = os.environ.get("JAC_DOCS_LOCAL", ""),
     CLONE_DIR: str = os.environ.get(
         "JAC_DOCS_CLONE_DIR", os.path.join(os.getcwd(), ".jac", "data", "docs-repo")
     ),
     RELEASE_FLOOR: tuple[int, int] = (0, 31),
     RELEASE_CEIL: tuple[int, int] = (2, 0),
     FETCH_GATE_S: float = 600.0,
     SYNC_TICK_S: float = 30.0,
     GIT_STATE: dict[str, float] = {},
     log: logging.Logger = logging.getLogger("docs.sync");

def clone_url -> str;

def git_out(args: list[str], timeout_s: int = 120) -> tuple[int, bytes];

def git_text(args: list[str], timeout_s: int = 120) -> tuple[int, str];

def self_heal;

def ensure_repo -> bool;

def fetch_repo;

def sync_ref(ref: str) -> str;

def head_sha_of(ref: str) -> str;

def pick_releases(tags: list[str]) -> list[VersionSpec];

def release_specs -> list[VersionSpec];

def untar_members(data: bytes) -> dict[str, bytes];

def archive_members(ref: str) -> dict[str, bytes];

def git_bundle(ref: str, label: str) -> DocBundle;

def local_bundle(src_root: str, label: str) -> DocBundle;

def _manifest_pages(items: list) -> list[dict];

def parse_nav_manifest(text: str) -> dict[str, NavEntry];

def parse_nav(text: str) -> dict[str, NavEntry];

def clean_md(text: str) -> str;

def first_h1(text: str) -> str;

def rewrite_links(text: str, version: str, rel: str) -> str;

def write_assets(assets: dict[str, bytes]);

def build_version(label: str, ref: str) -> tuple[DocVersion, DocBundle];

def effective_specs -> list[VersionSpec];

def specs_drifted -> bool;

def ingest_all;

def dev_stale -> bool;

def refresh_dev(hub: DocsHub);

@schedule(trigger=ScheduleTrigger.STATIC, interval=SYNC_TICK_S)
def docs_sync_tick;
