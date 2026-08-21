class TestDescrCore(unittest.TestCase):
    def test_classmethod_binds_class(self):
        class C:
            @classmethod
            def f(cls):
                return cls

        self.assertIs(C.f(), C)
        self.assertIs(C().f(), C)

    def test_staticmethod_no_bind(self):
        class C:
            @staticmethod
            def f():
                return 42

        self.assertEqual(C.f(), 42)
        self.assertEqual(C().f(), 42)

    def test_property_getter(self):
        class C:
            @property
            def x(self):
                return 7

        c = C()
        self.assertEqual(c.x, 7)

    def test_property_setter(self):
        class C:
            @property
            def x(self):
                return self._x

            @x.setter
            def x(self, v):
                self._x = v

        c = C()
        c.x = 3
        self.assertEqual(c.x, 3)
