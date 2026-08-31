import hashlib;
import os;


def _frame(h: any, part: any) {
    payload = part if isinstance(part, bytes) else str(part).encode();
    h.update(f"{len(payload)}:".encode());
    h.update(payload);
}


def digest(parts: list) -> str {
    h = hashlib.sha256();
    for part in parts {
        _frame(h, part);
    }
    return h.hexdigest();
}


def short(hex_digest: str, n: int = 16) -> str {
    return hex_digest[:n];
}


def file_digest(path: str) -> str {
    h = hashlib.sha256();
    with open(path, "rb") as f {
        while True {
            chunk = f.read(1 << 20);
            if not chunk {
                break;
            }
            h.update(chunk);
        }
    }
    return h.hexdigest();
}


def files_digest(paths: list[str]) -> str {
    h = hashlib.sha256();
    for path in sorted(paths) {
        _frame(h, path);
        try {
            with open(path, "rb") as f {
                _frame(h, f.read());
            }
        } except OSError {
            _frame(h, b"<missing>");
        }
    }
    return h.hexdigest();
}


def mtime_fresh(entry_path: str, source_paths: list[str]) -> bool {
    try {
        entry_mtime = os.path.getmtime(entry_path);
        for source in source_paths {
            if os.path.getmtime(source) >= entry_mtime {
                return False;
            }
        }
        return True;
    } except OSError {
        return False;
    }
}


def fresh(
    entry_path: str, source_paths: list[str], content_check: any = None
) -> bool {
    if not os.path.exists(entry_path) {
        return False;
    }
    if mtime_fresh(entry_path, source_paths) {
        return True;
    }
    if content_check is not None {
        return bool(content_check());
    }
    return False;
}
