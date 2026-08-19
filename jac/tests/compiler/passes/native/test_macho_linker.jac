"""Tests for the Mach-O (macOS) shared-object link path.

These pin the import-provenance rule for dlopen'd artifacts (seal libraries,
JIT/AOT dylibs): an undefined symbol with an explicit `symbol_lib_map` entry
binds two-level to that dylib's ordinal, and every OTHER undefined symbol
binds via the flat-namespace special ordinal -- the `-undefined dynamic_lookup`
shape real linkers emit for plugins -- so it resolves from whatever the host
process has loaded (the launcher dlopens the bundled libpython RTLD_GLOBAL).
The old default bound unmapped symbols to ordinal 1 (libSystem), which made
the first sealed artifact referencing a CPython C-API symbol fail its load
canary on macOS: `Symbol not found: _PyDict_New ... Expected in:
/usr/lib/libSystem.B.dylib`.

The dylib is validated structurally on any host (like test_pe_linker.jac);
the dlopen round trip runs only on a matching darwin host.
"""

import ctypes;
import os;
import struct;
import sys;
import tempfile;
import from jaclang.compiler.passes.native.macho_linker { MachOLinker }
import jaclang.compiler.passes.native.llvm.binding as llvm;

glob MACHO_TRIPLE = "arm64-apple-darwin",
     LC_DYLD_INFO_ONLY = 0x80000022;


"""IR with one unmapped extern (PyDict_New) and one mapped one (malloc)."""
def probe_ir(triple: str) -> str {
    return (
        f'target triple = "{triple}"\n'
        + 'declare ptr @PyDict_New()\n'
        + 'declare ptr @malloc(i64)\n'
        + 'define ptr @jac_probe() {\n'
        + 'entry:\n'
        + '  %d = call ptr @PyDict_New()\n'
        + '  ret ptr %d\n'
        + '}\n'
        + 'define ptr @jac_probe_malloc() {\n'
        + 'entry:\n'
        + '  %p = call ptr @malloc(i64 16)\n'
        + '  ret ptr %p\n'
        + '}\n'
    );
}


"""Emit a Mach-O relocatable object for the given triple."""
def emit_macho_object(triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(probe_ir(triple));
    mod.verify();
    tm = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );
    return tm.emit_object(mod);
}


"""Link the probe object into a dylib and return (path, bytes)."""
def link_dylib(triple: str) -> tuple {
    relobj = emit_macho_object(triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "libprobe.dylib");
    ok = MachOLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        symbol_lib_map={"malloc": "/usr/lib/libSystem.B.dylib"},
        shared=True,
        export_symbols=["jac_probe", "jac_probe_malloc"],
        init_funcs=[],
        soname="libprobe.dylib"
    );
    assert ok , "MachOLinker.link returned False";
    with open(out, "rb") as f {
        img = f.read();
    }
    return (out, img);
}


"""Extract the LC_DYLD_INFO_ONLY bind stream from a 64-bit Mach-O image."""
def bind_stream(img: bytes) -> bytes {
    magic = struct.unpack_from("<I", img, 0)[0];
    assert magic == 0xFEEDFACF , f"not a 64-bit Mach-O: {hex(magic)}";
    ncmds = struct.unpack_from("<I", img, 16)[0];
    off = 32;
    for _i in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", img, off);
        if cmd == LC_DYLD_INFO_ONLY {
            (bind_off, bind_size) = struct.unpack_from("<II", img, off + 16);
            return img[bind_off:bind_off + bind_size];
        }
        off += cmdsize;
    }
    assert False , "no LC_DYLD_INFO_ONLY load command";
}


# ─── tests ───────────────────────────────────────────────────────────────────
test "unmapped undefined symbols bind via flat-namespace lookup" {
    (_out, img) = link_dylib(MACHO_TRIPLE);
    bind = bind_stream(img);
    # per-symbol bind record: [SET_DYLIB op] [0x40 name NUL] [type/seg/DO_BIND]
    idx = bind.find(b"\x40_PyDict_New\x00");
    assert idx >= 1 , "no bind record for _PyDict_New";
    # 0x3E = SET_DYLIB_SPECIAL_IMM | FLAT_LOOKUP (-2 & 0x0F), not an ordinal
    assert bind[idx - 1] == 0x3E , (
        f"_PyDict_New bind provenance byte {hex(bind[idx - 1])}, expected "
        "flat lookup (0x3E): unmapped symbols must resolve from the process, "
        "not dylib ordinal 1 (libSystem)"
    );
}

test "mapped symbols keep their two-level dylib ordinal" {
    (_out, img) = link_dylib(MACHO_TRIPLE);
    bind = bind_stream(img);
    jdx = bind.find(b"\x40_malloc\x00");
    assert jdx >= 2 , "no bind record for _malloc";
    # 0x20 = SET_DYLIB_ORDINAL_ULEB, then uleb ordinal 1 = libSystem
    assert bind[jdx - 2] == 0x20 and bind[jdx - 1] == 0x01 , (
        f"_malloc bind bytes {hex(bind[jdx - 2])},{hex(bind[jdx - 1])}, "
        "expected two-level ordinal 1 (libSystem)"
    );
}

test "darwin host: the dylib loads and resolves CPython from the process" {
    if sys.platform != "darwin" {
        return;
    }
    import platform;
    host_arch = platform.machine();
    triple = llvm.get_default_triple();
    if ("arm64" in triple) != (host_arch == "arm64") {
        return;
    }
    (out, _img) = link_dylib(triple);
    # PyDLL keeps the GIL held across the call, which PyDict_New needs
    lib = ctypes.PyDLL(out);
    lib.jac_probe.restype = ctypes.c_void_p;
    d = lib.jac_probe();
    assert d , "PyDict_New returned NULL through the linked dylib";
    ctypes.pythonapi.Py_DecRef.argtypes = [ctypes.c_void_p];
    ctypes.pythonapi.Py_DecRef(d);
}
