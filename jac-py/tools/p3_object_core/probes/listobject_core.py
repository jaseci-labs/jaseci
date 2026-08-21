class TestListCore(unittest.TestCase):
    def test_list_richcompare(self):
        self.assertEqual([1, 2], [1, 2])
        self.assertLess([1], [1, 2])
        self.assertNotEqual([1, 2], [2, 1])

    def test_list_repr(self):
        self.assertEqual(repr([]), '[]')
        self.assertEqual(repr([1, 2]), '[1, 2]')
