/* jacmat: C materializer that turns a sealed native parser's tree into real
 * Python unitree objects.
 *
 * The sealed parser (see utils/precompile_bytecode.jac, seal_native_artifacts)
 * builds the full unitree in native memory. This module walks that memory and
 * reconstructs the identical object graph as ordinary Python instances, so the
 * unmodified bytecode compiler pipeline can consume native parses with no view
 * layer in between. Instances are allocated via tp_new (never __init__ or
 * __post_init__: the native tree already holds post-construction state) and
 * their instance dicts are filled directly with interned keys.
 *
 * It is table driven: jacmat.install(recipes) installs per-struct field tables
 * that the seal bakes into the artifact layout ("materialize" section) and the
 * runtime resolves against live classes (native_marshal.jac,
 * materialize_recipes_from_layout). Field kind codes here MUST match
 * MATERIALIZE_K_* in jaclang/jac0core/native_marshal.jac.
 *
 * Class identity comes from the rc allocation header's class stamp:
 *   [addr-32] alloc_id (magic 0xAC1D in bits 32..47)
 *   [addr-24] char* type tag (class name, or a container tag like "list_ptr")
 *   [addr-16] refcount (0x7FFFFFFFFFFFFFFF = immortal sentinel)
 *   [addr-8]  dtor slot; for strings (length << 1) | 1
 * (offsets mirror jaclang/jac0core/codeinfo.jac HDR_*_OFF).
 *
 * The load-bearing decode rule, learned the hard way: a pointer slot is
 * decoded by its runtime stamp FIRST and by its declared layout type only for
 * unstamped memory. Declared types lie whenever a union is erased into one
 * arm (LambdaExpr.body declared Expr* holding a list; ImplDef.spec declared
 * List.ptr* holding a FuncSignature).
 */
#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define HDR_ALLOC_ID_OFF (-32)
#define HDR_TAG_OFF (-24)
#define HDR_RC_OFF (-16)
#define HDR_DTOR_OFF (-8)
#define RC_SENTINEL 0x7FFFFFFFFFFFFFFFULL
#define HDR_MAGIC 0xAC1DULL

/* field kinds; keep in lockstep with MATERIALIZE_K_* in native_marshal.jac */
enum {
    K_NONE = 0, K_I64 = 1, K_I1 = 2, K_F64 = 3, K_STR = 4,
    K_STRUCT = 5, K_OPT = 6, K_LIST = 7, K_DICT = 8, K_SET = 9,
    K_ENUM = 10, K_RAWPTR = 11,
};

typedef struct { PyObject *key; int kind; int off; int aux1; int aux2; int hint; PyObject *extra; } FieldRec;
typedef struct { PyObject *cls; int nfields; FieldRec *fields; } Recipe;

typedef struct { int64_t len; int64_t cap; void *data; } NativeList;
typedef struct { int64_t len; int64_t cap; void *keys; void *vals; void *ctrl; int64_t used; void *order; } NativeDict;
typedef struct { int64_t len; int64_t cap; void *keys; void *ctrl; int64_t used; void *order; } NativeSet;

static Recipe *g_recipes = NULL;
static int g_nrecipes = 0;
static PyObject *g_name_to_idx = NULL; /* struct name -> int index */
static PyObject *g_empty_tuple = NULL;

/* anomaly counters, exposed via stats(); a nonzero count after a materialize
 * means the artifact and this build disagree about memory layout somewhere */
static long g_ct_nodes, g_ct_unknown_stamp, g_ct_unmapped_cls;
static long g_ct_bad_list, g_ct_bad_ptr, g_ct_bad_dict;

#define LIST_MAX (1L << 24)
static inline int list_ok(NativeList *nl) {
    return nl->len >= 0 && nl->len <= LIST_MAX && nl->cap >= nl->len &&
           (nl->len == 0 || (nl->data && ((uintptr_t)nl->data & 7) == 0));
}

/* open-address table: uintptr -> PyObject* (strong refs) */
typedef struct { uintptr_t *keys; PyObject **vals; size_t cap; size_t n; } Memo;
static Memo g_memo, g_strcache, g_stampcache;

static int memo_grow(Memo *m);
static int memo_init(Memo *m, size_t cap) {
    m->keys = (uintptr_t *)calloc(cap, sizeof(uintptr_t));
    m->vals = (PyObject **)calloc(cap, sizeof(PyObject *));
    m->cap = cap;
    m->n = 0;
    return (m->keys && m->vals) ? 0 : -1;
}
static void memo_free(Memo *m) {
    free(m->keys);
    free(m->vals);
    m->keys = NULL;
    m->vals = NULL;
    m->cap = m->n = 0;
}
static int memo_put(Memo *m, uintptr_t k, PyObject *v) {
    if (m->n * 2 >= m->cap && memo_grow(m) < 0) return -1;
    size_t mask = m->cap - 1, i = (k * 0x9E3779B97F4A7C15ULL >> 17) & mask;
    while (m->keys[i] && m->keys[i] != k) i = (i + 1) & mask;
    if (!m->keys[i]) { m->keys[i] = k; m->n++; }
    m->vals[i] = v;
    return 0;
}
static PyObject *memo_get(Memo *m, uintptr_t k) {
    if (!m->cap) return NULL;
    size_t mask = m->cap - 1, i = (k * 0x9E3779B97F4A7C15ULL >> 17) & mask;
    while (m->keys[i]) {
        if (m->keys[i] == k) return m->vals[i];
        i = (i + 1) & mask;
    }
    return NULL;
}
static int memo_grow(Memo *m) {
    Memo bigger;
    if (memo_init(&bigger, m->cap * 2) < 0) return -1;
    for (size_t i = 0; i < m->cap; i++)
        if (m->keys[i]) memo_put(&bigger, m->keys[i], m->vals[i]);
    memo_free(m);
    *m = bigger;
    return 0;
}
static void memo_clear_decref(Memo *m) {
    for (size_t i = 0; i < m->cap; i++)
        if (m->keys[i]) { Py_XDECREF(m->vals[i]); m->keys[i] = 0; m->vals[i] = NULL; }
    m->n = 0;
}

static inline uint64_t rd_u64(uintptr_t a) { uint64_t v; memcpy(&v, (void *)a, 8); return v; }
static inline int64_t rd_i64(uintptr_t a) { int64_t v; memcpy(&v, (void *)a, 8); return v; }
static inline int8_t rd_i8(uintptr_t a) { int8_t v; memcpy(&v, (void *)a, 1); return v; }
static inline double rd_f64(uintptr_t a) { double v; memcpy(&v, (void *)a, 8); return v; }

static inline int hdr_valid(uintptr_t addr) {
    if (addr & 7) return 0;
    if (rd_u64(addr + HDR_RC_OFF) == RC_SENTINEL) return 1;
    uint64_t aid = rd_u64(addr + HDR_ALLOC_ID_OFF);
    return ((aid >> 32) & 0xFFFF) == HDR_MAGIC;
}

/* stamp categories */
enum { C_CLASS = 0, C_LIST = 1, C_DICT = 2, C_SET = 3, C_STR = 4, C_UNKNOWN = 5 };
typedef struct { int cat; int kk; int vk; int vhint; } TagInfo;
static TagInfo *g_taginfos = NULL;
static int g_ntag = 0, g_captag = 0;

static int class_idx_of(const char *s) {
    PyObject *name = PyUnicode_FromString(s);
    if (!name) { PyErr_Clear(); return -1; }
    PyObject *idxo = PyDict_GetItem(g_name_to_idx, name); /* borrowed */
    Py_DECREF(name);
    return idxo ? (int)PyLong_AsLong(idxo) : -1;
}

/* tag char* -> TagInfo index (cached by tag pointer: type tags are shared
 * constants inside the artifact, so the cache converges to a handful) */
static int taginfo_for(uintptr_t tag) {
    PyObject *cached = memo_get(&g_stampcache, tag);
    if (cached) return (int)PyLong_AsLong(cached);
    TagInfo ti = {C_UNKNOWN, K_STR, K_RAWPTR, -1};
    const char *s = (const char *)tag;
    int cidx = class_idx_of(s);
    if (cidx >= 0) {
        ti.cat = C_CLASS;
        ti.vhint = cidx;
    } else if (!strncmp(s, "list_", 5)) {
        ti.cat = C_LIST;
        ti.kk = !strcmp(s + 5, "i64") ? K_I64 : (!strcmp(s + 5, "f64") ? K_F64 : K_STRUCT);
    } else if (!strncmp(s, "dict_", 5)) {
        ti.cat = C_DICT;
        const char *p = s + 5;
        if (!strncmp(p, "i64", 3)) { ti.kk = K_I64; p += 3; }
        else if (!strncmp(p, "ptr", 3)) { ti.kk = K_STR; p += 3; }
        if (*p == '_') p++;
        if (!strncmp(p, "ptr_", 4)) p += 4;
        if (!strcmp(p, "List_ptr")) { ti.vk = K_LIST; ti.vhint = -1; }
        else if (!strcmp(p, "Set_ptr")) ti.vk = K_SET;
        else {
            int v = class_idx_of(p);
            if (v >= 0) { ti.vk = K_STRUCT; ti.vhint = v; }
        }
    } else if (!strncmp(s, "set_", 4)) {
        ti.cat = C_SET;
        ti.kk = strcmp(s, "set_i64") ? K_STR : K_I64;
    } else if (!strcmp(s, "str") || !strcmp(s, "bytes")) {
        ti.cat = C_STR;
    }
    if (g_ntag == g_captag) {
        g_captag = g_captag ? g_captag * 2 : 64;
        g_taginfos = (TagInfo *)realloc(g_taginfos, g_captag * sizeof(TagInfo));
        if (!g_taginfos) { PyErr_NoMemory(); return -1; }
    }
    g_taginfos[g_ntag] = ti;
    PyObject *store = PyLong_FromLong(g_ntag);
    if (store) memo_put(&g_stampcache, tag, store); /* cache keeps the ref */
    return g_ntag++;
}

static PyObject *decode_str(uintptr_t addr) {
    if (!addr) return PyUnicode_FromString("");
    PyObject *cached = memo_get(&g_strcache, addr);
    if (cached) { Py_INCREF(cached); return cached; }
    PyObject *s;
    uint64_t dv;
    if (hdr_valid(addr) && ((dv = rd_u64(addr + HDR_DTOR_OFF)) & 1) && (dv >> 1) < (1ULL << 31)) {
        int64_t ln = (int64_t)(dv >> 1);
        s = (ln > 0) ? PyUnicode_DecodeUTF8((const char *)addr, ln, "replace")
                     : PyUnicode_FromString("");
    } else {
        s = PyUnicode_DecodeUTF8((const char *)addr, (Py_ssize_t)strlen((const char *)addr), "replace");
    }
    if (s) { Py_INCREF(s); memo_put(&g_strcache, addr, s); }
    return s;
}

static PyObject *decode_struct(uintptr_t addr, int hint_idx); /* fwd */

/* i8* slot: stamped string, else any rc-stamped boxed value (opaque generic
 * slot), else NUL-terminated constant */
static PyObject *decode_str_or_struct(uintptr_t addr) {
    if (!addr) return PyUnicode_FromString("");
    if (hdr_valid(addr)) {
        uint64_t dv = rd_u64(addr + HDR_DTOR_OFF);
        if (dv & 1) return decode_str(addr);
        uintptr_t tag = (uintptr_t)rd_u64(addr + HDR_TAG_OFF);
        if (tag) {
            int tidx = taginfo_for(tag);
            if (tidx < 0) return NULL;
            if (g_taginfos[tidx].cat != C_UNKNOWN) return decode_struct(addr, -1);
        }
    }
    return decode_str(addr);
}

static PyObject *decode_list_structs(uintptr_t lp, int hint_idx) {
    if (!lp || (lp & 7)) { if (lp) g_ct_bad_list++; return PyList_New(0); }
    NativeList *nl = (NativeList *)lp;
    if (!list_ok(nl)) { g_ct_bad_list++; return PyList_New(0); }
    int64_t n = nl->len;
    PyObject *out = PyList_New(n);
    if (!out) return NULL;
    uintptr_t *elems = (uintptr_t *)nl->data;
    for (int64_t i = 0; i < n; i++) {
        uintptr_t p = elems[i];
        PyObject *e;
        if (!p || (p & 7)) { if (p) g_ct_bad_ptr++; Py_INCREF(Py_None); e = Py_None; }
        else e = decode_struct(p, hint_idx);
        if (!e) { Py_DECREF(out); return NULL; }
        PyList_SET_ITEM(out, i, e);
    }
    return out;
}

static PyObject *decode_list_i64(uintptr_t lp) {
    if (!lp || (lp & 7)) return PyList_New(0);
    NativeList *nl = (NativeList *)lp;
    if (!list_ok(nl)) { g_ct_bad_list++; return PyList_New(0); }
    int64_t n = nl->len;
    PyObject *out = PyList_New(n);
    if (!out) return NULL;
    int64_t *elems = (int64_t *)nl->data;
    for (int64_t i = 0; i < n; i++) {
        PyObject *e = PyLong_FromLongLong(elems[i]);
        if (!e) { Py_DECREF(out); return NULL; }
        PyList_SET_ITEM(out, i, e);
    }
    return out;
}

static PyObject *decode_list_strs(uintptr_t lp) {
    if (!lp || (lp & 7)) return PyList_New(0);
    NativeList *nl = (NativeList *)lp;
    if (!list_ok(nl)) { g_ct_bad_list++; return PyList_New(0); }
    int64_t n = nl->len;
    PyObject *out = PyList_New(n);
    if (!out) return NULL;
    uintptr_t *elems = (uintptr_t *)nl->data;
    for (int64_t i = 0; i < n; i++) {
        PyObject *e = decode_str(elems[i]);
        if (!e) { Py_DECREF(out); return NULL; }
        PyList_SET_ITEM(out, i, e);
    }
    return out;
}

static PyObject *decode_set(uintptr_t sp, int elem_kind) {
    PyObject *out = PySet_New(NULL);
    if (!out || !sp || (sp & 7)) return out;
    NativeSet *ns = (NativeSet *)sp;
    if (ns->len <= 0 || ns->len > LIST_MAX || ns->cap < ns->len || !ns->order ||
        ((uintptr_t)ns->order & 7) || !ns->keys) {
        if (ns->len) g_ct_bad_dict++;
        return out;
    }
    int64_t *order = (int64_t *)ns->order;
    for (int64_t i = 0; i < ns->len; i++) {
        int64_t slot = order[i];
        if (slot < 0 || slot >= ns->cap) continue;
        PyObject *e = (elem_kind == K_STR) ? decode_str(((uintptr_t *)ns->keys)[slot])
                                           : PyLong_FromLongLong(((int64_t *)ns->keys)[slot]);
        if (!e) { Py_DECREF(out); return NULL; }
        if (PySet_Add(out, e) < 0) { Py_DECREF(e); Py_DECREF(out); return NULL; }
        Py_DECREF(e);
    }
    return out;
}

/* dict value kinds: K_STRUCT | K_LIST (of structs) | K_SET (of str) | K_STR */
static PyObject *decode_dict(uintptr_t dp, int kkind, int vkind, int vhint) {
    PyObject *out = PyDict_New();
    if (!out || !dp || (dp & 7)) return out;
    NativeDict *nd = (NativeDict *)dp;
    if (nd->len <= 0 || nd->len > LIST_MAX || nd->cap < nd->len || !nd->order ||
        ((uintptr_t)nd->order & 7) || !nd->keys || !nd->vals) {
        if (nd->len) g_ct_bad_dict++;
        return out;
    }
    int64_t *order = (int64_t *)nd->order;
    for (int64_t i = 0; i < nd->len; i++) {
        int64_t slot = order[i];
        if (slot < 0 || slot >= nd->cap) continue;
        PyObject *k = (kkind == K_STR) ? decode_str(((uintptr_t *)nd->keys)[slot])
                                       : PyLong_FromLongLong(((int64_t *)nd->keys)[slot]);
        if (!k) { Py_DECREF(out); return NULL; }
        uintptr_t vraw = ((uintptr_t *)nd->vals)[slot];
        PyObject *v;
        switch (vkind) {
            case K_STRUCT: v = vraw ? decode_struct(vraw, vhint) : (Py_INCREF(Py_None), Py_None); break;
            case K_LIST: v = decode_list_structs(vraw, vhint); break;
            case K_SET: v = decode_set(vraw, K_STR); break;
            case K_STR: v = decode_str(vraw); break;
            default: v = PyLong_FromLongLong((int64_t)vraw); break;
        }
        if (!v) { Py_DECREF(k); Py_DECREF(out); return NULL; }
        if (PyDict_SetItem(out, k, v) < 0) { Py_DECREF(k); Py_DECREF(v); Py_DECREF(out); return NULL; }
        Py_DECREF(k);
        Py_DECREF(v);
    }
    return out;
}

/* declared-kind decode of a container pointer (unstamped memory) */
static PyObject *decode_declared(uintptr_t p, int kind, int a1, int a2, int hint) {
    switch (kind) {
        case K_LIST:
            if (a1 == K_I64) return decode_list_i64(p);
            if (a1 == K_STR) return decode_list_strs(p);
            return decode_list_structs(p, hint);
        case K_DICT: return decode_dict(p, a1, a2, hint);
        case K_SET: return decode_set(p, a1);
        case K_STRUCT: return p ? decode_struct(p, hint) : (Py_INCREF(Py_None), Py_None);
    }
    Py_RETURN_NONE;
}

/* pointer-valued field: categorize by rc stamp first, declared kind only as
 * the fallback for unstamped memory (see the union-erasure note up top) */
static PyObject *decode_ptr_field(uintptr_t p, int kind, int a1, int a2, int hint) {
    if (!p || (p & 7)) {
        if (p) g_ct_bad_ptr++;
        return decode_declared(0, kind, a1, a2, hint);
    }
    if (hdr_valid(p)) {
        uintptr_t tag = (uintptr_t)rd_u64(p + HDR_TAG_OFF);
        if (tag) {
            int tidx = taginfo_for(tag);
            if (tidx < 0) return NULL;
            TagInfo *ti = &g_taginfos[tidx];
            switch (ti->cat) {
                case C_CLASS: return decode_struct(p, -1);
                case C_LIST: {
                    int ek = (kind == K_LIST) ? a1 : ti->kk;
                    if (ek == K_I64) return decode_list_i64(p);
                    if (ek == K_STR) return decode_list_strs(p);
                    return decode_list_structs(p, kind == K_LIST ? hint : -1);
                }
                case C_DICT:
                    if (kind == K_DICT) return decode_dict(p, a1, a2, hint);
                    return decode_dict(p, ti->kk, ti->vk, ti->vhint);
                case C_SET: return decode_set(p, kind == K_SET ? a1 : ti->kk);
                case C_STR: return decode_str(p);
                default: break; /* C_UNKNOWN: fall through to declared */
            }
        }
    }
    return decode_declared(p, kind, a1, a2, hint);
}

static PyObject *decode_field(uintptr_t base, FieldRec *f) {
    uintptr_t fa = base + f->off;
    switch (f->kind) {
        case K_NONE: Py_RETURN_NONE;
        case K_I64: return PyLong_FromLongLong(rd_i64(fa));
        case K_I1: { PyObject *b = rd_i8(fa) ? Py_True : Py_False; Py_INCREF(b); return b; }
        case K_F64: return PyFloat_FromDouble(rd_f64(fa));
        case K_STR: return decode_str_or_struct((uintptr_t)rd_u64(fa));
        case K_STRUCT: {
            uintptr_t p = (uintptr_t)rd_u64(fa);
            if (!p) Py_RETURN_NONE;
            return decode_ptr_field(p, K_STRUCT, 0, 0, f->hint);
        }
        case K_OPT: {
            if (!rd_i8(fa)) Py_RETURN_NONE;
            uintptr_t pa = fa + f->aux2;
            switch (f->aux1) {
                case K_I64: return PyLong_FromLongLong(rd_i64(pa));
                case K_STR: return decode_str_or_struct((uintptr_t)rd_u64(pa));
                case K_LIST: return decode_ptr_field((uintptr_t)rd_u64(pa), K_LIST, K_STRUCT, 0, f->hint);
                case K_STRUCT: {
                    uintptr_t p = (uintptr_t)rd_u64(pa);
                    if (!p) Py_RETURN_NONE;
                    return decode_ptr_field(p, K_STRUCT, 0, 0, f->hint);
                }
                default: Py_RETURN_NONE;
            }
        }
        case K_LIST: return decode_ptr_field((uintptr_t)rd_u64(fa), K_LIST, f->aux1, 0, f->hint);
        case K_DICT: return decode_ptr_field((uintptr_t)rd_u64(fa), K_DICT, f->aux1, f->aux2, f->hint);
        case K_SET: return decode_ptr_field((uintptr_t)rd_u64(fa), K_SET, f->aux1, 0, f->hint);
        case K_ENUM: {
            /* the native slot holds the declaration ordinal for
             * string-valued enums and the raw int value otherwise; extra is
             * the matching {key: member} dict baked at seal time */
            if (f->extra) {
                PyObject *keyo = PyLong_FromLongLong(rd_i64(fa));
                if (keyo) {
                    PyObject *m = PyDict_GetItem(f->extra, keyo); /* borrowed */
                    Py_DECREF(keyo);
                    if (m) { Py_INCREF(m); return m; }
                }
            }
            return PyLong_FromLongLong(rd_i64(fa));
        }
        case K_RAWPTR: Py_RETURN_NONE;
    }
    Py_RETURN_NONE;
}

static PyObject *decode_struct(uintptr_t addr, int hint_idx) {
    if (addr & 7) { g_ct_bad_ptr++; Py_RETURN_NONE; }
    PyObject *hit = memo_get(&g_memo, addr);
    if (hit) { Py_INCREF(hit); return hit; }
    int ridx = -1;
    uintptr_t tag = hdr_valid(addr) ? (uintptr_t)rd_u64(addr + HDR_TAG_OFF) : 0;
    if (tag) {
        int tidx = taginfo_for(tag);
        if (tidx < 0) return NULL;
        TagInfo *ti = &g_taginfos[tidx];
        switch (ti->cat) {
            case C_CLASS: ridx = ti->vhint; break;
            case C_LIST:
                if (ti->kk == K_I64) return decode_list_i64(addr);
                return decode_list_structs(addr, -1);
            case C_DICT: return decode_dict(addr, ti->kk, ti->vk, ti->vhint);
            case C_SET: return decode_set(addr, ti->kk);
            case C_STR: return decode_str(addr);
            default: g_ct_unknown_stamp++; Py_RETURN_NONE;
        }
    }
    if (ridx < 0) {
        ridx = hint_idx;
        if (ridx < 0) { g_ct_unknown_stamp++; Py_RETURN_NONE; }
    }
    Recipe *r = &g_recipes[ridx];
    if (!r->cls || r->cls == Py_None) { g_ct_unmapped_cls++; Py_RETURN_NONE; }
    PyTypeObject *tp = (PyTypeObject *)r->cls;
    PyObject *obj = tp->tp_new(tp, g_empty_tuple, NULL);
    if (!obj) return NULL;
    g_ct_nodes++;
    /* memo BEFORE filling: cycle safety (Source.orig_src is Source itself) */
    Py_INCREF(obj);
    if (memo_put(&g_memo, addr, obj) < 0) { Py_DECREF(obj); Py_DECREF(obj); return PyErr_NoMemory(); }
    PyObject *d = PyObject_GenericGetDict(obj, NULL); /* new ref, managed-dict safe */
    if (!d) { Py_DECREF(obj); return NULL; }
    for (int i = 0; i < r->nfields; i++) {
        FieldRec *f = &r->fields[i];
        PyObject *v = decode_field(addr, f);
        if (!v) { Py_DECREF(d); Py_DECREF(obj); return NULL; }
        if (PyDict_SetItem(d, f->key, v) < 0) { Py_DECREF(v); Py_DECREF(d); Py_DECREF(obj); return NULL; }
        Py_DECREF(v);
    }
    Py_DECREF(d);
    return obj;
}

static void free_recipes(void) {
    for (int i = 0; i < g_nrecipes; i++) {
        for (int j = 0; j < g_recipes[i].nfields; j++) {
            Py_XDECREF(g_recipes[i].fields[j].key);
            Py_XDECREF(g_recipes[i].fields[j].extra);
        }
        free(g_recipes[i].fields);
        Py_XDECREF(g_recipes[i].cls);
    }
    free(g_recipes);
    g_recipes = NULL;
    g_nrecipes = 0;
}

static PyObject *jm_init(PyObject *self, PyObject *args) {
    PyObject *recipes;
    if (!PyArg_ParseTuple(args, "O!", &PyList_Type, &recipes)) return NULL;
    free_recipes();
    g_nrecipes = (int)PyList_GET_SIZE(recipes);
    g_recipes = (Recipe *)calloc(g_nrecipes, sizeof(Recipe));
    if (!g_recipes) return PyErr_NoMemory();
    Py_XDECREF(g_name_to_idx);
    g_name_to_idx = PyDict_New();
    if (!g_empty_tuple) g_empty_tuple = PyTuple_New(0);
    for (int i = 0; i < g_nrecipes; i++) {
        PyObject *entry = PyList_GET_ITEM(recipes, i); /* (name, cls, fields) */
        PyObject *name = PyTuple_GET_ITEM(entry, 0);
        PyObject *cls = PyTuple_GET_ITEM(entry, 1);
        PyObject *fields = PyTuple_GET_ITEM(entry, 2);
        PyObject *idxo = PyLong_FromLong(i);
        PyDict_SetItem(g_name_to_idx, name, idxo);
        Py_DECREF(idxo);
        Py_INCREF(cls);
        g_recipes[i].cls = cls;
        int nf = (int)PyList_GET_SIZE(fields);
        g_recipes[i].nfields = nf;
        g_recipes[i].fields = (FieldRec *)calloc(nf ? nf : 1, sizeof(FieldRec));
        if (!g_recipes[i].fields) return PyErr_NoMemory();
        for (int j = 0; j < nf; j++) {
            PyObject *ft = PyList_GET_ITEM(fields, j); /* (key, kind, off, aux1, aux2, hint, extra) */
            FieldRec *f = &g_recipes[i].fields[j];
            f->key = PyTuple_GET_ITEM(ft, 0);
            Py_INCREF(f->key);
            PyUnicode_InternInPlace(&f->key);
            f->kind = (int)PyLong_AsLong(PyTuple_GET_ITEM(ft, 1));
            f->off = (int)PyLong_AsLong(PyTuple_GET_ITEM(ft, 2));
            f->aux1 = (int)PyLong_AsLong(PyTuple_GET_ITEM(ft, 3));
            f->aux2 = (int)PyLong_AsLong(PyTuple_GET_ITEM(ft, 4));
            f->hint = (int)PyLong_AsLong(PyTuple_GET_ITEM(ft, 5));
            f->extra = PyTuple_GET_ITEM(ft, 6);
            if (f->extra == Py_None) f->extra = NULL;
            else Py_INCREF(f->extra);
        }
    }
    /* reset the tag cache: recipe indexes changed */
    memo_clear_decref(&g_stampcache);
    g_ntag = 0;
    if (!g_memo.cap && memo_init(&g_memo, 1 << 16) < 0) return PyErr_NoMemory();
    if (!g_strcache.cap && memo_init(&g_strcache, 1 << 14) < 0) return PyErr_NoMemory();
    if (!g_stampcache.cap && memo_init(&g_stampcache, 1 << 10) < 0) return PyErr_NoMemory();
    Py_RETURN_NONE;
}

static PyObject *jm_materialize(PyObject *self, PyObject *args) {
    unsigned long long addr;
    if (!PyArg_ParseTuple(args, "K", &addr)) return NULL;
    if (!addr) Py_RETURN_NONE;
    if (!g_nrecipes) {
        PyErr_SetString(PyExc_RuntimeError, "jacmat.materialize before jacmat.install");
        return NULL;
    }
    PyObject *root = decode_struct((uintptr_t)addr, -1);
    /* hand ownership to the tree: parents hold their children; the caller
     * holds the root */
    memo_clear_decref(&g_memo);
    memo_clear_decref(&g_strcache);
    return root;
}

static PyObject *jm_stats(PyObject *self, PyObject *noargs) {
    return Py_BuildValue(
        "{s:l,s:l,s:l,s:l,s:l,s:l}",
        "nodes", g_ct_nodes, "unknown_stamp", g_ct_unknown_stamp,
        "unmapped_cls", g_ct_unmapped_cls, "bad_list", g_ct_bad_list,
        "bad_ptr", g_ct_bad_ptr, "bad_dict", g_ct_bad_dict);
}

static PyMethodDef methods[] = {
    {"install", jm_init, METH_VARARGS, "install per-struct field recipes"},
    {"materialize", jm_materialize, METH_VARARGS, "native tree addr -> Python object tree"},
    {"stats", jm_stats, METH_NOARGS, "anomaly counters"},
    {NULL, NULL, 0, NULL},
};

static struct PyModuleDef mod = {PyModuleDef_HEAD_INIT, "jacmat", NULL, -1, methods};
PyMODINIT_FUNC PyInit_jacmat(void) { return PyModule_Create(&mod); }
