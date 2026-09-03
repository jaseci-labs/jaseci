import hashlib;
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.types.stubcat.reader { StubCatalog }
import from jaclang.compiler.types.stubcat.writer { CatalogWriter }

glob IFACE_HASH_LEN: int = 64;

def build_module_iface(mod: Module, evaluator: any, pkg_dir: str) -> bytes {
    writer = CatalogWriter(evaluator=evaluator, pkg_dir=pkg_dir, boundary=mod);
    dotted = mod.name or "";
    writer.add_module(mod, dotted);
    prev_pass = evaluator?._pass;
    evaluator._pass = None;
    try {
        writer.force_all();
    } finally {
        evaluator._pass = prev_pass;
    }
    key = mod.loc.mod_path if mod.loc else dotted;
    body = writer.emit(key, {});
    digest = hashlib.sha256(body).hexdigest();
    return digest.encode("utf-8") + body;
}

def read_iface_hash(section: (bytes | None)) -> (str | None) {
    if section is None or len(section) <= IFACE_HASH_LEN {
        return None;
    }
    try {
        return section[:IFACE_HASH_LEN].decode("ascii");
    } except Exception {
        return None;
    }
}

def open_module_iface(
    section: bytes, pkg_dir: str, resolver: any = None
) -> (StubCatalog | None) {
    if len(section) <= IFACE_HASH_LEN {
        return None;
    }
    try {
        return StubCatalog(
            buf=section[IFACE_HASH_LEN:], pkg_dir=pkg_dir, resolver=resolver
        );
    } except ValueError {
        return None;
    }
}

def iface_module(catalog: StubCatalog) -> (Module | None) {
    return catalog.module_by_id(0);
}
