import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.transform { Alert }
import type from jaclang.compiler.driver.mtp { Info }

obj ModuleHub {
    has mod: uni.ProgramModule,
        stamps: dict[str, float] = {},
        artifacts: dict[str, any] = {};

    def stamp(resolved_path: str) {
        import time;
        self.stamps[resolved_path] = time.time();
    }

    def is_fresh(resolved_path: str) -> bool {
        import os;
        import from jaclang.compiler.driver.bccache { discover_annex_files }
        cached_at = self.stamps.get(resolved_path);
        if cached_at is None {
            return True;
        }
        try {
            if os.path.getmtime(resolved_path) > cached_at {
                return False;
            }
            for related in discover_annex_files(resolved_path) {
                if os.path.getmtime(related) > cached_at {
                    return False;
                }
            }
            return True;
        } except OSError {
            return False;
        }
    }

    def evict(resolved_path: str) {
        if resolved_path in self.mod.hub {
            del self.mod.hub[resolved_path];
        }
        if resolved_path in self.stamps {
            del self.stamps[resolved_path];
        }
        if resolved_path in self.artifacts {
            del self.artifacts[resolved_path];
        }
    }

    def reset(keep_stubs: bool = False) {
        retained_mods: dict[str, uni.Module] = {};
        retained_stamps: dict[str, float] = {};
        if keep_stubs {
            for path in self.mod.hub.keys() {
                if path.endswith(".pyi") {
                    retained_mods[path] = self.mod.hub[path];
                    if path in self.stamps {
                        retained_stamps[path] = self.stamps[path];
                    }
                }
            }
        }
        self.mod = uni.ProgramModule();
        self.mod.hub.update(retained_mods);
        self.stamps.clear();
        self.stamps.update(retained_stamps);
    }
}

obj DepGraph {
    has dependents: dict[str, set[str]] = {},
        tracking: bool = False;

    def record(importer_path: str, target_path: str) -> None {
        if importer_path == target_path {
            return;
        }
        bucket = self.dependents.get(target_path);
        if bucket is None {
            bucket = set();
            self.dependents[target_path] = bucket;
        }
        bucket.add(importer_path);
    }

    def record_module(mod: uni.Module) -> None {
        import from pathlib { Path }
        if mod.loc is None {
            return;
        }
        mod_path = mod.loc.mod_path;
        if not mod_path.endswith(".jac") {
            return;
        }
        try {
            importer = str(Path(mod_path).resolve());
        } except Exception {
            return;
        }
        for imp in mod.get_all_sub_nodes(uni.Import) {
            paths: list[uni.ModulePath] = [];
            if imp.from_loc is not None {
                paths.append(imp.from_loc);
            } else {
                for item in imp.items {
                    if isinstance(item, uni.ModulePath) {
                        paths.append(item);
                    }
                }
            }
            for mp in paths {
                try {
                    target = str(Path(mp.resolve_relative_path()).resolve());
                } except Exception {
                    continue;
                }
                self.record(importer, target);
            }
        }
    }

    def transitive_dependents(target_path: str) -> set[str] {
        out: set[str] = set();
        frontier: list[str] = [target_path];
        while frontier {
            current = frontier.pop();
            for importer in self.dependents.get(current, set()) {
                if importer in out {
                    continue;
                }
                out.add(importer);
                frontier.append(importer);
            }
        }
        return out;
    }

    def forget(resolved_path: str) {
        for bucket in self.dependents.values() {
            bucket.discard(resolved_path);
        }
    }

    def clear {
        self.dependents.clear();
    }
}

obj DiagLedger {
    has errors: list[Alert] = [],
        warnings: list[Alert] = [];

    def drop_module(resolved_path: str) {
        import os;
        try {
            norm = os.path.realpath(resolved_path);
        } except OSError {
            return;
        }
        import from jaclang.jac0core.ext_registry { is_annex_path_of }

        def owned(alert: Alert) -> bool {
            return alert.owner == norm or is_annex_path_of(alert.owner, norm);
        }
        self.errors[:] = [
            a
            for a in self.errors
            if not owned(a)
        ];
        self.warnings[:] = [
            a
            for a in self.warnings
            if not owned(a)
        ];
    }

    def clear {
        self.errors.clear();
        self.warnings.clear();
    }
}

obj BuildScratch {
    has na_dep_units: dict[str, (uni.Module | str)] = {},
        na_dep_inflight: set[str] postinit,
        na_verdict_resolving: set[str] postinit,
        na_unverified_live: dict[str, dict] = {},
        na_verdict_misses: int = 0,
        boundary_parse_memo: dict[str, any] = {},
        compile_depth: int = 0;

    def postinit {
        self.na_dep_inflight = set();
        self.na_verdict_resolving = set();
    }
}

class AnalysisCaches {
    has placement_summaries: dict[str, any],
        placement_state: dict[str, any],
        analyses_run: dict[int, set[str]],
        mtir_map: dict[(str, Info)];

    def init(self: AnalysisCaches) {
        self.placement_summaries: dict[str, any] = {};
        self.placement_state: dict[str, any] = {};
        self.analyses_run: dict[int, set[str]] = {};
        self.mtir_map: dict[(str, Info)] = {};
    }
}
