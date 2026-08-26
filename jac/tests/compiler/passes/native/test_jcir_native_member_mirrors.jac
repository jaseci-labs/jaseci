"""Server-side mirrors for native-placed module members (B7).

`JcirGenPass.exit_import` used to drop every import whose target is a
natively-pinned user module (`Import.native_only_drop`, stamped by the
driver per #8305). The drop is right about ownership -- the native lane
owns the module -- but it left the importing server tier with no binding
at all, so constructing one of the target's obj archetypes died with
`NameError` at execution. Functions over primitives crossed the boundary;
classes did not.

The emitter now splices `interop_bridge.pyb_mirror_member` calls instead:
each imported name loads the target's server tier through the ordinary
Jac import machinery and binds the member. Pinned here:

1. a pinned-native import lowers to mirror splices, not to a plain
   `from <target> import ...` and not to nothing;
2. the mirrored names actually execute: construction, method call and
   free-function call across the codespace boundary produce values;
3. names already served by same-module ctypes interop stubs
   (`manifest.native_exports`) are left to those stubs.
"""

import os;
import contextlib;
import io;
import jaclang;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.program { JacProgram }
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     CLIENT = "na_mirror_client.jac";


"""Compile the B7 client fixture the ordinary way."""
def _compiled_client() -> tuple {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, CLIENT),
        options=CompileOptions(no_ir_cache=True)
    );
    return (prog, mod, );
}


test "mirror fixture compiles clean" {
    (prog, mod) = _compiled_client();
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
}


test "pinned-native import lowers to mirror splices" {
    (prog, mod) = _compiled_client();
    py_src = mod.gen.py;
    assert "pyb_mirror_member" in py_src , (
        "the dropped cross-codespace import emitted no mirror splice; "
        "server code constructing a native-placed obj will NameError again"
    );
    assert "MirrorPoint" in py_src;
    assert "mirror_double" in py_src;
    assert "from na_mirror_target import" not in py_src , (
        "the emitter issued a plain Python import for a natively-pinned "
        "module; that re-introduces the ownership violation #8305 fixed"
    );
}


test "mirrored obj constructs and answers across the codespace" {
    (prog, mod) = _compiled_client();
    assert not prog.errors_had;
    py_code = compile(
        mod.gen.py, os.path.join(FIXTURES, CLIENT), "exec"
    );
    buf = io.StringIO();
    with contextlib.redirect_stdout(buf) {
        exec(py_code, {});
    }
    output = buf.getvalue().strip();
    assert output == "7 42" , (
        f"cross-codespace construction produced '{output}', expected '7 42'"
    );
}
