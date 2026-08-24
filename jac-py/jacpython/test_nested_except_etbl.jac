# Regression pins for m2b: nested try/except exception-table emission.
#
# Bug: an enclosing try's unwind-bind pass retargeted the inner try's
# exception-table regions to the outer unwind chain (shared pending list),
# so an exception escaping an inner handler bypassed every outer handler.
# Fix: per-invocation region ownership in visit_try plus published
# success-epilogue spans consumed by the outer carve-out region.
#
# Parity is asserted on co_exceptiontable bytes vs the host CPython oracle
# (co_code const-registration order can differ benignly on nested shapes).
import from layer9_product_exec { product_exec, oracle_exec }
import from objects { PyCode }

def etbl_parity(name: str, src: str) -> bool {
    a = product_exec(src) as PyCode;
    e = oracle_exec(src, "<nested_except_etbl>") as PyCode;
    return a.exceptiontable == e.exceptiontable;
}

glob SRC_2LVL_MISMATCH = (
    "try:\n"
    "    try:\n"
    "        raise KeyError('x')\n"
    "    except ValueError:\n"
    "        r = 'wrong'\n"
    "except KeyError:\n"
    "    r = 'outer'\n"
);

glob SRC_2LVL_MATCH_INNER = (
    "try:\n"
    "    try:\n"
    "        raise ValueError('x')\n"
    "    except ValueError:\n"
    "        r = 'inner'\n"
    "except KeyError:\n"
    "    r = 'outer'\n"
);

glob SRC_3LVL = (
    "try:\n"
    "    try:\n"
    "        try:\n"
    "            raise KeyError('x')\n"
    "        except ValueError:\n"
    "            r = 'a'\n"
    "    except TypeError:\n"
    "        r = 'b'\n"
    "except KeyError:\n"
    "    r = 'outer'\n"
);

glob SRC_BOUND_HANDLERS = (
    "try:\n"
    "    try:\n"
    "        raise KeyError('x')\n"
    "    except ValueError as v:\n"
    "        r = 'wrong'\n"
    "except KeyError as e:\n"
    "        r = 'outer'\n"
);

glob SRC_FLAT_CONTROL = (
    "try:\n"
    "    raise KeyError('x')\n"
    "except KeyError:\n"
    "    r = 'ok'\n"
);

test "nested except etbl: two-level mismatched inner" {
    assert etbl_parity("2lvl-mismatch", SRC_2LVL_MISMATCH);
}

test "nested except etbl: two-level matching inner" {
    assert etbl_parity("2lvl-match", SRC_2LVL_MATCH_INNER);
}

test "nested except etbl: three levels" {
    assert etbl_parity("3lvl", SRC_3LVL);
}

test "nested except etbl: bound handlers" {
    assert etbl_parity("bound", SRC_BOUND_HANDLERS);
}

test "nested except etbl: flat control" {
    assert etbl_parity("flat", SRC_FLAT_CONTROL);
}

# Runtime: an exception raised inside an inner handler body must reach the
# OUTER matching handler instead of escaping every handler.
glob SRC_RT_ESCAPE = (
    "out = []\n"
    "try:\n"
    "    try:\n"
    "        raise KeyError('x')\n"
    "    except ValueError:\n"
    "        raise RuntimeError('inner handler ran')\n"
    "except KeyError:\n"
    "    out.append('outer-keyerror')\n"
    "assert out == ['outer-keyerror'], out\n"
);

glob SRC_RT_CHAIN = (
    "hits = []\n"
    "try:\n"
    "    try:\n"
    "        raise ValueError(7)\n"
    "    except LookupError:\n"
    "        hits.append(1)\n"
    "    raise KeyError('k')\n"
    "except KeyError:\n"
    "    hits.append(2)\n"
    "assert hits == [1, 2], hits\n"
);

test "nested except runtime: inner-handler raise reaches outer handler" {
    product_exec(SRC_RT_ESCAPE);
}

test "nested except runtime: sequential raises through nested handlers" {
    product_exec(SRC_RT_CHAIN);
}
