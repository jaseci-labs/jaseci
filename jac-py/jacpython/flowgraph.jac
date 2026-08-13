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
    OP_END_ASYNC_FOR,
    stack_effect,
    has_target,
    is_unconditional_jump_opcode,
    is_scope_exit_opcode,
}
import from compiler_ir {
    unverified_cfg,
    basicblock,
    cinstr,
    mk_instr,
    instr_size_codeunits,
}
import from compiler_diagnostics {
    compiler_diagnostic,
    internal_compiler_diagnostic,
}

# Verified CFG: flat instruction stream with stack depth, ready for assembly.
# Phase 3 adds hard errors on underflow and inconsistent joins via diag.
obj verified_cfg {
    has unit: unverified_cfg,
        flat: list[cinstr],
        stacksize: int,
        diag: compiler_diagnostic | None = None;
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
def flatten_blocks(u: unverified_cfg) -> flatten_result {
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
def normalize_jumps(u: unverified_cfg) {
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
def resolve_jump_offsets(flat: list[cinstr], block_starts: list[int]) {
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
def rewrite_small_ints(u: unverified_cfg, flat: list[cinstr]) {
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

glob UNSET_STARTDEPTH: int = -1000000;

def block_last_instr(b: basicblock) -> cinstr | None {
    if len(b.instrs) == 0 {
        return None;
    }
    return b.instrs[len(b.instrs) - 1];
}

def block_has_fallthrough(b: basicblock) -> bool {
    last = block_last_instr(b);
    if last is None {
        return True;
    }
    if is_scope_exit_opcode(last.opcode) or is_unconditional_jump_opcode(last.opcode) {
        return False;
    }
    return True;
}

def find_block(u: unverified_cfg, block_id: int) -> basicblock | None {
    i = 0;
    while i < len(u.blocks) {
        if u.blocks[i].id == block_id {
            return u.blocks[i];
        }
        i = i + 1;
    }
    return None;
}

def stackdepth_diag(kind: str, message: str) -> internal_compiler_diagnostic {
    return internal_compiler_diagnostic(kind=kind, message=message);
}

def stackdepth_push(
    startdepths: list[int], work: list[int], b: basicblock, depth: int
) -> bool {
    idx = b.id;
    if idx < 0 or idx >= len(startdepths) {
        return False;
    }
    cur = startdepths[idx];
    if cur != UNSET_STARTDEPTH and cur != depth {
        return False;
    }
    if cur == UNSET_STARTDEPTH {
        startdepths[idx] = depth;
        work.append(idx);
    }
    return True;
}

# CPython flowgraph.c calculate_stackdepth: worklist over block edges with
# generated stack_effect metadata (INTEGRATION_PLAN Phase 3).
def calculate_stackdepth(u: unverified_cfg) -> tuple[int, compiler_diagnostic | None] {
    if len(u.blocks) == 0 {
        return (0, None);
    }
    n = len(u.blocks);
    startdepths: list[int] = [];
    i = 0;
    while i < n {
        startdepths.append(UNSET_STARTDEPTH);
        i = i + 1;
    }
    work: list[int] = [];
    maxdepth = 0;
    entry = u.blocks[0];

    if not stackdepth_push(startdepths, work, entry, 0) {
        return (0, stackdepth_diag("ValueError", "Invalid CFG, inconsistent stackdepth"));
    }
    while len(work) > 0 {
        bid = work[len(work) - 1];
        work = work[0 : len(work) - 1];
        b = find_block(u, bid);
        if b is None {
            return (0, stackdepth_diag("ValueError", "Invalid CFG, missing basic block"));
        }
        depth = startdepths[bid];
        next_id = b.id + 1;
        next_blk = None;
        if next_id < n {
            next_blk = find_block(u, next_id);
        }
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            eff = stack_effect(ins.opcode, ins.oparg, 0);
            if eff is None {
                return (
                    0,
                    stackdepth_diag(
                        "SystemError",
                        "Invalid stack effect for opcode="
                            + str(ins.opcode)
                            + ", arg="
                            + str(ins.oparg)
                    )
                );
            }
            new_depth = depth + eff;
            if new_depth < 0 {
                return (0, stackdepth_diag("ValueError", "Invalid CFG, stack underflow"));
            }
            if new_depth > maxdepth {
                maxdepth = new_depth;
            }
            if has_target(ins.opcode) and ins.opcode != OP_END_ASYNC_FOR {
                if ins.target_block < 0 {
                    return (
                        0,
                        stackdepth_diag("ValueError", "Invalid CFG, jump missing target block")
                    );
                }
                target = find_block(u, ins.target_block);
                if target is None {
                    return (
                        0,
                        stackdepth_diag("ValueError", "Invalid CFG, invalid jump target")
                    );
                }
                jeff = stack_effect(ins.opcode, ins.oparg, 1);
                if jeff is None {
                    return (
                        0,
                        stackdepth_diag(
                            "SystemError",
                            "Invalid stack effect for opcode="
                                + str(ins.opcode)
                                + ", arg="
                                + str(ins.oparg)
                        )
                    );
                }
                target_depth = depth + jeff;
                if target_depth < 0 {
                    return (0, stackdepth_diag("ValueError", "Invalid CFG, stack underflow"));
                }
                if target_depth > maxdepth {
                    maxdepth = target_depth;
                }
                if not stackdepth_push(startdepths, work, target, target_depth) {
                    return (
                        0,
                        stackdepth_diag("ValueError", "Invalid CFG, inconsistent stackdepth")
                    );
                }
            }
            depth = new_depth;
            if is_unconditional_jump_opcode(ins.opcode) or is_scope_exit_opcode(ins.opcode) {
                next_blk = None;
                break;
            }
            ii = ii + 1;
        }
        if next_blk is not None and block_has_fallthrough(b) {
            if not stackdepth_push(startdepths, work, next_blk, depth) {
                return (
                    0,
                    stackdepth_diag("ValueError", "Invalid CFG, inconsistent stackdepth")
                );
            }
        }
    }
    return (maxdepth, None);
}

# UnverifiedCFG -> VerifiedCFG (Phase 2 contract; Phase 3 worklist stack proof).
def verify_cfg(u: unverified_cfg) -> verified_cfg {
    normalize_jumps(u);
    sd = calculate_stackdepth(u);
    stacksize = sd[0];
    sdiag = sd[1];
    if sdiag is not None {
        return verified_cfg(unit=u, flat=[], stacksize=0, diag=sdiag);
    }
    fr = flatten_blocks(u);
    flat = fr.flat;
    block_starts = fr.block_starts;
    resolve_jump_offsets(flat, block_starts);
    rewrite_small_ints(u, flat);
    return verified_cfg(unit=u, flat=flat, stacksize=stacksize);
}
