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
    PyNoneType,
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
    PyMappingProxy,
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

obj DCKwOnlyMark(PyObj) {
    # Stand-in for dataclasses.KW_ONLY. `x: KW_ONLY` (or KW_ONLY[...]) splits
    # the field list: every field after it becomes keyword-only.
    def mp_subscript(index: PyObj) -> PyObj {
        return self;
    }
}

glob DC_KW_ONLY: DCKwOnlyMark = DCKwOnlyMark(t="dc_kw_only");

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
        kw_only: bool = False,
        match_args: bool = True;
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
        has_kw_only: bool = False,
        # hash=None in field() means "follow compare" (CPython Field.hash);
        # has_hash marks the explicit form. fmetadata carries field(metadata=).
        fhash: bool = False,
        has_hash: bool = False,
        fmetadata: any = None,
        # InitVar pseudo-fields: __init__ params forwarded to __post_init__,
        # never instance fields (CPython _FIELD_INITVAR).
        finitvar: bool = False;

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
            fv = "_FIELD";
            if self.finitvar {
                fv = "_FIELD_INITVAR";
            }
            return PyStr(t="str", val=fv);
        }
        if name == "hash" {
            if self.has_hash {
                return PyBool(t="bool", val=self.fhash);
            }
            return py_none();
        }
        if name == "metadata" {
            # Always a mappingproxy (wrapped once at field construction), so
            # per-access identity is stable and writes raise like CPython.
            return self.fmetadata as PyObj;
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
        params: DCParams,
        # The class MRO resolves __post_init__: dc_build_init appends the
        # trailing self.__post_init__() call (CPython _init_fn has_post_init).
        has_post_init: bool = False;
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
        if f.finitvar {
            continue;
        }
        if mode == "repr" and not f.frepr {
            continue;
        }
        if mode == "hash" and not f.fhash {
            # CPython hash inclusion uses the RESOLVED field.hash (which
            # defaults to following compare), not compare itself.
            continue;
        }
        if mode == "eq" and not f.fcompare {
            continue;
        }
        if (mode != "repr" and mode != "hash" and mode != "eq")
            and not f.fcompare {
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
        got = dc_read_fields(spec, args[1], "hash");
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
        fhash = False;
        if "hash" in kwargs {
            hv = kwargs["hash"];
            if isinstance(hv, PyNoneType) {
                # hash=None is the CPython default: "follow compare".
            } elif isinstance(hv, PyBool) {
                fhash = (hv as PyBool).val;
            } else {
                return py_error("TypeError", "'hash' must be a bool or None");
            }
        }
        fmetadata: any = None;
        if "metadata" in kwargs {
            mv = kwargs["metadata"];
            if not isinstance(mv, PyDict) {
                return py_error("TypeError", "metadata must be a mapping");
            }
            fmetadata = PyMappingProxy(t="mappingproxy", target=mv as PyDict);
        } else {
            fmetadata = PyMappingProxy(t="mappingproxy", target=PyDict(t="dict", items={}));
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
            fhash=fhash,
            has_hash="hash" in kwargs,
            fmetadata=fmetadata,
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

def dc_public_fields(stored: PyObj) -> PyObj {
    # fields() / asdict() / astuple() exclude InitVar pseudo-fields
    # (CPython _FIELD_INITVAR never appears in the public tuple).
    items: list[PyObj] = [];
    for hk in (stored as PyDict).items {
        f = (stored as PyDict).items[hk].value;
        if isinstance(f, DCField) and (f as DCField).finitvar {
            continue;
        }
        items.append(f);
    }
    return PyTuple(t="tuple", items=items);
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
        return dc_public_fields(stored);
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
            fv = ent.value;
            if isinstance(fv, DCField) and (fv as DCField).finitvar {
                continue;
            }
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
            fv = ent.value;
            if isinstance(fv, DCField) and (fv as DCField).finitvar {
                continue;
            }
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
                if fd.finit and not fd.finitvar {
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
        match_args=dc_param_flag(kwargs, "match_args", True),
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

def dc_is_kwonly(annot: PyObj) -> bool {
    if isinstance(annot, DCKwOnlyMark) {
        return True;
    }
    return dc_strip_module_prefix(dc_annotation_str(annot)).startswith("KW_ONLY");
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
        # A KW_ONLY pseudo-annotation splits the declaration: every field after
        # it becomes keyword-only (CPython _process_class KW_ONLY handling).
        kw_split = False;
        for hk in adict.items {
            name = expect_str(adict.items[hk].key);
            annot = adict.items[hk].value;
            if dc_is_classvar(annot) {
                continue;
            }
            if dc_is_kwonly(annot) {
                kw_split = True;
                continue;
            }
            is_initvar = dc_is_initvar(annot);
            new_default: PyObj = DC_MISSING;
            new_factory: PyObj = py_none();
            new_has_factory = False;
            finit = True;
            frepr = True;
            fcompare = True;
            # Default resolution for kw_only is the decorator's class-level
            # param OR a preceding KW_ONLY marker; an explicit field(kw_only=...)
            # carried on a DCField attribute overrides below.
            fkw_only = params.kw_only or kw_split;
            new_fhash = False;
            new_has_hash = False;
            # Absent field() metadata still gets the shared empty read-only
            # view (CPython: an empty mappingproxy per Field).
            new_fmetadata: any = PyMappingProxy(
                t="mappingproxy", target=PyDict(t="dict", items={})
            );
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
                    if old.has_hash {
                        new_fhash = old.fhash;
                        new_has_hash = True;
                    }
                    new_fmetadata = old.fmetadata;
                    if old.fdefault is not DC_MISSING {
                        new_default = old.fdefault;
                    }
                } else {
                    new_default = existing;
                    # Plain non-field default: class-param resolution already
                    # held when fkw_only was initialized.
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
            resolved_fhash = new_fhash;
            if not new_has_hash {
                resolved_fhash = fcompare;
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
                # CPython _get_field: hash missing -> follow compare.
                fhash=resolved_fhash,
                has_hash=new_has_hash,
                fmetadata=new_fmetadata,
                finitvar=is_initvar,
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
    post_args = "";
    j = 1000;
    for f in spec.fields {
        if f.finitvar {
            # InitVar pseudo-field: signature param at its declaration
            # position (CPython preserves source order), never assigned to
            # the instance, forwarded verbatim to __post_init__.
            if f.fkw_only and not star_done {
                sig_parts.append("*");
                star_done = True;
            }
            tok = f.fname;
            if f.has_factory or f.fdefault is not DC_MISSING {
                tok += "=_DC_MISSING";
                body += "    if " + f.fname + " is _DC_MISSING:\n";
                if f.has_factory {
                    helper = "_dc_f" + str(j);
                    ns[helper] = f.ffactory;
                    body += "        " + f.fname + " = " + helper + "()\n";
                } else {
                    helper = "_dc_d" + str(j);
                    ns[helper] = f.fdefault;
                    body += "        " + f.fname + " = " + helper + "\n";
                }
            }
            sig_parts.append(tok);
            if post_args != "" {
                post_args += ", ";
            }
            post_args += f.fname;
            j += 1;
            continue;
        }
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
    DC_DEBUG_LAST_SRC = PyStr(t="str", val=src + "\n" + body);
    if sig != "" {
        src += ", " + sig;
    }
    src += "):\n";
    if spec.has_post_init {
        # CPython _init_fn: the generated __init__ ends with the __post_init__
        # call, receiving the InitVar values in field order.
        call = "self.__post_init__(" + post_args + ")";
        body += "    " + call + "\n";
    }
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
    # CPython _process_class ordering check over POSITIONAL init params
    # INCLUDING InitVar pseudo-fields (all_init_fields); kw_only fields are
    # exempt; defaults and factories both count as defaults.
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
    resolved_post = class_lookup_attr(cls, "__post_init__");
    spec = DCSpec(
        t="dc_spec", cls=cls, fields=fields_list, params=params,
        has_post_init=not is_error(resolved_post),
    );
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
    if params.match_args {
        # CPython _process_class: __match_args__ lists the fields callable can
        # pass positionally -- init=True, not kw_only.
        ma: list[PyObj] = [];
        for f in fields_list {
            if f.finit and not f.fkw_only and not f.finitvar {
                ma.append(PyStr(t="str", val=f.fname));
            }
        }
        cls.attrs["__match_args__"] = PyTuple(t="tuple", items=ma);
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

# Stand-in for the dataclasses.Field CLASS object (isinstance checks against it
# are out of scope; field() instances are the real DCFields).
glob DC_FIELD_CLASS_MARK: PyObj = PyObj(t="dc_field_class_mark");

obj DCMakeDataclassFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error(
                "TypeError",
                "make_dataclass() missing 2 required positional arguments"
            );
        }
        cls_name = expect_str(args[0]);
        specs_obj = args[1];
        specs: list[PyObj] = [];
        if isinstance(specs_obj, PyList) {
            for sp in (specs_obj as PyList).items {
                specs.append(sp);
            }
        } elif isinstance(specs_obj, PyTuple) {
            for sp in (specs_obj as PyTuple).items {
                specs.append(sp);
            }
        } else {
            return py_error("TypeError", "fields must be a list of tuples");
        }
        params = dc_parse_params(kwargs);
        if is_error(params) {
            return params;
        }
        # Decorator parameter text: serialize only non-default flags so error
        # parity with direct @dataclass use stays exact.
        pbits: list[str] = [];
        if not (params as DCParams).init {
            pbits.append("init=False");
        }
        if not (params as DCParams).frepr {
            pbits.append("repr=False");
        }
        if not (params as DCParams).eq {
            pbits.append("eq=False");
        }
        if (params as DCParams).order {
            pbits.append("order=True");
        }
        if (params as DCParams).unsafe_hash {
            pbits.append("unsafe_hash=True");
        }
        if (params as DCParams).frozen {
            pbits.append("frozen=True");
        }
        if (params as DCParams).kw_only {
            pbits.append("kw_only=True");
        }
        if not (params as DCParams).match_args {
            pbits.append("match_args=False");
        }
        dec = "dataclass";
        if len(pbits) > 0 {
            dec += "(";
            first = True;
            for pb in pbits {
                if not first {
                    dec += ", ";
                }
                dec += pb;
                first = False;
            }
            dec += ")";
        }
        ns: dict[str, PyObj] = {
            "__name__": PyStr(t="str", val="dataclasses"),
            "dataclass": DC_DATACLASS_FN,
        };
        src = "@" + dec + "\nclass " + cls_name + ":\n";
        body = "";
        i = 0;
        for sp in specs {
            name = "";
            annot_helper = "_dc_t" + str(i);
            default_helper = "";
            if isinstance(sp, PyStr) {
                # A bare string name means an untyped field; None annotation
                # behaves as Any for our collection pass.
                name = expect_str(sp);
                ns[annot_helper] = py_none();
            } elif isinstance(sp, PyTuple) {
                items = (sp as PyTuple).items;
                if len(items) < 2 {
                    return py_error(
                        "ValueError",
                        "field tuples must be (name, type[, default])"
                    );
                }
                name = expect_str(items[0]);
                ns[annot_helper] = items[1];
                if len(items) >= 3 {
                    third = items[2];
                    if isinstance(third, DCField) {
                        # field(...) spec: seed the DCField as the class-body
                        # default so dc_collect_fields resolves it exactly like
                        # an explicit field() declaration.
                        default_helper = "_dc_f" + str(i);
                        ns[default_helper] = third;
                    } elif third is not DC_MISSING {
                        default_helper = "_dc_d" + str(i);
                        ns[default_helper] = third;
                    }
                }
            } else {
                return py_error("TypeError", "invalid field spec");
            }
            body += "    " + name + ": " + annot_helper;
            if default_helper != "" {
                body += " = " + default_helper;
            }
            body += "\n";
            i += 1;
        }
        if body == "" {
            body = "    pass\n";
        }
        src += body;
        outcome = exec_code(
            unmarshal(host_compile_marshal(src, "<dataclasses>", "exec")), [], ns
        );
        if is_error(outcome) {
            return outcome;
        }
        if cls_name not in ns {
            return py_error(
                "SystemError", "make_dataclass lost class '" + cls_name + "'"
            );
        }
        return ns[cls_name];
    }
}

glob DC_MAKE_DATACLASS_FN: DCMakeDataclassFn = DCMakeDataclassFn(t="dc_make_dataclass_fn");

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
        "KW_ONLY": DC_KW_ONLY,
        "make_dataclass": DC_MAKE_DATACLASS_FN,
        "Field": DC_FIELD_CLASS_MARK,
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
