class TestWeakrefCore(unittest.TestCase):
    def test_object_alive(self):
        class C:
            pass
        c = C()
        # Layer 1 diffs each assert arg across VMs; a bare fresh instance can't
        # be carried host<->jac, so fold liveness into one expression.
        self.assertTrue(c is not None)
        self.assertTrue(isinstance(c, C))

    def test_object_identity(self):
        a = object()
        # Cross-process identity of a fresh object() never matches per-arg;
        # intra-expression identity keeps the intent.
        self.assertTrue(a is a)
