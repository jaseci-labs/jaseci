"""Emit a real aarch64-linux object out of the executable path's finalized IR.

Run as a subprocess by test_aarch64_outline_atomics.jac: the failure this pins
is an LLVM `report_fatal_error`, which aborts the process rather than raising,
so it cannot be caught in-process.

The outline-atomics helpers are `module asm`, and assembling module asm needs a
registered asm parser FOR THE TARGET. Parsing the IR does not: `parse_assembly`
accepts the block happily, which is why the emit has to run all the way to an
object here.
"""

import jaclang.compiler.backends.native.llvm.binding as llvm;
import from jaclang.compiler.backends.native.shared_emit { init_object_codegen }
import from jaclang.cli.commands.nacompile { _finalize_native_ir }

glob TRIPLE = "aarch64-unknown-linux-gnu",
     EM_AARCH64 = 183;

with entry {
    init_object_codegen();
    (ir, _exports) = _finalize_native_ir(
        llvm_ir_str='define void @"jac_entry"() {\nentry:\n  ret void\n}\n',
        triple=TRIPLE,
        clib_paths=["libz.so"],
        manifest=None,
        shared=False,
        is_windows=False,
        is_macos=False,
        static_musl=False
    );
    mod = llvm.parse_assembly(f'target triple = "{TRIPLE}"\n' + ir);
    mod.verify();
    tm = llvm.Target.from_triple(TRIPLE).create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );
    blob = tm.emit_object(mod);
    if blob[:4] != b"\x7fELF" {
        print("EMIT_NOT_ELF");
    } elif (blob[18] + (blob[19] * 256)) != EM_AARCH64 {
        print("EMIT_WRONG_MACHINE");
    } elif blob.find(b"__aarch64_ldset8_acq_rel") < 0 {
        print("EMIT_MISSING_SYMBOL");
    } else {
        print("EMIT_OK");
    }
}
