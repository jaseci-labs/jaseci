impl ModuleManager.clear_alerts_for_file(file_path_fs: str) -> None {
    self.program.errors_had[:] = [
        e
        for e in self.program.errors_had
        if e.loc.mod_path != file_path_fs
    ];
    self.program.warnings_had[:] = [
        w
        for w in self.program.warnings_had
        if w.loc.mod_path != file_path_fs
    ];
}

impl ModuleManager.update(
    file_path: str,
    build: uni.Module,
    update_annexed: bool = True,
    files: (list[str] | None) = None
) -> None {
    main_key = self.program.hub_key(file_path);
    self.program.mod.hub[main_key] = build;

    if update_annexed {
        rebuilt: set[str] = set();
        for f in (files or [file_path]) {
            f_key = self.program.hub_key(f);
            rebuilt.add(f_key);
            self.sem_managers[f_key] = SemTokManager(ir=build, target_path=f_key);
        }

        for (p, mod) in self.program.mod.hub.items() {
            if p in rebuilt {
                continue;
            }
            mgr = self.sem_managers.get(p);
            if mgr and mgr.ir is not mod {
                self.sem_managers[p] = SemTokManager(ir=mod, target_path=p);
            }
        }
    }
}
