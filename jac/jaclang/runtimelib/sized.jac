import math;
import struct;
import from jaclang.jac0core.scalars {
    numeric_shapes,
    ScalarShape,
    range_of,
    shape_of,
    unify,
    wrap_value
}

glob OVERFLOW_MESSAGE: str = "integer overflow",
     SHIFT_MESSAGE: str = "shift count out of range",
     SIZED_TYPES: dict[str, type] = {},
     JS_SAFE_INT: int = (1 << 53) - 1;

# The jac0core table is a pure table by design (a sealed artifact runs global
# inits in dependency-walk order, so it can hold no globals of its own) and
# rebuilds its thirteen rows on every call. Every arithmetic dunder below asks
# it for a shape, a range and a unification, so the uncached path allocated
# scores of rows per operation. These caches live on the runtime side, where a
# global is safe, and _build_family primes them so the hot paths never miss.
glob _SHAPES: dict[str, ScalarShape] = {},
     _RANGES: dict[str, tuple[int, int]] = {},
     _UNIFY: dict[tuple[str, str], str | None] = {};

def scalar_name_of(value: any) -> str | None {
    sized = type(value)?.__jac_sized__;
    if sized is not None {
        return sized;
    }
    if isinstance(value, bool) {
        return "bool";
    }
    if isinstance(value, int) {
        return "int";
    }
    if isinstance(value, float) {
        return "float";
    }
    return None;
}

def shape(name: str) -> ScalarShape {
    hit = _SHAPES.get(name);
    if hit is not None {
        return hit;
    }
    found = shape_of(name);
    assert found is not None , name;
    _SHAPES[name] = found;
    return found;
}

def bounds(name: str) -> tuple[int, int] {
    hit = _RANGES.get(name);
    if hit is not None {
        return hit;
    }
    found = range_of(name);
    _RANGES[name] = found;
    return found;
}

def unified_name(an: str, bn: str) -> str | None {
    key = (an, bn);
    if key in _UNIFY {
        return _UNIFY[key];
    }
    found = unify(an, bn);
    _UNIFY[key] = found;
    return found;
}

def round_float(name: str, value: float) -> float {
    if name != "f32" {
        return float(value);
    }
    try {
        return struct.unpack("f", struct.pack("f", value))[0];
    } except OverflowError {
        return math.copysign(math.inf, value);
    }
}

def make_int(name: str, value: int) -> any {
    return int.__new__(SIZED_TYPES[name], value);
}

def make_float(name: str, value: float) -> any {
    return float.__new__(SIZED_TYPES[name], round_float(name, value));
}

def checked_int(name: str, value: int) -> any {
    (lo, hi) = bounds(name);
    if value < lo or value > hi {
        raise OverflowError(OVERFLOW_MESSAGE);
    }
    return make_int(name, value);
}

def unify_operands(a: any, b: any, op: str) -> str {
    an = scalar_name_of(a);
    bn = scalar_name_of(b);
    if an is None or bn is None {
        raise TypeError(
            f"unsupported operand type(s) for {op}: "
            f"'{type(a).__name__}' and '{type(b).__name__}'"
        );
    }
    target = an if an == bn else unified_name(an, bn);
    if target is None {
        raise TypeError(
            f"operands of '{op}' have no common fixed-width type ({an} and {bn}); "
            "cast one operand explicitly"
        );
    }
    return target;
}

def arith(a: any, b: any, op: str, fn: any) -> any {
    target = unify_operands(a, b, op);
    sh = shape(target);
    if not sh.sized {
        if sh.is_float {
            return fn(float(a), float(b));
        }
        return fn(int(a), int(b));
    }
    if sh.is_float {
        return make_float(target, fn(float(a), float(b)));
    }
    return checked_int(target, fn(int(a), int(b)));
}

def true_div(a: any, b: any) -> any {
    target = unify_operands(a, b, "/");
    sh = shape(target);
    if sh.sized and sh.is_float {
        return make_float(target, float(a) / float(b));
    }
    return float(a) / float(b);
}

def power(a: any, b: any) -> any {
    target = unify_operands(a, b, "**");
    sh = shape(target);
    if sh.is_float {
        result = float(a) ** float(b);
        return make_float(target, result) if sh.sized else result;
    }
    base = int(a);
    exp = int(b);
    if exp < 0 {
        return float(base) ** float(exp);
    }
    if not sh.sized {
        return base ** exp;
    }
    if abs(base) >= 2 and exp >= sh.width {
        raise OverflowError(OVERFLOW_MESSAGE);
    }
    return checked_int(target, pow(base, exp));
}

def shift_count(name: str, count: any) -> int {
    n = int(count);
    if n < 0 or n >= shape(name).width {
        raise OverflowError(SHIFT_MESSAGE);
    }
    return n;
}

def shift_left(a: any, b: any) -> any {
    name = scalar_name_of(a);
    if name is None or not shape(name).sized {
        return int(a) << int(b);
    }
    return checked_int(name, int(a) << shift_count(name, b));
}

def shift_right(a: any, b: any) -> any {
    name = scalar_name_of(a);
    if name is None or not shape(name).sized {
        return int(a) >> int(b);
    }
    return make_int(name, int(a) >> shift_count(name, b));
}

def negate(a: any) -> any {
    name = scalar_name_of(a) or "int";
    return checked_int(name, -int(a));
}

def absolute(a: any) -> any {
    name = scalar_name_of(a) or "int";
    return checked_int(name, abs(int(a)));
}

def invert(a: any) -> any {
    name = scalar_name_of(a) or "int";
    sh = shape(name);
    if sh.signed {
        return make_int(name, ~int(a));
    }
    return make_int(name, ((1 << sh.width) - 1) ^ int(a));
}

def cast_int(name: str, value: any) -> any {
    if isinstance(value, (bool, int)) {
        return checked_int(name, int(value));
    }
    if isinstance(value, float) {
        return checked_int(name, int(value));
    }
    raise TypeError(
        f"{name}() argument must be a number, not '{type(value).__name__}'"
    );
}

def cast_float(name: str, value: any) -> any {
    if isinstance(value, (bool, int, float)) {
        return make_float(name, float(value));
    }
    raise TypeError(
        f"{name}() argument must be a number, not '{type(value).__name__}'"
    );
}

def _binary_dunders(op: str, fn: any) -> dict[str, any] {
    return {
        "__" + op + "__": lambda (self: any, other: any) { fn(self, other); },
        "__r" + op + "__": lambda (self: any, other: any) { fn(other, self); }
    };
}

def _int_namespace(name: str) -> dict[str, any] {
    import operator;
    ns: dict[str, any] = {
        "__slots__": (),
        "__jac_sized__": name,
        "__new__": lambda (cls: type, x: any = 0) { cast_int(name, x); },
        "wrap": classmethod(
            lambda (cls: type, x: any) { make_int(name, wrap_value(name, int(x))); }
        ),
        "__neg__": negate,
        "__pos__": lambda (self: any) { self; },
        "__abs__": absolute,
        "__invert__": invert
    };
    ns.update(
        _binary_dunders(
            "add", lambda (a: any, b: any) { arith(a, b, "+", operator.add); }
        )
    );
    ns.update(
        _binary_dunders(
            "sub", lambda (a: any, b: any) { arith(a, b, "-", operator.sub); }
        )
    );
    ns.update(
        _binary_dunders(
            "mul", lambda (a: any, b: any) { arith(a, b, "*", operator.mul); }
        )
    );
    ns.update(
        _binary_dunders(
            "floordiv",
            lambda (a: any, b: any) { arith(a, b, "//", operator.floordiv); }
        )
    );
    ns.update(
        _binary_dunders(
            "mod", lambda (a: any, b: any) { arith(a, b, "%", operator.mod); }
        )
    );
    ns.update(
        _binary_dunders(
            "and", lambda (a: any, b: any) { arith(a, b, "&", operator.and_); }
        )
    );
    ns.update(
        _binary_dunders(
            "or", lambda (a: any, b: any) { arith(a, b, "|", operator.or_); }
        )
    );
    ns.update(
        _binary_dunders(
            "xor", lambda (a: any, b: any) { arith(a, b, "^", operator.xor); }
        )
    );
    ns.update(_binary_dunders("truediv", true_div));
    ns.update(_binary_dunders("pow", power));
    ns.update(_binary_dunders("lshift", shift_left));
    ns.update(_binary_dunders("rshift", shift_right));
    return ns;
}

def _float_namespace(name: str) -> dict[str, any] {
    import operator;
    ns: dict[str, any] = {
        "__slots__": (),
        "__jac_sized__": name,
        "__new__": lambda (cls: type, x: any = 0.0) { cast_float(name, x); },
        "__neg__": lambda (self: any) { make_float(name, -float(self)); },
        "__pos__": lambda (self: any) { self; },
        "__abs__": lambda (self: any) { make_float(name, abs(float(self))); }
    };
    ns.update(
        _binary_dunders(
            "add", lambda (a: any, b: any) { arith(a, b, "+", operator.add); }
        )
    );
    ns.update(
        _binary_dunders(
            "sub", lambda (a: any, b: any) { arith(a, b, "-", operator.sub); }
        )
    );
    ns.update(
        _binary_dunders(
            "mul", lambda (a: any, b: any) { arith(a, b, "*", operator.mul); }
        )
    );
    ns.update(
        _binary_dunders(
            "floordiv",
            lambda (a: any, b: any) { arith(a, b, "//", operator.floordiv); }
        )
    );
    ns.update(
        _binary_dunders(
            "mod", lambda (a: any, b: any) { arith(a, b, "%", operator.mod); }
        )
    );
    ns.update(_binary_dunders("truediv", true_div));
    ns.update(_binary_dunders("pow", power));
    return ns;
}

"""The wire form of one value.

A 64-bit sized integer leaves as a JSON string when it falls outside the range a
JSON number survives in an ECMAScript reader, and as a JSON number otherwise.
Narrower widths and the float kinds always fit, so they pass through unchanged.
Both lanes encode with this rule and both decoders accept either form.
"""
def json_wire_form(value: any) -> any {
    name = scalar_name_of(value);
    if name is None {
        return value;
    }
    sh = shape(name);
    if not sh.sized or sh.is_float or sh.width < 64 {
        return value;
    }
    n = int(value);
    if n > JS_SAFE_INT or n < -JS_SAFE_INT {
        return str(n);
    }
    return n;
}

"""Read a wire value back into `name`, accepting either encoding above."""
def json_wire_read(name: str, value: any) -> any {
    if isinstance(value, str) {
        return SIZED_TYPES[name](float(value) if shape(name).is_float else int(value));
    }
    return SIZED_TYPES[name](value);
}

def sized_value(name: str, value: any) -> any {
    return SIZED_TYPES[name](value);
}

def _prime_caches {
    rows = numeric_shapes();
    for row in rows {
        _SHAPES[row.name] = row;
        if row.sized and not row.is_float {
            _RANGES[row.name] = range_of(row.name);
        }
    }
    for a in rows {
        for b in rows {
            _UNIFY[(a.name, b.name)] = unify(a.name, b.name);
        }
    }
}

def _build_family {
    _prime_caches();
    for row in numeric_shapes() {
        if not row.sized {
            continue;
        }
        base = float if row.is_float else int;
        ns = _float_namespace(row.name) if row.is_float else _int_namespace(row.name);
        ns["__module__"] = "builtins";
        ns["__qualname__"] = row.name;
        ns["__reduce__"] = lambda (self: any) { (
            sized_value,
            (
                scalar_name_of(self),
                float(self) if isinstance(self, float) else int(self)
            )
        ); };
        cls: any = type(row.name, (base, ), ns);
        SIZED_TYPES[row.name] = cls;
        if not row.is_float {
            (lo, hi) = range_of(row.name);
            cls.MIN = make_int(row.name, lo);
            cls.MAX = make_int(row.name, hi);
        }
    }
}

def _wrapping(a: any, b: any, op: str, fn: any) -> any {
    target = unify_operands(a, b, op);
    sh = shape(target);
    if not sh.sized or sh.is_float {
        raise TypeError(f"{op} needs two fixed-width integer operands, got {target}");
    }
    return make_int(target, wrap_value(target, fn(int(a), int(b))));
}

def wrapping_add(a: any, b: any) -> any {
    import operator;
    return _wrapping(a, b, "wrapping_add", operator.add);
}

def wrapping_sub(a: any, b: any) -> any {
    import operator;
    return _wrapping(a, b, "wrapping_sub", operator.sub);
}

def wrapping_mul(a: any, b: any) -> any {
    import operator;
    return _wrapping(a, b, "wrapping_mul", operator.mul);
}

def wrapping_shl(a: any, b: any) -> any {
    target = unify_operands(a, b, "wrapping_shl");
    sh = shape(target);
    if not sh.sized or sh.is_float {
        raise TypeError(
            f"wrapping_shl needs two fixed-width integer operands, got {target}"
        );
    }
    count = int(b) & (sh.width - 1);
    return make_int(target, wrap_value(target, int(a) << count));
}

def wrapping_neg(a: any) -> any {
    name = scalar_name_of(a);
    if name is None or not shape(name).sized {
        raise TypeError(f"wrapping_neg needs a fixed-width integer operand");
    }
    return make_int(name, wrap_value(name, -int(a)));
}

with entry {
    _build_family();
}
