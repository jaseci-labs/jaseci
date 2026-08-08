"""Seal integrity: a native demotion must never ship as an abort stub.

In-process, a method the native backend cannot lower is demoted and falls back
to its Python implementation -- congruence survives and only speed is lost. A
*sealed* artifact has no Python left to fall back to, so the same demotion is
emitted as an `abort()` stub and the first call kills the process with no
diagnostic. Every congruence gap therefore turns from "slower" into "runtime
crash", which is what made the old sealed native parser artifact segfault for
weeks without an explanation.

These tests pin the build-time gate that closes that hole:

1. a module the backend lowers in full still seals, and its artifact passes the
   dlopen + canary smoke before it is written into the manifest;
2. a module carrying an un-lowerable method *fails* the seal, with a diagnostic
   that names the method, says what shipping it would cost, and points at both
   the waiver list and the debug gate; nothing is written to the output tree;
3. naming that exact method in the waiver list lets the seal through and says
   so on stderr -- while waiving some *other* method does not launder it;
4. the canary rejects a deliberately broken artifact and an artifact whose
   advertised exports are not really in it, and accepts a live one;
5. `JAC_NA_DEBUG=1` explains the demotion behind the refusal.

The canary is exercised end-to-end by test 1 (a seal only succeeds if the
canary passed) and directly by test 4; there is no in-flight hook to corrupt
the artifact between the linker and the canary inside a single seal, so the
rejection half of test 4 calls the canary on its own.
"""

import contextlib;
import hashlib;
import io;
import json;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import from jaclang.utils.precompile_bytecode {
    seal_native_artifacts,
    seal_native_canary
}

glob FIXTURES = Path(TESTS_DIR) / "compiler" / "passes" / "native" / "fixtures";


"""Seal one fixture into a fresh temp tree.

Returns (artifacts, captured_stderr, tmpdir). `JAC_SEAL_NO_NATIVE` is dropped
for the duration so an ambient setting cannot turn the seal into a no-op.
"""
def _seal(rel: str, waivers: (dict | None) = None, na_debug: bool = False) -> tuple {
    tmp = tempfile.mkdtemp(prefix="jac_seal_integrity_");
    saved_skip = os.environ.pop("JAC_SEAL_NO_NATIVE", None);
    saved_dbg = os.environ.pop("JAC_NA_DEBUG", None);
    if na_debug {
        os.environ["JAC_NA_DEBUG"] = "1";
    }
    buf = io.StringIO();
    try {
        with contextlib.redirect_stderr(buf) {
            arts = seal_native_artifacts(
                FIXTURES, Path(tmp), modules=(rel, ), waivers=waivers
            );
        }
    } finally {
        os.environ.pop("JAC_NA_DEBUG", None);
        if saved_skip is not None {
            os.environ["JAC_SEAL_NO_NATIVE"] = saved_skip;
        }
        if saved_dbg is not None {
            os.environ["JAC_NA_DEBUG"] = saved_dbg;
        }
    }
    return (arts, buf.getvalue(), tmp);
}


test "a fully lowerable module still seals and its artifact is live" {
    (arts, err, tmp) = _seal("seal_clean.jac");
    try {
        assert arts is not None , f"clean module failed the seal:\n{err}";
        assert "fixtures.seal_clean" in arts , f"unexpected artifacts: {list(arts)}";
        rec = arts["fixtures.seal_clean"];
        lib = Path(tmp) / rec["lib"];
        assert lib.is_file() , f"no shared library at {lib}";
        assert hashlib.sha256(lib.read_bytes()).hexdigest() == rec["lib_sha256"] , (
            "manifest lib_sha256 does not match the artifact on disk"
        );
        layout = json.loads((Path(tmp) / rec["layout"]).read_text(encoding="utf-8"));
        assert "run" in layout["functions"] , f"exports: {sorted(layout['functions'])}";
        assert "Counter.bump" in layout["methods"] , (
            f"methods: {sorted(layout['methods'])}"
        );
        assert "canary" in err.lower() , (
            f"the seal accepted an artifact without running the canary:\n{err}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "an un-lowerable method fails the seal with an actionable diagnostic" {
    (arts, err, tmp) = _seal("seal_demoted_method.jac");
    try {
        assert arts is None , (
            "the seal accepted a module whose Gauge.unlowerable demoted; in a "
            f"sealed artifact that demotion ships as an abort stub. Got: {arts}"
        );
        assert "Gauge.unlowerable" in err , (
            f"the diagnostic does not name the offending method:\n{err}"
        );
        assert "abort stub" in err , (
            f"the diagnostic does not say what shipping the demotion costs:\n{err}"
        );
        assert "NATIVE_SEAL_DEMOTION_WAIVERS" in err , (
            f"the diagnostic does not point at the waiver escape hatch:\n{err}"
        );
        assert "JAC_NA_DEBUG" in err , (
            f"the diagnostic does not name the debug gate that explains it:\n{err}"
        );
        assert "eval" in err , (
            f"the diagnostic drops the reason the method could not lower:\n{err}"
        );
        assert not list(Path(tmp).rglob("*.so")) , (
            "a refused seal still wrote a shared library into the output tree"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "waiving that exact method seals and says so; waiving another does not" {
    (arts, err, tmp) = _seal(
        "seal_demoted_method.jac",
        waivers={"seal_demoted_method.jac": ("Gauge.unlowerable", )}
    );
    try {
        assert arts is not None , f"a waived demotion still failed the seal:\n{err}";
        assert "fixtures.seal_demoted_method" in arts , f"artifacts: {list(arts)}";
        assert "Gauge.unlowerable" in err , (
            f"a waived demotion must still be announced by name:\n{err}"
        );
        assert "waiv" in err.lower() , (
            f"the seal did not say the demotion was waived:\n{err}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }

    (other, err2, tmp2) = _seal(
        "seal_demoted_method.jac", waivers={"seal_demoted_method.jac": ("Gauge.good", )}
    );
    try {
        assert other is None , (
            "the waiver list is per-method: naming Gauge.good must not launder "
            f"Gauge.unlowerable. Got: {other}"
        );
        assert "Gauge.unlowerable" in err2 , err2;
    } finally {
        shutil.rmtree(tmp2, ignore_errors=True);
    }
}


test "the canary rejects a broken artifact and accepts a live one" {
    (arts, err, tmp) = _seal("seal_clean.jac");
    try {
        assert arts is not None , err;
        rec = arts["fixtures.seal_clean"];
        lib = Path(tmp) / rec["lib"];
        layout = json.loads((Path(tmp) / rec["layout"]).read_text(encoding="utf-8"));
        exports = sorted(layout["functions"].keys());

        assert seal_native_canary(str(lib), exports) == "" , (
            "the canary rejected a live artifact the seal just produced"
        );

        # Break a *copy*: truncating a mapped ELF in place drops even the
        # copy-on-write pages holding glibc's relocated .dynamic entries, and
        # the next dlopen in this process would segfault walking the stale
        # soname (glibc _dl_map_object, dl-load.c).
        broken = Path(tmp) / "broken_copy.so";
        broken.write_bytes(lib.read_bytes()[:256]);
        why = seal_native_canary(str(broken), exports);
        assert why , "a truncated artifact passed the canary";
        assert "dlopen" in why.lower() , f"unhelpful canary reason: {why}";

        absent = seal_native_canary(str(lib), exports + ["__jac_no_such_export"]);
        assert "__jac_no_such_export" in absent , (
            f"the canary did not name the absent export: {absent}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "JAC_NA_DEBUG explains the demotion behind a refused seal" {
    (arts, err, tmp) = _seal("seal_demoted_method.jac", na_debug=True);
    try {
        assert arts is None , f"gate did not fire under JAC_NA_DEBUG: {arts}";
        assert "NA_DEBUG demote Gauge.unlowerable" in err , (
            f"JAC_NA_DEBUG=1 did not explain the demotion:\n{err}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }

    (quiet_arts, quiet_err, tmp2) = _seal("seal_demoted_method.jac");
    try {
        assert quiet_arts is None;
        assert "NA_DEBUG demote" not in quiet_err , (
            f"the NA_DEBUG trace leaked with the gate off:\n{quiet_err}"
        );
    } finally {
        shutil.rmtree(tmp2, ignore_errors=True);
    }
}
