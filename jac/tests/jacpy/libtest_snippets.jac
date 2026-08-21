"""Shared Lib/test-style snippets for P2 libtest gates.

Each ``LibtestSnippet`` carries:
  - ``code`` — host CPython snippet (stdlib algorithm smoke)
  - ``jac_preamble`` / ``jac_entry`` — optional staged ``Modules/*.jac`` differential
"""

obj LibtestSnippet {
    has module_stem: str;
    has name: str;
    has code: str;
    has expect_stdout: str = "ok";
    has jac_preamble: str = "";
    has jac_entry: str = "";
    has jac_expect_stdout: str = "";
    has jacpython_capable: bool = False;
}

# Mock PyObj helpers for _bisectmodule / _heapqmodule differential legs
# (same protocol as test_p2_module_oracles.jac).
glob PY_MOCK_PREAMBLE: str = (
    "glob _mock_objs: list = [];\n"
    "glob _mock_vals: list = [];\n"
    "def PyObject_RichCompareBool(a: PyObj, b: PyObj, op: int) -> int {\n"
    "    av = 0; bv = 0;\n"
    "    for i in range(len(_mock_objs)) {\n"
    "        if _mock_objs[i] is a { av = _mock_vals[i]; }\n"
    "        if _mock_objs[i] is b { bv = _mock_vals[i]; }\n"
    "    }\n"
    "    if op == 0 and av < bv { return 1; }\n"
    "    return 0;\n"
    "}\n"
    "def PySequence_Size(seq: PyObj) -> int {\n"
    "    lst: PyListObject = seq;\n"
    "    return lst.ob_size;\n"
    "}\n"
    "def Py_EnterRecursiveCall(where: str) -> int { return 0; }\n"
    "def Py_LeaveRecursiveCall() -> None { }\n"
    "def PyErr_SetString(exc: PyObj, msg: str) -> None { }\n"
    "def Py_INCREF(o: PyObj) -> None { }\n"
    "def Py_DECREF(o: PyObj) -> None { }\n"
    "def mock_sq_item(s: PyObj, i: int) -> PyObj {\n"
    "    lst: PyListObject = s;\n"
    "    items: list = lst.ob_item;\n"
    "    return items[i];\n"
    "}\n"
    "def get_sq_item(s: PyObj) -> ssizeargfunc { return mock_sq_item; }\n"
    "def _make_int(v: int) -> PyObj {\n"
    "    o = PyObject();\n"
    "    _mock_objs.append(o);\n"
    "    _mock_vals.append(v);\n"
    "    return o;\n"
    "}\n"
    "def _mock_heap_list() -> PyListObject {\n"
    "    items = [_make_int(1), _make_int(3), _make_int(5), _make_int(7)];\n"
    "    lst = PyListObject();\n"
    "    lst.ob_size = 4;\n"
    "    lst.ob_item = items;\n"
    "    list_type = PyTypeObject();\n"
    "    list_seq = PySequenceMethods();\n"
    "    list_seq.sq_item = ssizeargfunc();\n"
    "    list_type.tp_as_sequence = list_seq;\n"
    "    lst.ob_base.ob_type = list_type;\n"
    "    return lst;\n"
    "}\n"
);

glob LIBTEST_SNIPPETS: list[LibtestSnippet] = [
    LibtestSnippet(
        module_stem="_bisectmodule",
        name="bisect_precomputed",
        code=(
            "import bisect\n"
            "cases = [\n"
            "    (bisect.bisect_right, [], 1, 0),\n"
            "    (bisect.bisect_right, [1, 2, 3], 2, 2),\n"
            "    (bisect.bisect_left, [1, 1, 2, 2], 1.5, 2),\n"
            "    (bisect.bisect_left, [1, 2, 2, 3, 3, 3, 4, 4, 4, 4], 3, 3),\n"
            "]\n"
            "for func, data, elem, expected in cases:\n"
            "    got = func(data, elem)\n"
            "    assert got == expected, (func.__name__, data, elem, got, expected)\n"
            "print('ok')\n"
        ),
        jac_preamble=PY_MOCK_PREAMBLE,
        jac_entry=(
            "with entry {\n"
            "    lst = _mock_heap_list();\n"
            "    item4 = _make_int(4);\n"
            "    got = bisect_right(lst, item4, 0, -1, Py_None);\n"
            "    assert got >= 0;\n"
            "    print('ok');\n"
            "}\n"
        )
    ),
    LibtestSnippet(
        module_stem="_bisectmodule",
        name="bisect_insort",
        code=(
            "import bisect\n"
            "data = [1, 2, 3]\n"
            "bisect.insort(data, 2)\n"
            "assert data == [1, 2, 2, 3]\n"
            "bisect.insort_left(data, 2)\n"
            "assert data == [1, 2, 2, 2, 3]\n"
            "print('ok')\n"
        )
    ),
    LibtestSnippet(
        module_stem="_heapqmodule",
        name="heapq_push_pop",
        code=(
            "import heapq\n"
            "heap = []\n"
            "data = [3, 1, 4, 1, 5, 9, 2, 6]\n"
            "for x in data:\n"
            "    heapq.heappush(heap, x)\n"
            "out = []\n"
            "while heap:\n"
            "    out.append(heapq.heappop(heap))\n"
            "assert out == sorted(data)\n"
            "print('ok')\n"
        ),
        jac_preamble=PY_MOCK_PREAMBLE,
        jac_entry=(
            "with entry {\n"
            "    lst = _mock_heap_list();\n"
            "    assert heap_siftdown(lst, 0, 3) == 0;\n"
            "    print('ok');\n"
            "}\n"
        )
    ),
    LibtestSnippet(
        module_stem="_heapqmodule",
        name="heapq_heapify",
        code=(
            "import heapq\n"
            "data = [3, 1, 4, 1, 5, 9, 2, 6]\n"
            "heapq.heapify(data)\n"
            "parent_ok = all(data[(i - 1) >> 1] <= data[i] for i in range(1, len(data)))\n"
            "assert parent_ok\n"
            "assert sorted(data) == [1, 1, 2, 3, 4, 5, 6, 9]\n"
            "print('ok')\n"
        )
    ),
    LibtestSnippet(
        module_stem="getplatform",
        name="platform_basic",
        code=(
            "import platform\n"
            "plat = platform.platform()\n"
            "assert isinstance(plat, str) and len(plat) > 0\n"
            "assert isinstance(platform.system(), str)\n"
            "assert isinstance(platform.machine(), str)\n"
            "print('ok')\n"
        ),
        jac_entry=(
            "with entry {\n"
            "    plat = Py_GetPlatform();\n"
            "    assert isinstance(plat, str) and len(plat) > 0;\n"
            "    print('ok');\n"
            "}\n"
        ),
        jacpython_capable=True
    ),
];
