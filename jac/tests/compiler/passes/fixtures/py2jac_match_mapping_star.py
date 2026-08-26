def handle(d):
    match d:
        case {"k": key, **rest}:
            return key, rest
        case {1: first, **others}:
            return first, others
    return None
