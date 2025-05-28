# 1:  This does not have any type error/warning
enum Colorenum {
    RED,
    GREEN,
    BLUE
}

obj Colour1 {
    has color1: Colorenum,
        point1: int;

    def get_color -> Colorenum{
        return self.color1;
    }
    def get_color1 -> Colorenum;
}

impl Colour1.get_color1 -> Colorenum {
    return self.color1;
}

