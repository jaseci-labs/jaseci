class TestClassCore(unittest.TestCase):
    def test_bound_method_attrs(self):
        class C:
            def m(self):
                return 1
        c = C()
        self.assertIs(c.m.__self__, c)
        self.assertEqual(c.m.__func__.__name__, 'm')

    def test_bound_method_call(self):
        class C:
            def m(self, x):
                return x + 1
        self.assertEqual(C().m(2), 3)
