import operator as pyop;
import jaclang.jac0core.parser.lexer as ct_lexer;

import from jaclang.jac0core.arena { NIL, SyntaxArena, Tag }
import from jaclang.jac0core.arena {
    KIND_CT_BLOCK,
    KIND_CT_ELSE,
    KIND_CT_FOR,
    KIND_CT_IF,
    KIND_CT_NAME,
    KIND_CT_SPLICE,
    SPECS
}
import from jaclang.jac0core.arena_materialize { spec_of as decode_spec_of }
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.helpers { pascal_to_snake }
import from jaclang.jac0core.parser.parser { Parser }
import jaclang.jac0core.ct_reflect as ct_reflect;

glob CT_STRUCT_KINDS: tuple = (KIND_CT_FOR, KIND_CT_IF, KIND_CT_ELSE),
     CT_EXPR_KINDS: tuple = (KIND_CT_BLOCK, KIND_CT_SPLICE, KIND_CT_NAME),
     CT_FUEL_DEFAULT: int = 50000000;


def arena_has_ct(a: SyntaxArena) -> bool {
    for k in a.kinds {
        if k in CT_STRUCT_KINDS or k in CT_EXPR_KINDS {
            return True;
        }
    }
    return False;
}


obj CtFragment {
    has kind: str,
        text: str;
}


obj CtHelpers {
    def name(s: str) -> CtFragment {
        return CtFragment(kind="name", text=str(s));
    }

    def typ(src: str) -> CtFragment {
        return CtFragment(kind="type", text=str(src));
    }

    def expr(src: str) -> CtFragment {
        return CtFragment(kind="expr", text=str(src));
    }

    def snake(s: str) -> str {
        return pascal_to_snake(str(s));
    }

    def parts(ann: str) -> list[str] {
        t = str(ann).strip();
        if t.startswith("(") and t.endswith(")") {
            t = t[1:-1];
        }
        out: list[str] = [];
        depth = 0;
        cur = "";
        for ch in t {
            if ch == "[" or ch == "(" {
                depth += 1;
            } elif ch == "]" or ch == ")" {
                depth -= 1;
            }
            if ch == "|" and depth == 0 {
                out.append(cur.strip());
                cur = "";
            } else {
                cur += ch;
            }
        }
        out.append(cur.strip());
        return out;
    }
}


obj CtReflectNS {
    has cur_dir: str = "";

    def module(dotted: str) -> ct_reflect.CtModuleInfo {
        return ct_reflect.load_module(dotted, self.cur_dir);
    }
}


obj CtTarget {
    has contexts: list[str] = [];

    def postinit {
        if not self.contexts {
            self.contexts = ["server", "client", "native"];
        }
    }

    def has(ctx: any) -> bool {
        want = ctx.value if isinstance(ctx, CodeContext) else str(ctx);
        return want in self.contexts;
    }
}


def _ct_err(msg: str) {
    raise RuntimeError(f"comptime: {msg}");
}


obj CtEval {
    has a: SyntaxArena,
        file_path: str = "<input>",
        cur_dir: str = "",
        fuel: int = 50000000,
        frames: list[dict] = [],
        frame_barriers: list[bool] = [],
        module_defs: dict[str, int] = {},
        module_glob_ids: dict[str, int] = {},
        module_globals: dict[str, any] = {},
        targets: list[str] = [],
        loc_stack: list[int] = [],
        _call_memo: dict = {},
        _ret: any = None,
        _builtins: dict = {},
        _ns: dict = {};

    def postinit {
        if not self.targets {
            self.targets = ["server", "client", "native"];
        }
        self._builtins = {
            "len": len,
            "str": str,
            "int": int,
            "float": float,
            "bool": bool,
            "repr": repr,
            "sorted": sorted,
            "range": range,
            "enumerate": enumerate,
            "list": list,
            "dict": dict,
            "set": set,
            "tuple": tuple,
            "min": min,
            "max": max,
            "sum": sum,
            "abs": abs,
            "any": any,
            "all": all,
            "zip": zip,
            "reversed": reversed,
            "fail": _ct_err
        };
        self._ns = {
            "ct": CtHelpers(),
            "reflect": CtReflectNS(cur_dir=self.cur_dir),
            "target": CtTarget(contexts=list(self.targets)),
            "CodeContext": CodeContext
        };
    }

    def burn(n: int = 1) {
        self.fuel -= n;
        if self.fuel < 0 {
            _ct_err("fuel exhausted (runaway comptime expansion?)");
        }
    }

    def spec_of(i: int) -> (tuple | None) {
        kind = self.a.kinds[i];
        if kind not in SPECS {
            return None;
        }
        return decode_spec_of(kind);
    }

    def cls_name(i: int) -> str {
        spec = self.spec_of(i);
        if spec is None {
            _ct_err(f"unknown arena kind {self.a.kinds[i]}");
        }
        return spec[0];
    }

    def slot_of(i: int, pname: str) -> int {
        spec = decode_spec_of(self.a.kinds[i]);
        slot = 0;
        plist: tuple = spec[1];
        for p in plist {
            pt: tuple = p;
            if pt[1] == "SOURCE" {
                continue;
            }
            if pt[0] == pname {
                return slot;
            }
            slot += 1;
        }
        return -1;
    }

    def node_arg(i: int, pname: str) -> int {
        s = self.slot_of(i, pname);
        return self.a.arg_node(i, s) if s >= 0 else NIL;
    }

    def list_arg(i: int, pname: str) -> list[int] {
        s = self.slot_of(i, pname);
        if s < 0 {
            return [];
        }
        got = self.a.arg_list(i, s);
        return got if got is not None else [];
    }

    def poly_arg(i: int, pname: str) -> list[int] {
        s = self.slot_of(i, pname);
        if s < 0 {
            return [];
        }
        (tag, val) = self.a.arg_at(i, s);
        if tag == Tag.NODE {
            return [val];
        }
        if tag == Tag.LIST {
            return self.a.seq_ids(val);
        }
        return [];
    }

    def str_arg(i: int, pname: str) -> str {
        s = self.slot_of(i, pname);
        if s < 0 {
            return "";
        }
        got = self.a.arg_str(i, s);
        return got if got is not None else "";
    }

    def tok_value(i: int) -> str {
        return self.str_arg(i, "value");
    }

    def loc_of(i: int) -> tuple {
        if i == NIL or i >= len(self.a.kinds) {
            return (0, 0, 0, 0);
        }
        spec = self.spec_of(i);
        if spec is not None and spec[2] {
            s_line = self.slot_of(i, "line");
            s_el = self.slot_of(i, "end_line");
            s_cs = self.slot_of(i, "col_start");
            s_ce = self.slot_of(i, "col_end");
            return (
                self.a.arg_int(i, s_line),
                self.a.arg_int(i, s_el),
                self.a.arg_int(i, s_cs),
                self.a.arg_int(i, s_ce)
            );
        }
        for k in self.a.kid_ids(i) {
            got = self.loc_of(k);
            if got[0] > 0 {
                return got;
            }
        }
        return (0, 0, 0, 0);
    }

    def push_frame(barrier: bool = False) {
        self.frames.append({});
        self.frame_barriers.append(barrier);
    }

    def pop_frame {
        self.frames.pop();
        self.frame_barriers.pop();
    }

    def bind(name: str, v: any) {
        self.frames[-1][name] = v;
    }

    def lookup(name: str) -> any {
        idx = len(self.frames) - 1;
        while idx >= 0 {
            if name in self.frames[idx] {
                return self.frames[idx][name];
            }
            if self.frame_barriers[idx] {
                break;
            }
            idx -= 1;
        }
        if name in self._ns {
            return self._ns[name];
        }
        if name in self.module_globals {
            return self.module_globals[name];
        }
        if name in self.module_glob_ids {
            gid = self.module_glob_ids[name];
            self.module_globals[name] = self.eval(gid);
            return self.module_globals[name];
        }
        if name in self._builtins {
            return self._builtins[name];
        }
        _ct_err(f"name '{name}' is not defined in comptime scope");
    }

    def assign(name: str, v: any) {
        idx = len(self.frames) - 1;
        while idx >= 0 {
            if name in self.frames[idx] {
                self.frames[idx][name] = v;
                return;
            }
            if self.frame_barriers[idx] {
                break;
            }
            idx -= 1;
        }
        if self.frames {
            self.frames[-1][name] = v;
        } else {
            self.module_globals[name] = v;
        }
    }

    def unquote(txt: str) -> any {
        import ast as pyast;
        try {
            return pyast.literal_eval(txt);
        } except Exception {
            return txt.strip("\"'");
        }
    }

    def eval(i: int) -> any {
        self.burn();
        self.loc_stack.append(i);
        try {
            return self._eval_inner(i);
        } finally {
            self.loc_stack.pop();
        }
    }

    def _eval_inner(i: int) -> any {
        cn = self.cls_name(i);
        if cn == "Name" {
            return self.lookup(self.tok_value(i));
        }
        if cn == "Int" {
            txt = self.tok_value(i).replace("_", "");
            return int(txt, 0) if txt.startswith("0") and len(txt) > 1 else int(txt);
        }
        if cn == "Float" {
            return float(self.tok_value(i));
        }
        if cn == "Bool" {
            return self.tok_value(i) == "True";
        }
        if cn == "Null" {
            return None;
        }
        if cn == "String" {
            return self.unquote(self.tok_value(i));
        }
        if cn == "MultiString" {
            out = "";
            for p in self.list_arg(i, "strings") {
                v = self.eval(p);
                out += str(v);
            }
            return out;
        }
        if cn == "FString" {
            out = "";
            for p in self.list_arg(i, "parts") {
                pcn = self.cls_name(p);
                if pcn == "String" {
                    out += str(self.tok_value(p));
                } elif pcn == "FormattedValue" {
                    fv = self.eval(self.node_arg(p, "format_part"));
                    out += str(fv);
                } elif pcn == "ExprStmt" {
                    out += str(self.eval(self.node_arg(p, "expr")));
                } else {
                    out += str(self.eval(p));
                }
            }
            return out;
        }
        if cn == "CtBlock" or cn == "CfgExpr" {
            return self.eval(self.node_arg(i, "expr"));
        }
        if cn == "AtomUnit" {
            return self.eval(self.node_arg(i, "value"));
        }
        if cn == "BinaryExpr" {
            return self._binop(
                self.tok_value(self.node_arg(i, "op")),
                self.eval(self.node_arg(i, "left")),
                self.eval(self.node_arg(i, "right"))
            );
        }
        if cn == "CompareExpr" {
            left = self.eval(self.node_arg(i, "left"));
            rights = self.list_arg(i, "rights");
            ops = self.list_arg(i, "ops");
            idx = 0;
            while idx < len(rights) {
                right = self.eval(rights[idx]);
                if not self._cmp(self.tok_value(ops[idx]), left, right) {
                    return False;
                }
                left = right;
                idx += 1;
            }
            return True;
        }
        if cn == "BoolExpr" {
            op = self.tok_value(self.node_arg(i, "op"));
            vals = self.list_arg(i, "values");
            if op == "and" {
                r: any = True;
                for v in vals {
                    r = self.eval(v);
                    if not r {
                        return r;
                    }
                }
                return r;
            }
            r2: any = False;
            for v in vals {
                r2 = self.eval(v);
                if r2 {
                    return r2;
                }
            }
            return r2;
        }
        if cn == "UnaryExpr" {
            op = self.tok_value(self.node_arg(i, "op"));
            v = self.eval(self.node_arg(i, "operand"));
            if op == "-" {
                return -v;
            }
            if op == "+" {
                return +v;
            }
            if op == "not" {
                return not v;
            }
            if op == "~" {
                return ~v;
            }
            _ct_err(f"unary operator '{op}' not supported in comptime");
        }
        if cn == "IfElseExpr" {
            if self.eval(self.node_arg(i, "condition")) {
                return self.eval(self.node_arg(i, "value"));
            }
            return self.eval(self.node_arg(i, "else_value"));
        }
        if cn == "ListVal" {
            return [self.eval(v) for v in self.list_arg(i, "values")];
        }
        if cn == "TupleVal" {
            return tuple([self.eval(v) for v in self.list_arg(i, "values")]);
        }
        if cn == "SetVal" {
            return {self.eval(v) for v in self.list_arg(i, "values")};
        }
        if cn == "DictVal" {
            out2: dict = {};
            for kv in self.list_arg(i, "kv_pairs") {
                key = self.node_arg(kv, "key");
                if key == NIL {
                    _ct_err("dict spread not supported in comptime");
                }
                out2[self.eval(key)] = self.eval(self.node_arg(kv, "value"));
            }
            return out2;
        }
        if cn in ("ListCompr", "GenCompr", "SetCompr") {
            items = self._compr_items(
                self.list_arg(i, "compr"), 0, self.node_arg(i, "out_expr")
            );
            return set(items) if cn == "SetCompr" else items;
        }
        if cn == "DictCompr" {
            kvp = self.node_arg(i, "kv_pair");
            pairs = self._compr_items(self.list_arg(i, "compr"), 0, NIL, kvp);
            out3: dict = {};
            for entry in pairs {
                out3[entry[0]] = entry[1];
            }
            return out3;
        }
        if cn == "AtomTrailer" {
            return self._eval_trailer(i);
        }
        if cn == "FuncCall" {
            return self._eval_call(i);
        }
        _ct_err(f"'{cn}' expression not supported in comptime");
    }

    def _compr_items(
        comprs: list[int], depth: int, out_expr: int, kv_pair: int = 0
    ) -> list {
        if depth >= len(comprs) {
            if kv_pair != NIL and kv_pair != 0 {
                k = self.eval(self.node_arg(kv_pair, "key"));
                v = self.eval(self.node_arg(kv_pair, "value"));
                return [(k, v, )];
            }
            return [self.eval(out_expr)];
        }
        c = comprs[depth];
        coll = self.eval(self.node_arg(c, "collection"));
        conds = self.list_arg(c, "conditional");
        tgt = self.node_arg(c, "target");
        out: list = [];
        for item in coll {
            self.push_frame();
            self._bind_target(tgt, item);
            keep = True;
            for cond in conds {
                if not self.eval(cond) {
                    keep = False;
                    break;
                }
            }
            if keep {
                out.extend(self._compr_items(comprs, depth + 1, out_expr, kv_pair));
            }
            self.pop_frame();
        }
        return out;
    }

    def _bind_target(tgt: int, v: any) {
        cn = self.cls_name(tgt);
        if cn == "Name" {
            self.bind(self.tok_value(tgt), v);
            return;
        }
        if cn == "TupleVal" {
            names = self.list_arg(tgt, "values");
            vals = list(v);
            if len(names) != len(vals) {
                _ct_err("comptime destructuring arity mismatch");
            }
            idx = 0;
            while idx < len(names) {
                self._bind_target(names[idx], vals[idx]);
                idx += 1;
            }
            return;
        }
        _ct_err(f"'{cn}' target not supported in comptime");
    }

    def _assign_target(tgt: int, v: any) {
        cn = self.cls_name(tgt);
        if cn == "Name" {
            self.assign(self.tok_value(tgt), v);
            return;
        }
        if cn == "TupleVal" {
            names = self.list_arg(tgt, "values");
            vals = list(v);
            if len(names) != len(vals) {
                _ct_err("comptime destructuring arity mismatch");
            }
            idx = 0;
            while idx < len(names) {
                self._assign_target(names[idx], vals[idx]);
                idx += 1;
            }
            return;
        }
        if cn == "AtomTrailer" {
            tv = self.eval(self.node_arg(tgt, "target"));
            right = self.node_arg(tgt, "right");
            if self.cls_name(right) == "IndexSlice" {
                slices = self.list_arg(right, "slices");
                if len(slices) == 1 {
                    s0 = slices[0];
                    if self.cls_name(s0) == "Slice" {
                        lo = self.node_arg(s0, "start");
                        if lo != NIL {
                            tv[self.eval(lo)] = v;
                            return;
                        }
                    } else {
                        tv[self.eval(s0)] = v;
                        return;
                    }
                }
            }
            _ct_err("attribute/slice assignment not supported in comptime");
        }
        _ct_err(f"'{cn}' assign target not supported in comptime");
    }

    def _attr_get(base: any, name: str) -> any {
        if name.startswith("_") {
            _ct_err(f"access to '{name}' not allowed in comptime");
        }
        try {
            return getattr(base, name);
        } except AttributeError {
            _ct_err(f"'{type(base).__name__}' has no attribute '{name}'");
        }
    }

    def _eval_trailer(i: int) -> any {
        tv = self.eval(self.node_arg(i, "target"));
        right = self.node_arg(i, "right");
        rcn = self.cls_name(right);
        if rcn == "Name" {
            return self._attr_get(tv, self.tok_value(right));
        }
        if rcn == "IndexSlice" {
            slices = self.list_arg(right, "slices");
            is_range = False;
            s_r = self.slot_of(right, "is_range");
            if s_r >= 0 {
                is_range = self.a.arg_bool(right, s_r);
            }
            if len(slices) != 1 {
                _ct_err("multi-dimension index not supported in comptime");
            }
            s0 = slices[0];
            if self.cls_name(s0) == "Slice" {
                lo = self.node_arg(s0, "start");
                hi = self.node_arg(s0, "stop");
                st = self.node_arg(s0, "step");
                if not is_range {
                    if lo == NIL {
                        _ct_err("empty index not supported in comptime");
                    }
                    return tv[self.eval(lo)];
                }
                lo_v = self.eval(lo) if lo != NIL else None;
                hi_v = self.eval(hi) if hi != NIL else None;
                st_v = self.eval(st) if st != NIL else None;
                return tv[slice(lo_v, hi_v, st_v)];
            }
            return tv[self.eval(s0)];
        }
        if rcn == "FuncCall" {
            inner_tgt = self.node_arg(right, "target");
            fn: any = None;
            if self.cls_name(inner_tgt) == "Name" {
                fn = self._attr_get(tv, self.tok_value(inner_tgt));
            } else {
                _ct_err("computed method call not supported in comptime");
            }
            (args, kwargs) = self._call_args(right);
            return fn(*args, **kwargs);
        }
        _ct_err(f"'{rcn}' trailer not supported in comptime");
    }

    def _call_args(call: int) -> tuple {
        args: list = [];
        kwargs: dict = {};
        for p in self.list_arg(call, "params") {
            if self.cls_name(p) == "KWPair" {
                key = self.node_arg(p, "key");
                if key == NIL {
                    _ct_err("** spread not supported in comptime calls");
                }
                kwargs[self.tok_value(key)] = self.eval(self.node_arg(p, "value"));
            } else {
                args.append(self.eval(p));
            }
        }
        return (args, kwargs, );
    }

    def _eval_call(i: int) -> any {
        tgt = self.node_arg(i, "target");
        tcn = self.cls_name(tgt);
        if tcn == "AtomTrailer" {
            tv = self.eval(self.node_arg(tgt, "target"));
            right = self.node_arg(tgt, "right");
            if self.cls_name(right) == "Name" {
                fn = self._attr_get(tv, self.tok_value(right));
                (args, kwargs) = self._call_args(i);
                self.burn(10);
                return fn(*args, **kwargs);
            }
            _ct_err("computed call target not supported in comptime");
        }
        if tcn == "Name" {
            fname = self.tok_value(tgt);
            if fname in self.module_defs {
                (args, kwargs) = self._call_args(i);
                return self.call_def(self.module_defs[fname], args, kwargs);
            }
            fn2 = self.lookup(fname);
            (args2, kwargs2) = self._call_args(i);
            self.burn(10);
            return fn2(*args2, **kwargs2);
        }
        if tcn == "BuiltinType" {
            fn3 = self._builtins.get(self.str_arg(tgt, "value") or "");
            if fn3 is None {
                fn3 = self._builtins.get(self.tok_value(tgt));
            }
            if fn3 is None {
                _ct_err("builtin-type call not supported in comptime");
            }
            (args3, kwargs3) = self._call_args(i);
            return fn3(*args3, **kwargs3);
        }
        _ct_err(f"'{tcn}' call target not supported in comptime");
    }

    def call_def(abil: int, args: list, kwargs: dict) -> any {
        self.burn(20);
        if not args and not kwargs and abil in self._call_memo {
            return self._call_memo[abil];
        }
        sig = self.node_arg(abil, "signature");
        pids = self.list_arg(sig, "params") if sig != NIL else [];
        self.push_frame(barrier=True);
        idx = 0;
        for pid in pids {
            pname_id = self.node_arg(pid, "name");
            pname = self.tok_value(pname_id);
            if idx < len(args) {
                self.bind(pname, args[idx]);
            } elif pname in kwargs {
                self.bind(pname, kwargs[pname]);
            } else {
                dflt = self.node_arg(pid, "value");
                if dflt == NIL {
                    self.pop_frame();
                    _ct_err(f"missing comptime argument '{pname}'");
                }
                self.bind(pname, self.eval(dflt));
            }
            idx += 1;
        }
        self._ret = None;
        body = self.poly_arg(abil, "body");
        _sig = self.exec_block(body);
        out = self._ret;
        self._ret = None;
        self.pop_frame();
        if not args and not kwargs {
            self._call_memo[abil] = out;
        }
        return out;
    }

    def exec_block(ids: list[int]) -> int {
        for i in ids {
            sig = self.exec_stmt(i);
            if sig != 0 {
                return sig;
            }
        }
        return 0;
    }

    def exec_stmt(i: int) -> int {
        self.burn();
        self.loc_stack.append(i);
        try {
            return self._exec_inner(i);
        } finally {
            self.loc_stack.pop();
        }
    }

    def _exec_inner(i: int) -> int {
        cn = self.cls_name(i);
        if cn == "Assignment" {
            aug = self.node_arg(i, "aug_op");
            targets = self.list_arg(i, "target");
            val = self.eval(self.node_arg(i, "value"));
            if aug != NIL {
                op = self.tok_value(aug);
                cur = self.eval(targets[0]);
                self._assign_target(targets[0], self._binop(op.rstrip("="), cur, val));
                return 0;
            }
            for t in targets {
                self._assign_target(t, val);
            }
            return 0;
        }
        if cn == "ExprStmt" {
            self.eval(self.node_arg(i, "expr"));
            return 0;
        }
        if cn in ("IfStmt", "ElseIf") {
            if self.eval(self.node_arg(i, "condition")) {
                return self.exec_block(self.list_arg(i, "body"));
            }
            eb = self.node_arg(i, "else_body");
            if eb != NIL {
                return self.exec_stmt(eb);
            }
            return 0;
        }
        if cn == "ElseStmt" {
            return self.exec_block(self.list_arg(i, "body"));
        }
        if cn == "WhileStmt" {
            while self.eval(self.node_arg(i, "condition")) {
                self.burn(2);
                sig = self.exec_block(self.list_arg(i, "body"));
                if sig == 1 {
                    return 1;
                }
                if sig == 2 {
                    break;
                }
            }
            return 0;
        }
        if cn == "InForStmt" {
            tgt = self.node_arg(i, "target");
            coll = self.eval(self.node_arg(i, "collection"));
            for item in coll {
                self.burn(2);
                self.push_frame();
                self._bind_target(tgt, item);
                sig = self.exec_block(self.list_arg(i, "body"));
                self.pop_frame();
                if sig == 1 {
                    return 1;
                }
                if sig == 2 {
                    break;
                }
            }
            return 0;
        }
        if cn == "ReturnStmt" {
            e = self.node_arg(i, "expr");
            self._ret = self.eval(e) if e != NIL else None;
            return 1;
        }
        if cn == "CtrlStmt" {
            word = self.tok_value(self.node_arg(i, "ctrl"));
            if word == "break" {
                return 2;
            }
            if word == "continue" {
                return 3;
            }
            _ct_err(f"'{word}' not supported in comptime");
        }
        if cn == "Semi" {
            return 0;
        }
        _ct_err(f"'{cn}' statement not supported in comptime");
        return 0;
    }

    def _binop(op: str, l: any, r: any) -> any {
        if op == "+" {
            return l + r;
        }
        if op == "-" {
            return l - r;
        }
        if op == "*" {
            return l * r;
        }
        if op == "/" {
            return l / r;
        }
        if op == "//" {
            return l // r;
        }
        if op == "%" {
            return l % r;
        }
        if op == "**" {
            return l ** r;
        }
        if op == "|" {
            return l | r;
        }
        if op == "&" {
            return l & r;
        }
        _ct_err(f"operator '{op}' not supported in comptime");
    }

    def _cmp(op: str, l: any, r: any) -> bool {
        if op == "==" {
            return l == r;
        }
        if op == "!=" {
            return l != r;
        }
        if op == "<" {
            return pyop.lt(l, r);
        }
        if op == "<=" {
            return pyop.le(l, r);
        }
        if op == ">" {
            return pyop.gt(l, r);
        }
        if op == ">=" {
            return pyop.ge(l, r);
        }
        if op == "in" {
            return pyop.contains(r, l);
        }
        if op == "not in" {
            return not pyop.contains(r, l);
        }
        if op == "is" {
            return l is r;
        }
        if op == "is not" {
            return l is not r;
        }
        _ct_err(f"comparison '{op}' not supported in comptime");
        return False;
    }
}

obj CtExpander {
    has ev: CtEval,
        subst: dict[int, list[int]] = {},
        ct_only: dict[int, int] = {};

    def a -> SyntaxArena {
        return self.ev.a;
    }

    def sweep_kids {
        a = self.a();
        n = len(a.kinds);
        i = 1;
        while i < n {
            hit = False;
            for k in a.kid_ids(i) {
                if k in self.subst {
                    hit = True;
                    break;
                }
            }
            if hit {
                rebuilt: list[int] = [];
                for k in a.kid_ids(i) {
                    if k in self.subst {
                        for r in self.subst[k] {
                            rebuilt.append(r);
                        }
                    } else {
                        rebuilt.append(k);
                    }
                }
                lo = len(a.kids);
                for k in rebuilt {
                    a.kids.append(k);
                }
                a.kid_los[i] = lo;
                a.kid_ns[i] = len(rebuilt);
            }
            i += 1;
        }
    }

    def _tok(mk_name: str, tok_name: str, text: str, loc: tuple) -> int {
        a = self.a();
        (line, end_line, cs, ce) = (loc[0], loc[1], loc[2], loc[3]);
        if mk_name == "NAME" {
            return a.mk_name(
                name="NAME",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce
            );
        }
        if mk_name == "INT" {
            return a.mk_int(
                name="INT",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce
            );
        }
        if mk_name == "FLOAT" {
            return a.mk_float(
                name="FLOAT",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce
            );
        }
        if mk_name == "STRING" {
            return a.mk_string(
                name="STRING",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce
            );
        }
        if mk_name == "BOOL" {
            return a.mk_bool(
                name="BOOL",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce
            );
        }
        if mk_name == "NULL" {
            return a.mk_null(
                name="NULL",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce
            );
        }
        _ct_err(f"internal: unknown token builder {mk_name}");
        return NIL;
    }

    def value_to_records(v: any, loc: tuple) -> int {
        self.ev.burn(2);
        a = self.a();
        if isinstance(v, CtFragment) {
            return self.parse_frag(v, loc);
        }
        if isinstance(v, bool) {
            return self._tok("BOOL", "BOOL", "True" if v else "False", loc);
        }
        if isinstance(v, int) {
            if v < 0 {
                op = self._tok("NAME", "NAME", "-", loc);
                return a.mk_unary_expr(
                    op=self._minus_tok(loc),
                    operand=self._tok("INT", "INT", str(-v), loc),
                    kid=[self._tok("INT", "INT", str(-v), loc)]
                );
            }
            return self._tok("INT", "INT", str(v), loc);
        }
        if isinstance(v, float) {
            return self._tok("FLOAT", "FLOAT", repr(v), loc);
        }
        if isinstance(v, str) {
            return self._tok("STRING", "STRING", _jac_str_lit(v), loc);
        }
        if v is None {
            return self._tok("NULL", "NULL", "None", loc);
        }
        if isinstance(v, (list, tuple)) {
            vals: list[int] = [];
            for item in v {
                vals.append(self.value_to_records(item, loc));
            }
            if isinstance(v, tuple) {
                lt = self._punct("LPAREN", "(", loc);
                rt = self._punct("RPAREN", ")", loc);
                return a.mk_tuple_val(values=vals, kid=[lt] + vals + [rt]);
            }
            lt2 = self._punct("LSQUARE", "[", loc);
            rt2 = self._punct("RSQUARE", "]", loc);
            return a.mk_list_val(values=vals, kid=[lt2] + vals + [rt2]);
        }
        if isinstance(v, dict) {
            pairs: list[int] = [];
            for entry in v.items() {
                kk = self.value_to_records(entry[0], loc);
                vv = self.value_to_records(entry[1], loc);
                pairs.append(a.mk_k_v_pair(key=kk, value=vv, kid=[kk, vv]));
            }
            lb = self._punct("LBRACE", "{", loc);
            rb = self._punct("RBRACE", "}", loc);
            return a.mk_dict_val(kv_pairs=pairs, kid=[lb] + pairs + [rb]);
        }
        _ct_err(
            f"comptime value of type '{type(v).__name__}' cannot lower to a literal"
        );
        return NIL;
    }

    def _minus_tok(loc: tuple) -> int {
        return self._punct("MINUS", "-", loc);
    }

    def _punct(name: str, text: str, loc: tuple) -> int {
        return self.a().mk_token(
            name=name,
            value=text,
            line=loc[0],
            end_line=loc[1],
            col_start=loc[2],
            col_end=loc[3]
        );
    }

    def parse_frag(f: CtFragment, loc: tuple) -> int {
        self.ev.burn(50);
        if f.kind == "name" {
            if not _is_ident(f.text) {
                _ct_err(f"ct.name('{f.text}') is not a valid identifier");
            }
            return self._tok("NAME", "NAME", f.text, loc);
        }
        (tokens, _c, _ld, lex_errs) = ct_lexer.tokenize_full(f.text, "<comptime>");
        parser = Parser(tokens=tokens, file_path="<comptime>", source_code=f.text);
        parser._tokens_len = len(tokens);
        frag_root = parser.parse_expression();
        if parser.error_count > 0 or lex_errs > 0 {
            _ct_err(f"cannot parse ct fragment '{f.text}'");
        }
        memo: dict[int, int] = {};
        return self.graft(parser.b, frag_root, memo);
    }

    def graft(src: SyntaxArena, i: int, memo: dict) -> int {
        if i == NIL {
            return NIL;
        }
        if i in memo {
            return memo[i];
        }
        self.ev.burn();
        a = self.a();
        kind = src.kinds[i];
        new_kids: list[int] = [];
        for k in src.kid_ids(i) {
            new_kids.append(self.graft(src, k, memo));
        }
        arg_n = src.arg_ns[i];
        pairs: list[int] = [];
        p = src.arg_los[i];
        s = 0;
        while s < arg_n {
            tag = src.args[p];
            val = src.args[p + 1];
            if tag == Tag.NODE {
                pairs.append(Tag.NODE);
                pairs.append(self.graft(src, val, memo));
            } elif tag == Tag.LIST {
                ids = src.seq_ids(val);
                new_ids: list[int] = [];
                for x in ids {
                    new_ids.append(self.graft(src, x, memo));
                }
                off = len(a.seqs);
                a.seqs.append(len(new_ids));
                for x in new_ids {
                    a.seqs.append(x);
                }
                pairs.append(Tag.LIST);
                pairs.append(off);
            } elif tag == Tag.STR {
                pairs.append(Tag.STR);
                pairs.append(a.intern(src.strtab[val]));
            } else {
                pairs.append(tag);
                pairs.append(val);
            }
            p += 2;
            s += 1;
        }
        new_i = a._start(kind, new_kids, arg_n);
        for pv in pairs {
            a.args.append(pv);
        }
        memo[i] = new_i;
        return new_i;
    }

    def copy_tree(i: int, memo: dict) -> int {
        if i == NIL {
            return NIL;
        }
        if i in memo {
            return memo[i];
        }
        self.ev.burn();
        a = self.a();
        kind = a.kinds[i];
        old_kids = a.kid_ids(i);
        arg_n = a.arg_ns[i];
        old_p = a.arg_los[i];
        old_args: list[int] = [];
        s = 0;
        while s < (arg_n * 2) {
            old_args.append(a.args[old_p + s]);
            s += 1;
        }
        new_kids: list[int] = [];
        for k in old_kids {
            new_kids.append(self.copy_tree(k, memo));
        }
        pairs: list[int] = [];
        s = 0;
        while s < arg_n {
            tag = old_args[s * 2];
            val = old_args[s * 2 + 1];
            if tag == Tag.NODE {
                pairs.append(Tag.NODE);
                pairs.append(self.copy_tree(val, memo));
            } elif tag == Tag.LIST {
                ids = a.seq_ids(val);
                new_ids: list[int] = [];
                for x in ids {
                    new_ids.append(self.copy_tree(x, memo));
                }
                off = len(a.seqs);
                a.seqs.append(len(new_ids));
                for x in new_ids {
                    a.seqs.append(x);
                }
                pairs.append(Tag.LIST);
                pairs.append(off);
            } else {
                pairs.append(tag);
                pairs.append(val);
            }
            s += 1;
        }
        new_i = a._start(kind, new_kids, arg_n);
        for pv in pairs {
            a.args.append(pv);
        }
        j = 0;
        posts = a.posts;
        n_posts = len(posts);
        while j + 2 < n_posts {
            if posts[j] == i {
                a.post_set(new_i, a.strtab[posts[j + 1]], posts[j + 2]);
                n_posts = len(a.posts) - 3;
            }
            j += 3;
        }
        memo[i] = new_i;
        return new_i;
    }

    def ct_name_text(i: int) -> str {
        out = "";
        for p in self.ev.list_arg(i, "parts") {
            k = self.a().kinds[p];
            if k == KIND_CT_SPLICE {
                v = self.ev.eval(self.ev.node_arg(p, "expr"));
                if isinstance(v, CtFragment) and v.kind == "name" {
                    v = v.text;
                }
                if not isinstance(v, str) {
                    _ct_err("name splice must evaluate to a string");
                }
                out += v;
            } else {
                out += self.ev.tok_value(p);
            }
        }
        if not _is_ident(out) {
            _ct_err(f"interpolated name '{out}' is not a valid identifier");
        }
        return out;
    }

    def subst_expr(i: int) -> int {
        a = self.a();
        kind = a.kinds[i];
        loc = self.ev.loc_of(i);
        if kind == KIND_CT_NAME {
            return self._tok("NAME", "NAME", self.ct_name_text(i), loc);
        }
        v = self.ev.eval(self.ev.node_arg(i, "expr"));
        if kind == KIND_CT_SPLICE and isinstance(v, CtFragment) {
            if v.kind == "name" {
                if not _is_ident(v.text) {
                    _ct_err(f"ct.name('{v.text}') is not a valid identifier");
                }
                return self._tok("NAME", "NAME", v.text, loc);
            }
            return self.parse_frag(v, loc);
        }
        return self.value_to_records(v, loc);
    }

    def expand_node(i: int) {
        if i == NIL {
            return;
        }
        self.ev.burn();
        a = self.a();
        spec = self.ev.spec_of(i);
        if spec is None {
            return;
        }
        slot = 0;
        plist: tuple = spec[1];
        for p in plist {
            pt: tuple = p;
            if pt[1] == "SOURCE" {
                continue;
            }
            (tag, val) = a.arg_at(i, slot);
            if tag == Tag.NODE {
                vk = a.kinds[val];
                if vk in CT_EXPR_KINDS {
                    nid = self.subst_expr(val);
                    a.set_arg_node(i, slot, nid);
                    self.subst[val] = [nid];
                } elif vk in CT_STRUCT_KINDS {
                    _ct_err(
                        "comptime for/if is not valid where a single "
                        "expression is required"
                    );
                } else {
                    self.expand_node(val);
                }
            } elif tag == Tag.LIST {
                ids = a.seq_ids(val);
                found_ct = False;
                for x in ids {
                    if a.kinds[x] in CT_STRUCT_KINDS or a.kinds[x] in CT_EXPR_KINDS {
                        found_ct = True;
                        break;
                    }
                }
                if found_ct {
                    new_ids = self.expand_items(ids, i);
                    a.set_arg_list(i, slot, new_ids);
                } else {
                    for x in ids {
                        self.expand_node(x);
                    }
                }
            }
            slot += 1;
        }
    }

    def expand_items(ids: list[int], parent: int) -> list[int] {
        a = self.a();
        out: list[int] = [];
        for x in ids {
            k = a.kinds[x];
            if k == KIND_CT_FOR {
                news = self.expand_ct_for(x);
                self.subst[x] = news;
                out.extend(news);
            } elif k == KIND_CT_IF {
                news = self.expand_ct_if(x, parent);
                self.subst[x] = news;
                out.extend(news);
            } elif k in CT_EXPR_KINDS {
                nid = self.subst_expr(x);
                self.subst[x] = [nid];
                out.append(nid);
            } else {
                self.expand_node(x);
                out.append(x);
            }
        }
        return out;
    }

    def expand_ct_for(i: int) -> list[int] {
        ev = self.ev;
        tgt = ev.node_arg(i, "target");
        tname = ev.tok_value(tgt);
        coll = ev.eval(ev.node_arg(i, "iter"));
        body = ev.list_arg(i, "body");
        out: list[int] = [];
        for v in coll {
            ev.burn(5);
            ev.push_frame();
            ev.bind(tname, v);
            for b in body {
                memo: dict[int, int] = {};
                nb = self.copy_tree(b, memo);
                out.extend(self.expand_items([nb], i));
            }
            ev.pop_frame();
        }
        return out;
    }

    def expand_ct_if(i: int, parent: int) -> list[int] {
        ev = self.ev;
        if ev.eval(ev.node_arg(i, "condition")) {
            return self.expand_items(ev.list_arg(i, "body"), i);
        }
        eb = ev.node_arg(i, "else_body");
        if eb == NIL {
            return [];
        }
        if self.a().kinds[eb] == KIND_CT_IF {
            return self.expand_ct_if(eb, parent);
        }
        return self.expand_items(ev.list_arg(eb, "body"), eb);
    }

    def collect_ct_only {
        a = self.a();
        j = 0;
        n = len(a.posts);
        while j + 2 < n {
            if a.strtab[a.posts[j + 1]] == "ct_only" {
                self.ct_only[a.posts[j]] = 1;
            }
            j += 3;
        }
    }

    def strip_ct_only(mod_id: int) {
        if not self.ct_only {
            return;
        }
        a = self.a();
        ev = self.ev;
        slot = ev.slot_of(mod_id, "body");
        if slot < 0 {
            return;
        }
        body = ev.list_arg(mod_id, "body");
        kept: list[int] = [];
        for b in body {
            if b not in self.ct_only {
                kept.append(b);
            }
        }
        if len(kept) != len(body) {
            a.set_arg_list(mod_id, slot, kept);
            for b in body {
                if b in self.ct_only {
                    a.replace_kid(mod_id, b, []);
                }
            }
        }
    }

    def collect_module(mod_id: int) {
        ev = self.ev;
        for item in ev.list_arg(mod_id, "body") {
            cn = ev.cls_name(item);
            if cn == "Ability" {
                nref = ev.node_arg(item, "name_ref");
                if nref != NIL and ev.cls_name(nref) == "Name" {
                    ev.module_defs[ev.tok_value(nref)] = item;
                }
            } elif cn == "GlobalVars" {
                for asg in ev.list_arg(item, "assignments") {
                    tgts = ev.list_arg(asg, "target");
                    if len(tgts) == 1 and ev.cls_name(tgts[0]) == "Name" {
                        ev.module_glob_ids[ev.tok_value(tgts[0])] = ev.node_arg(
                            asg, "value"
                        );
                    }
                }
            }
        }
    }
}


def _is_ident(s: str) -> bool {
    if not s {
        return False;
    }
    first = s[0];
    if not (first.isalpha() or first == "_") {
        return False;
    }
    for ch in s[1:] {
        if not (ch.isalnum() or ch == "_") {
            return False;
        }
    }
    return True;
}


def _jac_str_lit(s: str) -> str {
    body = "";
    for ch in s {
        if ch == "\\" {
            body += "\\\\";
        } elif ch == "\"" {
            body += "\\\"";
        } elif ch == "\n" {
            body += "\\n";
        } elif ch == "\t" {
            body += "\\t";
        } elif ch == "\r" {
            body += "\\r";
        } else {
            body += ch;
        }
    }
    return "\"" + body + "\"";
}


def expand_arena(
    a: SyntaxArena,
    file_path: str = "<input>",
    targets: (list[str] | None) = None,
    fuel: int = 50000000
) -> list {
    import os;
    ev = CtEval(
        a=a,
        file_path=file_path,
        cur_dir=os.path.dirname(file_path),
        fuel=fuel,
        targets=(targets if targets is not None else ["server", "client", "native"])
    );
    ev.push_frame();
    ex = CtExpander(ev=ev);
    try {
        ex.collect_ct_only();
        ex.collect_module(a.root_id);
        ex.expand_node(a.root_id);
        ex.sweep_kids();
        ex.strip_ct_only(a.root_id);
    } except Exception as e {
        at = ev.loc_stack[-1] if ev.loc_stack else a.root_id;
        loc = ev.loc_of(at);
        msg = str(e);
        if not msg.startswith("comptime") {
            msg = f"comptime: {msg}";
        }
        return [(loc[0], loc[1], loc[2], loc[3], msg, )];
    }
    return [];
}
