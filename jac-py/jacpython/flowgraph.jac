# CFG preparation for the P4 back track (PLAN.md P0.11 slice).
#
# Turns a compile_unit's block IR into a flat instruction list ready for bytecode
# emission: flatten blocks, insert NOT_TAKEN after forward conditional jumps,
# resolve jump targets to code-unit offsets, rewrite small-int LOAD_CONST, and
# verify stack depth.
#
# Product module: imports compiler_ir + opcode_meta + objects only.
# Never imports assembler.

import from objects { PyInt }
import from opcode_meta {
    OP_LOAD_CONST,
    OP_LOAD_SMALL_INT,
    OP_NOT_TAKEN,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_LOAD_NAME,
    OP_LOAD_ATTR,
    OP_STORE_NAME,
    OP_STORE_ATTR,
    OP_STORE_SUBSCR,
    OP_DELETE_NAME,
    OP_DELETE_ATTR,
    OP_DELETE_SUBSCR,
    OP_BINARY_OP,
    OP_COMPARE_OP,
    OP_CALL,
    OP_POP_TOP,
    OP_RETURN_VALUE,
    OP_PUSH_NULL,
    OP_COPY,
    OP_SWAP,
    OP_TO_BOOL,
}
import from compiler_ir {
    compile_unit,
    cinstr,
    mk_instr,
    instr_size_codeunits,
}

# Output of prepare_cfg: flat IR plus verified stack depth.
obj prepared_cfg {
    has flat: list[cinstr],
        stacksize: int;
}

# Intermediate flatten result.
obj flatten_result {
    has flat: list[cinstr],
        block_starts: list[int];
}

def is_conditional_jump(opcode: int) -> bool {
    if opcode == OP_POP_JUMP_IF_FALSE {
        return True;
    }
    if opcode == OP_POP_JUMP_IF_TRUE {
        return True;
    }
    if opcode == OP_POP_JUMP_IF_NONE {
        return True;
    }
    if opcode == OP_POP_JUMP_IF_NOT_NONE {
        return True;
    }
    return False;
}

# Lay blocks out in allocation order and record each block's code-unit start.
def flatten_blocks(u: compile_unit) -> flatten_result {
    flat: list[cinstr] = [];
    block_starts: list[int] = [];
    cur = 0;
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        while len(block_starts) <= b.id {
            block_starts.append(0);
        }
        block_starts[b.id] = cur;
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            flat.append(ins);
            cur = cur + instr_size_codeunits(ins);
            ii = ii + 1;
        }
        bi = bi + 1;
    }
    return flatten_result(flat=flat, block_starts=block_starts);
}

# CPython flowgraph.c: after each forward conditional jump, insert NOT_TAKEN
# (backward jump reversal is deferred to a later slice).
def normalize_jumps(u: compile_unit) -> None {
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        new_instrs: list[cinstr] = [];
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            new_instrs.append(ins);
            if is_conditional_jump(ins.opcode) and ins.target_block >= 0 {
                if ins.target_block > b.id {
                    new_instrs.append(mk_instr(OP_NOT_TAKEN, 0, ins.loc));
                }
            }
            ii = ii + 1;
        }
        b.instrs = new_instrs;
        bi = bi + 1;
    }
}

# POP_JUMP_* targets are forward code-unit offsets from the next instruction:
#   ip += 2 * oparg. target_block ids map to block starts laid out in order.
def resolve_jump_offsets(flat: list[cinstr], block_starts: list[int]) -> None {
    offsets: list[int] = [];
    cur = 0;
    i = 0;
    while i < len(flat) {
        offsets.append(cur);
        cur = cur + instr_size_codeunits(flat[i]);
        i = i + 1;
    }
    i = 0;
    while i < len(flat) {
        ins = flat[i];
        if ins.target_block >= 0 {
            target = block_starts[ins.target_block];
            next_ip = offsets[i] + instr_size_codeunits(ins);
            ins.oparg = target - next_ip;
        }
        i = i + 1;
    }
}

# CPython's maybe_instr_make_load_smallint rewrites LOAD_CONST <int in 0..255> to
# LOAD_SMALL_INT <value>. The const remains in the table (now unreferenced).
def rewrite_small_ints(u: compile_unit, flat: list[cinstr]) -> None {
    i = 0;
    while i < len(flat) {
        ins = flat[i];
        if ins.opcode == OP_LOAD_CONST {
            if ins.oparg < len(u.consts) {
                c = u.consts[ins.oparg];
                if isinstance(c, PyInt) {
                    v = (c as PyInt).val;
                    if v >= 0 and v <= 255 {
                        ins.opcode = OP_LOAD_SMALL_INT;
                        ins.oparg = v;
                    }
                }
            }
        }
        i = i + 1;
    }
}

# Net stack effect of one instruction for the expression-slice opcode set.
def stack_effect(ins: cinstr) -> int {
    op = ins.opcode;
    if op == OP_LOAD_NAME or op == OP_LOAD_CONST or op == OP_LOAD_SMALL_INT
    or op == OP_PUSH_NULL {
        return 1;
    }
    if op == OP_LOAD_ATTR {
        return 0;
    }
    if op == OP_STORE_NAME {
        return -1;
    }
    if op == OP_STORE_ATTR {
        return -2;
    }
    if op == OP_STORE_SUBSCR {
        return -3;
    }
    if op == OP_DELETE_NAME {
        return 0;
    }
    if op == OP_DELETE_ATTR {
        return -1;
    }
    if op == OP_DELETE_SUBSCR {
        return -2;
    }
    if op == OP_BINARY_OP or op == OP_COMPARE_OP {
        return -1;
    }
    if op == OP_CALL {
        return -(ins.oparg + 1);
    }
    if op == OP_POP_TOP or op == OP_RETURN_VALUE {
        return -1;
    }
    if op == OP_POP_JUMP_IF_FALSE or op == OP_POP_JUMP_IF_TRUE
    or op == OP_POP_JUMP_IF_NONE or op == OP_POP_JUMP_IF_NOT_NONE {
        return -1;
    }
    if op == OP_COPY {
        return 1;
    }
    if op == OP_SWAP or op == OP_TO_BOOL {
        return 0;
    }
    # RESUME, UNARY_*, CACHE, NOT_TAKEN, NOP, EXTENDED_ARG: no net effect.
    return 0;
}

# Linear stack-depth scan (CFG join verification deferred to a later slice).
def verify_stackdepth(flat: list[cinstr]) -> int {
    depth = 0;
    maxd = 0;
    i = 0;
    while i < len(flat) {
        depth = depth + stack_effect(flat[i]);
        if depth > maxd {
            maxd = depth;
        }
        if depth < 0 {
            depth = 0;
        }
        i = i + 1;
    }
    return maxd;
}

# Full CFG preparation pipeline (PLAN.md P0.11).
def prepare_cfg(u: compile_unit) -> prepared_cfg {
    normalize_jumps(u);
    fr = flatten_blocks(u);
    flat = fr.flat;
    block_starts = fr.block_starts;
    resolve_jump_offsets(flat, block_starts);
    rewrite_small_ints(u, flat);
    stacksize = verify_stackdepth(flat);
    return prepared_cfg(flat=flat, stacksize=stacksize);
}
