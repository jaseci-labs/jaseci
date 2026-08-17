"""Tests for the ambient test builtins: `skip_test`, `fail`, and `raises`.

These are declared in `jaclang/runtimelib/builtin.jac` (runtime behaviour) and
`jaclang/compiler/type_system/jac_builtins.pyi` (checker-visible signatures),
so they are usable inside any `test` block with no import. `skip` itself is a
Jac keyword (the walker skip statement), hence the `skip_test` spelling.
"""

test "raises catches the expected exception" {
    with raises(ValueError) {
        raise ValueError("boom");
    }
}

test "raises exposes the exception through .value" {
    with raises(ValueError) as ei {
        raise ValueError("boom");
    }
    assert "boom" in str(ei.value);
}

test "raises accepts several exception types" {
    with raises(KeyError, ValueError) {
        raise KeyError("k");
    }
}

test "raises honors a match pattern" {
    with raises(RuntimeError, `match="no native parser") {
        raise RuntimeError("there is no native parser here");
    }
}

test "raises rejects a non-matching pattern" {
    caught = "";
    try {
        with raises(RuntimeError, `match="expected text") {
            raise RuntimeError("entirely different");
        }
    } except AssertionError as e {
        caught = str(e);
    }
    assert "does not match" in caught;
}

test "raises fails when the block raises nothing" {
    caught = "";
    try {
        with raises(ValueError) {
            ;
        }
    } except AssertionError as e {
        caught = str(e);
    }
    assert "DID NOT RAISE ValueError" in caught;
}

test "raises lets an unrelated exception propagate" {
    propagated = False;
    try {
        with raises(ValueError) {
            raise KeyError("other");
        }
    } except KeyError {
        propagated = True;
    }
    assert propagated;
}

test "raises rejects non-exception arguments" {
    caught = False;
    try {
        raises(int);
    } except TypeError {
        caught = True;
    }
    assert caught;
}

test "raises requires at least one exception type" {
    caught = False;
    try {
        raises();
    } except TypeError {
        caught = True;
    }
    assert caught;
}

test "fail raises AssertionError carrying the reason" {
    caught = "";
    try {
        fail("nope");
    } except AssertionError as e {
        caught = str(e);
    }
    assert caught == "nope";
}

test "fail has a default reason" {
    caught = "";
    try {
        fail();
    } except AssertionError as e {
        caught = str(e);
    }
    assert caught == "explicit failure";
}

test "skip_test raises SkipTest so the runner reports a skip" {
    import from unittest { SkipTest }
    caught = "";
    try {
        skip_test("environment gate");
    } except SkipTest as e {
        caught = str(e);
    }
    assert caught == "environment gate";
}

test "skip_test actually skips the rest of this block" {
    skip_test("always skipped");
    assert False;
}
