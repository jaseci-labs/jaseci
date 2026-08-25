# Native heapq shim pins. Served from the host, heapq mutates a COPY of any
# guest list argument (MUTABLE_COPY bridge policy), so heappush/heapify
# silently no-op'd on the guest's heap. The native shim runs the Lib/heapq.py
# algorithms over live PyList storage; these pins hold the mutation-visibility
# and ordering contracts.
import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

test "heapq shim: mutations land in the guest list" {
    src = "class TestHeapqMutate(unittest.TestCase):\n"
    "    def test_heapify(self):\n"
    "        import heapq\n"
    "        h = [3, 1, 2]\n"
    "        heapq.heapify(h)\n"
    "        self.assertEqual(h, [1, 3, 2])\n"
    "    def test_heappush(self):\n"
    "        import heapq\n"
    "        h = [1, 3, 2]\n"
    "        heapq.heappush(h, 0)\n"
    "        self.assertEqual(h[0], 0)\n"
    "    def test_push_pop_cycle(self):\n"
    "        import heapq\n"
    "        h = []\n"
    "        for x in [5, 1, 3, 2]:\n"
    "            heapq.heappush(h, x)\n"
    "        out = []\n"
    "        while h:\n"
    "            out.append(heapq.heappop(h))\n"
    "        self.assertEqual(out, [1, 2, 3, 5])\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "heapq shim: replace/pushpop semantics" {
    src = "class TestHeapqReplace(unittest.TestCase):\n"
    "    def test_heapreplace(self):\n"
    "        import heapq\n"
    "        h = [1, 3, 2]\n"
    "        old = heapq.heapreplace(h, 5)\n"
    "        self.assertEqual(old, 1)\n"
    "        self.assertEqual(h[0], 2)\n"
    "    def test_heappushpop_returns_smaller(self):\n"
    "        import heapq\n"
    "        h = [1, 3, 2]\n"
    "        self.assertEqual(heapq.heappushpop(h, 0), 0)\n"
    "        self.assertEqual(h, [1, 3, 2])\n"
    "        self.assertEqual(heapq.heappushpop(h, 9), 1)\n"
    "        self.assertEqual(h[0], 2)\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}
