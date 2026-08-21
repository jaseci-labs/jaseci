import from objects { PyObj, PyCode }
import from parser { parse_file }
import from ast_nodes { Module, AsyncFunctionDef }
import from compiler_codegen { compile_fn_cfg, sym_function_child }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_diagnostics { compiler_diag_message }
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal }
import from pycode_diff { pycode_diff, dis_diff_first }

test "debug async for nested cfg" {
    src = (
        "class AI:\n"
        + "    def __aiter__(self):\n"
        + "        return self\n"
        + "    async def __anext__(self):\n"
        + "        if getattr(self, 'done', False):\n"
        + "            raise StopAsyncIteration\n"
        + "        self.done = True\n"
        + "        return 42\n"
        + "\n"
        + "async def f():\n"
        + "    total = 0\n"
        + "    async for x in AI():\n"
        + "        total = total + x\n"
        + "    return total\n"
    );
    m = parse_file(src, "<f>");
    assert m is not None;
    body = (m as Module).body;
    vr = validate_module_body(body);
    assert vr.diag is None;
    sr = build_module_symtable(body);
    assert sr.diag is None;
    afd = None;
    si = 0;
    while si < len(body) {
        s = body[si];
        if isinstance(s, AsyncFunctionDef) {
            cand = s as AsyncFunctionDef;
            if cand.name == "f" {
                afd = cand;
                break;
            }
        }
        si = si + 1;
    }
    assert afd is not None;
    sym_fn = sym_function_child(sr.top, "f");
    assert sym_fn is not None;
    u_fn = compile_fn_cfg(
        afd.name, afd.args, afd.body, afd.lineno, "<f>", sym_fn, None
    );
    if u_fn.diag is not None {
        print("compile_fn_cfg diag: " + compiler_diag_message(u_fn.diag));
    }
    bi = 0;
    while bi < len(u_fn.blocks) {
        b = u_fn.blocks[bi];
        ni = len(b.instrs);
        op0 = -1;
        oplast = -1;
        if ni > 0 {
            op0 = b.instrs[0].opcode;
            oplast = b.instrs[ni - 1].opcode;
        }
        ii = 0;
        while ii < ni {
            print("  op=" + str(b.instrs[ii].opcode));
            ii = ii + 1;
        }
        bi = bi + 1;
    }
    cfg = verify_cfg(u_fn);
    if cfg.diag is not None {
        print("verify_cfg diag: " + compiler_diag_message(cfg.diag));
    }
    assert cfg.diag is None;
    co = assemble(cfg);
    exp_mod = unmarshal(host_compile_marshal(src, "<f>", "exec", 0));
    exp_co = None;
    ci = 0;
    while ci < len((exp_mod as PyCode).consts) {
        c = (exp_mod as PyCode).consts[ci];
        if isinstance(c, PyCode) {
            nested = c as PyCode;
            if nested.name == "f" {
                exp_co = nested;
                break;
            }
        }
        ci = ci + 1;
    }
    assert exp_co is not None;
    d = pycode_diff(exp_co, co, "f");
    if exp_co.co_code != co.co_code {
        print("co_code mismatch");
    }
    if exp_co.exceptiontable != co.exceptiontable {
        print("exceptiontable mismatch");
        ei = 0;
        while ei < 28 {
            ev = 0;
            av = 0;
            if ei < len(exp_co.exceptiontable) {
                ev = exp_co.exceptiontable[ei];
            }
            if ei < len(co.exceptiontable) {
                av = co.exceptiontable[ei];
            }
            if ev != av {
                print("exc " + str(ei) + " exp=" + str(ev) + " act=" + str(av));
            }
            ei = ei + 1;
        }
    }
    assert exp_co.co_code == co.co_code;
    assert exp_co.exceptiontable == co.exceptiontable;
    assert exp_co.stacksize == co.stacksize;
    assert exp_co.flags == co.flags;
}
