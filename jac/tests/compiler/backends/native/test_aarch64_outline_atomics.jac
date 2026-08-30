"""The aarch64 LSE outline-atomics helpers a sealed artifact has to carry itself.

The aarch64 C floor (pbs's libcrypto, libpython and friends) is built with
`-moutline-atomics`, so every atomic in it compiles to a call into the LSE
dispatch family -- `__aarch64_ldadd4_relax` and ninety-nine siblings. Those
helpers live only in a static libgcc/compiler-rt: `libgcc_s.so.1` exports not
one of them. Nothing in the floor set defines them either, so a sealed shared
library linked perfectly clean and then died at `dlopen` with

    libjac_unitree.so: undefined symbol: __aarch64_ldadd4_relax

Executables link the same floor archives and pay the same debt. Once the
launcher stopped being a Zig-linked stub and became `jac nacompile --strict
launcher/launcher.jac` (#8468), nothing supplied compiler_rt for it any more,
and the linux/arm64 `jac` binary linked clean and then refused to start with

    jac: symbol lookup error: jac: undefined symbol: __aarch64_ldset8_acq_rel

(#8727). So the emitter hangs off `_finalize_native_ir`, the one point every
`nacompile` artifact passes through -- shared library and executable alike --
and it is keyed on the TARGET triple, not on `platform.machine()`: the host
that cross-compiles an aarch64 image is usually an x86_64 runner.

Our own codegen is not the source and cannot be the fix: under the exact target
machine `shared_emit` builds, LLVM lowers `atomicrmw` to inline `ldxr`/`stxr`
and never calls a helper. The vendored objects are the callers, so the artifact
has to bring the callees. The vendored `libcompiler_rt.a` does define all one
hundred, but as a single 1.9 MB object that also redefines `strlen`, `memset`
and `memcmp` -- merging it would collide with libc. So the family is emitted as
module-level assembly instead, ~2.4 KB of it, `.weak` and `.hidden` so it can
neither collide with nor escape into anything else.

These helpers use a restricted register contract: a caller may assume only x0,
x1, x15, x16, x17 and the flags are clobbered. That rules out writing them in
IR -- no LLVM calling convention matches -- which is why they are assembly, and
why these tests exist. They always take the LL/SC path rather than dispatching
on `__aarch64_have_lse_atomics`, which is correct on every ARMv8 and costs only
the LSE fast path.

Pinned here on every host: the family is complete and every member is weak and
hidden, both restated from the ABI's own axes rather than read back out of the
generator, and the block is well-formed IR. Pinned only on an aarch64 host: that
LLVM's assembler accepts every instruction and emits every symbol -- module asm
needs the MC assembly parser, and the shim exports only the *native* one, so a
cross-host run cannot assemble it.

Not pinned here at all, because it needs an aarch64 machine: the semantics. Each
helper was run under qemu-aarch64 against a C harness checking the returned old
value, the stored new value, sub-word CAS's zero-extension of a caller's wide
`expected`, and cas16's paired compare -- all four orderings of all of it.
"""

import jaclang.compiler.backends.native.llvm.binding as llvm;
import from jaclang.compiler.backends.native.shared_emit {
    aarch64_floor_atomics_ir,
    aarch64_outline_atomics_ir
}
import from jaclang.cli.commands.nacompile { _finalize_native_ir }

glob EXEC_STUB = 'define void @"jac_entry"() {\nentry:\n  ret void\n}\n';

"""Every symbol the LSE outline-atomics ABI defines, spelled out from its axes."""
def _abi_family -> list[str] {
    names: list[str] = [];
    for order in ["relax", "acq", "rel", "acq_rel"] {
        for size in [1, 2, 4, 8] {
            for op in ["ldadd", "ldclr", "ldeor", "ldset", "swp", "cas"] {
                names.append(f"__aarch64_{op}{size}_{order}");
            }
        }
        names.append(f"__aarch64_cas16_{order}");
    }
    return names;
}

"""The generated block with its `module asm "..."` wrapper peeled back off."""
def _raw_asm -> list[str] {
    out: list[str] = [];
    for ln in aarch64_outline_atomics_ir().splitlines() {
        s = ln.strip();
        if s.startswith("module asm \"") and s.endswith("\"") {
            out.append(s[len("module asm \""):-1]);
        }
    }
    return out;
}

test "the emitted family covers the whole outline-atomics ABI" {
    defined = {
        ln[:-1]
        for ln in _raw_asm()
        if ln.endswith(":") and not ln.startswith(".")
    };
    want = _abi_family();
    assert len(want) == 100 , f"the ABI has 100 helpers, not {len(want)}";
    missing = sorted(
        {
            n
            for n in want
            if n not in defined
        }
    );
    assert not missing , (
        f"{len(missing)} outline-atomics helper(s) unemitted, so a floor object "
        f"calling one would leave the artifact unloadable: {missing[:6]}"
    );
    assert "__aarch64_have_lse_atomics" in defined , (
        "the LSE feature flag must be defined too: an object carrying its own "
        "copy of the helpers references it directly"
    );
}

test "every helper is weak and hidden, so it neither collides nor escapes" {
    asm = _raw_asm();
    for nm in _abi_family() {
        assert f"  .weak {nm}" in asm , (
            f"{nm} is not weak; a floor member carrying its own copy would "
            "make this a duplicate-symbol link failure"
        );
        assert f"  .hidden {nm}" in asm , (
            f"{nm} is not hidden; it would join the artifact's dynamic symbol "
            "table and interpose on every other library's copy"
        );
    }
}

test "an aarch64 host assembles every instruction and emits every symbol" {
    # Module-level asm is assembled by the MC layer's *assembly parser*, and the
    # shim exports only LLVMPY_InitializeNativeAsmParser -- there is no
    # all-targets counterpart to reach for. So this can only run for real where
    # the host is the target. Writing it found the matching production bug: the
    # shared-library emitter initialized the asm PRINTERS and no parser at all,
    # which segfaults outright the moment a module carries asm.
    import platform;

    if platform.machine() not in ["aarch64", "arm64"] {
        return;
    }
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    llvm.initialize_native_asmparser();
    src = (
        "target triple = \"aarch64-unknown-linux-gnu\"\n" + aarch64_outline_atomics_ir()
    );
    mod = llvm.parse_assembly(src);
    mod.verify();
    tgt = llvm.Target.from_triple("aarch64-unknown-linux-gnu");
    tm = tgt.create_target_machine(opt=2, reloc="pic", codemodel="small");
    blob = tm.emit_object(mod);
    assert len(blob) > 0 , "the assembler produced no object at all";
    absent = sorted(
        {
            nm
            for nm in _abi_family()
            if nm.encode("utf-8") not in blob
        }
    );
    assert not absent , (
        f"{len(absent)} helper(s) never reached the object's symbol table: "
        f"{absent[:6]}"
    );
}

test "the asm block is well-formed IR on every host, not just aarch64" {
    # Parsing is host-independent. It does not assemble the asm, but it does
    # prove the block is well-formed IR -- a stray quote in a `module asm` line
    # would take down every sealed artifact on every platform, not only this
    # one, and that must not wait for a release leg to surface.
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    src = (
        "target triple = \"aarch64-unknown-linux-gnu\"\n" + aarch64_outline_atomics_ir()
    );
    mod = llvm.parse_assembly(src);
    mod.verify();
    text = str(mod);
    for nm in _abi_family() {
        assert nm in text , f"{nm} did not survive into the parsed module";
    }
}


"""The IR `jac nacompile` hands to LLVM for one target, straight off the
production finalization point. Every argument but the ones a test varies is
the launcher's own shape: a plain executable, not shared, not Windows, not
macOS."""
def _finalized(
    triple: str,
    clib_paths: list[str],
    shared: bool = False,
    is_macos: bool = False,
    static_musl: bool = False
) -> str {
    (out, _exports) = _finalize_native_ir(
        llvm_ir_str=EXEC_STUB,
        triple=triple,
        clib_paths=clib_paths,
        manifest=None,
        shared=shared,
        is_windows=False,
        is_macos=is_macos,
        static_musl=static_musl
    );
    return out;
}


test "the aarch64 executable path defines the whole family (issue #8727)" {
    # This host is x86_64 in CI and on every dev box that is not an ARM Mac, so
    # a pass here is also the proof that the decision follows the TARGET and not
    # `platform.machine()` -- the bug that made the injection wrong under the
    # cross-compiling release legs.
    ir = _finalized("aarch64-unknown-linux-gnu", ["libz.so"]);
    assert "__aarch64_ldset8_acq_rel" in ir , (
        "the aarch64 executable path emitted no __aarch64_ldset8_acq_rel; a "
        "floor object calling it leaves the binary unable to start at all "
        "(`jac: symbol lookup error: jac: undefined symbol: "
        "__aarch64_ldset8_acq_rel`)"
    );
    missing = sorted(
        {
            n
            for n in _abi_family()
            if n not in ir
        }
    );
    assert not missing , (
        f"{len(missing)} outline-atomics helper(s) missing from the aarch64 "
        f"executable's IR: {missing[:6]}"
    );
}


test "the static-musl executable path defines them too" {
    ir = _finalized("aarch64-unknown-linux-musl", ["libz.so"], static_musl=True);
    assert "__aarch64_ldset8_acq_rel" in ir , (
        "a fully static aarch64 executable merges the same floor archive "
        "members, so it needs the same callees"
    );
}


test "the aarch64 shared-library path defines them too" {
    ir = _finalized("aarch64-unknown-linux-gnu", ["libz.so"], shared=True);
    assert "__aarch64_ldset8_acq_rel" in ir , (
        "`jac nacompile --shared` links the floor archives as well; this is "
        "the dlopen failure the family was first written for"
    );
}


test "a non-aarch64 target carries none of them" {
    ir = _finalized("x86_64-unknown-linux-gnu", ["libz.so"]);
    assert "__aarch64_" not in ir , (
        "the helpers are aarch64 machine code; an x86_64 artifact carrying "
        "them would not assemble"
    );
}


test "an artifact that links no floor archive carries none of them" {
    ir = _finalized("aarch64-unknown-linux-gnu", []);
    assert "__aarch64_" not in ir , (
        "our own codegen never calls these -- with no vendored objects in the "
        "link there is no caller, so nothing to define"
    );
}


test "an aarch64 Mach-O artifact carries none of them" {
    ir = _finalized("arm64-apple-darwin", ["libz.dylib"], is_macos=True);
    assert "__aarch64_" not in ir , (
        "`.hidden` and `%function` are ELF directives, and Apple's toolchain "
        "supplies the helpers itself; emitting them here would fail to "
        "assemble"
    );
}


test "the finalized aarch64 executable IR still parses" {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    src = (
        "target triple = \"aarch64-unknown-linux-gnu\"\n"
        + _finalized("aarch64-unknown-linux-gnu", ["libz.so"])
    );
    mod = llvm.parse_assembly(src);
    mod.verify();
    text = str(mod);
    for nm in _abi_family() {
        assert nm in text , (f"{nm} did not survive into the parsed executable module");
    }
}


test "the emitter itself is gated on the target, not the host" {
    # `emit_shared_library` is the other consumer, so the gate is pinned on the
    # shared helper directly as well as through the nacompile path above.
    assert aarch64_floor_atomics_ir("aarch64-unknown-linux-gnu", ["libz.so"]) != "";
    assert aarch64_floor_atomics_ir("aarch64-unknown-linux-gnu", []) == "";
    assert aarch64_floor_atomics_ir("x86_64-unknown-linux-gnu", ["libz.so"]) == "";
    assert aarch64_floor_atomics_ir("arm64-apple-darwin", ["libz.dylib"]) == "";
    assert aarch64_floor_atomics_ir("aarch64-pc-windows-msvc", ["z.lib"]) == "";
}
