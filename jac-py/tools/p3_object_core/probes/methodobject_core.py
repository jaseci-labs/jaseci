class TestMethodCore(unittest.TestCase):
    def test_bound_method_call(self):
        class C:
            def f(self):
                return 42

        c = C()
        self.assertEqual(c.f(), 42)
        self.assertTrue(c.f.__self__ is c)

    def test_unbound_class_access(self):
        lst = []
        self.assertIsNone(list.append.__self__)
        list.append(lst, 1)
        self.assertEqual(lst, [1])

    def test_builtin_method_repr(self):
        self.assertIn("built-in method append", repr([].append))
        self.assertIn("built-in function len", repr(len))

    def test_method_identity(self):
        self.assertIs(list.append, list.append)
        a = []
        self.assertIsNot(a.append, list.append)
