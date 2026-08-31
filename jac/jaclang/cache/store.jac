import os;
import shutil;
import time;
import from pathlib { Path }
import from jaclang.jac0core.cachefs {
    atomic_publish, atomic_publish_dir, lock_path, pid_tmp, store_dir, unlock
}


glob PRUNE_SENTINEL: str = ".last-prune";


obj PrunePolicy {
    has ttl_seconds: float = 0.0,
        max_entries: int = 0,
        max_bytes: int = 0,
        prune_interval: float = 86400.0;
}


obj CacheStore {
    has name: str,
        schema_version: str = "v1",
        policy: (PrunePolicy | None) = None,
        prune_exempt: bool = False,
        dir_entries: bool = False,
        root_override: str = "";

    def postinit {
        if self.policy is None {
            self.policy = PrunePolicy();
        }
    }

    def root_dir -> Path {
        if self.root_override {
            path = Path(self.root_override);
            path.mkdir(parents=True, exist_ok=True);
            return path;
        }
        return store_dir(self.name);
    }

    def entry_path(key: str) -> Path {
        return self.root_dir() / key;
    }

    def has_entry(key: str) -> bool {
        return self.entry_path(key).exists();
    }

    def read(key: str) -> (bytes | None) {
        try {
            data = self.entry_path(key).read_bytes();
        } except OSError {
            return None;
        }
        self.touch(key);
        return data;
    }

    def publish(key: str, data: bytes) {
        atomic_publish(self.entry_path(key), data);
        self.maybe_prune();
    }

    def publish_dir(tmp_dir: Path, key: str) -> bool {
        published = atomic_publish_dir(tmp_dir, self.entry_path(key));
        self.maybe_prune();
        return published;
    }

    def scratch_dir(key: str) -> Path {
        return pid_tmp(self.entry_path(key));
    }

    def lock(key: str) -> any {
        return lock_path(self.root_dir() / f".{key}.lock");
    }

    def unlock(handle: any) {
        unlock(handle);
    }

    def touch(key: str) {
        try {
            os.utime(self.entry_path(key), None);
        } except OSError { }
    }

    def drop(key: str) {
        path = self.entry_path(key);
        try {
            if path.is_dir() {
                shutil.rmtree(path, ignore_errors=True);
            } else {
                path.unlink();
            }
        } except OSError { }
    }

    def purge {
        base = self.root_dir();
        try {
            for child in list(base.iterdir()) {
                if child.name == PRUNE_SENTINEL {
                    continue;
                }
                if child.is_dir() {
                    shutil.rmtree(child, ignore_errors=True);
                } else {
                    try {
                        child.unlink();
                    } except OSError { }
                }
            }
        } except OSError { }
    }

    def entry_count -> int {
        return len(self._live_entries());
    }

    def size_bytes -> int {
        total = 0;
        try {
            for (dirpath, _dirnames, filenames) in os.walk(self.root_dir()) {
                for fname in filenames {
                    try {
                        total += os.path.getsize(os.path.join(dirpath, fname));
                    } except OSError { }
                }
            }
        } except OSError { }
        return total;
    }

    def maybe_prune {
        if self.prune_exempt {
            return;
        }
        policy = self.policy;
        if (
            policy.ttl_seconds <= 0
            and policy.max_entries <= 0
            and policy.max_bytes <= 0
        ) {
            return;
        }
        sentinel = self.root_dir() / PRUNE_SENTINEL;
        now = time.time();
        try {
            if now - sentinel.stat().st_mtime < policy.prune_interval {
                return;
            }
        } except OSError { }
        try {
            sentinel.touch();
        } except OSError {
            return;
        }
        self.prune(now);
    }

    def prune(now: float = 0.0) {
        if self.prune_exempt {
            return;
        }
        if not now {
            now = time.time();
        }
        policy = self.policy;
        live: list[tuple[float, int, Path]] = [];
        for path in self._all_entries() {
            name = path.name;
            try {
                mtime = path.stat().st_mtime;
                if name.startswith(".") {
                    if now - mtime > policy.prune_interval {
                        self._remove(path);
                    }
                    continue;
                }
                if policy.ttl_seconds > 0 and now - mtime > policy.ttl_seconds {
                    self._remove(path);
                    continue;
                }
                live.append((mtime, self._entry_size(path), path));
            } except OSError {
                continue;
            }
        }
        live.sort();
        if policy.max_entries > 0 {
            overflow = len(live) - policy.max_entries;
            if overflow > 0 {
                for item in live[:overflow] {
                    self._remove(item[2]);
                }
                live = live[overflow:];
            }
        }
        if policy.max_bytes > 0 {
            total = sum(item[1] for item in live);
            index = 0;
            while total > policy.max_bytes and index < len(live) {
                self._remove(live[index][2]);
                total -= live[index][1];
                index += 1;
            }
        }
    }

    def _all_entries -> list[Path] {
        try {
            return [
                p
                for p in self.root_dir().iterdir()
                if p.name != PRUNE_SENTINEL
            ];
        } except OSError {
            return [];
        }
    }

    def _live_entries -> list[Path] {
        return [
            p
            for p in self._all_entries()
            if not p.name.startswith(".")
        ];
    }

    def _entry_size(path: Path) -> int {
        if not self.dir_entries {
            try {
                return path.stat().st_size;
            } except OSError {
                return 0;
            }
        }
        total = 0;
        try {
            for (dirpath, _dirnames, filenames) in os.walk(path) {
                for fname in filenames {
                    try {
                        total += os.path.getsize(os.path.join(dirpath, fname));
                    } except OSError { }
                }
            }
        } except OSError { }
        return total;
    }

    def _remove(path: Path) {
        try {
            if path.is_dir() {
                shutil.rmtree(path, ignore_errors=True);
            } else {
                path.unlink();
            }
        } except OSError { }
    }
}
