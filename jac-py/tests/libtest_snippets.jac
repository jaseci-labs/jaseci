"""Shared Lib/test-style host CPython snippets for P2 libtest gates."""

obj LibtestSnippet {
    has module_stem: str;
    has name: str;
    has code: str;
    has expect_stdout: str = "ok";
}

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
        )
    ),
];
