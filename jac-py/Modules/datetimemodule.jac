def c_idiv(a: int, b: int) -> int {
    q = a // b;
    return q + (1 if (a % b != 0) and ((a < 0) != (b < 0)) else 0);
}

def c_imod(a: int, b: int) -> int {
    return a - c_idiv(a, b) * b;
}

glob Py_ssize_t = int;

glob _days_in_month: list[int] = [
         0,
         31,
         28,
         31,
         30,
         31,
         30,
         31,
         31,
         30,
         31,
         30,
         31
     ];

glob _days_before_month: list[int] = [
         0,
         0,
         31,
         59,
         90,
         120,
         151,
         181,
         212,
         243,
         273,
         304,
         334
     ];


def datetime_divmod(x: int, y: int, r: object) -> int {
    quo: int = 0;
    quo = c_idiv(x, y);
    r = x - (quo * y);
    if (r < 0) {
        quo = quo - 1;
        r = r + y;
    }

    return quo;
}


def datetime_is_leap(year: int) -> int {
    ayear: int = year;
    return (
        (c_imod(ayear, 4) == 0)
        and ((c_imod(ayear, 100) != 0) or (c_imod(ayear, 400) == 0))
    );
}


def datetime_days_in_month(year: int, month: int) -> int {
    if ((month == 2) and datetime_is_leap(year)) {
        return 29;
    } else {
        return _days_in_month[month];
    }
}


def datetime_days_before_month(year: int, month: int) -> int {
    days: int = 0;
    days = _days_before_month[month];
    if ((month > 2) and datetime_is_leap(year)) {
        days = days + 1;
    }

    return days;
}


def datetime_days_before_year(year: int) -> int {
    y: int = year - 1;

    return ((((y * 365) + c_idiv(y, 4)) - c_idiv(y, 100)) + c_idiv(y, 400));
}


def datetime_ymd_to_ord(year: int, month: int, day: int) -> int {
    return (
        (datetime_days_before_year(year) + datetime_days_before_month(year, month))
        + day
    );
}


def datetime_ord_to_ymd(
    ordinal: int, year: object, month: object, day: object
) -> None {
    n: int = 0;
    n1: int = 0;
    n4: int = 0;
    n100: int = 0;
    n400: int = 0;
    leapyear: int = 0;
    preceding: int = 0;

    ordinal = ordinal - 1;
    n400 = c_idiv(ordinal, 146097);
    n = c_imod(ordinal, 146097);
    year = (n400 * 400) + 1;

    n100 = c_idiv(n, 36524);
    n = c_imod(n, 36524);

    n4 = c_idiv(n, 1461);
    n = c_imod(n, 1461);

    n1 = c_idiv(n, 365);
    n = c_imod(n, 365);

    year = ((year + (n100 * 100)) + (n4 * 4)) + n1;
    if ((n1 == 4) or (n100 == 4)) {
        year = year - 1;
        month = 12;
        day = 31;
        return;
    }

    leapyear = (n1 == 3) and ((n4 != 24) or (n100 == 3));
    month = (n + 50) >> 5;
    preceding = _days_before_month[month] + ((month > 2) and leapyear);
    if (preceding > n) {
        month = month - 1;
        preceding = preceding - datetime_days_in_month(year, month);
    }

    n = n - preceding;
    day = n + 1;
}


def datetime_weekday(year: int, month: int, day: int) -> int {
    return ((datetime_ymd_to_ord(year, month, day) + 6) % 7);
}


def datetime_iso_week1_monday(year: int) -> int {
    first_day: int = datetime_ymd_to_ord(year, 1, 1);

    first_weekday: int = (first_day + 6) % 7;

    week1_monday: int = first_day - first_weekday;

    if (first_weekday > 3) {
        week1_monday = week1_monday + 7;
    }

    return week1_monday;
}


def datetime_normalize_pair(hi: object, lo: object, factor: int) -> None {
    if ((lo < 0) or (lo >= factor)) {
        num_hi: int = datetime_divmod(lo, factor, lo);
        hi = hi + num_hi;
    }
}


def datetime_normalize_d_s_us(d: object, s: object, us: object) -> None {
    if ((us < 0) or (us >= 1000000)) {
        datetime_normalize_pair(s, us, 1000000);
    }

    if ((s < 0) or (s >= (24 * 3600))) {
        datetime_normalize_pair(d, s, (24 * 3600));
    }
}
