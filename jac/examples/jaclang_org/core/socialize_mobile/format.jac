glob:pub POST_LIMIT: int = 280;

def:pub display_name(username: str) -> str {
    return username.split("@")[0] if "@" in username else username;
}

def:pub initial_of(name: str) -> str {
    return name[0].upper() if name else "?";
}

def:pub avatar_url(username: str) -> str {
    return "https://i.pravatar.cc/150?u=fake@" + username;
}

def:pub count_label(count: int, one: str, many: str) -> str {
    return str(count) + " " + (one if count == 1 else many);
}

def:pub chars_left(text: str) -> int {
    return POST_LIMIT - len(text);
}
