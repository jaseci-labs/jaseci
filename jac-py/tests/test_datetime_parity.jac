"""P2 wave 21 datetime parity: date/timedelta calendrical kernels vs host.

jac-py/Modules/datetimemodule.{c,jac} are the staged c2jac corpus pair
(staging=lift) carrying CPython 3.14's calendrical integer kernels verbatim
(is_leap unsigned-mod ladder, month/year day tables, ymd_to_ord,
weekday, iso_week1_monday, normalize_pair/normalize_d_s_us carry folding).
This file gates the lifted kernels against the host ``datetime`` oracle.
Expected values were verified against real python3 at authoring time (see
tools/p2_corpus_wave21/probes/mutation_probe.py).

ord_to_ymd and the normalize_* helpers take C pointer out-params; c2jac
lowers those to rebinding parameters (documented infidelity, same class as
wave-12's itertools_count_next_fast ``out`` param), so they cannot be called
for observation from Jac. They stay ratchet artifacts; the single-result
kernels below pin the same algorithms from every observable angle.
"""

import from datetimemodule {
    datetime_days_before_month,
    datetime_days_before_year,
    datetime_days_in_month,
    datetime_is_leap,
    datetime_iso_week1_monday,
    datetime_weekday,
    datetime_ymd_to_ord,
}
import datetime as host_dt;


test "wave21 is_leap matches host leap rule (century + 400-year cases)" {
    years: list = [1, 4, 100, 400, 1900, 1996, 2000, 2023, 2024, 2100, 2400];
    for y in years {
        host_leap = (y % 4 == 0) and ((y % 100 != 0) or (y % 400 == 0));
        got = datetime_is_leap(y);
        assert got == (1 if host_leap else 0) , (y, got);
    }
}


test "wave21 days_in_month/days_before_month match host calendar tables" {
    # month lengths derived from host ordinal arithmetic, not re-typed here
    for year in [1999, 2000] {
        for month in range(1, 13) {
            if month < 12 {
                nxt = host_dt.date(year, month + 1, 1);
            } else {
                nxt = host_dt.date(year + 1, 1, 1);
            }
            first = host_dt.date(year, month, 1);
            dim_host = nxt.toordinal() - first.toordinal();
            assert datetime_days_in_month(year, month) == dim_host , (
                year, month
            );
        }
    }
    # pinned python3 values
    assert datetime_days_in_month(2000, 2) == 29 , "leap feb";
    assert datetime_days_in_month(1999, 2) == 28 , "plain feb";
    assert datetime_days_before_month(2000, 3) == 60 , "leap mar";
    assert datetime_days_before_month(1999, 3) == 59 , "plain mar";
    assert datetime_days_before_month(2000, 1) == 0 , "jan";
}


test "wave21 days_before_year anchors the proleptic epoch" {
    assert datetime_days_before_year(1) == 0 , "epoch";
    for year in [2, 5, 100, 101, 400, 401, 1970, 2000, 2024] {
        host_ord = host_dt.date(year, 1, 1).toordinal() - 1;
        got = datetime_days_before_year(year);
        assert got == host_ord , (year, got, host_ord);
    }
}


test "wave21 ymd_to_ord round-trips against host toordinal" {
    probes: list = [
        (1, 1, 1), (1, 12, 31), (2, 1, 1), (4, 12, 31), (5, 1, 1),
        (100, 12, 31), (101, 1, 1), (400, 12, 31), (401, 1, 1),
        (1600, 2, 29), (1970, 1, 1), (1999, 12, 31), (2000, 2, 29),
        (2024, 1, 4), (9999, 12, 31),
    ];
    for (y, m, d) in probes {
        got = datetime_ymd_to_ord(y, m, d);
        want = host_dt.date(y, m, d).toordinal();
        assert got == want , ((y, m, d), got, want);
    }
}


test "wave21 weekday matches host Monday==0 convention" {
    probes: list = [
        (1, 1, 1), (2024, 1, 4), (2026, 2, 17), (2000, 1, 1), (9999, 12, 31),
    ];
    for (y, m, d) in probes {
        got = datetime_weekday(y, m, d);
        want = host_dt.date(y, m, d).weekday();
        assert got == want , ((y, m, d), got, want);
    }
}


test "wave21 iso_week1_monday matches host fromisocalendar" {
    years: list = [1, 4, 5, 100, 400, 2015, 2020, 2021, 2026];
    for y in years {
        got = datetime_iso_week1_monday(y);
        want = host_dt.date.fromisocalendar(y, 1, 1).toordinal();
        assert got == want , (y, got, want);
    }
}
