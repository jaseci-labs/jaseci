# Compiler IR for the P4 back track (PLAN.md P0.10).
#
# Source-location, instruction, basic-block, and compile-unit objects shared by
# codegen (AST -> IR) and the assembler (IR -> PyCode). The two consumers import
# FROM this module; neither imports the other, keeping an acyclic front-end DAG.
#
# na-clean leaf: no host calls, no import cycles. Location encoding matches
# CPython 3.14 (PEP 626); col offsets are 0-based byte offsets, NO_COLUMN = -1.

import from objects { PyObj }
import from opcode_meta { opcode_cache_count }
import from compiler_diagnostics { compiler_diagnostic }
import from compiler_symtable { sym_block }

# A source location. lineno/end_lineno are 1-based; col_offset/end_col_offset are
# 0-based. Matches CPython's `location` struct (Python/compile.c).
obj cloc {
    has lineno: int,
        end_lineno: int,
        col_offset: int,
        end_col_offset: int;
}

glob NO_LINE: int = -1,
     NO_COLUMN: int = -1;

def loc(lineno: int, end_lineno: int, col_offset: int, end_col_offset: int) -> cloc {
    return cloc(
        lineno=lineno,
        end_lineno=end_lineno,
        col_offset=col_offset,
        end_col_offset=end_col_offset
    );
}

# NO_LOCATION sentinel (CPython: all fields -1). Emitted as a NONE linetable entry.
def no_loc -> cloc {
    return loc(NO_LINE, NO_LINE, NO_COLUMN, NO_COLUMN);
}

# Two locations are equal only when all four fields agree (used by the linetable
# encoder to group consecutive same-location instructions).
def same_loc(a: cloc, b: cloc) -> bool {
    if a.lineno != b.lineno {
        return False;
    }
    if a.end_lineno != b.end_lineno {
        return False;
    }
    if a.col_offset != b.col_offset {
        return False;
    }
    if a.end_col_offset != b.end_col_offset {
        return False;
    }
    return True;
}

# A single IR instruction. oparg is the logical argument (0 for no-arg opcodes).
# For jumps, target_block is the destination basicblock id (resolved by the
# assembler to a code-unit offset); -1 means "not a jump".
obj cinstr {
    has opcode: int,
        oparg: int,
        loc: cloc,
        target_block: int = -1;
}

def mk_instr(opcode: int, oparg: int, lc: cloc) -> cinstr {
    return cinstr(opcode=opcode, oparg=oparg, loc=lc, target_block=-1);
}

def mk_jump(opcode: int, target: int, lc: cloc) -> cinstr {
    return cinstr(opcode=opcode, oparg=0, loc=lc, target_block=target);
}

# CFG builder: owns the current block and emits into unverified_cfg (Phase 4).
obj cfg_builder {
    has u: unverified_cfg,
        cur: basicblock,
        sym_top: sym_block | None = None;

    def emit(ins: cinstr) {
        self.cur.instrs.append(ins);
    }

    def emit_op(opcode: int, oparg: int, lc: cloc) {
        self.emit(mk_instr(opcode, oparg, lc));
    }

    def emit_jump(opcode: int, target: int, lc: cloc) {
        self.emit(mk_jump(opcode, target, lc));
    }

    def new_block -> basicblock {
        return self.u.add_block();
    }

    def use(b: basicblock) {
        self.cur = b;
    }
}

def new_cfg_builder(
    u: unverified_cfg, start_blk: basicblock, sym_top: sym_block | None = None
) -> cfg_builder {
    return cfg_builder(u=u, cur=start_blk, sym_top=sym_top);
}

# Statement lowering result: continuation location and whether the CFG path
# terminated (no fallthrough to the next statement).
obj stmt_cont {
    has loc: cloc,
        terminated: bool = False;
}

# A basic block: an ordered instruction list. The assembler lays blocks out in
# allocation order and resolves each jump's target_block to a code-unit offset.
obj basicblock {
    has id: int,
        instrs: list[cinstr];
}

# Unverified CFG plus compile metadata from codegen. Flowgraph verification
# produces verified_cfg; assembly accepts verified CFG only (Phase 2 contract).
obj unverified_cfg {
    has filename: str,
        name: str,
        qualname: str,
        firstlineno: int,
        argcount: int = 0,
        posonlyargcount: int = 0,
        kwonlyargcount: int = 0,
        flags: int = 0,
        varnames: list[str] = [],
        cellvars: list[str] = [],
        freevars: list[str] = [],
        consts: list[PyObj] = [],
        names: list[str] = [],
        blocks: list[basicblock] = [],
        next_block_id: int = 0,
        # Set by codegen on unsupported nodes; product_compile checks before
        # flowgraph verification (PLAN.md: no silent codegen paths).
        diag: compiler_diagnostic | None = None;

    def add_block -> basicblock {
        b = basicblock(id=self.next_block_id, instrs=[]);
        self.next_block_id = self.next_block_id + 1;
        self.blocks.append(b);
        return b;
    }

    # Const dedup by value (tp_hashkey collapses numeric/value equality the same
    # way CPython's const table dedups). Append-first-seen preserves CPython's
    # deterministic ordering.
    def add_const(c: PyObj) -> int {
        key = c.tp_hashkey();
        i = 0;
        while i < len(self.consts) {
            if self.consts[i].tp_hashkey() == key {
                return i;
            }
            i = i + 1;
        }
        self.consts.append(c);
        return len(self.consts) - 1;
    }

    def add_name(n: str) -> int {
        i = 0;
        while i < len(self.names) {
            if self.names[i] == n {
                return i;
            }
            i = i + 1;
        }
        self.names.append(n);
        return len(self.names) - 1;
    }
}

# Shared instruction sizing (assembler linetable + flowgraph jump resolution).
def extended_arg_count(oparg: int) -> int {
    n = 0;
    if oparg > 0xFFFFFF {
        n = n + 1;
    }
    if oparg > 0xFFFF {
        n = n + 1;
    }
    if oparg > 0xFF {
        n = n + 1;
    }
    return n;
}

def instr_size_codeunits(ins: cinstr) -> int {
    return extended_arg_count(ins.oparg) + 1 + opcode_cache_count(ins.opcode);
}
