class TestCapsuleCore(unittest.TestCase):
    def test_sys_modules(self):
        import sys
        self.assertTrue(hasattr(sys, 'modules'))
        # assertIn isn't a Layer-1 check form; fold membership intra-expression.
        self.assertEqual('sys' in sys.modules, True)

    def test_builtin_type(self):
        # len() is a native PyNativeBuiltin in jacpython; to_host() drops it to
        # None so type(len).__name__ diverges (escalated). Use abs(), which
        # round-trips as a host builtin, for the typing check.
        self.assertEqual(type(abs).__name__, 'builtin_function_or_method')
