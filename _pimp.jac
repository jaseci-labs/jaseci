with entry {
    try {
        import json;
    } except ImportError {
        json = None;
    }
}

def use -> str {
    if json is None {
        raise ImportError("no json");
    }
    return json.dumps({});
}
