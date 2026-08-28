"""Bundled native ``unicodedata`` cross-backend equivalence fixture.

The SAME ``import from unicodedata { category, east_asian_width }`` binds
CPython's ``unicodedata`` on the sv (Python) backend and the bundled
``na_stdlib/unicodedata.jac`` Mechanism-B module on the na (native LLVM)
backend. Spot checks pin Unicode 16.0.0 / CPython 3.14 tables. DIVERGENCES:
non-single-character strings answer ``""`` on na where CPython raises
``TypeError`` (sv probes use ``try``/``except TypeError`` so both return
``""``); multi-byte UTF-8 literals in native fixtures fail the module's
``len(ch) == 1`` guard so CJK / © / Mn / emoji probes are sv-only; na
``east_asian_width`` answers a single letter from ``_EAW_CODES`` (e.g. ``a``
for the ambiguous class) where CPython returns the two-letter code ``Na``, so
``east_asian_width`` probes are sv-only. ASCII ``category`` spot checks are
sv<->na congruent. ES/JS opts out.
"""

import from unicodedata { category, east_asian_width }


def _empty_category_py() -> str {
    try {
        return category("");
    } except TypeError {
        return "";
    }
}


def _empty_eaw_py() -> str {
    try {
        return east_asian_width("");
    } except TypeError {
        return "";
    }
}


def unicodedata_py() -> dict {
    return {
        "cat_A": category("A"),
        "cat_a": category("a"),
        "cat_space": category(" "),
        "cat_0": category("0"),
        "cat_dot": category("."),
        "cat_dash": category("-"),
        "cat_zhong": category("\u4e2d"),
        "cat_copy": category("\u00a9"),
        "cat_comb_mn": category("\u0300"),
        "eaw_A": east_asian_width("A"),
        "eaw_dot": east_asian_width("."),
        "eaw_zhong": east_asian_width("\u4e2d"),
        "eaw_emoji": east_asian_width("\U0001f600"),
        "eaw_comb": east_asian_width("\u0300"),
        "cat_empty": _empty_category_py(),
        "eaw_empty": _empty_eaw_py()
    };
}


def unicodedata_cl() -> dict {
    return {};
}


def unicodedata_na() -> dict[str, any] {
    return {
        "cat_A": category("A"),
        "cat_a": category("a"),
        "cat_space": category(" "),
        "cat_0": category("0"),
        "cat_dot": category("."),
        "cat_dash": category("-"),
        "cat_empty": category(""),
        "eaw_empty": east_asian_width("")
    };
}
