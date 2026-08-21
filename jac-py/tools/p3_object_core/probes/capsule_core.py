class TestCapsuleCore(unittest.TestCase):
    def test_sys_modules(self):
        import sys
        self.assertTrue(hasattr(sys, 'modules'))
        self.assertIn('sys', sys.modules)

    def test_builtin_type(self):
        self.assertEqual(type(len).__name__, 'builtin_function_or_method')
