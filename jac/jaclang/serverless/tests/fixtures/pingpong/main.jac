walker:pub ping {
    has msg: str = "";

    can go with Root entry {
        report {"pong": self.msg};
    }
}
