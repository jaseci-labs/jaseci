# Native @dataclass support (CPython Lib/dataclasses.py facade).
#
# The decorator consumes a guest class's PEP 649 annotations by calling the
# class dict's ``__annotate_func__(1)`` (stored there by class-body AnnAssign
# lowering), merges inherited ``__dataclass_fields__`` base-first, and attaches
# synthesized dunders to the class. Synthesis follows CPython's own strategy:
# textual function templates compiled through host_compile_marshal + exec into
# a scratch namespace, so every generated dunder is a REAL PyFunction and binds
# through the normal descriptor path. Dunder bodies stay one-line delegations
# to the native ops below (DCReprOp/DCEqOp/... parameterized by the per-class
# DCSpec), keeping field semantics in one place.
#
# Defaults never appear as literals in the template: defaulted/factory params
# carry a private sentinel default (_DC_MISSING) resolved by fixup lines that
# read pre-seeded values (_dc_d<i>) or call pre-seeded factories (_dc_f<i>)
# from the scratch namespace -- arbitrary objects cross without repr round-
# trips, exactly why CPython threads them as fake parameters too.
#
# Hash rule mirrors CPython's slot machinery: eq=True leaves __hash__ unset,
# which mro_hash_blocked already renders unhashable; frozen+eq / unsafe_hash
# attach a tuple-of-fields hash.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyDict,
    PyList,
    PyTuple,
    PySet,
    PyExceptionType,
    PY_NOT_IMPLEMENTED,
    is_error,
    py_none,
    py_error,
    expect_str,
}
import from ceval {
    PyClass,
    PyUserObj,
    PyModule,
    class_lookup_attr,
    class_mro,
    host_builtin,
    py_attr,
    py_compare,
    py_hash,
    py_repr,
    py_slot_truth,
    py_str,
    register_shim_module,
}
import from pyc_first { unmarshal, exec_code }
import from host_oracle { host_compile_marshal }

# ---------------- singletons and metadata objects ----------------

obj DCMissingSentinel(PyObj) {
    # CPython dataclasses.MISSING: distinct from "no attribute" so a field
    # whose genuine default IS None stays distinguishable from no default.
}

glob DC_MISSING: DCMissingSentinel = DCMissingSentinel(t="dc_missing");

obj DCInitVarMark(PyObj) {
    # Stand-in for dataclasses.InitVar. Pseudo-fields are EXCLUDED from fields
    # entirely (gap vs CPython, which gives them init-only behavior); the
    # marker only needs to survive annotation evaluation, including the
    # `InitVar[int]` subscript form.
    def mp_subscript(index: PyObj) -> PyObj {
        return self;
    }
}

glob DC_INITVAR: DCInitVarMark = DCInitVarMark(t="dc_initvar");

obj DCParams(PyObj) {
    has init: bool = True,
        frepr: bool = True,
        eq: bool = True,
        order: bool = False,
        unsafe_hash: bool = False,
        frozen: bool = False,
        kw_only: bool = False;
}

obj DCField(PyObj) {
    # One real field (ClassVar/InitVar pseudo-fields never become these).
    # fdefault is DC_MISSING when absent; ffactory is py_none() unless
    # default_factory was given (has_factory gates it). has_kw_only marks an
    # EXPLICIT field(kw_only=...); otherwise the decorator's kw_only decides.
    has fname: str,
        annot: PyObj,
        fdefault: PyObj,
        ffactory: PyObj,
        has_factory: bool = False,
        finit: bool = True,
        frepr: bool = True,
        fcompare: bool = True,
        fkw_only: bool = False,
        has_kw_only: bool = False;

    def tp_getattro(name: str) -> PyObj {
        if name == "name" {
            return PyStr(t="str", val=self.fname);
        }
        if name == "type" {
            return self.annot;
        }
        if name == "default" {
            if self.fdefault is DC_MISSING {
                return py_error(
                    "AttributeError",
                    "'Field' object has no attribute 'default'",
                );
            }
            return self.fdefault;
        }
        if name == "default_factory" {
            # CPython exposes the MISSING sentinel when no factory was given.
            if self.has_factory {
                return self.ffactory;
            }
            return DC_MISSING;
        }
        if name == "init" {
            return PyBool(t="bool", val=self.finit);
        }
        if name == "repr" {
            return PyBool(t="bool", val=self.frepr);
        }
        if name == "compare" {
            return PyBool(t="bool", val=self.fcompare);
        }
        if name == "kw_only" {
            return PyBool(t="bool", val=self.fkw_only);
        }
        if name == "_field_type" {
            return PyStr(t="str", val="_FIELD");
        }
        if name == "hash" or name == "metadata" {
            # None means "follow compare"; metadata stays an empty mapping.
            if name == "metadata" {
                return PyDict(t="dict", items={});
            }
            return py_none();
        }
        return py_error(
            "AttributeError", "'Field' object has no attribute '" + name + "'"
        );
    }
}

# Per-class record handed to every native op; lives in each scratch namespace
# as _DC_SPEC so the generated one-line wrappers can pass it back in.
obj DCSpec(PyObj) {
    has cls: PyClass,
        fields: list[DCField],
        params: DCParams;
}

# ---------------- shared helpers ----------------

def dc_join(parts: list[str], sep: str) -> str {
    out = "";
    i = 0;
    while i < len(parts) {
        if i > 0 {
            out += sep;
        }
        out += parts[i];
        i += 1;
    }
    return out;
}

def dc_same_class(a: PyObj, b: PyObj) -> PyClass | None {
    if isinstance(a, PyUserObj) and isinstance(b, PyUserObj) {
        lc = (a as PyUserObj).cls;
        rc = (b as PyUserObj).cls;
        if lc is rc {
            return lc;
        }
    }
    return None;
}

def dc_selected_fields(spec: DCSpec, mode: str) -> list[DCField] {
    out: list[DCField] = [];
    for f in spec.fields {
        if mode == "repr" and not f.frepr {
            continue;
        }
        if mode != "repr" and not f.fcompare {
            continue;
        }
        out.append(f);
    }
    return out;
}

def dc_read_fields(spec: DCSpec, inst: PyObj, mode: str) -> PyObj {
    values: list[PyObj] = [];
    for f in dc_selected_fields(spec, mode) {
        v = py_attr(inst, f.fname);
        if is_error(v) {
            return v;
        }
        values.append(v);
    }
    return PyList(t="list", items=values);
}

def dc_param_flag(kwargs: dict[str, PyObj], name: str, fallback: bool) -> bool {
    if name in kwargs {
        v = kwargs[name];
        if isinstance(v, PyBool) {
            return (v as PyBool).val;
        }
        if isinstance(v, PyInt) {
            return (v as PyInt).val != 0;
        }
    }
    return fallback;
}

# ---------------- native dunder ops ----------------

obj DCReprOp(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        spec = args[0] as DCSpec;
        parts: list[str] = [];
        for f in dc_selected_fields(spec, "repr") {
            v = py_attr(args[1], f.fname);
            if is_error(v) {
                return v;
            }
            r = py_repr(v);
            if is_error(r) {
                return r;
            }
            parts.append(f.fname + "=" + expect_str(r));
        }
        return PyStr(
            t="str", val=spec.cls.name + "(" + dc_join(parts, ", ") + ")"
        );
    }
}

obj DCEqOp(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        spec = args[0] as DCSpec;
        if dc_same_class(args[1], args[2]) is None {
            return PY_NOT_IMPLEMENTED;
        }
        mine = dc_read_fields(spec, args[1], "compare");
        if is_error(mine) {
            return mine;
        }
        theirs = dc_read_fields(spec, args[2], "compare");
        if is_error(theirs) {
            return theirs;
        }
        mvals = (mine as PyList).items;
        tvals = (theirs as PyList).items;
        i = 0;
        while i < len(mvals) {
            c = py_compare(2, mvals[i], tvals[i]);
            if is_error(c) {
                return c;
            }
            truth = py_slot_truth(c);
            if is_error(truth) {
                return truth;
            }
            if not ((truth as PyBool).val) {
                return PyBool(t="bool", val=False);
            }
            i += 1;
        }
        return PyBool(t="bool", val=True);
    }
}

obj DCOrderOp(PyObj) {
    # args: spec, self, other, op char ("<", "<=", ">", ">="). Compares field
    # pairs in declaration order; the first unequal pair decides, all-equal
    # yields the inclusive/exclusive boundary per CPython's generated dunders.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        spec = args[0] as DCSpec;
        op = expect_str(args[3]);
        kind = 0;
        if op == "<=" {
            kind = 1;
        } elif op == ">" {
            kind = 4;
        } elif op == ">=" {
            kind = 5;
        }
        if dc_same_class(args[1], args[2]) is None {
            return PY_NOT_IMPLEMENTED;
        }
        mine = dc_read_fields(spec, args[1], "compare");
        if is_error(mine) {
            return mine;
        }
        theirs = dc_read_fields(spec, args[2], "compare");
        if is_error(theirs) {
            return theirs;
        }
        mvals = (mine as PyList).items;
        tvals = (theirs as PyList).items;
        i = 0;
        while i < len(mvals) {
            eqc = py_compare(2, mvals[i], tvals[i]);
            if is_error(eqc) {
                return eqc;
            }
            etruth = py_slot_truth(eqc);
            if is_error(etruth) {
                return etruth;
            }
            if not ((etruth as PyBool).val) {
                return py_compare(kind, mvals[i], tvals[i]);
            }
            i += 1;
        }
        return PyBool(t="bool", val=kind == 1 or kind == 5);
    }
}

obj DCHashOp(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        spec = args[0] as DCSpec;
        got = dc_read_fields(spec, args[1], "compare");
        if is_error(got) {
            return got;
        }
        return py_hash(PyTuple(t="tuple", items=(got as PyList).items));
    }
}

obj DCFrozenSetattrOp(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_error(
            "FrozenInstanceError",
            "cannot assign to field '" + expect_str(args[2]) + "'",
        );
    }
}

obj DCFrozenDelattrOp(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_error(
            "FrozenInstanceError",
            "cannot delete field '" + expect_str(args[2]) + "'",
        );
    }
}

glob DC_REPR_OP: DCReprOp = DCReprOp(t="dc_repr_op");
glob DC_EQ_OP: DCEqOp = DCEqOp(t="dc_eq_op");
glob DC_ORDER_OP: DCOrderOp = DCOrderOp(t="dc_order_op");
glob DC_HASH_OP: DCHashOp = DCHashOp(t="dc_hash_op");
glob DC_FROZEN_SET_OP: DCFrozenSetattrOp = DCFrozenSetattrOp(
    t="dc_frozen_set_op"
);
glob DC_FROZEN_DEL_OP: DCFrozenDelattrOp = DCFrozenDelattrOp(
    t="dc_frozen_del_op"
);

# ---------------- decorator ent points ----------------

obj PyDataclassWithParams(PyObj) {
    # The callable returned by @dataclass(...): applies the captured params.
    has params: DCParams;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 or not isinstance(args[0], PyClass) {
            return py_error(
                "TypeError", "@dataclass(...) expected exactly one class"
            );
        }
        return dc_process_class(args[0] as PyClass, self.params);
    }
}

obj DCDataclassFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) > 0 {
            if len(kwargs) > 0 {
                return py_error(
                    "TypeError",
                    "dataclass() received both a class and keyword arguments",
                );
            }
            if not isinstance(args[0], PyClass) {
                return py_error(
                    "TypeError",
                    "@dataclass expected a class, got '" + args[0].t + "'",
                );
            }
            return dc_process_class(args[0] as PyClass, DCParams(t="dc_params"));
        }
        params = dc_parse_params(kwargs);
        if is_error(params) {
            return params;
        }
        return PyDataclassWithParams(
            t="dc_with_params", params=params as DCParams
        );
    }
}

obj DCFieldFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) > 0 {
            return py_error("TypeError", "field() takes no positional arguments");
        }
        has_default = "default" in kwargs;
        has_factory = "default_factory" in kwargs;
        if has_default and has_factory {
            return py_error(
                "ValueError", "cannot specify both default and default_factory"
            );
        }
        fdefault: PyObj = DC_MISSING;
        ffactory: PyObj = py_none();
        if has_default {
            fdefault = kwargs["default"];
        }
        if has_factory {
            ffactory = kwargs["default_factory"];
        }
        return DCField(
            t="dc_field",
            fname="",
            annot=py_none(),
            fdefault=fdefault,
            ffactory=ffactory,
            has_factory=has_factory,
            finit=dc_param_flag(kwargs, "init", True),
            frepr=dc_param_flag(kwargs, "repr", True),
            fcompare=dc_param_flag(kwargs, "compare", True),
            fkw_only=dc_param_flag(kwargs, "kw_only", False),
            has_kw_only="kw_only" in kwargs,
        );
    }
}

# ---------------- module-level API callables ----------------

def dc_dataclass_cls_of(target: PyObj, msg: str) -> PyClass | PyObj {
    if isinstance(target, PyClass)
        and "__dataclass_fields__" in (target as PyClass).attrs {
        return target;
    }
    if isinstance(target, PyUserObj)
        and "__dataclass_fields__" in (target as PyUserObj).cls.attrs {
        return (target as PyUserObj).cls;
    }
    return py_error("TypeError", msg);
}

def dc_stored_fields(cls: PyClass) -> PyObj {
    if "__dataclass_fields__" in cls.attrs {
        stored = cls.attrs["__dataclass_fields__"];
        if isinstance(stored, PyDict) {
            return stored;
        }
    }
    return py_error("TypeError", "malformed __dataclass_fields__");
}

obj DCFieldsFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        got = dc_dataclass_cls_of(
            args[0], "fields() must be called with a dataclass type or instance"
        );
        if is_error(got) {
            return got;
        }
        stored = dc_stored_fields(got as PyClass);
        if is_error(stored) {
            return stored;
        }
        items: list[PyObj] = [];
        for hk in (stored as PyDict).items {
            items.append((stored as PyDict).items[hk].value);
        }
        return PyTuple(t="tuple", items=items);
    }
}

obj DCIsDataclassFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        v = args[0];
        if isinstance(v, PyClass) {
            return PyBool(
                t="bool",
                val="__dataclass_fields__" in (v as PyClass).attrs,
            );
        }
        if isinstance(v, PyUserObj) {
            return PyBool(
                t="bool",
                val="__dataclass_fields__" in (v as PyUserObj).cls.attrs,
            );
        }
        return PyBool(t="bool", val=False);
    }
}

# ---------------- recursion for asdict/astuple ----------------

def dc_is_dataclass_instance(v: PyObj) -> PyClass | None {
    if isinstance(v, PyUserObj)
        and "__dataclass_fields__" in (v as PyUserObj).cls.attrs {
        return (v as PyUserObj).cls;
    }
    return None;
}

def dc_asdict_value(v: PyObj) -> PyObj {
    cls = dc_is_dataclass_instance(v);
    if cls is not None {
        stored = dc_stored_fields(cls);
        if is_error(stored) {
            return stored;
        }
        out = PyDict(t="dict", items={});
        for hk in (stored as PyDict).items {
            ent = (stored as PyDict).items[hk];
            attr = py_attr(v, expect_str(ent.key));
            if is_error(attr) {
                return attr;
            }
            sub = dc_asdict_value(attr);
            if is_error(sub) {
                return sub;
            }
            setres = out.dict_set(ent.key, sub);
            if is_error(setres) {
                return setres;
            }
        }
        return out;
    }
    if isinstance(v, PyList) {
        new_items: list[PyObj] = [];
        for item in (v as PyList).items {
            sub = dc_asdict_value(item);
            if is_error(sub) {
                return sub;
            }
            new_items.append(sub);
        }
        return PyList(t="list", items=new_items);
    }
    if isinstance(v, PyTuple) {
        tup_items: list[PyObj] = [];
        for item in (v as PyTuple).items {
            sub = dc_asdict_value(item);
            if is_error(sub) {
                return sub;
            }
            tup_items.append(sub);
        }
        return PyTuple(t="tuple", items=tup_items);
    }
    if isinstance(v, PyDict) {
        d_out = PyDict(t="dict", items={});
        for hk in (v as PyDict).items {
            ent = (v as PyDict).items[hk];
            sub_v = dc_asdict_value(ent.value);
            if is_error(sub_v) {
                return sub_v;
            }
            setres = d_out.dict_set(ent.key, sub_v);
            if is_error(setres) {
                return setres;
            }
        }
        return d_out;
    }
    return v;
}

def dc_astuple_value(v: PyObj) -> PyObj {
    cls = dc_is_dataclass_instance(v);
    if cls is not None {
        stored = dc_stored_fields(cls);
        if is_error(stored) {
            return stored;
        }
        items: list[PyObj] = [];
        for hk in (stored as PyDict).items {
            ent = (stored as PyDict).items[hk];
            attr = py_attr(v, expect_str(ent.key));
            if is_error(attr) {
                return attr;
            }
            sub = dc_astuple_value(attr);
            if is_error(sub) {
                return sub;
            }
            items.append(sub);
        }
        return PyTuple(t="tuple", items=items);
    }
    if isinstance(v, PyList) {
        lst_items: list[PyObj] = [];
        for item in (v as PyList).items {
            sub = dc_astuple_value(item);
            if is_error(sub) {
                return sub;
            }
            lst_items.append(sub);
        }
        return PyList(t="list", items=lst_items);
    }
    if isinstance(v, PyTuple) {
        tp_items: list[PyObj] = [];
        for item in (v as PyTuple).items {
            sub = dc_astuple_value(item);
            if is_error(sub) {
                return sub;
            }
            tp_items.append(sub);
        }
        return PyTuple(t="tuple", items=tp_items);
    }
    if isinstance(v, PyDict) {
        d_out2 = PyDict(t="dict", items={});
        for hk in (v as PyDict).items {
            ent = (v as PyDict).items[hk];
            sub_v = dc_astuple_value(ent.value);
            if is_error(sub_v) {
                return sub_v;
            }
            setres = d_out2.dict_set(ent.key, sub_v);
            if is_error(setres) {
                return setres;
            }
        }
        return d_out2;
    }
    return v;
}

obj DCAsdictFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if dc_is_dataclass_instance(args[0]) is None {
            return py_error(
                "TypeError", "asdict() should be called on dataclass instances"
            );
        }
        return dc_asdict_value(args[0]);
    }
}

obj DCAstupleFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if dc_is_dataclass_instance(args[0]) is None {
            return py_error(
                "TypeError", "astuple() should be called on dataclass instances"
            );
        }
        return dc_astuple_value(args[0]);
    }
}

obj DCReplaceFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        cls = dc_is_dataclass_instance(args[0]);
        if cls is None {
            return py_error(
                "TypeError",
                "replace() should be called on dataclass instances",
            );
        }
        stored = dc_stored_fields(cls);
        if is_error(stored) {
            return stored;
        }
        call_kwargs: dict[str, PyObj] = {};
        # Seed every init=True field with its current value first.
        sdict = stored as PyDict;
        known: dict[str, DCField] = {};
        for hk in sdict.items {
            f = sdict.items[hk].value;
            if isinstance(f, DCField) {
                fd = f as DCField;
                known[fd.fname] = fd;
                if fd.finit {
                    cur = py_attr(args[0], fd.fname);
                    if is_error(cur) {
                        return cur;
                    }
                    call_kwargs[fd.fname] = cur;
                }
            }
        }
        for k in kwargs {
            if k not in known {
                return py_error(
                    "TypeError",
                    "(" + (cls as PyClass).name
                        + ") got an unexpected keyword argument '" + k + "'",
                );
            }
            if not known[k].finit {
                return py_error(
                    "ValueError",
                    "field " + k + " is declared with "
                        + "init=False, it cannot be specified with replace()",
                );
            }
            call_kwargs[k] = kwargs[k];
        }
        return (cls as PyClass).tp_call([], call_kwargs);
    }
}

# ---------------- parameter parsing ----------------

def dc_parse_params(kwargs: dict[str, PyObj]) -> PyObj {
    known = ["init", "repr", "eq", "order", "unsafe_hash", "frozen", "kw_only",
        "match_args", "slots", "weakref_slot"];
    for k in kwargs {
        ok = False;
        for cand in known {
            if k == cand {
                ok = True;
                break;
            }
        }
        if not ok {
            return py_error(
                "TypeError",
                "dataclass() got an unexpected keyword argument '" + k + "'",
            );
        }
    }
    return DCParams(
        t="dc_params",
        init=dc_param_flag(kwargs, "init", True),
        frepr=dc_param_flag(kwargs, "repr", True),
        eq=dc_param_flag(kwargs, "eq", True),
        order=dc_param_flag(kwargs, "order", False),
        unsafe_hash=dc_param_flag(kwargs, "unsafe_hash", False),
        frozen=dc_param_flag(kwargs, "frozen", False),
        kw_only=dc_param_flag(kwargs, "kw_only", False),
    );
}

# ---------------- field collection ----------------

def dc_annotation_str(a: PyObj) -> str {
    s = py_str(a);
    if is_error(s) {
        return "";
    }
    return expect_str(s);
}

def dc_strip_module_prefix(s: str) -> str {
    for pfx in ["typing.", "dataclasses."] {
        if s.startswith(pfx) {
            return s[len(pfx):];
        }
    }
    return s;
}

def dc_is_classvar(annot: PyObj) -> bool {
    return dc_strip_module_prefix(dc_annotation_str(annot)).startswith("ClassVar");
}

def dc_is_initvar(annot: PyObj) -> bool {
    if isinstance(annot, DCInitVarMark) {
        return True;
    }
    return dc_strip_module_prefix(dc_annotation_str(annot)).startswith("InitVar");
}

def dc_own_annotations(cls: PyClass) -> PyObj {
    # Evaluate the PEP 649 annotate function at format 1 (values evaluated).
    # Returns a PyDict keyed by field name in source order, or py_none() when
    # the class body declared no annotations.
    if "__annotate_func__" in cls.attrs {
        afn = cls.attrs["__annotate_func__"];
        return afn.tp_call([PyInt(t="int", val=1)], {});
    }
    return py_none();
}

def dc_mutable_type_name(v: PyObj) -> str {
    if isinstance(v, PyList) {
        return "<class 'list'>";
    }
    if isinstance(v, PyDict) {
        return "<class 'dict'>";
    }
    if isinstance(v, PySet) {
        return "<class 'set'>";
    }
    return "";
}

def dc_collect_fields(cls: PyClass, anns: PyObj, params: DCParams) -> PyObj {
    # Inherited fields keep their base-declaration order; a redeclared field
    # keeps its original position but refreshes type/annotation and any newly
    # given default/flags. `anns` is the caller-resolved annotation mapping
    # (PyDict) or py_none() when the class body has none.
    merged: list[DCField] = [];
    index: dict[str, int] = {};
    bases_first: list[PyClass] = [];
    for klass in class_mro(cls) {
        bases_first.insert(0, klass);
    }
    for klass in bases_first {
        if "__dataclass_fields__" not in klass.attrs {
            continue;
        }
        stored = klass.attrs["__dataclass_fields__"];
        if not isinstance(stored, PyDict) {
            continue;
        }
        for hk in (stored as PyDict).items {
            f = (stored as PyDict).items[hk].value;
            if not isinstance(f, DCField) {
                continue;
            }
            name = (f as DCField).fname;
            if name not in index {
                index[name] = len(merged);
                merged.append(f as DCField);
            }
        }
    }
    if isinstance(anns, PyDict) {
        adict = anns as PyDict;
        for hk in adict.items {
            name = expect_str(adict.items[hk].key);
            annot = adict.items[hk].value;
            if dc_is_classvar(annot) {
                continue;
            }
            if dc_is_initvar(annot) {
                # InitVar pseudo-field support is a tracked gap: excluded from
                # fields entirely rather than half-implemented.
                continue;
            }
            new_default: PyObj = DC_MISSING;
            new_factory: PyObj = py_none();
            new_has_factory = False;
            finit = True;
            frepr = True;
            fcompare = True;
            fkw_only = False;
            if name in cls.attrs {
                existing = cls.attrs[name];
                if isinstance(existing, DCField) {
                    old = existing as DCField;
                    finit = old.finit;
                    frepr = old.frepr;
                    fcompare = old.fcompare;
                    if old.has_kw_only {
                        fkw_only = old.fkw_only;
                    } else {
                        fkw_only = params.kw_only;
                    }
                    new_has_factory = old.has_factory;
                    new_factory = old.ffactory;
                    if old.fdefault is not DC_MISSING {
                        new_default = old.fdefault;
                    }
                } else {
                    new_default = existing;
                }
            }
            mutable = dc_mutable_type_name(new_default);
            if mutable != "" {
                return py_error(
                    "ValueError",
                    "mutable default " + mutable + " for field " + name
                        + " is not allowed: use default_factory",
                );
            }
            field_obj = DCField(
                t="dc_field",
                fname=name,
                annot=annot,
                fdefault=new_default,
                ffactory=new_factory,
                has_factory=new_has_factory,
                finit=finit,
                frepr=frepr,
                fcompare=fcompare,
                fkw_only=fkw_only,
                has_kw_only=True,
            );
            if name in index {
                merged[index[name]] = field_obj;
            } else {
                index[name] = len(merged);
                merged.append(field_obj);
            }
        }
    }
    return PyList(t="list", items=merged);
}

# ---------------- decoration ----------------

def dc_make_fn(ns: dict[str, PyObj], src: str, fname: str) -> PyObj {
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<dataclasses>", "exec")), [], ns
    );
    if is_error(outcome) {
        return outcome;
    }
    if fname not in ns {
        return py_error(
            "SystemError", "dataclass synthesis lost function '" + fname + "'"
        );
    }
    return ns[fname];
}

def dc_assign_lhs(spec: DCSpec, fname: str) -> str {
    if spec.params.frozen {
        return "object.__setattr__(self, '" + fname + "', ";
    }
    return "self." + fname + " = ";
}

def dc_build_init(spec: DCSpec, ns: dict[str, PyObj]) -> PyObj {
    sig_parts: list[str] = [];
    body = "";
    star_done = False;
    i = 0;
    for f in spec.fields {
        if not f.finit {
            # init=False fields never appear in the signature but ARE assigned
            # unconditionally by the body (default value or factory call).
            if f.has_factory {
                helper = "_dc_f" + str(i);
                ns[helper] = f.ffactory;
                body += "    " + dc_assign_lhs(spec, f.fname) + helper + "()\n";
            } else {
                helper = "_dc_d" + str(i);
                ns[helper] = f.fdefault;
                body += "    " + dc_assign_lhs(spec, f.fname) + helper + "\n";
            }
        }
        if f.finit {
            if f.fkw_only and not star_done {
                sig_parts.append("*");
                star_done = True;
            }
            tok = f.fname;
            if f.has_factory or f.fdefault is not DC_MISSING {
                tok += "=_DC_MISSING";
                body += "    if " + f.fname + " is _DC_MISSING:\n";
                if f.has_factory {
                    helper = "_dc_f" + str(i);
                    ns[helper] = f.ffactory;
                    body += "        " + f.fname + " = " + helper + "()\n";
                } else {
                    helper = "_dc_d" + str(i);
                    ns[helper] = f.fdefault;
                    body += "        " + f.fname + " = " + helper + "\n";
                }
            }
            sig_parts.append(tok);
            body += "    " + dc_assign_lhs(spec, f.fname) + f.fname;
            if spec.params.frozen {
                body += ")\n";
            } else {
                body += "\n";
            }
        }
        i += 1;
    }
    src = "def __init__(self";
    sig = dc_join(sig_parts, ", ");
    _LAST_INIT_SRC = PyStr(t="str", val=src + "\n" + body);
    if sig != "" {
        src += ", " + sig;
    }
    src += "):\n";
    if body == "" {
        body = "    pass\n";
    }
    return dc_make_fn(ns, src + body, "__init__");
}

def dc_wrapper_src(fname: str, op_name: str, extra_arg: str) -> str {
    src = "def " + fname + "(self";
    if extra_arg != "" {
        src += ", " + extra_arg;
    }
    src += "):\n    return " + op_name + "(_DC_SPEC, self";
    if extra_arg != "" {
        src += ", " + extra_arg;
    }
    src += ")\n";
    return src;
}

def dc_process_class(cls: PyClass, params: DCParams) -> PyObj {
    if params.order and not params.eq {
        return py_error("ValueError", "eq must be true if order is true");
    }
    anns = dc_own_annotations(cls);
    if is_error(anns) {
        return anns;
    }
    collected = dc_collect_fields(cls, anns, params);
    if is_error(collected) {
        return collected;
    }
    fields_list: list[DCField] = [];
    for item in (collected as PyList).items {
        fields_list.append(item as DCField);
    }
    # CPython _process_class ordering check over POSITIONAL init params only:
    # kw_only fields are exempt; defaults and factories both count as defaults.
    seen_default_name = "";
    for f in fields_list {
        if not f.finit or f.fkw_only {
            continue;
        }
        if f.has_factory or f.fdefault is not DC_MISSING {
            seen_default_name = f.fname;
            continue;
        }
        if seen_default_name != "" {
            return py_error(
                "TypeError",
                "non-default argument '" + f.fname + "' follows default argument '"
                    + seen_default_name + "'",
            );
        }
    }
    spec = DCSpec(t="dc_spec", cls=cls, fields=fields_list, params=params);
    ns: dict[str, PyObj] = {
        "_DC_MISSING": DC_MISSING,
        "_DC_SPEC": spec,
        # Frozen __init__ bodies assign through object.__setattr__, whose
        # attribute access resolves to the default-protocol wrapper in-VM.
        "object": host_builtin("object"),
    };
    if params.init {
        made = dc_build_init(spec, ns);
        if is_error(made) {
            return made;
        }
        cls.attrs["__init__"] = made;
    }
    if params.frepr {
        ns["_dc_repr_op"] = DC_REPR_OP;
        made2 = dc_make_fn(
            ns, dc_wrapper_src("__repr__", "_dc_repr_op", ""), "__repr__"
        );
        if is_error(made2) {
            return made2;
        }
        cls.attrs["__repr__"] = made2;
    }
    if params.eq {
        ns["_dc_eq_op"] = DC_EQ_OP;
        made3 = dc_make_fn(
            ns, dc_wrapper_src("__eq__", "_dc_eq_op", "other"), "__eq__"
        );
        if is_error(made3) {
            return made3;
        }
        cls.attrs["__eq__"] = made3;
    }
    if params.order {
        ns["_dc_order_op"] = DC_ORDER_OP;
        order_dunders = [["__lt__", "<"], ["__le__", "<="],
            ["__gt__", ">"], ["__ge__", ">="]];
        for pair in order_dunders {
            src = "def " + pair[0]
                + "(self, other):\n    return _dc_order_op(_DC_SPEC, self, other, '"
                + pair[1] + "')\n";
            made4 = dc_make_fn(ns, src, pair[0]);
            if is_error(made4) {
                return made4;
            }
            cls.attrs[pair[0]] = made4;
        }
    }
    if params.unsafe_hash or (params.eq and params.frozen) {
        ns["_dc_hash_op"] = DC_HASH_OP;
        made5 = dc_make_fn(
            ns, dc_wrapper_src("__hash__", "_dc_hash_op", ""), "__hash__"
        );
        if is_error(made5) {
            return made5;
        }
        cls.attrs["__hash__"] = made5;
    }
    if params.frozen {
        ns["_dc_frozen_set_op"] = DC_FROZEN_SET_OP;
        ns["_dc_frozen_del_op"] = DC_FROZEN_DEL_OP;
        made6 = dc_make_fn(
            ns,
            "def __setattr__(self, name, value):\n"
                + "    _dc_frozen_set_op(_DC_SPEC, self, name, value)\n",
            "__setattr__",
        );
        if is_error(made6) {
            return made6;
        }
        cls.attrs["__setattr__"] = made6;
        made7 = dc_make_fn(
            ns,
            "def __delattr__(self, name):\n"
                + "    _dc_frozen_del_op(_DC_SPEC, self, name)\n",
            "__delattr__",
        );
        if is_error(made7) {
            return made7;
        }
        cls.attrs["__delattr__"] = made7;
    }
    # eq=True without an explicit __hash__: leave __hash__ unset. The VM's
    # mro_hash_blocked rule (a class-dict __eq__ with no __hash__ blocks
    # hashing) already reproduces CPython's unhashable-instance behavior.
    stored = PyDict(t="dict", items={});
    for f in fields_list {
        setres = stored.dict_set(PyStr(t="str", val=f.fname), f);
        if is_error(setres) {
            return setres;
        }
    }
    cls.attrs["__dataclass_fields__"] = stored;
    return cls as PyObj;
}

# ---------------- module registration ----------------

glob DC_DATACLASS_FN: DCDataclassFn = DCDataclassFn(t="dc_dataclass_fn");
glob DC_FIELD_FN: DCFieldFn = DCFieldFn(t="dc_field_fn");

def register_dataclasses_module {
    attrs: dict[str, PyObj] = {
        "dataclass": DC_DATACLASS_FN,
        "field": DC_FIELD_FN,
        "fields": DCFieldsFn(t="dc_fields_fn"),
        "asdict": DCAsdictFn(t="dc_asdict_fn"),
        "astuple": DCAstupleFn(t="dc_astuple_fn"),
        "replace": DCReplaceFn(t="dc_replace_fn"),
        "is_dataclass": DCIsDataclassFn(t="dc_is_dc_fn"),
        "MISSING": DC_MISSING,
        "InitVar": DC_INITVAR,
        "FrozenInstanceError": PyExceptionType(
            t="exception_type", name="FrozenInstanceError"
        ),
    };
    register_shim_module(
        "dataclasses", PyModule(t="module", name="dataclasses", attrs=attrs)
    );
}


glob _LAST_INIT_SRC: PyStr = PyStr(t="str", val="");

def dc_debug_last_init_src -> PyStr {
    return _LAST_INIT_SRC;
}
