class TestRangeCore(unittest.TestCase):
    def test_range_len(self):
        self.assertEqual(len(range(5)), 5)
        self.assertEqual(len(range(1, 10, 2)), 5)

    def test_range_contains(self):
        self.assertTrue(3 in range(5))
        self.assertFalse(5 in range(5))

    def test_range_eq(self):
        self.assertEqual(range(3), range(0, 3))
