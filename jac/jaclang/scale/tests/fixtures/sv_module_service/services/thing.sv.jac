node Item {
    has label: str;
}

def :pub list_items -> list[str] {
    return [i.label for i in [root --> (`?Item)]];
}
