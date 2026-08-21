import from objects { PyCode }
import from parser { parse_file }
import from ast_nodes { Module }
import from compiler_codegen { compile_exec }
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_diagnostics { compiler_diag_kind, compiler_diag_message }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal }
import sys;

def probe_src(src: str, path: str) -> str {
    print("  parse...");
    sys.stdout.flush();
    m = parse_file(src, path);
    if m is None {
        return "PARSE_NONE";
    }
    body = (m as Module).body;
    print("  validate...");
    sys.stdout.flush();
    vr = validate_module_body(body);
    if vr.diag is not None {
        return "VALIDATE["
            + compiler_diag_kind(vr.diag)
            + "]: "
            + compiler_diag_message(vr.diag)[:80];
    }
    print("  symtab...");
    sys.stdout.flush();
    sr = build_module_symtable(body);
    if sr.diag is not None {
        return "SYMTAB["
            + compiler_diag_kind(sr.diag)
            + "]: "
            + compiler_diag_message(sr.diag)[:80];
    }
    print("  codegen...");
    sys.stdout.flush();
    u = compile_exec(body, path, "<module>", 1, sr.top);
    if u.diag is not None {
        return "CODEGEN["
            + compiler_diag_kind(u.diag)
            + "]: "
            + compiler_diag_message(u.diag)[:100];
    }
    print("  assemble...");
    sys.stdout.flush();
    co = assemble(verify_cfg(u));
    print("  oracle...");
    sys.stdout.flush();
    exp = unmarshal(host_compile_marshal(src, path, "exec", 0)) as PyCode;
    if co.co_code != exp.co_code {
        return "BYTES:co_code";
    }
    if co.exceptiontable != exp.exceptiontable {
        return "BYTES:exctable";
    }
    if co.stacksize != exp.stacksize {
        return "BYTES:stacksize";
    }
    return "OK";
}

with entry {
    sys.setrecursionlimit(200000);
}

glob path = sys.argv[1];

with entry {
    fh = open(path, "r");
    src = fh.read();
    fh.close();
    print("probing " + path + " (" + str(len(src)) + " chars)");
    sys.stdout.flush();
    r = probe_src(src, path);
    print("RESULT: " + r);
    sys.stdout.flush();
}
