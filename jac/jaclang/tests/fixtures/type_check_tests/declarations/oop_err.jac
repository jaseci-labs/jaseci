enum ShapeType {
    CIRCLE = "Circle",
    UNKNOWN = "Unknown"
}

obj Shape {
    has shape_type: ShapeType;
}

obj Circle(Shape) {
    def init(radius: float) {
        super.init("qwe");
        self.added = False;
    }

    def b() {
        print(self.kk);
    }
}

with entry{
    c = Circle("asd");
    c.added = 99;
    c.kk = 9;
    Circle.b();
}