import from parser { parse_file }
import json;
import sys;

def parses(src: str) -> str {
    try {
        m = parse_file(src, "<f>");
    } except Exception as e {
        return "EXC:" + str(e)[:60];
    }
    if m is None {
        return "NONE";
    }
    return "OK";
}

with entry {
    sys.setrecursionlimit(200000);
    fh = open("/tmp/claude-1000/-home-jac-repos-jac-python/31393663-4893-4c74-b635-99e40a17186c/scratchpad/stdlib_stmts.json", "r");
    data = json.load(fh);
    fh.close();
    ok = 0;
    fail = 0;
    by_type: dict[str, int] = {};
    examples: dict[str, str] = {};
    exc_tally: dict[str, int] = {};
    for nm in data.keys() {
        for entry in data[nm] {
            ntype = entry[0];
            lineno = entry[1];
            seg = entry[2];
            r = parses(seg + "\n");
            if r == "OK" {
                ok = ok + 1;
            } else {
                fail = fail + 1;
                key = ntype;
                if key not in by_type {
                    by_type[key] = 0;
                    examples[key] = nm + ":" + str(lineno) + " | " + seg.split("\n")[0][:70];
                }
                by_type[key] = by_type[key] + 1;
                if r.startswith("EXC:") {
                    em = r[4:];
                    if em not in exc_tally {
                        exc_tally[em] = 0;
                    }
                    exc_tally[em] = exc_tally[em] + 1;
                }
            }
        }
    }
    print("=== OK " + str(ok) + " FAIL " + str(fail) + " ===");
    print("--- fail by top-level stmt type ---");
    for k in by_type.keys() {
        print(str(by_type[k]).rjust(4) + "  " + k.ljust(14) + " e.g. " + examples[k]);
    }
    print("--- exceptions (arity/name bugs) ---");
    for k in exc_tally.keys() {
        print(str(exc_tally[k]).rjust(4) + "  " + k);
    }
}
