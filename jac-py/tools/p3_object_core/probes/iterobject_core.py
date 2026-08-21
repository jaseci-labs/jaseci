class TestIterCore(unittest.TestCase):
    def test_iter_list(self):
        it = iter([1, 2, 3])
        self.assertEqual(next(it), 1)
        self.assertEqual(next(it), 2)
        self.assertEqual(list(it), [3])

    def test_iter_stop(self):
        it = iter([])
        with self.assertRaises(StopIteration):
            next(it)
