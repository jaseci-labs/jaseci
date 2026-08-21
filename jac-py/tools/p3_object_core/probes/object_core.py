class TestObjectCore(unittest.TestCase):
    def test_object_identity(self):
        a = object()
        self.assertIs(a, a)
        self.assertIsNot(a, object())

    def test_object_eq(self):
        a = object()
        self.assertTrue(a == a)
        self.assertFalse(a == object())
