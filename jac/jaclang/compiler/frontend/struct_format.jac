obj StructField {
    has kind: str,
        size: int,
        signed: bool;
}

obj StructLayout {
    has fields: list[StructField],
        total: int,
        little: bool;

    def value_fields -> list[StructField] {
        return [
            f
            for f in self.fields
            if f.kind != "pad"
        ];
    }
}

glob STRUCT_INT_SIZES: dict[str, int] = {
         "b": 1,
         "B": 1,
         "h": 2,
         "H": 2,
         "i": 4,
         "I": 4,
         "l": 4,
         "L": 4,
         "q": 8,
         "Q": 8,
         "n": 8,
         "N": 8
     },
     STRUCT_SIGNED_CODES: frozenset[str] = frozenset({"b", "h", "i", "l", "q", "n"}),
     STRUCT_FLOAT_SIZES: dict[str, int] = {"f": 4, "d": 8};

def parse_struct_format(fmt: str) -> (StructLayout | None) {
    little = True;
    body = fmt;
    if len(fmt) > 0 and fmt[0] in "<>=!@" {
        little = fmt[0] in "<=@";
        body = fmt[1:];
    }
    fields: list[StructField] = [];
    total = 0;
    i = 0;
    count_str = "";
    while i < len(body) {
        ch = body[i];
        if ch.isdigit() {
            count_str = count_str + ch;
            i = i + 1;
            continue;
        }
        rep = int(count_str) if count_str else 1;
        count_str = "";
        if ch == "x" {
            for _r in range(rep) {
                fields.append(StructField(kind="pad", size=1, signed=False));
                total = total + 1;
            }
        } elif ch in STRUCT_INT_SIZES {
            _sz = STRUCT_INT_SIZES[ch];
            for _r in range(rep) {
                fields.append(
                    StructField(kind="int", size=_sz, signed=ch in STRUCT_SIGNED_CODES)
                );
                total = total + _sz;
            }
        } elif ch in STRUCT_FLOAT_SIZES {
            _sz = STRUCT_FLOAT_SIZES[ch];
            for _r in range(rep) {
                fields.append(StructField(kind="float", size=_sz, signed=False));
                total = total + _sz;
            }
        } elif ch == " " { } else {
            return None;
        }
        i = i + 1;
    }
    return StructLayout(fields=fields, total=total, little=little);
}
