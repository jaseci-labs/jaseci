glob Py_ssize_t = int;
glob uint64_t_ = int;


def dl_fast_sum(a: float, b: float, out: list) -> None {
    x: float = a + b;
    y: float = (a - x) + b;
    out[0] = x;
    out[1] = y;
}


def dl_sum(a: float, b: float, out: list) -> None {
    x: float = a + b;
    z: float = x - a;
    y: float = (a - (x - z)) + (b - z);
    out[0] = x;
    out[1] = y;
}


def m_fabs(x: float) -> float {
    if (x == 0.0) {
        return 0.0;
    }

    if (x < 0.0) {
        return -x;
    }

    return x;
}


def fsum_fold_partials(p: object, n: int, x: float, x_out: list) -> int {
    i: int = 0;
    j: int = 0;
    y: float = 0.0;
    t: float = 0.0;
    hi: float = 0.0;
    yr: float = 0.0;
    lo: float = 0.0;
    for i = 0 while j < n with j += 1 {
        y = p[j];
        if (m_fabs(x) < m_fabs(y)) {
            t = x;
            x = y;
            y = t;
        }

        hi = x + y;
        yr = hi - x;
        lo = y - yr;
        if (lo != 0.0) {
            p[i] = lo;
            i = i + 1;
        }

        x = hi;
    }

    x_out[0] = x;
    return i;
}


def isclose_tol_invalid(rel_tol: float, abs_tol: float) -> int {
    return ((rel_tol < 0.0) or (abs_tol < 0.0));
}


def isclose_weak_test(a: float, b: float, rel_tol: float, abs_tol: float) -> int {
    diff: float = m_fabs((b - a));
    return (
        ((diff <= m_fabs((rel_tol * b))) or (diff <= m_fabs((rel_tol * a))))
        or (diff <= abs_tol)
    );
}


def comb_small_step(n: int, k: int) -> int {
    result: int = n;
    i: int = 1;
    while (i < k) {
        n = n - 1;
        result = result * n;
        i = i + 1;
        result = result // i;
    }

    return result;
}


def perm_small_step(n: int, k: int) -> int {
    result: int = n;
    i: int = 1;
    while (i < k) {
        n = n - 1;
        result = result * n;
        i = i + 1;
    }

    return result;
}
