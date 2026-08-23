"""The fixed-width numeric contract holds identically on every lane (#8532).

One fixture, three backends: the server reference, native LLVM, and the
client's ECMAScript. A value or a trap that differs between lanes fails here.
"""

import from jaclang.compiler.tests.xbackend_equiv {
    compile_fixture_to_js,
    run_js_function,
    run_py_fixture,
    run_with_both
}

glob EXPECTED: dict[str, any] = {
         "overflow_add": 1,
         "overflow_max": 1,
         "underflow": 1,
         "cast_trap": 1,
         "neg_min": 1,
         "shl_trap": 1,
         "wrap_300": 44,
         "wrap_i8_200": -56,
         "wrapping_add": -56,
         "wrapping_sub": 255,
         "wrapping_mul": 0,
         "wrapping_shl": 128,
         "lshr": 127,
         "ashr": -1,
         "u64_gt": 1,
         "u8_floordiv": 66,
         "u8_mod": 2,
         "i8_floordiv": -4,
         "i8_mod": 1,
         "u32_truediv": 3.5,
         "invert_u8": 255,
         "pow_u8": 128,
         "f32_literal": 0.10000000149011612,
         "f32_sum": 0.30000001192092896,
         "f32_to_f64": 0.10000000149011612,
         "i8_min": -128,
         "u16_max": 65535,
         "widened_u8": 200,
         "literal_adopt": 2,
         "cast_float_trunc": -3,
         "abs_i8": 5
     };

test "the server lane matches the spec row for row" {
    got = run_py_fixture("fw_conformance", "fw_py");
    assert got == EXPECTED , {
        k: (got.get(k), v)
        for (k, v) in EXPECTED.items()
        if got.get(k) != v
    };
}

test "native and client lanes agree with the server lane" {
    run_with_both(
        "fw_conformance.jac",
        "fw_py",
        "fw_cl",
        "fw_na",
        tolerance=1e-12,
        require=["na", "cl"]
    );
}

test "a 64-bit value crosses the client JSON boundary as a number when safe, else as a string" {
    js = compile_fixture_to_js("fw_conformance.jac");
    got = run_js_function(js, "fw_json_cl");
    assert got == {"big": "9223372036854775808", "small": 5, "neg": -7} , got;
}
