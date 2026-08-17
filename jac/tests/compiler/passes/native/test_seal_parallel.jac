"""The seal's worker pool: same artifacts, same refusals, one process per root.

Sealing thirteen native roots in one process cost both time and memory: the
roots are independent (the single ordering edge is that the materializer root is
generated from unitree's layout), so a sequential seal left every core but one
idle, and each root's materializer crossings strand their native trees in the
process that built them, so a single-process seal accumulated every root's
high-water mark at once. Sealing each root in its own worker process fixes both
halves with one mechanism -- and moves the whole seal across a process boundary,
which is exactly the kind of change that can quietly alter what gets sealed.

So these tests pin that it does not:

1. **The artifacts are the same bytes.** A pooled seal and a sequential seal of
   the same roots agree on every artifact record -- library and layout sha256
   included -- and on the seal index the parent writes. Byte-determinism of the
   emitted artifact is a maintained invariant (`test_seal_incremental.jac` keys
   reuse on it); the pool must not be the thing that breaks it.
2. **The ordering edge still refuses.** The materializer root without unitree's
   layout is refused with the same named mechanism it always was, now raised
   inside a worker and replayed by the parent.
3. **A refusing root fails the whole seal, out loud.** The refusal diagnostics
   are the product of this seal, not incidental logging, so a worker's text must
   reach the operator verbatim and the seal must return None -- the sequential
   failure contract, unchanged by the process boundary.
4. **The job count is decided, not guessed.** `JAC_SEAL_JOBS` is the documented
   override in both directions, and `JAC_SEAL_JOBS=1` is the escape back to the
   original single-process seal.

The seals below use the two cheapest real roots; the rest of the file's cases
refuse before any compiler runs, so the file's cost is two artifacts twice over
and change.
"""

import contextlib;
import io;
import os;
import shutil;
import tempfile;
import jaclang;
import from pathlib { Path }
import jaclang.utils.precompile_bytecode as pb;

glob PKG_PATH = Path(jaclang.__file__).parent,
     SMALL_ROOTS: tuple = (
         "jac0core/passes/annex_pass.jac",
         "jac0core/passes/endpoint_effect_pass.jac"
     ),
     ABSENT_ROOTS: tuple = (
         "compiler/native_materialize.jac",
         "jac0core/passes/no_such_seal_root.jac"
     );

def _triple -> str {
    import jaclang.compiler.passes.native.llvm.binding as llvm;
    return llvm.get_default_triple();
}

"""Seal `modules` into a fresh tree at `jobs`, returning (artifacts, out, stderr)."""
def _seal(modules: tuple, jobs: int) -> tuple {
    out = tempfile.mkdtemp(prefix=f"jac_seal_pool_{jobs}_");
    buf = io.StringIO();
    with contextlib.redirect_stderr(buf) {
        arts = pb.seal_native_artifacts(
            PKG_PATH, Path(out), modules=modules, jobs=jobs
        );
    }
    return (arts, out, buf.getvalue(), );
}

test "a pooled seal and a sequential seal agree byte for byte" {
    (seq, seq_out, _seq_err) = _seal(SMALL_ROOTS, 1);
    (par, par_out, _par_err) = _seal(SMALL_ROOTS, 2);
    try {
        assert seq is not None , "the sequential seal refused; nothing to compare";
        assert par is not None , "the pooled seal refused where the sequential one did not";
        assert sorted(seq.keys()) == sorted(par.keys()) , (
            f"the pool sealed a different module set: {sorted(par.keys())} "
            f"vs {sorted(seq.keys())}"
        );
        for name in sorted(seq.keys()) {
            assert seq[name] == par[name] , (
                f"{name} differs between the pooled and sequential seals -- the "
                f"artifact record is not the same: {par[name]} vs {seq[name]}"
            );
        }
        triple = _triple();
        seq_index = pb.read_seal_index(Path(seq_out), triple);
        par_index = pb.read_seal_index(Path(par_out), triple);
        assert seq_index , "the sequential seal wrote no index to compare against";
        assert seq_index == par_index , (
            "the parent's seal index differs after a pooled seal; the workers' "
            "records did not aggregate to the same thing the loop recorded"
        );
    } finally {
        shutil.rmtree(seq_out, ignore_errors=True);
        shutil.rmtree(par_out, ignore_errors=True);
    }
}

test "the pool still refuses the materializer without unitree's layout" {
    (arts, out, err) = _seal(ABSENT_ROOTS, 2);
    try {
        assert arts is None , "the pool sealed a materializer root it cannot generate";
        assert "the materializer root is generated from the unitree layout" in err , (
            f"the ordering refusal did not survive the worker boundary: {err}"
        );
        assert "seal jac0core/unitree.jac first" in err , (
            f"the refusal lost the instruction that makes it actionable: {err}"
        );
    } finally {
        shutil.rmtree(out, ignore_errors=True);
    }
}

test "a refusing root fails the whole pooled seal and replays its worker's text" {
    (arts, out, err) = _seal(ABSENT_ROOTS, 2);
    try {
        assert arts is None , "a refused root did not fail the seal";
        assert "NATIVE SEAL: missing source" in err , (
            f"the missing-source refusal never reached the parent: {err}"
        );
        assert "no_such_seal_root.jac" in err , (
            f"the refusal did not name the root it refused: {err}"
        );
        for rel in ABSENT_ROOTS {
            assert f"the worker sealing {rel} refused it" in err , (
                f"the parent did not attribute {rel}'s refusal to its worker: {err}"
            );
        }
    } finally {
        shutil.rmtree(out, ignore_errors=True);
    }
}

test "JAC_SEAL_JOBS decides the pool size, and 1 means the sequential seal" {
    prior = os.environ.get(pb.NATIVE_SEAL_JOBS_ENV);
    try {
        os.environ[pb.NATIVE_SEAL_JOBS_ENV] = "1";
        assert pb.seal_jobs() == 1 , "JAC_SEAL_JOBS=1 must resolve to one job";
        os.environ[pb.NATIVE_SEAL_JOBS_ENV] = "5";
        assert pb.seal_jobs() == 5 , "JAC_SEAL_JOBS must win over the auto-size";
        os.environ[pb.NATIVE_SEAL_JOBS_ENV] = "not-a-number";
        assert pb.seal_jobs() >= 1 , "an unparsable JAC_SEAL_JOBS must fall back, not raise";
        assert pb.seal_jobs(3) == 3 , "an explicit request must be honoured";
        assert pb.seal_jobs(0) == 1 , "a nonsense request must clamp to one job";
    } finally {
        if prior is None {
            os.environ.pop(pb.NATIVE_SEAL_JOBS_ENV, None);
        } else {
            os.environ[pb.NATIVE_SEAL_JOBS_ENV] = prior;
        }
    }
}

test "the auto-size is bounded by memory and cores, never zero" {
    jobs = pb.seal_jobs(None) if not os.environ.get(pb.NATIVE_SEAL_JOBS_ENV) else 1;
    assert jobs >= 1 , "the auto-size must never return a job count below one";
    assert jobs <= (os.cpu_count() or 1) , (
        "the auto-size must not oversubscribe the machine's cores"
    );
    assert pb.seal_mem_available_gib() >= 0.0 , (
        "the memory probe must answer a number even where it cannot read one"
    );
}
