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
import os;

def probe_one(path: str) -> str {
    src = "";
    try {
        fh = open(path, "r");
        src = fh.read();
        fh.close();
    } except Exception as e {
        return "READFAIL";
    }
    try {
        m = parse_file(src, path);
    } except Exception as e {
        return "PARSE_EXC: " + str(e)[:80];
    }
    if m is None {
        return "PARSE_NONE";
    }
    body = (m as Module).body;
    try {
        vr = validate_module_body(body);
    } except Exception as e {
        return "VALIDATE_EXC: " + str(e)[:80];
    }
    if vr.diag is not None {
        return "VALIDATE[" + compiler_diag_kind(vr.diag) + "]: " + compiler_diag_message(vr.diag)[:80];
    }
    try {
        sr = build_module_symtable(body);
    } except Exception as e {
        return "SYMTAB_EXC: " + str(e)[:80];
    }
    if sr.diag is not None {
        return "SYMTAB[" + compiler_diag_kind(sr.diag) + "]: " + compiler_diag_message(sr.diag)[:80];
    }
    try {
        u = compile_exec(body, path, "<module>", 1, sr.top);
    } except Exception as e {
        return "CODEGEN_EXC: " + str(e)[:100];
    }
    if u.diag is not None {
        return "CODEGEN[" + compiler_diag_kind(u.diag) + "]: " + compiler_diag_message(u.diag)[:100];
    }
    try {
        co = assemble(verify_cfg(u));
    } except Exception as e {
        return "ASM_EXC: " + str(e)[:100];
    }
    try {
        exp = unmarshal(host_compile_marshal(src, path, "exec", 0)) as PyCode;
    } except Exception as e {
        return "OK_NO_ORACLE";
    }
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
    stddir = "/home/jac/.local/share/uv/python/cpython-3.14.6-linux-x86_64-gnu/lib/python3.14";
    names = sorted(os.listdir(stddir));
    ok = 0;
    total = 0;
    tally: dict[str, int] = {};
    for nm in names {
        if not nm.endswith(".py") {
            continue;
        }
        total = total + 1;
        r = probe_one(stddir + "/" + nm);
        if r == "OK" {
            ok = ok + 1;
        } else {
            # bucket by prefix before ':'
            key = r;
            print(nm.ljust(22) + " " + r);
        }
    }
    print("=== OK " + str(ok) + " / " + str(total) + " ===");
}
