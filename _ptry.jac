def f -> int {
    try {
        z = 1;
    } except Exception {
        z = 2;
    }
    return z;
}

def g -> int {
    try {
        import json;
        q = 5;
    } except ImportError {
        q = 6;
    }
    return q;
}
