class TestWeakrefCore(unittest.TestCase):
    def test_object_alive(self):
        class C:
            pass
        c = C()
        self.assertIsNotNone(c)
        self.assertTrue(isinstance(c, C))

    def test_object_identity(self):
        a = object()
        self.assertIs(a, a)
