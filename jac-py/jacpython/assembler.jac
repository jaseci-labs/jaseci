# Compiler assembler for the P4 back track (PLAN.md P0.10 / P0.11 slice).
#
# Turns a prepared_cfg (flat IR from flowgraph) into a native PyCode: EXTENDED_ARG
# folding, mandatory CACHE padding, deterministic const/name tables, PEP 626 line
# table (ported from CPython 3.14 Python/assemble.c), and (for this slice) an
# empty exception table.
#
# Product module: imports flowgraph + compiler_ir + opcode_meta + objects only.

import from objects { PyCode }
import from opcode_meta {
    OP_CACHE,
    OP_EXTENDED_ARG,
    opcode_cache_count,
}
import from compiler_ir {
    cinstr,
    cloc,
    loc,
    same_loc,
    NO_LINE,
    instr_size_codeunits,
}
import from flowgraph { verified_cfg }

# ---------------- bytecode emission ----------------
def emit_instr(code: list[int], ins: cinstr) -> None {
    oparg = ins.oparg;
    op = ins.opcode;
    # EXTENDED_ARG chain, high bytes first (assemble write_instr fall-through).
    if oparg > 0xFFFFFF {
        code.append(OP_EXTENDED_ARG);
        code.append((oparg >> 24) & 0xFF);
    }
    if oparg > 0xFFFF {
        code.append(OP_EXTENDED_ARG);
        code.append((oparg >> 16) & 0xFF);
    }
    if oparg > 0xFF {
        code.append(OP_EXTENDED_ARG);
        code.append((oparg >> 8) & 0xFF);
    }
    code.append(op);
    code.append(oparg & 0xFF);
    caches = opcode_cache_count(op);
    ci = 0;
    while ci < caches {
        code.append(OP_CACHE);
        code.append(0);
        ci = ci + 1;
    }
}

# ---------------- PEP 626 line table (ported from Python/assemble.c) ----------------
# Linetable location-entry kind codes (Include/cpython/code.h).
glob LI_SHORT0: int = 0,
     LI_ONE_LINE0: int = 10,
     LI_NO_COLUMNS: int = 13,
     LI_LONG: int = 14,
     LI_NONE: int = 15;

def write_varint(out: list[int], val: int) -> None {
    v = val;
    while v >= 64 {
        out.append(64 | (v & 63));
        v = v >> 6;
    }
    out.append(v);
}

def write_signed_varint(out: list[int], val: int) -> None {
    v = val;
    if v < 0 {
        # (0 - val) << 1 | 1, matching CPython's unsigned conversion.
        write_varint(out, (((0 - v) << 1) | 1));
    } else {
        write_varint(out, v << 1);
    }
}

def write_entry_start(out: list[int], code: int, length: int) -> None {
    out.append(128 | (code << 3) | (length - 1));
}

def write_location_info_entry(
    out: list[int], st: lintable_state, lc: cloc
) -> None {
    if lc.lineno == NO_LINE {
        write_entry_start(out, LI_NONE, st.length);
        return;
    }
    line_delta = lc.lineno - st.a_lineno;
    column = lc.col_offset;
    end_column = lc.end_col_offset;
    if column < 0 or end_column < 0 {
        if lc.end_lineno == lc.lineno or lc.end_lineno < 0 {
            write_entry_start(out, LI_NO_COLUMNS, st.length);
            write_signed_varint(out, line_delta);
            st.a_lineno = lc.lineno;
            return;
        }
    }
    elif lc.end_lineno == lc.lineno {
        if line_delta == 0 and column < 80 and end_column >= column
        and end_column - column < 16 {
            column_group = column >> 3;
            write_entry_start(out, LI_SHORT0 + column_group, st.length);
            out.append(((column & 7) << 4) | (end_column - column));
            # short form does NOT update a_lineno (matches CPython).
            return;
        }
        if line_delta >= 0 and line_delta < 3 and column < 128
        and end_column < 128 {
            write_entry_start(out, LI_ONE_LINE0 + line_delta, st.length);
            out.append(column);
            out.append(end_column);
            st.a_lineno = lc.lineno;
            return;
        }
    }
    write_entry_start(out, LI_LONG, st.length);
    write_signed_varint(out, lc.lineno - st.a_lineno);
    end_ln = lc.end_lineno;
    if end_ln < 0 {
        end_ln = lc.lineno;
    }
    write_varint(out, end_ln - lc.lineno);
    write_varint(out, column + 1);
    write_varint(out, end_column + 1);
    st.a_lineno = lc.lineno;
}

# Per-call mutable state threaded through the location encoder (CPython's
# `struct assembler` a_lineno + a_location_off).
obj lintable_state {
    has a_lineno: int = 1;
    has length: int = 0;
}

# Emit a run of `isize` code units all carrying location `lc`, chunked into
# length<=8 entries (assemble_emit_location).
def emit_location_run(
    out: list[int], st: lintable_state, lc: cloc, isize: int
) -> None {
    if isize == 0 {
        return;
    }
    remaining = isize;
    while remaining > 8 {
        st.length = 8;
        write_location_info_entry(out, st, lc);
        remaining = remaining - 8;
    }
    st.length = remaining;
    write_location_info_entry(out, st, lc);
}

# Port of assemble_location_info: group consecutive same-location instructions,
# summing code-unit sizes, and emit one entry per group (chunked at 8).
def assemble_linetable(flat: list[cinstr], firstlineno: int) -> list[int] {
    out: list[int] = [];
    st = lintable_state(a_lineno=firstlineno, length=0);
    cur: cloc = loc(NO_LINE, NO_LINE, -1, -1);
    size = 0;
    i = 0;
    while i < len(flat) {
        ins = flat[i];
        if not same_loc(cur, ins.loc) {
            emit_location_run(out, st, cur, size);
            cur = ins.loc;
            size = 0;
        }
        size = size + instr_size_codeunits(ins);
        i = i + 1;
    }
    emit_location_run(out, st, cur, size);
    return out;
}

# ---------------- assemble ----------------
def assemble(cfg: verified_cfg) -> PyCode {
    u = cfg.unit;
    flat = cfg.flat;
    stacksize = cfg.stacksize;
    code: list[int] = [];
    i = 0;
    while i < len(flat) {
        emit_instr(code, flat[i]);
        i = i + 1;
    }
    linetable = assemble_linetable(flat, u.firstlineno);
    return PyCode(
        t="code",
        argcount=u.argcount,
        posonlyargcount=u.posonlyargcount,
        kwonlyargcount=u.kwonlyargcount,
        stacksize=stacksize,
        flags=u.flags,
        co_code=code,
        consts=u.consts,
        names=u.names,
        varnames=u.varnames,
        cellvars=u.cellvars,
        freevars=u.freevars,
        filename=u.filename,
        name=u.name,
        qualname=u.qualname,
        firstlineno=u.firstlineno,
        linetable=linetable,
        exceptiontable=[]
    );
}
