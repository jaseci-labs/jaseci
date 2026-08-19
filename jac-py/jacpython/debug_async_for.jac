import from objects { PyObj }
import from parser { parse_file }
import from ast_nodes { Module }
import from compiler_codegen { compile_exec }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_diagnostics { compiler_diag_message }
import from flowgraph { verify_cfg }
import from assembler { assemble }

test "debug async for diag" {
    src = "async def f():\n  async for x in aiter():\n    pass\n";
    m = parse_file(src, "<f>");
    assert m is not None;
    body = (m as Module).body;
    vr = validate_module_body(body);
    if vr.diag is not None {
        print("validate: " + compiler_diag_message(vr.diag));
    }
    assert vr.diag is None;
    sr = build_module_symtable(body);
    if sr.diag is not None {
        print("symtable: " + compiler_diag_message(sr.diag));
    }
    assert sr.diag is None;
    u = compile_exec(body, "<f>", "<module>", 1, sr.top);
    if u.diag is not None {
        print("compile_exec diag: " + compiler_diag_message(u.diag));
        bi = 0;
        while bi < len(u.blocks) {
            b = u.blocks[bi];
            op = -1;
            if len(b.instrs) > 0 {
                op = b.instrs[0].opcode;
            }
            ni = len(b.instrs);
            print("block " + str(b.id) + " ninstr=" + str(ni) + " first_op=" + str(op));
            bi = bi + 1;
        }
    }
    cfg = verify_cfg(u);
    if cfg.diag is not None {
        print("verify_cfg diag: " + compiler_diag_message(cfg.diag));
    }
    assert u.diag is None;
    assert cfg.diag is None;
    assemble(cfg);
}
