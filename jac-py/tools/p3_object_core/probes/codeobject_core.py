class TestCodeCore(unittest.TestCase):
    def test_code_flags_generator(self):
        def g():
            yield 1
        self.assertTrue(g.__code__.co_flags & 0x20)

    def test_code_argcount(self):
        def f(a, b, c=1):
            return a
        self.assertEqual(f.__code__.co_argcount, 3)
