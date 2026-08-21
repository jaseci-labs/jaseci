import from ast_nodes { Module }
import from parser { parse_file }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_diagnostics { compiler_diag_kind, compiler_diag_message }
import os;
import sys;

def probe_parse(path: str) -> str {
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
        return "PARSE_EXC:" + str(e)[:50];
    }
    if m is None {
        return "PARSE_NONE";
    }
    body = (m as Module).body;
    try {
        vr = validate_module_body(body);
    } except Exception as e {
        return "VAL_EXC:" + str(e)[:50];
    }
    if vr.diag is not None {
        return "VAL["
            + compiler_diag_kind(vr.diag)
            + "]:"
            + compiler_diag_message(vr.diag)[:50];
    }
    try {
        sr = build_module_symtable(body);
    } except Exception as e {
        return "SYM_EXC:" + str(e)[:50];
    }
    if sr.diag is not None {
        return "SYM["
            + compiler_diag_kind(sr.diag)
            + "]:"
            + compiler_diag_message(sr.diag)[:50];
    }
    return "OK";
}

with entry {
    sys.setrecursionlimit(200000);
}

glob stddir = "/home/jac/.local/share/uv/python/cpython-3.14.6-linux-x86_64-gnu/lib/python3.14";

with entry {
    names = sorted(os.listdir(stddir));
    ok = 0;
    total = 0;
    for nm in names {
        if not nm.endswith(".py") {
            continue;
        }
        total = total + 1;
        r = probe_parse(stddir + "/" + nm);
        if r == "OK" {
            ok = ok + 1;
        } else {
            print(nm.ljust(24) + " " + r);
        }
    }
    print("=== parse+validate+symtab OK " + str(ok) + " / " + str(total) + " ===");
}
