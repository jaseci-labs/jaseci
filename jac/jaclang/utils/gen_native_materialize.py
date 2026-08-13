"""Generate jaclang/compiler/native_materialize.jac and its Python manifest.

Dev-time tool (follow-up: fold into a `jac gen-materialize` command like
`jac gen-uni-dispatch`). Usage, from jac/ with a dev jaclang importable:

    python jaclang/utils/gen_native_materialize.py <parser layout.json>

where the layout comes from any fresh seal of the materializer root (the
parity suite's temp dir, or a payload build). Staleness is self-policing:
if unitree's schema moves and this file is not regenerated, the sealed
parity suite fails at field/key level.

Emits a native jac module that walks the sealed parser's tree with TYPED
field reads and rebuilds it as CPython objects through libpython externs.
Field selection reuses the seal's mask (parser-set fields only) and the
layout's foreign flags (dead slots -> None, reconstructed by
materialize_fixups exactly as the C path does).
"""
import json
import re
import sys
from dataclasses import fields as dc_fields
from pathlib import Path

import jaclang
import jaclang.jac0core.unitree as uni
import jaclang.jac0core.srcloc as srcloc
import jaclang.jac0core.constant as constant
from jaclang.utils.precompile_bytecode import _materialize_mask

PKG = Path(jaclang.__file__).parent
LAYOUT = json.loads(Path(sys.argv[1]).read_text())
OUT_JAC = PKG / "compiler" / "native_materialize.jac"
OUT_MANIFEST = PKG / "compiler" / "native_materialize_manifest.py"

NS = {}
for mod in (uni, srcloc):
    for k, v in vars(mod).items():
        if isinstance(v, type) and v.__module__ == mod.__name__:
            NS.setdefault(k, v)

ENUM_NS = {}
for mod in (uni, constant, srcloc):
    for k, v in vars(mod).items():
        if isinstance(v, type) and hasattr(v, "__members__"):
            ENUM_NS.setdefault(k, v)

observed, mangle = _materialize_mask(PKG)
inv_mangle = {v: k for k, v in mangle.items()}

structs = LAYOUT["structs"]
foreign = {
    (sn, f["name"]): bool(f.get("foreign"))
    for sn, sd in structs.items()
    for f in sd["fields"]
}
layout_fields = {sn: [f["name"] for f in sd["fields"]] for sn, sd in structs.items()}

chain_classes = []  # UniNode subclasses, leaf-first
direct_classes = []  # non-UniNode emittables (CodeLocInfo, Symbol, ...)
for sn in structs:
    cls = NS.get(sn)
    if cls is None:
        continue
    if issubclass(cls, uni.UniNode):
        chain_classes.append(sn)
    else:
        direct_classes.append(sn)

# leaf-first: deepest MRO first so isinstance dispatch picks the most
# specific class; frequency boost for the hot token family
freq = {"Name": 0, "Token": 1, "String": 2, "Int": 3, "Semi": 4}
chain_classes.sort(key=lambda n: (-len(NS[n].__mro__), freq.get(n, 50), n))
all_emit = chain_classes + sorted(direct_classes)

SCALARS = {"int": "LONG", "bool": "BOOL", "float": "FLOAT", "str": "STR"}

keys = []          # interned key strings, index order
key_idx = {}
enum_sites = []    # enum class names, index order
enum_idx = {}
enum_handle_base = {}
warnings = []


def kidx(name):
    if name not in key_idx:
        key_idx[name] = len(keys)
        keys.append(name)
    return key_idx[name]


def register_enum(en):
    if en not in enum_idx:
        enum_idx[en] = len(enum_sites)
        enum_sites.append(en)
    return enum_idx[en]


def split_union(s):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        if ch == "|" and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    out.append(cur.strip())
    return [a.strip("() ") for a in out if a.strip("() ")]


def norm(t):
    return t.replace("Sequence[", "list[").strip("() ")


def inner(t):
    m = re.match(r"^\w+\[(.*)\]$", t)
    return m.group(1) if m else ""


def emit_value(expr, ann, out, ind, uid):
    """Append jac lines computing handle `v_{uid}` for `expr` typed `ann`.
    Every generated local carries the uid: native locals are single-typed,
    so nothing may be reused across fields of different types."""
    v = f"v_{uid}"
    ann = norm(ann)
    arms = split_union(ann)
    has_none = "None" in arms
    arms = [a for a in arms if a != "None"]
    pre = ind

    def line(t):
        out.append(pre + t)

    if not arms:
        line(f"{v} = _py_none();")
        return v
    # flow narrowing applies to locals, not repeated attribute reads
    fv = f"fv_{uid}"
    line(f"{fv} = {expr};")
    expr = fv
    if has_none:
        line(f"if {expr} is None {{")
        line(f"    {v} = _py_none();")
        line("} else {")
        pre = ind + "    "
    if len(arms) == 1:
        a = arms[0]
        base = re.match(r"^(\w+)", a).group(1)
        if a in SCALARS:
            line(f"{v} = " + _scalar_expr(expr, a) + ";")
        elif base == "list":
            _emit_list(v, expr, inner(a), out, pre, uid)
        elif base == "dict":
            _emit_dict(v, expr, inner(a), out, pre, uid)
        elif base == "set":
            # native set iteration does not lower; every set-typed field is
            # an analysis-time slot that is empty at parse, so emit an empty
            # set and refuse loudly if that contract ever breaks
            line(f"{v} = PySet_New(0);")
            line(f"if len({expr}) != 0 {{")
            line(f"    Py_DecRef({v});")
            line("    return 0;")
            line("}")
        elif base in ENUM_NS:
            register_enum(base)
            line(f"{v} = _enum_{base}({expr});")
        elif base == "SubTag":
            line(f"{v} = _emit_node({expr});")
        elif base in NS and issubclass(NS[base], uni.UniNode):
            line(f"{v} = _emit_node({expr});")
        elif base in NS:
            line(f"{v} = _emit_{base}({expr});")
        else:
            warnings.append(f"unhandled annotation {ann!r} -> None")
            line(f"{v} = _py_none();")
    else:
        list_arms = [a for a in arms if norm(a).startswith("list[")]
        cls_arms = []
        for a in arms:
            b = re.match(r"^(\w+)", norm(a)).group(1)
            if b != "list" and b in NS:
                cls_arms.append(b)
        first_kw = "if"
        if list_arms:
            la_elem = inner(norm(list_arms[0]))
            la_base = re.match(r"^(\w+)", la_elem).group(1) if la_elem else "UniNode"
            line(f"if isinstance({expr}, list) {{")
            # annotated rebind coerces the union's first-member pointer repr
            # into the list repr the loop helpers expect
            line(f"    tl_{uid}: list[{la_base}] = {expr};")
            _emit_list(v, f"tl_{uid}", la_elem, out, pre + "    ", uid)
            first_kw = "} elif"
        for b in cls_arms:
            line(f"{first_kw} isinstance({expr}, {b}) {{")
            line(f"    {v} = _emit_node({expr});")
            first_kw = "} elif"
        if first_kw == "if":
            line(f"{v} = _py_none();")
        else:
            line("} else {")
            line(f"    {v} = _py_none();")
            line("}")
    if has_none:
        out.append(ind + "}")
    return v


def _scalar_expr(expr, a):
    a = a.strip()
    if a == "int":
        return f"PyLong_FromLongLong({expr})"
    if a == "bool":
        return f"PyBool_FromLong(1 if {expr} else 0)"
    if a == "float":
        return f"PyFloat_FromDouble({expr})"
    if a == "str":
        return f"_py_str({expr})"
    return "_py_none()"


def _emit_list(v, expr, elem, out, ind, uid):
    elem = norm(elem)
    base = re.match(r"^(\w+)", elem).group(1) if elem else ""
    u = uid + "l"
    out.append(ind + f"{v} = PyList_New(len({expr}));")
    out.append(ind + f"li_{u} = 0;")
    out.append(ind + f"for it_{u} in {expr} {{")
    if elem in SCALARS:
        out.append(ind + f"    e_{u} = " + _scalar_expr(f"it_{u}", elem) + ";")
    elif base in NS and not issubclass(NS.get(base, object), uni.UniNode):
        out.append(ind + f"    e_{u} = _emit_{base}(it_{u});")
    else:
        out.append(ind + f"    e_{u} = _emit_node(it_{u});")
    out.append(ind + f"    PyList_SetItem({v}, li_{u}, e_{u});")
    out.append(ind + f"    li_{u} += 1;")
    out.append(ind + "}")


def _emit_dict(v, expr, kv, out, ind, uid):
    kv_parts, dpt, cur = [], 0, ""
    for ch in kv:
        if ch == "[":
            dpt += 1
        elif ch == "]":
            dpt -= 1
        if ch == "," and dpt == 0:
            kv_parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    kv_parts.append(cur.strip())
    kt, vt = (kv_parts + ["", ""])[:2]
    kt, vt = norm(kt), norm(vt)
    u = uid + "d"
    out.append(ind + f"{v} = PyDict_New();")
    out.append(ind + f"for (dk_{u}, dv_{u}) in {expr}.items() {{")
    kexpr = _scalar_expr(f"dk_{u}", kt if kt in SCALARS else "int")
    out.append(ind + f"    kh_{u} = {kexpr};")
    vbase = re.match(r"^(\w+)", vt).group(1) if vt else ""
    if vt in SCALARS:
        out.append(ind + f"    vh_{u} = " + _scalar_expr(f"dv_{u}", vt) + ";")
    elif vbase == "list":
        _emit_list(f"vh_{u}", f"dv_{u}", inner(vt), out, ind + "    ", u)
    elif vbase == "set":
        out.append(ind + f"    vh_{u} = PySet_New(0);")
        out.append(ind + f"    if len(dv_{u}) != 0 {{")
        out.append(ind + f"        Py_DecRef(vh_{u});")
        out.append(ind + "        return 0;")
        out.append(ind + "    }")
    elif vbase in NS and not issubclass(NS.get(vbase, object), uni.UniNode):
        out.append(ind + f"    vh_{u} = _emit_{vbase}(dv_{u});")
    else:
        out.append(ind + f"    vh_{u} = _emit_node(dv_{u});")
    out.append(ind + f"    PyDict_SetItem({v}, kh_{u}, vh_{u});")
    out.append(ind + f"    Py_DecRef(kh_{u});")
    out.append(ind + f"    Py_DecRef(vh_{u});")
    out.append(ind + "}")


def class_fields(sn):
    """(layout field name, dict key, annotation) for fields to materialize."""
    cls = NS[sn]
    ann_by_name = {}
    for f in dc_fields(cls):
        base = inv_mangle.get(f.name, f.name)
        ann_by_name[base] = str(f.type)
    keep = observed.get(sn)
    out = []
    for lf in layout_fields.get(sn, []):
        dict_key = mangle.get(lf, lf)
        if keep is not None and dict_key not in keep:
            continue
        out.append((lf, dict_key, ann_by_name.get(lf)))
    return out


emit_fns = []
for ci, sn in enumerate(all_emit):
    lines = []
    param_t = sn
    lines.append(f"def _emit_{sn}(nd: {param_t}) -> int {{")
    lines.append("    h = _mat_memo.get(id(nd), 0);")
    lines.append("    if h != 0 {")
    lines.append("        Py_IncRef(h);")
    lines.append("        return h;")
    lines.append("    }")
    lines.append(
        f"    obj_h = PyObject_CallOneArg(_mat_news[{ci}], _mat_classes[{ci}]);"
    )
    lines.append("    if obj_h == 0 {")
    lines.append("        return 0;")
    lines.append("    }")
    lines.append("    _mat_memo[id(nd)] = obj_h;")
    lines.append("    d_h = PyObject_GenericGetDict(obj_h, 0);")
    lines.append("    if d_h == 0 {")
    lines.append("        return 0;")
    lines.append("    }")
    for fi, (lf, dict_key, ann) in enumerate(class_fields(sn)):
        ki = kidx(dict_key)
        uid = f"{ci}_{fi}"
        lines.append(f"    # {dict_key}: {ann}")
        if foreign.get((sn, lf)) or ann is None:
            vname = f"v_{uid}"
            lines.append(f"    {vname} = _py_none();")
        elif sn == "SubTag" and lf == "tag":
            # generic slot is type-erased natively; the payload is the LAST
            # kid (leading kids are punctuation like the colon)
            vname = f"v_{uid}"
            lines.append(f"    {vname} = _emit_node(nd.kid[len(nd.kid) - 1]);")
        else:
            body = []
            vname = emit_value(f"nd.{lf}", ann, body, "    ", uid)
            lines.extend(body)
        lines.append(f"    PyDict_SetItem(d_h, _mat_keys[{ki}], {vname});")
        lines.append(f"    Py_DecRef({vname});")
    lines.append("    Py_DecRef(d_h);")
    lines.append("    Py_IncRef(obj_h);")
    lines.append("    return obj_h;")
    lines.append("}")
    emit_fns.append("\n".join(lines))

# dispatch chain over UniNode subclasses, leaf-first
chain = ["def _emit_node(nd: UniNode) -> int {"]
first = True
for sn in chain_classes:
    kw = "if" if first else "} elif"
    chain.append(f"    {kw} isinstance(nd, {sn}) {{")
    chain.append(f"        return _emit_{sn}(nd);")
    first = False
chain.append("    }")
chain.append("    return _py_none();")
chain.append("}")

enum_fns = []
enum_members_manifest = []
base = 0
for en in enum_sites:
    ecls = ENUM_NS[en]
    members = [m for m in ecls.__members__]
    enum_handle_base[en] = base
    enum_members_manifest.append((en, members))
    fl = [f"def _enum_{en}(v: {en}) -> int {{"]
    for mi, mn in enumerate(members):
        kw = "if" if mi == 0 else "} elif"
        fl.append(f"    {kw} v == {en}.{mn} {{")
        fl.append(f"        h = _mat_enums[{base + mi}];")
        fl.append("        Py_IncRef(h);")
        fl.append("        return h;")
    fl.append("    }")
    fl.append("    return PyLong_FromLongLong(0);")
    fl.append("}")
    enum_fns.append("\n".join(fl))
    base += len(members)

uni_imports = sorted({sn for sn in all_emit if NS[sn].__module__ == uni.__name__}
                     | {"UniNode"})
src_imports = sorted({sn for sn in all_emit if NS[sn].__module__ == srcloc.__name__})
enum_imports = sorted(
    {en for en in enum_sites if ENUM_NS[en].__module__ == uni.__name__})
const_enum_imports = sorted(
    {en for en in enum_sites if ENUM_NS[en].__module__ == constant.__name__})

HEADER = f'''"""GENERATED by gen_materialize (do not edit; regenerate on unitree
schema changes -- the sealed parity suite fails loudly when stale).

The seal root for the native parser artifact: importing the parser pulls
parse_program (and the whole unitree closure) into this native unit, and the
emitters below rebuild a parsed tree as real CPython objects through
libpython externs resolved from the host process (ELF lazy PLT / Mach-O flat
lookup). Bound with the GIL HELD (PYFUNCTYPE); see frontend._native_parse.
Erased native slots stay None here and are reconstructed by
native_marshal.materialize_fixups, same as the C materializer they replace.
"""
# the closure anchor: pulls parse_program and the whole parser+unitree
# native unit into this artifact
import from jaclang.jac0core.parser.parser {{ parse_program }}
import from jaclang.jac0core.unitree {{
    {("," + chr(10) + "    ").join(uni_imports)}
}}
import from jaclang.jac0core.srcloc {{ {", ".join(src_imports)} }}

import from python {{
    def PyLong_FromLongLong(v: int) -> int;
    def PyBool_FromLong(v: int) -> int;
    def PyFloat_FromDouble(v: float) -> int;
    def PyUnicode_FromStringAndSize(s: str, n: int) -> int;
    def PyList_New(n: int) -> int;
    def PyList_SetItem(l: int, i: int, v: int) -> i32;
    def PyDict_New() -> int;
    def PyDict_SetItem(d: int, k: int, v: int) -> i32;
    def PySet_New(i: int) -> int;
    def PySet_Add(s: int, v: int) -> i32;
    def PyObject_CallOneArg(f: int, a: int) -> int;
    def PyObject_GenericGetDict(o: int, ctx: int) -> int;
    def Py_IncRef(o: int) -> None;
    def Py_DecRef(o: int) -> None;
    def Py_GetConstant(cid: int) -> int;
}}

glob _mat_classes: list[int] = [],
     _mat_news: list[int] = [],
     _mat_keys: list[int] = [],
     _mat_enums: list[int] = [],
     _mat_memo: dict[int, int] = {{}};

def _py_none -> int {{
    return Py_GetConstant(0);
}}

def _py_str(s: str) -> int {{
    return PyUnicode_FromStringAndSize(s, len(s));
}}

def mat_reset(ncls: int, nkeys: int, nenums: int) -> None {{
    _mat_classes.clear();
    _mat_news.clear();
    _mat_keys.clear();
    _mat_enums.clear();
    i = 0;
    while i < ncls {{
        _mat_classes.append(0);
        _mat_news.append(0);
        i += 1;
    }}
    i = 0;
    while i < nkeys {{
        _mat_keys.append(0);
        i += 1;
    }}
    i = 0;
    while i < nenums {{
        _mat_enums.append(0);
        i += 1;
    }}
}}

def mat_set_class(i: int, cls_h: int, new_h: int) -> None {{
    _mat_classes[i] = cls_h;
    _mat_news[i] = new_h;
}}

def mat_set_key(i: int, key_h: int) -> None {{
    _mat_keys[i] = key_h;
}}

def mat_set_enum(i: int, member_h: int) -> None {{
    _mat_enums[i] = member_h;
}}

def mat_materialize(mod: Module) -> int {{
    root_h = _emit_node(mod);
    for (_addr, h) in _mat_memo.items() {{
        Py_DecRef(h);
    }}
    _mat_memo.clear();
    return root_h;
}}
'''

if const_enum_imports:
    HEADER = HEADER.replace(
        "import from jaclang.jac0core.srcloc",
        "import from jaclang.jac0core.constant { "
        + ", ".join(const_enum_imports)
        + " }\nimport from jaclang.jac0core.srcloc",
    )

parts = [HEADER, "\n\n".join(enum_fns), "\n\n".join(emit_fns), "\n".join(chain)]
OUT_JAC.write_text("\n\n".join(p for p in parts if p) + "\n", encoding="utf-8")

manifest = {
    "class_names": all_emit,
    "key_names": keys,
    "enums": enum_members_manifest,
}
OUT_MANIFEST.write_text(
    '"""GENERATED by gen_materialize alongside native_materialize.jac."""\n'
    f"CLASS_NAMES = {manifest['class_names']!r}\n"
    f"KEY_NAMES = {manifest['key_names']!r}\n"
    f"ENUM_MEMBERS = {manifest['enums']!r}\n",
    encoding="utf-8",
)
print(f"emitted {OUT_JAC} ({len(OUT_JAC.read_text().splitlines())} lines)")
print(f"classes {len(all_emit)}, keys {len(keys)}, enum handles {base}")
for w in sorted(set(warnings)):
    print("WARN:", w)
