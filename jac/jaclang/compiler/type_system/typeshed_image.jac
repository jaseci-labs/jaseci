import hashlib;
import json;
import os;
import sys;
import from pathlib { Path }

import from jaclang.jac0core.jir { FORMAT_VERSION }
import from jaclang.jac0core.jir_passes { JirReader }
import from jaclang.jac0core.unitree { Module }

glob MANIFEST_NAME: str = "MANIFEST.json",
     MANIFEST_FORMAT: int = 1,
     KIND: str = "typeshed";


def sealed_stub_skipped(fullname: str) -> bool {
    if fullname == "_typeshed" {
        return True;
    }
    return fullname
        in (
            "typing",
            "types",
            "enum",
            "builtins",
            "jac_builtins",
            "dom_types",
            "na_builtins",
            "js_globals",
            "typing_ambient",

        );
}


def python_tag -> str {
    return f"cpython-{sys.version_info.major}{sys.version_info.minor}";
}


def stub_fullname(base_dir: str, pyi_path: str) -> str {
    rel = Path(pyi_path).relative_to(base_dir);
    parts = list(rel.with_suffix("").parts);
    if parts and parts[-1] == "__init__" {
        parts = parts[:-1];
    }
    return ".".join(parts);
}


def fullname_for_resolved_path(path: str) -> (str | None) {
    import from jaclang.jac0core.modresolver { get_typeshed_paths }
    p = Path(path).resolve();
    for d in get_typeshed_paths() {
        base = Path(d).resolve();
        try {
            p.relative_to(base);
        } except Exception {
            continue;
        }
        return stub_fullname(str(base), str(p));
    }
    return None;
}


def discover_image -> (TypeshedImage | None) {
    env = os.environ.get("JAC_TYPESHED_IMAGE", "");
    if env {
        return load_typeshed_image(env);
    }

    pkg_dir = Path(__file__ as str).resolve().parent.parent.parent;
    return load_typeshed_image(pkg_dir / "vendor" / "typeshed" / "_sealed");
}


obj TypeshedImage {
    has image_dir: Path,
        manifest: dict,
        jir_dir: Path postinit,
        index: dict postinit;

    def postinit {
        self.jir_dir = self.image_dir
            / (self.manifest.get("python_tag", python_tag()) as str);
        self.index = {};
        mods: dict = self.manifest.get("modules", {}) as dict;
        for (fullname, entry) in mods.items() {
            self.index[fullname] = entry;
        }
    }

    def find_stub(fullname: str) -> (Module | None) {
        entry: (dict | None) = self.index.get(fullname);
        if entry is None {
            return None;
        }
        jir_rel: str = entry.get("jir", "") as str;
        if not jir_rel {
            return None;
        }
        jir_path = self.jir_dir / jir_rel;
        try {
            data: bytes = jir_path.read_bytes();
        } except Exception {
            return None;
        }
        reader = JirReader(_source_path=str(jir_path));
        return reader.read_module(data);
    }
}


def load_typeshed_image(image_dir: (str | Path)) -> (TypeshedImage | None) {
    pdir = Path(image_dir);
    try {
        raw: bytes = (pdir / MANIFEST_NAME).read_bytes();
    } except Exception {
        return None;
    }
    manifest: dict = json.loads(raw);
    if manifest.get("format") != MANIFEST_FORMAT {
        return None;
    }
    if manifest.get("kind") != KIND {
        return None;
    }
    if manifest.get("python_tag") != python_tag() {
        return None;
    }
    if manifest.get("jir_format_version") != FORMAT_VERSION {
        return None;
    }
    return TypeshedImage(image_dir=pdir, manifest=manifest);
}
