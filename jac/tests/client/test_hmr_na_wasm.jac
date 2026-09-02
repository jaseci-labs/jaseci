"""HMR must re-emit wasm when a native module the client imports changes.

`jac run --dev` compiles the client's `na` imports to `/static/<stem>.wasm`
once at startup (`ViteCompiler._emit_na_wasm`). Editing one of those modules
during the session recompiled the Jac side and left the stale wasm in place,
so native game code needed a full server restart to show up in the browser.

The set of modules that owe a wasm is already tracked -- the client compile
records them in `JacClientCompiler.na_wasm_modules` -- so the watcher has
everything it needs to re-emit the one that changed and ask the page to
reload.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.server.hmr { HotReloader }
import from jaclang.server.watcher { JacFileWatcher }


obj _FakeJacClientCompiler {
    has compiled_dir: Path,
        project_dir: Path,
        na_wasm_modules: set[str],
        recompiled: list[str];

    def _output_path_for(module_path: Path, source_root: Path) -> Path {
        return self.compiled_dir / (module_path.stem + ".js");
    }

    def compile_dependencies_recursively(module_path: Path, **kwargs: any) {
        self.recompiled.append(str(module_path));
    }

    def rescan_pages -> bool {
        return False;
    }
}


obj _FakeViteCompiler {
    has jac_client_compiler: _FakeJacClientCompiler,
        emitted: list[str],
        _has_pages: bool = False;

    def _emit_na_wasm(module_path: Path) {
        self.emitted.append(str(module_path));
    }

    def create_entry_file(module_path: Path) {}
}


"""Build a project holding a client entry and one native module, and return
(base_path, native_module_path, hot_reloader, fake_compiler)."""
def _make_reloader(tmp: str) -> tuple {
    Path(os.path.join(tmp, "jac.toml")).write_text(
        '[project]\nname = "wasmproj"\n', encoding="utf-8"
    );
    Path(os.path.join(tmp, "main.jac")).write_text(
        'glob READY: bool = True;\n', encoding="utf-8"
    );
    na_dir = Path(tmp) / "game";
    na_dir.mkdir();
    na_file = na_dir / "arena.jac";
    na_file.write_text(
        'na {\n    def tick(x: int) -> int {\n        return x + 1;\n    }\n}\n',
        encoding="utf-8"
    );
    compiled_dir = Path(tmp) / ".jac" / "client" / "compiled";
    compiled_dir.mkdir(parents=True);
    jcc = _FakeJacClientCompiler(
        compiled_dir=compiled_dir,
        project_dir=Path(tmp),
        na_wasm_modules={str(na_file.resolve())},
        recompiled=[]
    );
    compiler = _FakeViteCompiler(jac_client_compiler=jcc, emitted=[]);
    reloader = HotReloader(
        base_path=tmp,
        module_name="main",
        watcher=JacFileWatcher(watch_paths=[tmp]),
        client_compiler=compiler
    );
    reloader._running = True;
    return (na_file, reloader, compiler);
}


test "editing a tracked native module re-emits its wasm" {
    with TemporaryDirectory() as tmp {
        (na_file, reloader, compiler) = _make_reloader(tmp);
        reloader._process_change(str(na_file));
        emitted = list(compiler.emitted);
    }
    assert emitted , (
        "a change to a module the client imports natively must re-emit its "
        "wasm; the watcher emitted nothing"
    );
    assert any(str(na_file) in e for e in emitted) , (
        f"the changed native module must be the one re-emitted; got {emitted}"
    );
}


test "re-emitting wasm asks the browser to reload" {
    with TemporaryDirectory() as tmp {
        (na_file, reloader, compiler) = _make_reloader(tmp);
        reloader._process_change(str(na_file));
        signal = Path(tmp) / ".jac" / "client" / ".jac-force-reload";
        existed = signal.exists();
    }
    assert existed , (
        "a fresh wasm binary is only picked up on a full page load, so the "
        "watcher must raise the force-reload signal"
    );
}


test "an ordinary module change does not re-emit wasm" {
    with TemporaryDirectory() as tmp {
        (na_file, reloader, compiler) = _make_reloader(tmp);
        other = Path(tmp) / "main.jac";
        reloader._process_change(str(other));
        emitted = list(compiler.emitted);
    }
    assert emitted == [] , (
        f"only tracked native modules owe a wasm re-emit; got {emitted}"
    );
}
