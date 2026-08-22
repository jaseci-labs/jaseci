obj ScalarShape {
    has name: str,
        width: int,
        signed: bool = False,
        is_float: bool = False,
        sized: bool = False;

    def size_bytes -> int {
        return max(1, self.width // 8);
    }

    def align -> int {
        return self.size_bytes();
    }

    def is_int_kind -> bool {
        return not self.is_float;
    }
}

glob NUMERIC_SHAPES: list[ScalarShape] = [
         ScalarShape(name="int", width=64, signed=True),
         ScalarShape(name="float", width=64, is_float=True),
         ScalarShape(name="bool", width=1),
         ScalarShape(name="i8", width=8, signed=True, sized=True),
         ScalarShape(name="u8", width=8, sized=True),
         ScalarShape(name="i16", width=16, signed=True, sized=True),
         ScalarShape(name="u16", width=16, sized=True),
         ScalarShape(name="i32", width=32, signed=True, sized=True),
         ScalarShape(name="u32", width=32, sized=True),
         ScalarShape(name="i64", width=64, signed=True, sized=True),
         ScalarShape(name="u64", width=64, sized=True),
         ScalarShape(name="f32", width=32, is_float=True, sized=True),
         ScalarShape(name="f64", width=64, is_float=True, sized=True)
     ],
     NUMERIC_SHAPE_BY_NAME: dict[str, ScalarShape] = {
         shape.name: shape for shape in NUMERIC_SHAPES
     };

def shape_of(name: str) -> ScalarShape | None {
    return NUMERIC_SHAPE_BY_NAME.get(name, None);
}

def is_sized(name: str) -> bool {
    shape = NUMERIC_SHAPE_BY_NAME.get(name, None);
    return shape is not None and shape.sized;
}

def sized_int_names -> list[str] {
    return [
        s.name
        for s in NUMERIC_SHAPES
        if s.sized and not s.is_float
    ];
}

def sized_float_names -> list[str] {
    return [
        s.name
        for s in NUMERIC_SHAPES
        if s.sized and s.is_float
    ];
}

def sized_scalar_names -> list[str] {
    return [
        s.name
        for s in NUMERIC_SHAPES
        if s.sized
    ];
}

def range_of(name: str) -> tuple[int, int] {
    shape = NUMERIC_SHAPE_BY_NAME[name];
    if not shape.sized or shape.is_float {
        raise ValueError(f"{name} is not a sized integer type");
    }
    if shape.signed {
        half = 1 << (shape.width - 1);
        return (-half, half - 1);
    }
    return (0, (1 << shape.width) - 1);
}

def literal_fits(name: str, value: int | float) -> bool {
    shape = NUMERIC_SHAPE_BY_NAME.get(name, None);
    if shape is None or not shape.sized {
        return False;
    }
    if shape.is_float {
        return isinstance(value, (int, float));
    }
    if isinstance(value, float) {
        return False;
    }
    (lo, hi) = range_of(name);
    return lo <= int(value) <= hi;
}

def widens_to(src: str, dst: str) -> bool {
    if src == dst {
        return True;
    }
    s = NUMERIC_SHAPE_BY_NAME.get(src, None);
    d = NUMERIC_SHAPE_BY_NAME.get(dst, None);
    if s is None or d is None {
        return False;
    }
    if src == "bool" {
        return True;
    }
    if dst == "bool" {
        return False;
    }
    if dst == "int" {
        return not s.is_float;
    }
    if dst == "float" {
        return True;
    }
    if src == "int" {
        return False;
    }
    if src == "float" {
        return dst == "f64";
    }
    if s.is_float {
        return d.is_float and d.width >= s.width;
    }
    if d.is_float {
        return s.width <= d.width // 2;
    }
    if s.signed == d.signed {
        return d.width >= s.width;
    }
    return d.signed and d.width > s.width;
}

def unify(a: str, b: str) -> str | None {
    if widens_to(a, b) {
        return b;
    }
    if widens_to(b, a) {
        return a;
    }
    return None;
}

def wrap_value(name: str, value: int) -> int {
    shape = NUMERIC_SHAPE_BY_NAME[name];
    mask = (1 << shape.width) - 1;
    out = int(value) & mask;
    if shape.signed and out >= (1 << (shape.width - 1)) {
        out -= 1 << shape.width;
    }
    return out;
}
