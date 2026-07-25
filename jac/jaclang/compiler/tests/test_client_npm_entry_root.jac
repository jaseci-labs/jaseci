"""Type-checker tests for npm resolution from library client modules.

Regression coverage for the W1100 cascade on `@jac/runtime` re-exports: npm
package resolution walked up from the file containing the import statement to
its nearest jac.toml, so an `import from 'react-router-dom'` inside the shipped
client runtime resolved against the jaclang tree (or site-packages), never the
app project whose `.jac/client/node_modules` actually holds the package. Any
app symbol demanded through such a re-export (e.g. `<Outlet/>`) then cascaded
W1100 -> W1051 into user code.

The fix keeps the importing file's project root as the primary base and falls
back to the compiled program's entry root, mirroring how the bundler resolves
npm specifiers. A library module in one project tree importing an npm package
installed only in the app's tree must therefore type-check clean, while a
genuinely missing package must still warn.
"""

import os;
import sys;
import shutil;
import tempfile;
import from jaclang.jac0core.program { JacProgram }


glob _LIB_SRC: str = (
         "import from 'fake-widgets' { makeWidget as _mw }\n"
         "\n"
         "glob make_widget = _mw;\n"
     ),
     _ENTRY_SRC: str = (
         "import from libmod { make_widget }\n"
         "\n"
         "def:pub run -> None {\n"
         "    make_widget();\n"
         "}\n"
     );


"""Write an app project and a separate library project; return (entry_file, lib_dir)."""
def _write_projects(base_dir: str, with_pkg: bool) -> tuple[str, str] {
    app = os.path.join(base_dir, "app");
    lib = os.path.join(base_dir, "lib");
    os.makedirs(app, exist_ok=True);
    os.makedirs(lib, exist_ok=True);
    for proj in (app, lib) {
        with open(os.path.join(proj, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"" + os.path.basename(proj) + "\"\n");
        }
    }
    if with_pkg {
        pkg = os.path.join(app, ".jac", "client", "node_modules", "fake-widgets");
        os.makedirs(pkg, exist_ok=True);
        with open(os.path.join(pkg, "package.json"), "w") as f {
            f.write('{"name": "fake-widgets", "main": "index.js"}\n');
        }
        with open(os.path.join(pkg, "index.js"), "w") as f {
            f.write("export function makeWidget() { return {}; }\n");
        }
    }
    entry_file = os.path.join(app, "main.cl.jac");
    with open(entry_file, "w") as f {
        f.write(_ENTRY_SRC);
    }
    with open(os.path.join(lib, "libmod.cl.jac"), "w") as f {
        f.write(_LIB_SRC);
    }
    return (entry_file, lib);
}


"""Type-check the app entry with the library project visible on `sys.path`."""
def _check(entry_file: str, lib_dir: str) -> JacProgram {
    sys.path.insert(0, lib_dir);
    try {
        prog = JacProgram();
        prog.compile(file_path=entry_file, type_check=True, no_cgen=True);
        return prog;
    } finally {
        sys.path.remove(lib_dir);
    }
}


test "npm import in a library module resolves from the app entry root" {
    base_dir = tempfile.mkdtemp(prefix="jac_npm_root_");
    try {
        (entry_file, lib_dir) = _write_projects(base_dir, with_pkg=True);
        prog = _check(entry_file, lib_dir);
        w1100 = [
            str(w)
            for w in prog.warnings_had
            if w.code and w.code.code == "W1100"
        ];
        assert w1100 == [] , w1100;
    } finally {
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}


test "npm import missing from both project roots still warns" {
    base_dir = tempfile.mkdtemp(prefix="jac_npm_root_");
    try {
        (entry_file, lib_dir) = _write_projects(base_dir, with_pkg=False);
        prog = _check(entry_file, lib_dir);
        w1100 = [
            str(w)
            for w in prog.warnings_had
            if w.code and w.code.code == "W1100"
        ];
        assert w1100 != [] , "unresolvable npm package must keep warning W1100";
    } finally {
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}
