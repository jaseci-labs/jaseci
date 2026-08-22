# c2jac: 17 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L104 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder
#   L105 [W4202] switch fall-through not modelled — case fall-through not modelled and/or an impure selector is re-evaluated per branch
#   L145 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L189 [W4290] C construct `BinaryOp` has no faithful Jac lowering — emitted as a placeholder
#   L194 [W4290] C construct `BinaryOp` has no faithful Jac lowering — emitted as a placeholder
#   L195 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L196 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L197 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L215 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L224 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L239 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L271 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L284 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L297 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L343 [W4201] cast to `long` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L361 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder
#   L401 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied

def c_idiv(a: int, b: int) -> int {
    q = a // b;
    return q + (1 if (a % b != 0) and ((a < 0) != (b < 0)) else 0);
}

def c_imod(a: int, b: int) -> int {
    return a - c_idiv(a, b) * b;
}

glob Py_ssize_t = int;


@__jac_value__
obj struct_formatdef {
    has format: int = 0;
    has size: int = 0;
    has alignment: int = 0;
}


glob struct_native_table: list[struct_formatdef] = [
         struct_formatdef(format=120, size=1, alignment=0),
         struct_formatdef(format=98, size=1, alignment=0),
         struct_formatdef(format=66, size=1, alignment=0),
         struct_formatdef(format=99, size=1, alignment=0),
         struct_formatdef(format=115, size=1, alignment=0),
         struct_formatdef(format=112, size=1, alignment=0),
         struct_formatdef(format=104, size=2, alignment=2),
         struct_formatdef(format=72, size=2, alignment=2),
         struct_formatdef(format=105, size=4, alignment=4),
         struct_formatdef(format=73, size=4, alignment=4),
         struct_formatdef(format=108, size=8, alignment=8),
         struct_formatdef(format=76, size=8, alignment=8),
         struct_formatdef(format=110, size=8, alignment=8),
         struct_formatdef(format=78, size=8, alignment=8),
         struct_formatdef(format=113, size=8, alignment=8),
         struct_formatdef(format=81, size=8, alignment=8),
         struct_formatdef(format=63, size=1, alignment=1),
         struct_formatdef(format=101, size=2, alignment=2),
         struct_formatdef(format=102, size=4, alignment=4),
         struct_formatdef(format=100, size=8, alignment=8),
         struct_formatdef(format=80, size=8, alignment=8),
         struct_formatdef(format=0, size=0, alignment=0)
     ];

glob struct_lilendian_table: list[struct_formatdef] = [
         struct_formatdef(format=120, size=1, alignment=0),
         struct_formatdef(format=98, size=1, alignment=0),
         struct_formatdef(format=66, size=1, alignment=0),
         struct_formatdef(format=99, size=1, alignment=0),
         struct_formatdef(format=115, size=1, alignment=0),
         struct_formatdef(format=112, size=1, alignment=0),
         struct_formatdef(format=104, size=2, alignment=0),
         struct_formatdef(format=72, size=2, alignment=0),
         struct_formatdef(format=105, size=4, alignment=0),
         struct_formatdef(format=73, size=4, alignment=0),
         struct_formatdef(format=108, size=4, alignment=0),
         struct_formatdef(format=76, size=4, alignment=0),
         struct_formatdef(format=113, size=8, alignment=0),
         struct_formatdef(format=81, size=8, alignment=0),
         struct_formatdef(format=63, size=1, alignment=0),
         struct_formatdef(format=101, size=2, alignment=0),
         struct_formatdef(format=102, size=4, alignment=0),
         struct_formatdef(format=100, size=8, alignment=0),
         struct_formatdef(format=0, size=0, alignment=0)
     ];

glob struct_bigendian_table: list[struct_formatdef] = [
         struct_formatdef(format=120, size=1, alignment=0),
         struct_formatdef(format=98, size=1, alignment=0),
         struct_formatdef(format=66, size=1, alignment=0),
         struct_formatdef(format=99, size=1, alignment=0),
         struct_formatdef(format=115, size=1, alignment=0),
         struct_formatdef(format=112, size=1, alignment=0),
         struct_formatdef(format=104, size=2, alignment=0),
         struct_formatdef(format=72, size=2, alignment=0),
         struct_formatdef(format=105, size=4, alignment=0),
         struct_formatdef(format=73, size=4, alignment=0),
         struct_formatdef(format=108, size=4, alignment=0),
         struct_formatdef(format=76, size=4, alignment=0),
         struct_formatdef(format=113, size=8, alignment=0),
         struct_formatdef(format=81, size=8, alignment=0),
         struct_formatdef(format=63, size=1, alignment=0),
         struct_formatdef(format=101, size=2, alignment=0),
         struct_formatdef(format=102, size=4, alignment=0),
         struct_formatdef(format=100, size=8, alignment=0),
         struct_formatdef(format=0, size=0, alignment=0)
     ];


def struct_whichtable(pfmt: str) -> struct_formatdef {
    raise "c2jac: quarantined function 'struct_whichtable' — L104 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder; L105 [W4202] switch fall-through not modelled — case fall-through not modelled and/or an impure selector is re-evaluated per branch";
}


def struct_getentry(c: int, f: struct_formatdef) -> struct_formatdef {
    while (f.format != 0) {
        if (f.format == c) {
            return f;
        }
        f += 1;
    }

    return None;
}


def struct_align(size: int, c: int, e: struct_formatdef) -> int {
    extra: int = 0;

    if (e.format == c) {
        if (e.alignment and (size > 0)) {
            extra = (e.alignment - 1) - ((size - 1) % e.alignment);
            if (extra > (9223372036854775807 - size)) {
                return -1;
            }
            size += extra;
        }
    }

    return size;
}


@__jac_value__
obj struct_code {
    has fmtdef: int = 0;
    has offset: int = 0;
    has size: int = 0;
    has repeat: int = 0;
}


def struct_prepare_s(
    fmt: str, codes: struct_code, out_ncodes: object, out_size: object, out_len: object
) -> int {
    raise "c2jac: quarantined function 'struct_prepare_s' — L189 [W4290] C construct `BinaryOp` has no faithful Jac lowering — emitted as a placeholder; L194 [W4290] C construct `BinaryOp` has no faithful Jac lowering — emitted as a placeholder";
}


def struct_np_pack(x: int, size: int, p: str) -> None {
    i: int = 0;
    for i = 0 while i < size with i += 1 {
        p[i] = x & 255;
        x >>= 8;
    }
}


def struct_lp_pack(x: int, size: int, p: str) -> None {
    i: int = 0;
    for i = 0 while i < size with i += 1 {
        p[i] = x & 255;
        x >>= 8;
    }
}


def struct_bp_pack(x: int, size: int, p: str) -> None {
    i: int = 0;
    i = size;
    while True {
        p[(i := i - 1)] = x & 255;
        x >>= 8;
        if not (i > 0) {
            break;
        }
    }
}


def struct_range_check(x: int, size: int, is_unsigned: int) -> int {
    if is_unsigned {
        if (x < 0) {
            return -1;
        }
        if (size >= 8) {
            return 0;
        }

        maxint: int = 1 << (size * 8);
        if (x >= maxint) {
            return -1;
        }

        return 0;
    }

    if (size >= 8) {
        return 0;
    }

    limit: int = 1 << ((size * 8) - 1);
    if ((x < -limit) or (x > (limit - 1))) {
        return -1;
    }

    return 0;
}


def struct_unpack_le(p: str, size: int, is_signed: int) -> int {
    x: int = 0;
    i: int = 0;
    for i = 0 while i < size with i += 1 {
        x |= p[i] << (8 * i);
    }
    if (is_signed and (size < 8)) {
        signbit: int = 1 << ((size * 8) - 1);
        if (x & signbit) {
            x = ~x + 1;
        }
    }

    return x;
}


def struct_unpack_be(p: str, size: int, is_signed: int) -> int {
    raise "c2jac: quarantined function 'struct_unpack_be' — L361 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder";
}


def struct_s_fill(src: str, n: int, codesize: int, dst: str) -> int {
    k: int = codesize if (n > codesize) else n;
    i: int = 0;
    for i = 0 while i < k with i += 1 {
        dst[i] = src[i];
    }
    return k;
}


def struct_p_fill(src: str, n: int, codesize: int, dst: str) -> None {
    i: int = 0;
    if (codesize == 0) {
        n = 0;
    } elif (n > (codesize - 1)) {
        n = codesize - 1;
    }

    for i = 0 while i < n with i += 1 {
        dst[(i + 1)] = src[i];
    }
    if (n > 255) {
        n = 255;
    }
    dst[0] = n;
}


def struct_p_span(res: str, codesize: int) -> int {
    n: int = 0;
    if (codesize == 0) {
        return 0;
    }
    n = res[0];
    if (n >= codesize) {
        n = codesize - 1;
    }
    return n;
}
