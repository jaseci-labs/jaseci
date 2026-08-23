/* Header-free extract: date/timedelta calendrical arithmetic kernels.
 *
 * Source: CPython 3.14.6 Modules/_datetimemodule.c (pinned reference).
 * Slices: proleptic Gregorian calendar core (is_leap unsigned-mod ladder,
 * days_in_month/days_before_month tables, days_before_year, ymd_to_ord,
 * ord_to_ymd 400/100/4/1-year divmod decomposition with the month
 * estimate-and-correct tail), weekday/ISO week-1-Monday derivations,
 * and the timedelta normalization utilities (normalize_pair mixed-radix
 * step, normalize_d_s_us carry folding) that underpin every timedelta
 * constructor and arithmetic path.
 *
 * The PyObject protocol glue (date/datetime/timedelta/tzinfo objects,
 * constructors, rich comparisons, strftime, C-API clients) stays in the
 * product facade; these integer kernels carry CPython's calendrical
 * control-state machines verbatim so they can be differentially lifted
 * and ratcheted by c2jac.
 */

typedef int Py_ssize_t; /* mirrors _datetimemodule.c's own int-based math */
#define DI4Y 1461   /* days_before_year(5); days in 4 years */
#define DI100Y 36524 /* days_before_year(101); days in 100 years */
#define DI400Y 146097 /* days_before_year(401); days in 400 years */
#define MAXORDINAL 3652059 /* date.max.toordinal() */

/* For each month ordinal in 1..12, the number of days in that month,
 * and the number of days before that month in the same year.  These
 * are correct for non-leap years only (1-based indexing, [0] unused). */
static const int _days_in_month[] = {
    0,
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
};

static const int _days_before_month[] = {
    0,
    0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334
};

/* Compute Python divmod(x, y), returning the quotient and storing the
 * remainder into *r.  The quotient is the floor of x/y.  We require
 * y > 0 here, as do all uses made of it; that makes the overflow case
 * impossible. */
int
datetime_divmod(int x, int y, int *r)
{
    int quo;
    quo = x / y;
    *r = x - quo * y;
    if (*r < 0) {
        quo = quo - 1;
        *r = *r + y;
    }
    return quo;
}

/* year -> 1 if leap year, else 0.  The unsigned cast mirrors
 * _datetimemodule.c's ayear trick; c2jac's W4201 cast-elision idiom must
 * not change the value (same discipline as wave 12's PY_SSIZE_T_MAX). */
int
datetime_is_leap(int year)
{
    const unsigned int ayear = (unsigned int)year;
    return ayear % 4 == 0 && (ayear % 100 != 0 || ayear % 400 == 0);
}

/* year, month -> number of days in that month in that year */
int
datetime_days_in_month(int year, int month)
{
    if (month == 2 && datetime_is_leap(year)) {
        return 29;
    }
    else {
        return _days_in_month[month];
    }
}

/* year, month -> number of days in year preceding first day of month */
int
datetime_days_before_month(int year, int month)
{
    int days;
    days = _days_before_month[month];
    if (month > 2 && datetime_is_leap(year)) {
        days = days + 1;
    }
    return days;
}

/* year -> number of days before January 1st of year.  We start with
 * year 1, so days_before_year(1) == 0. */
int
datetime_days_before_year(int year)
{
    int y = year - 1;
    /* Floor division would be needed for year <= 0, but MINYEAR is 1. */
    return y * 365 + y / 4 - y / 100 + y / 400;
}

/* year, month, day -> ordinal, considering 01-Jan-0001 as day 1. */
int
datetime_ymd_to_ord(int year, int month, int day)
{
    return datetime_days_before_year(year)
        + datetime_days_before_month(year, month) + day;
}

/* ordinal -> year, month, day, considering 01-Jan-0001 as day 1.
 *
 * The pattern of leap years repeats exactly every 400 years: find the
 * closest 400-year boundary at or before ordinal, then decompose the
 * offset through 100-, 4-, and 1-year cycles.  n100/n1 can legitimately
 * equal their cycle count (desired day is Dec 31 at the end of a full
 * cycle); the estimate-and-correct month tail then lands the day. */
void
datetime_ord_to_ymd(int ordinal, int *year, int *month, int *day)
{
    int n, n1, n4, n100, n400, leapyear, preceding;

    ordinal = ordinal - 1;
    n400 = ordinal / DI400Y;
    n = ordinal % DI400Y;
    *year = n400 * 400 + 1;

    n100 = n / DI100Y;
    n = n % DI100Y;

    n4 = n / DI4Y;
    n = n % DI4Y;

    n1 = n / 365;
    n = n % 365;

    *year = *year + n100 * 100 + n4 * 4 + n1;
    if (n1 == 4 || n100 == 4) {
        *year = *year - 1;
        *month = 12;
        *day = 31;
        return;
    }

    leapyear = n1 == 3 && (n4 != 24 || n100 == 3);
    *month = (n + 50) >> 5;
    preceding = (_days_before_month[*month] + (*month > 2 && leapyear));
    if (preceding > n) {
        /* estimate is too large */
        *month = *month - 1;
        preceding = preceding - datetime_days_in_month(*year, *month);
    }
    n = n - preceding;
    *day = n + 1;
}

/* Day of week, where Monday==0, ..., Sunday==6.  1/1/1 was a Monday. */
int
datetime_weekday(int year, int month, int day)
{
    return (datetime_ymd_to_ord(year, month, day) + 6) % 7;
}

/* Ordinal of the Monday starting week 1 of the ISO year.  Week 1 is the
 * first calendar week containing a Thursday. */
int
datetime_iso_week1_monday(int year)
{
    int first_day = datetime_ymd_to_ord(year, 1, 1); /* ord of 1/1 */
    /* 0 if 1/1 is a Monday, 1 if a Tue, etc. */
    int first_weekday = (first_day + 6) % 7;
    /* ordinal of closest Monday at or before 1/1 */
    int week1_monday = first_day - first_weekday;

    if (first_weekday > 3) { /* if 1/1 was Fri, Sat, Sun */
        week1_monday = week1_monday + 7;
    }
    return week1_monday;
}

/* One step of a mixed-radix conversion.  A "hi" unit is equivalent to
 * factor "lo" units.  factor must be > 0.  If *lo is less than 0, or at
 * least factor, enough of *lo is converted into "hi" units so that
 * 0 <= *lo < factor. */
void
datetime_normalize_pair(int *hi, int *lo, int factor)
{
    if (*lo < 0 || *lo >= factor) {
        const int num_hi = datetime_divmod(*lo, factor, lo);
        *hi = *hi + num_hi;
    }
}

/* Fiddle days (d), seconds (s), and microseconds (us) so that
 *      0 <= *s < 24*3600
 *      0 <= *us < 1000000
 * This is the carry-folding ladder every timedelta result walks. */
void
datetime_normalize_d_s_us(int *d, int *s, int *us)
{
    if (*us < 0 || *us >= 1000000) {
        datetime_normalize_pair(s, us, 1000000);
    }
    if (*s < 0 || *s >= 24 * 3600) {
        datetime_normalize_pair(d, s, 24 * 3600);
    }
}
