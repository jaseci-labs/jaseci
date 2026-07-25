#!/usr/bin/env python3
"""Committed cross-tool FFI producer for JacInteropBench (Section sec:xtool).

Answers STEPS.md #39 ("make cross-tool FFI comparisons truly matched") and the
"more kernels" scope expansion in the Related Work / Conclusion. Prior to this
script the tab:xtool numbers had no committed producer; here every Python-side
binding is built and timed from one source of truth, with a differential-identity
oracle spanning toolchains.

What it does, for each KERNEL (sqrt / struct-by-value / bytes-digest) x each
TOOLCHAIN (ctypes, cffi ABI, raw METH_O C-extension, pybind11, PyO3/Rust):

  * MATCHED  -- per-foreign-call cost under the kernel's exact loop, warmed and
                digest-verified (the honest end-to-end number a user pays).
  * ISOLATED -- the boundary alone: a tight call loop minus an empty loop, so
                CPython interpreter dispatch is differenced out and only the
                call transition + argument conversion remains.

Plus each side's no-FFI arithmetic floor (pure Python) so "overhead above the
matching no-FFI reference" (STEPS #39) is reportable.

All variants recompute one byte-identical digest per kernel; the run ABORTS if
any toolchain disagrees -- the cross-toolchain oracle is load-bearing, not
decorative. Missing toolchains (no compiler, no pybind11, no cargo) are recorded
as skipped with a reason rather than silently dropped.

The Jac-native FFI point is measured by a separate path (the existing
iop_ffi_scalar kernel via `jac run`); it is pulled in with --jac-na so this
script stays a pure Python-side cross-tool producer that also anchors to Jac.

Usage:
    python3 scripts/xtool_ffi.py --reps 5 --matched-n 2000 --isolated-n 2000000 \
        --out results/controlled/xtool_ffi.json
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import shutil
import statistics
import subprocess
import sys
import sysconfig
import tempfile
import time
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "jac" / "examples" / "interopbench"

# ---------------------------------------------------------------------------
# Kernel definitions. Each kernel is one C function signature plus the exact
# host loop that consumes it. The Python "ref" is the identical arithmetic with
# no foreign call, so overhead-above-floor is well defined. digest() must agree
# across every toolchain AND the ref.
# ---------------------------------------------------------------------------

# C source shared by ctypes / cffi / C-ext / pybind11. One translation unit.
C_FIXTURE = r"""
#include <math.h>
#include <stdint.h>
#include <stddef.h>

/* sqrt kernel: integer sqrt of a perfect square -> exact i. */
long ib_sqrt(double x) { return (long)sqrt(x); }

/* struct-by-value kernel: dot product of two 3-vectors passed BY VALUE.
   Exercises the register-vs-byval ABI distinction the paper calls out. */
typedef struct { double x, y, z; } Vec3;
double ib_dot(Vec3 a, Vec3 b) { return a.x*b.x + a.y*b.y + a.z*b.z; }

/* bytes kernel: FNV-1a over a small buffer passed by pointer+length.
   Exercises pointer/length marshalling (the string/bytes seam). */
uint64_t ib_fnv1a(const uint8_t *p, size_t n) {
    uint64_t h = 1469598103934665603ULL;
    for (size_t i = 0; i < n; i++) { h ^= p[i]; h *= 1099511628211ULL; }
    return h;
}
"""

MATCHED_N_DEFAULT = 2000
ISOLATED_N_DEFAULT = 2_000_000
BUF_LEN = 16  # fnv1a buffer length per call


def sqrt_ref(n: int) -> int:
    acc = 0
    for i in range(1, n + 1):
        acc += int(math.sqrt(float(i * i)))
    return acc


def struct_ref(n: int) -> int:
    acc = 0
    for i in range(1, n + 1):
        # dot({i,i,i},{i,i,i}) = 3*i*i, exact in double for our range
        acc += int(3.0 * float(i) * float(i))
    return acc


def bytes_ref(n: int) -> int:
    acc = 0
    for i in range(1, n + 1):
        buf = (i & 0xFF).to_bytes(1, "little") * BUF_LEN
        h = 1469598103934665603
        for b in buf:
            h ^= b
            h = (h * 1099511628211) & 0xFFFFFFFFFFFFFFFF
        acc = (acc ^ h) & 0xFFFFFFFFFFFFFFFF
    return acc


KERNELS = {
    "sqrt": {"digest_prefix": "sqrt", "ref": sqrt_ref},
    "struct": {"digest_prefix": "struct", "ref": struct_ref},
    "bytes": {"digest_prefix": "bytes", "ref": bytes_ref},
}


def digest(kernel: str, value: int) -> str:
    return f"{KERNELS[kernel]['digest_prefix']}:{value}"


# ---------------------------------------------------------------------------
# Timing helper: median-of-reps per-call ns.
# ---------------------------------------------------------------------------
def time_loop(fn: Callable[[], object], reps: int) -> float:
    """Return median wall-ns of fn() across reps (fn does its own iteration)."""
    samples = []
    for _ in range(reps):
        t0 = time.perf_counter_ns()
        fn()
        samples.append(time.perf_counter_ns() - t0)
    return statistics.median(samples)


# ---------------------------------------------------------------------------
# Toolchain builders. Each returns a dict of callables:
#   sqrt(x)->long, dot_call(i)->float, fnv(buf)->int   (raw single calls)
# plus we build the matched loops in Python around them. Returns None + reason
# if the toolchain can't be built here.
# ---------------------------------------------------------------------------
def _compile_shared(workdir: Path) -> Path | None:
    """Compile C_FIXTURE to a shared lib for ctypes/cffi. gcc required."""
    if not shutil.which("gcc"):
        return None
    src = workdir / "ib_fixture.c"
    src.write_text(C_FIXTURE)
    so = workdir / "libibfixture.so"
    p = subprocess.run(
        ["gcc", "-O2", "-fPIC", "-shared", str(src), "-o", str(so), "-lm"],
        capture_output=True,
    )
    return so if p.returncode == 0 else None


def build_ctypes(workdir: Path) -> tuple[dict | None, str | None]:
    import ctypes

    so = _compile_shared(workdir)
    if so is None:
        return None, "gcc missing or C fixture failed to compile"
    lib = ctypes.CDLL(str(so))
    lib.ib_sqrt.restype = ctypes.c_long
    lib.ib_sqrt.argtypes = [ctypes.c_double]

    class Vec3(ctypes.Structure):
        _fields_ = [
            ("x", ctypes.c_double),
            ("y", ctypes.c_double),
            ("z", ctypes.c_double),
        ]

    lib.ib_dot.restype = ctypes.c_double
    lib.ib_dot.argtypes = [Vec3, Vec3]
    lib.ib_fnv1a.restype = ctypes.c_uint64
    lib.ib_fnv1a.argtypes = [ctypes.c_char_p, ctypes.c_size_t]

    def dot_call(i: int) -> float:
        v = Vec3(float(i), float(i), float(i))
        return lib.ib_dot(v, v)

    return {
        "sqrt": lib.ib_sqrt,
        "dot": dot_call,
        "fnv": lambda buf: lib.ib_fnv1a(buf, len(buf)),
    }, None


def build_cffi(workdir: Path) -> tuple[dict | None, str | None]:
    try:
        import cffi
    except ImportError:
        return None, "cffi not importable"
    so = _compile_shared(workdir)
    if so is None:
        return None, "gcc missing or C fixture failed to compile"
    ffi = cffi.FFI()
    ffi.cdef(
        "long ib_sqrt(double);"
        "typedef struct { double x, y, z; } Vec3;"
        "double ib_dot(Vec3 a, Vec3 b);"
        "uint64_t ib_fnv1a(const uint8_t *p, size_t n);"
    )
    lib = ffi.dlopen(str(so))

    def dot_call(i: int) -> float:
        a = ffi.new("Vec3 *", [float(i), float(i), float(i)])[0]
        return lib.ib_dot(a, a)

    def fnv(buf: bytes) -> int:
        return lib.ib_fnv1a(buf, len(buf))

    return {"sqrt": lib.ib_sqrt, "dot": dot_call, "fnv": fnv}, None


C_EXT_SOURCE = r"""
#include <Python.h>
#include <math.h>
#include <stdint.h>

static PyObject* m_sqrt(PyObject* self, PyObject* a) {
    double x = PyFloat_AsDouble(a);
    return PyLong_FromLong((long)sqrt(x));
}
/* dot({i,i,i},{i,i,i}) taking the scalar i, to keep a single METH_O arg while
   still crossing for a by-value-ish struct computation. */
static PyObject* m_dot(PyObject* self, PyObject* a) {
    double i = PyFloat_AsDouble(a);
    typedef struct { double x, y, z; } Vec3;
    Vec3 v = { i, i, i };
    double r = v.x*v.x + v.y*v.y + v.z*v.z;
    return PyFloat_FromDouble(r);
}
static PyObject* m_fnv(PyObject* self, PyObject* a) {
    Py_buffer view;
    if (PyObject_GetBuffer(a, &view, PyBUF_SIMPLE) != 0) return NULL;
    uint64_t h = 1469598103934665603ULL;
    const uint8_t* p = (const uint8_t*)view.buf;
    for (Py_ssize_t i = 0; i < view.len; i++) { h ^= p[i]; h *= 1099511628211ULL; }
    PyBuffer_Release(&view);
    return PyLong_FromUnsignedLongLong(h);
}
static PyObject* m_noop(PyObject* self, PyObject* a) { Py_RETURN_NONE; }
static PyMethodDef Methods[] = {
    {"sqrt", m_sqrt, METH_O, ""}, {"dot", m_dot, METH_O, ""},
    {"fnv", m_fnv, METH_O, ""}, {"noop", m_noop, METH_O, ""},
    {NULL, NULL, 0, NULL}
};
static struct PyModuleDef mod = {PyModuleDef_HEAD_INIT, "ib_cext", "", -1, Methods};
PyMODINIT_FUNC PyInit_ib_cext(void) { return PyModule_Create(&mod); }
"""


def _build_ext_module(
    workdir: Path, name: str, source: str, extra: list[str], lang_cpp: bool = False
) -> tuple[object | None, str | None]:
    """Compile a Python C/C++ extension module and import it. Returns module."""
    cc = sysconfig.get_config_var("CC") or ("g++" if lang_cpp else "gcc")
    if lang_cpp:
        cc = shutil.which("g++") or "g++"
    inc = sysconfig.get_path("include")
    src = workdir / f"{name}.c" if not lang_cpp else workdir / f"{name}.cpp"
    src.write_text(source)
    so = workdir / f"{name}.so"
    cmd = [cc, "-O2", "-fPIC", "-shared", f"-I{inc}", *extra, str(src), "-o", str(so)]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        return None, f"compile failed: {p.stderr.strip().splitlines()[-1:]}"
    spec = importlib.util.spec_from_file_location(name, so)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod, None


def build_cext(workdir: Path) -> tuple[dict | None, str | None]:
    if not shutil.which("gcc"):
        return None, "gcc missing"
    mod, err = _build_ext_module(workdir, "ib_cext", C_EXT_SOURCE, [])
    if mod is None:
        return None, err
    return {
        "sqrt": mod.sqrt,
        "dot": lambda i: mod.dot(float(i)),
        "fnv": mod.fnv,
        "noop": mod.noop,
    }, None


PYBIND_SOURCE = r"""
#include <pybind11/pybind11.h>
#include <math.h>
#include <stdint.h>
#include <string_view>
namespace py = pybind11;
static long b_sqrt(double x) { return (long)sqrt(x); }
static double b_dot(double i) {
    struct Vec3 { double x, y, z; } v{ i, i, i };
    return v.x*v.x + v.y*v.y + v.z*v.z;
}
static uint64_t b_fnv(py::buffer b) {
    py::buffer_info info = b.request();
    uint64_t h = 1469598103934665603ULL;
    const uint8_t* p = (const uint8_t*)info.ptr;
    for (ssize_t i = 0; i < info.size; i++) { h ^= p[i]; h *= 1099511628211ULL; }
    return h;
}
PYBIND11_MODULE(ib_pybind, m) {
    m.def("sqrt", &b_sqrt); m.def("dot", &b_dot); m.def("fnv", &b_fnv);
}
"""


def build_pybind(workdir: Path) -> tuple[dict | None, str | None]:
    try:
        import pybind11
    except ImportError:
        return None, "pybind11 not importable"
    if not shutil.which("g++"):
        return None, "g++ missing"
    extra = [f"-I{pybind11.get_include()}", "-std=c++14"]
    mod, err = _build_ext_module(
        workdir, "ib_pybind", PYBIND_SOURCE, extra, lang_cpp=True
    )
    if mod is None:
        return None, err
    return {"sqrt": mod.sqrt, "dot": lambda i: mod.dot(float(i)), "fnv": mod.fnv}, None


PYO3_LIB_RS = r"""
use pyo3::prelude::*;
use pyo3::types::PyBytes;

#[pyfunction]
fn sqrt(x: f64) -> i64 { (x.sqrt()) as i64 }

#[pyfunction]
fn dot(i: f64) -> f64 {
    let (x, y, z) = (i, i, i);
    x*x + y*y + z*z
}

#[pyfunction]
fn fnv(b: &Bound<'_, PyBytes>) -> u64 {
    let mut h: u64 = 1469598103934665603;
    for &byte in b.as_bytes() { h ^= byte as u64; h = h.wrapping_mul(1099511628211); }
    h
}

#[pymodule]
fn ib_pyo3(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(sqrt, m)?)?;
    m.add_function(wrap_pyfunction!(dot, m)?)?;
    m.add_function(wrap_pyfunction!(fnv, m)?)?;
    Ok(())
}
"""

PYO3_CARGO_TOML = """
[package]
name = "ib_pyo3"
version = "0.1.0"
edition = "2021"

[lib]
name = "ib_pyo3"
crate-type = ["cdylib"]

[dependencies]
pyo3 = { version = "0.22", features = ["extension-module", "abi3-py39"] }
"""


def build_pyo3(workdir: Path) -> tuple[dict | None, str | None]:
    if not shutil.which("cargo"):
        return None, "cargo missing"
    crate = workdir / "pyo3crate"
    (crate / "src").mkdir(parents=True, exist_ok=True)
    (crate / "Cargo.toml").write_text(PYO3_CARGO_TOML)
    (crate / "src" / "lib.rs").write_text(PYO3_LIB_RS)
    # PyO3 <=0.22 caps at CPython 3.13; on 3.14+ build against the stable ABI
    # (abi3) with the forward-compat escape hatch. PYO3_PYTHON pins the target
    # interpreter to the one running this script.
    import os

    env = {
        **os.environ,
        "PYO3_PYTHON": sys.executable,
        "PYO3_USE_ABI3_FORWARD_COMPATIBILITY": "1",
    }
    p = subprocess.run(
        ["cargo", "build", "--release"],
        cwd=str(crate),
        capture_output=True,
        text=True,
        env=env,
    )
    if p.returncode != 0:
        return None, f"cargo build failed: {p.stderr.strip().splitlines()[-1:]}"
    built = crate / "target" / "release" / "libib_pyo3.so"
    if not built.exists():
        return None, "cargo build produced no libib_pyo3.so"
    so = workdir / "ib_pyo3.so"
    shutil.copy(built, so)
    spec = importlib.util.spec_from_file_location("ib_pyo3", so)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return {"sqrt": mod.sqrt, "dot": lambda i: mod.dot(float(i)), "fnv": mod.fnv}, None


BUILDERS = {
    "ctypes": build_ctypes,
    "cffi": build_cffi,
    "cext": build_cext,
    "pybind11": build_pybind,
    "pyo3": build_pyo3,
}


# ---------------------------------------------------------------------------
# Matched + isolated measurement over a bound toolchain.
# ---------------------------------------------------------------------------
def matched_digest(kernel: str, calls: dict, n: int) -> int:
    if kernel == "sqrt":
        f = calls["sqrt"]
        acc = 0
        for i in range(1, n + 1):
            acc += int(f(float(i * i)))
        return acc
    if kernel == "struct":
        f = calls["dot"]
        acc = 0
        for i in range(1, n + 1):
            acc += int(f(i))
        return acc
    if kernel == "bytes":
        f = calls["fnv"]
        acc = 0
        for i in range(1, n + 1):
            buf = (i & 0xFF).to_bytes(1, "little") * BUF_LEN
            acc = (acc ^ int(f(buf))) & 0xFFFFFFFFFFFFFFFF
        return acc
    raise ValueError(kernel)


def isolated_per_call_ns(kernel: str, calls: dict, n: int, reps: int) -> float:
    """Tight call loop minus empty loop -> boundary+conversion per call ns."""
    if kernel == "sqrt":
        f = calls["sqrt"]
        arg = 4.0

        def full():
            for _ in range(n):
                f(arg)
    elif kernel == "struct":
        f = calls["dot"]

        def full():
            for _ in range(n):
                f(2)
    else:  # bytes
        f = calls["fnv"]
        buf = b"\x07" * BUF_LEN

        def full():
            for _ in range(n):
                f(buf)

    def empty():
        for _ in range(n):
            pass

    full_ns = time_loop(full, reps)
    empty_ns = time_loop(empty, reps)
    return max(0.0, (full_ns - empty_ns) / n)


def matched_per_call_ns(kernel: str, calls: dict, n: int, reps: int) -> tuple:
    """Per-call cost under the kernel's exact digest loop. Returns (ns, digest)."""
    dg = {"v": None}

    def run():
        dg["v"] = matched_digest(kernel, calls, n)

    total = time_loop(run, reps)
    return total / n, dg["v"]


# ---------------------------------------------------------------------------
# Pure-Python no-FFI floor (matched loop, no foreign call).
# ---------------------------------------------------------------------------
def python_ref_per_call_ns(kernel: str, n: int, reps: int) -> float:
    ref = KERNELS[kernel]["ref"]
    return time_loop(lambda: ref(n), reps) / n


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernels", default=",".join(KERNELS))
    ap.add_argument("--toolchains", default=",".join(BUILDERS))
    ap.add_argument("--matched-n", type=int, default=MATCHED_N_DEFAULT)
    ap.add_argument("--isolated-n", type=int, default=ISOLATED_N_DEFAULT)
    ap.add_argument("--reps", type=int, default=5)
    ap.add_argument(
        "--jac-na",
        action="store_true",
        help="also measure the Jac-native iop_ffi_scalar sqrt point",
    )
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    kernels = [k.strip() for k in args.kernels.split(",") if k.strip()]
    toolchains = [t.strip() for t in args.toolchains.split(",") if t.strip()]

    gov = _governor()
    if gov["governor"] and gov["governor"] != "performance":
        print(
            f"WARNING: governor is '{gov['governor']}' (not 'performance'); "
            f"absolutes will be noisy.",
            file=sys.stderr,
        )

    workdir = Path(tempfile.mkdtemp(prefix="xtool_ffi_"))
    print(f"build dir: {workdir}", file=sys.stderr)

    # Build every requested toolchain once.
    bound: dict[str, dict] = {}
    skipped: dict[str, str] = {}
    for tc in toolchains:
        builder = BUILDERS.get(tc)
        if builder is None:
            skipped[tc] = "unknown toolchain"
            continue
        try:
            calls, err = builder(workdir)
        except Exception as e:  # noqa: BLE001 - report, don't crash the suite
            calls, err = None, f"{type(e).__name__}: {e}"
        if calls is None:
            skipped[tc] = err
            print(f"  SKIP {tc}: {err}", file=sys.stderr)
        else:
            bound[tc] = calls
            print(f"  built {tc}", file=sys.stderr)

    # Reference digests (pure Python) define the oracle target per kernel.
    ref_digests = {k: digest(k, KERNELS[k]["ref"](args.matched_n)) for k in kernels}

    cells: dict = {}
    oracle_ok = True
    for k in kernels:
        py_ref_ns = python_ref_per_call_ns(k, args.matched_n, args.reps)
        tc_rows = {}
        for tc, calls in bound.items():
            matched_ns, mval = matched_per_call_ns(k, calls, args.matched_n, args.reps)
            mdig = digest(k, mval)
            iso_ns = isolated_per_call_ns(k, calls, args.isolated_n, args.reps)
            agree = mdig == ref_digests[k]
            oracle_ok = oracle_ok and agree
            tc_rows[tc] = {
                "matched_per_call_ns": round(matched_ns, 2),
                "isolated_per_call_ns": round(iso_ns, 2),
                "overhead_above_ref_ns": round(matched_ns - py_ref_ns, 2),
                "digest": mdig,
                "digest_ok": agree,
            }
            print(
                f"  {k:7s} {tc:9s} matched={matched_ns:8.1f}ns "
                f"isolated={iso_ns:7.1f}ns digest={mdig} ok={agree}",
                file=sys.stderr,
            )
        cells[k] = {
            "reference_digest": ref_digests[k],
            "python_ref_per_call_ns": round(py_ref_ns, 2),
            "toolchains": tc_rows,
        }

    jac_na = None
    if args.jac_na:
        jac_na = _measure_jac_na_sqrt(args.reps)

    shutil.rmtree(workdir, ignore_errors=True)

    doc = {
        "schema_version": 1,
        "kind": "cross_tool_ffi",
        "captured_utc": datetime.now(UTC).isoformat(),
        "matched_n": args.matched_n,
        "isolated_n": args.isolated_n,
        "reps": args.reps,
        "python": sys.version.split()[0],
        "machine_control": gov,
        "oracle_all_toolchains_agree": oracle_ok,
        "skipped_toolchains": skipped,
        "jac_na_sqrt": jac_na,
        "note": "matched = per foreign call under the kernel loop (warmed, "
        "digest-verified); isolated = tight call loop minus empty loop "
        "(boundary+conversion only). overhead_above_ref = matched minus "
        "the pure-Python no-FFI floor. Digest identity across all "
        "toolchains is the cross-tool oracle.",
        "cells": cells,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=1))
    print(f"wrote {out}", file=sys.stderr)
    if not oracle_ok:
        print("ORACLE FAILED: toolchains disagree on a digest.", file=sys.stderr)
        sys.exit(3)


def _governor() -> dict:
    g = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    t = "/sys/devices/system/cpu/intel_pstate/no_turbo"
    try:
        gov = Path(g).read_text().strip()
        tur = Path(t).read_text().strip() if Path(t).exists() else None
    except OSError:
        gov, tur = None, None
    return {"governor": gov, "turbo_disabled": tur}


def _measure_jac_na_sqrt(reps: int) -> dict | None:
    """Measure the existing Jac-native iop_ffi_scalar kernel via `jac run`."""
    jac = shutil.which("jac")
    if jac is None:
        return {"skipped": "jac not on PATH"}
    cmd = [jac, "run", "kernels/iop_ffi_scalar.na.jac"]
    samples = []
    digest_seen = None
    import re

    per_re = re.compile(rb"m:per_ffi_call_ns=(\d+)")
    dig_re = re.compile(rb"(sqrt:\d+)")
    for _ in range(reps):
        p = subprocess.run(cmd, cwd=str(BENCH), capture_output=True, timeout=120)
        m = per_re.search(p.stdout)
        d = dig_re.search(p.stdout)
        if m:
            samples.append(int(m.group(1)))
        if d:
            digest_seen = d.group(1).decode()
    if not samples:
        return {
            "skipped": "iop_ffi_scalar produced no m:per_ffi_call_ns "
            "(kernel may need nacompile); run manually"
        }
    return {
        "per_ffi_call_ns": statistics.median(samples),
        "samples": samples,
        "digest": digest_seen,
    }


if __name__ == "__main__":
    main()
