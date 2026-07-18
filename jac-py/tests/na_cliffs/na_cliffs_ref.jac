# T7 known-na-cliffs conformance reference (jac-py/PLAN.md §6.7, TODO.md D4 #4).
#
# Each function here mirrors a pattern jacpython's na-clean core ALREADY uses,
# and each targets a documented na landmine. This file pins the CORRECT answer
# on the bytecode backend; CI nacompiles the identical logic (the sibling
# cliff_*.na.jac fixtures) and diffs against these values. A divergence is a
# real na miscompile on a pattern the port depends on -- discovered here on
# day one instead of at P7.
#
# Measured na status (local `jac nacompile`, 2026-07-15): all four reach
# capability-clean + LLVM IR + object-code emit; only the final musl link is
# blocked locally (env, not code). Runtime-correctness legs (NUL-drop,
# union-receiver-drop) require the linked binary and run in CI. See README.md.

# --- cliff 1: list[int] subscript. Core site: marshal Reader.r_byte ---
def r_byte(data: list[int], pos: int) -> int {
    b = data[pos];
    return b & 0xFF;
}

# --- cliff 2: dict[str,T] build + return + subscript. Core site: exec_module ---
def exec_module_like() -> dict[str, int] {
    g: dict[str, int] = {};
    g["y"] = 43;
    return g;
}

# --- cliff 3: method/field on a T|None receiver. Core site: deref_cell ---
obj Cell { has val: int; }

def find_cell(hit: bool) -> Cell | None {
    if hit { return Cell(val=7); }
    return None;
}

def cell_value(hit: bool) -> int {
    c = find_cell(hit);
    if c is None { return -1; }
    return c.val;
}

# --- cliff 4: binary buffer via chr concat incl NUL. Core site: bytes_to_str ---
def build_binary() -> str {
    s = "";
    s = s + chr(0);
    s = s + chr(65);
    return s;
}

# --- cliff 5: data-driven dict-lookup method/attr dispatch over an MRO.
# Core site: PyUserObj.tp_getattro (pyc_first.jac) -- instance-dict-wins then a
# class_mro walk, the looked-up PyObj narrowed via isinstance/as and invoked
# through a vtable (no function values / no fn-pointer table; na resolves every
# call statically). na landmines mirrored: the T|None-shaped receiver-drop is
# guarded (narrow before call), and the dict-literal-subclass-upcast ICE is
# worked around by building attrs empty and subscript-storing through a
# PyObj-typed local -- exactly as the sibling cliff_user_dispatch.na.jac does.
obj DObj { has t: str; }
obj DInt(DObj) { has val: int; }

obj DMethod(DObj) {
    def invoke(receiver: DUserObj) -> DObj {
        return DObj(t="error");
    }
}
obj DAddMethod(DMethod) {
    has delta: int;
    def invoke(receiver: DUserObj) -> DObj {
        base = d_expect_int(receiver.getattr("val"));
        return DInt(t="int", val=base + self.delta);
    }
}
obj DMulMethod(DMethod) {
    has factor: int;
    def invoke(receiver: DUserObj) -> DObj {
        base = d_expect_int(receiver.getattr("val"));
        return DInt(t="int", val=base * self.factor);
    }
}

obj DClass(DObj) {
    has name: str,
        attrs: dict[str, DObj],
        bases: list[DObj] = [];
}

obj DUserObj(DObj) {
    has cls: DClass,
        attrs: dict[str, DObj];

    def getattr(name: str) -> DObj {
        if name in self.attrs {
            return self.attrs[name];
        }
        return d_lookup(self.cls, name);
    }
}

def d_mro(cls: DClass) -> list[DClass] {
    result: list[DClass] = [cls];
    for base in cls.bases {
        if isinstance(base, DClass) {
            for klass in d_mro(base as DClass) {
                result.append(klass);
            }
        }
    }
    return result;
}

def d_lookup(cls: DClass, name: str) -> DObj {
    for klass in d_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return DObj(t="error");
}

def d_expect_int(o: DObj) -> int {
    if isinstance(o, DInt) {
        return (o as DInt).val;
    }
    return 0;
}

def d_dispatch(o: DUserObj, name: str) -> int {
    m = o.getattr(name);
    if m.t == "error" {
        return -1;
    }
    if not isinstance(m, DMethod) {
        return -2;
    }
    method = m as DMethod;          # narrow the union before the call
    return d_expect_int(method.invoke(o));
}

def d_make_class(nm: str, bases: list[DObj]) -> DClass {
    a: dict[str, DObj] = {};
    return DClass(t="type", name=nm, attrs=a, bases=bases);
}

def d_make_inst(c: DClass, v: int) -> DUserObj {
    a: dict[str, DObj] = {};
    boxed: DObj = DInt(t="int", val=v);
    a["val"] = boxed;
    return DUserObj(t="obj", cls=c, attrs=a);
}

# Returns [accumulated total over the heterogeneous dispatch, post-mutation
# redispatch result]. Base <- Mid <- Leaf; Mid shadows "act"; "other" only on
# Base is reached two levels down.
def d_run() -> list[int] {
    no_bases: list[DObj] = [];
    base_cls = d_make_class("Base", no_bases);
    m_add: DObj = DAddMethod(t="add", delta=100);
    m_other: DObj = DAddMethod(t="add", delta=1);
    base_cls.attrs["act"] = m_add;
    base_cls.attrs["other"] = m_other;

    mid_bases: list[DObj] = [base_cls];
    mid_cls = d_make_class("Mid", mid_bases);
    m_mul: DObj = DMulMethod(t="mul", factor=3);
    mid_cls.attrs["act"] = m_mul;

    leaf_bases: list[DObj] = [mid_cls];
    leaf_cls = d_make_class("Leaf", leaf_bases);

    insts: list[DUserObj] = [];
    leaf_inst = d_make_inst(leaf_cls, 5);
    base_inst = d_make_inst(base_cls, 7);
    insts.append(leaf_inst);
    insts.append(base_inst);

    names: list[str] = ["act", "other"];
    total = 0;
    for inst in insts {
        for nm in names {
            r = d_dispatch(inst, nm);
            total = total + r;
        }
    }

    # Killer: mutate the instance dict so "act" now hits the instance dict, then
    # redispatch from the same call site.
    override: DObj = DAddMethod(t="add", delta=1000);
    leaf_inst.attrs["act"] = override;
    again = d_dispatch(leaf_inst, names[0]);
    return [total, again];
}

test "cliff: list[int] subscript reads the right byte" {
    assert r_byte([227, 2, 0], 0) == 227;
    assert r_byte([227, 2, 0], 1) == 2;
}

test "cliff: dict build/return/subscript round-trips" {
    assert exec_module_like()["y"] == 43;
}

test "cliff: T|None receiver field access after None-guard" {
    assert cell_value(True) == 7;
    assert cell_value(False) == -1;
}

test "cliff: binary buffer preserves NUL (na len=strlen would report 1)" {
    # Bytecode truth: two code units. On na this is the canary -- if len()
    # degrades to strlen, this returns 1 and the CI differential goes red.
    assert len(build_binary()) == 2;
}

test "cliff: MRO dict dispatch resolves + mutates (na devirt/drop canary)" {
    # Leaf.act -> Mid.mul3(5)=15 ; Leaf.other -> Base.add1(5)=6 ;
    # Base.act -> Base.add100(7)=107 ; Base.other -> Base.add1(7)=8. Sum=136.
    # Post-mutation Leaf.act hits the instance dict: add1000(5)=1005.
    r = d_run();
    assert r[0] == 136;
    assert r[1] == 1005;
    assert r[0] + r[1] == 1141;
}

# --- cliff 6: generator as a suspended-frame state machine. Core site: the
# generator machinery in pyc_first.jac -- PyFrame(ip + saved locals + value
# stack) / PyGenerator drive a `yield` one .send()/next() at a time, and
# gen.close() injects GeneratorExit at the suspend point and must run an active
# finally. Resumption is INTEGER ip/state advanced over DATA -- no stored
# function values / no indirect calls (na resolves every call statically).
# na landmines mirrored: na exceptions are LEXICALLY structured, so you cannot
# jump into the middle of a try to reach an in-body finally -- it is lifted to an
# ip state (g_run_finally) that EVERY exit path (normal stop + close) passes
# through, guarded by `in_try` so a repeated close() is an idempotent no-op; the
# T|None-shaped receiver-drop is avoided by making the delegated sub-frame a
# required field (never T|None) -- exactly as sibling cliff_gen_frame.na.jac does.
obj GObj { has t: str; }
obj GInt(GObj) { has val: int; }
obj GGenStop(GObj) { has val: int; }

def g_expect_int(o: GObj) -> int {
    if isinstance(o, GInt) {
        return (o as GInt).val;
    }
    return 0;
}

# Delegated sub-generator: yields its seq, then RETURNS 42 (StopIteration payload)
# which the delegating frame folds back into its own expression.
obj GSubFrame(GObj) {
    has seq: list[int],
        k: int = 0;

    def resume(sent: GObj) -> GObj {
        if self.k < len(self.seq) {
            v = self.seq[self.k];
            self.k = self.k + 1;
            return GInt(t="int", val=v);
        }
        return GGenStop(t="genstop", val=42);
    }
}

# The resumable frame: nested loop (state in i/j) + expression-position yield
# (partial spilled onto `spill`, completed by the sent value on resume) + a
# try/finally lifted to an ip state + yield-from delegation with value flow-back.
obj GFrame(GObj) {
    has data: list[int],
        sub: GSubFrame,
        nrows: int,
        ncols: int,
        ip: int = 0,
        i: int = 0,
        j: int = 0,
        swept: int = 0,
        spill: int = 0,
        in_try: bool = False,
        finally_runs: int = 0;

    def resume(sent: GObj) -> GObj {
        if self.ip == 2 {
            self.swept = self.swept + (self.spill + g_expect_int(sent));
            self.j = self.j + 1;
        }
        if self.ip == 3 {
            step = self.sub.resume(sent);
            if step.t != "genstop" {
                return step;
            }
            self.swept = self.swept + (step as GGenStop).val;
            self.ip = 4;
        }
        self.in_try = True;
        while self.i < self.nrows {
            while self.j < self.ncols {
                x = self.data[self.i * self.ncols + self.j];
                self.spill = x * 10;
                self.ip = 2;
                return GInt(t="int", val=x);
            }
            self.j = 0;
            self.i = self.i + 1;
        }
        if self.ip != 4 {
            self.ip = 3;
            first = self.sub.resume(sent);
            if first.t != "genstop" {
                return first;
            }
            self.swept = self.swept + (first as GGenStop).val;
        }
        self.run_finally();
        return GGenStop(t="genstop", val=self.swept);
    }

    # Finally lifted to an ip state, guarded to fire exactly once (idempotent
    # double-close). The workaround for na's lexically-structured exceptions.
    def run_finally -> None {
        if self.in_try {
            self.finally_runs = self.finally_runs + 1;
            self.in_try = False;
        }
    }

    # gen.close(): route through the finally, then tear down. Idempotent.
    def close -> GObj {
        self.run_finally();
        self.ip = 99;
        return GGenStop(t="genstop", val=self.swept);
    }
}

def g_make_frame() -> GFrame {
    sub = GSubFrame(t="subframe", seq=[100, 200]);
    return GFrame(t="frame", data=[1, 2, 3, 4], sub=sub, nrows=2, ncols=2);
}

# next -> send(5) -> close() EARLY (mid-try, ip parked at 2). Finally must run
# once; a second close() must be a no-op.
def g_drive_close() -> int {
    g = g_make_frame();
    collected = 0;
    y0 = g.resume(GInt(t="int", val=0));
    collected = collected + g_expect_int(y0);
    y1 = g.resume(GInt(t="int", val=5));
    collected = collected + g_expect_int(y1);
    g.close();
    first_ct = g.finally_runs;
    g.close();
    second_ct = g.finally_runs;
    return collected * 1000000 + g.swept * 10000 + first_ct * 100 + second_ct;
}

# Drive to exhaustion: nested loop + yield-from flow-back; finally once on stop.
def g_drive_full() -> int {
    g = g_make_frame();
    collected = 0;
    steps = 0;
    sent: GObj = GInt(t="int", val=0);
    keep = True;
    while keep {
        y = g.resume(sent);
        if y.t == "genstop" {
            keep = False;
        } else {
            collected = collected + g_expect_int(y);
            steps = steps + 1;
            sent = GInt(t="int", val=1);
        }
    }
    return collected * 1000 + steps * 100 + g.finally_runs * 10;
}

test "cliff: generator suspend/resume frame -- try/finally on close + yield-from" {
    # Mid-try close: yields data[0]=1 then data[1]=2 (collected=3); send(5) makes
    # swept = 10+5 = 15; close() runs the finally once (1), second close is a
    # no-op (still 1). Encoded 3_15_1_1 -> 3150101.
    assert g_drive_close() == 3150101;
    # Exhaustion: nested loop yields 1,2,3,4 then delegation yields 100,200
    # (collected=310) over 6 steps; finally runs once on the normal exit.
    # Encoded 310_06_1 -> 310610.
    assert g_drive_full() == 310610;
}
