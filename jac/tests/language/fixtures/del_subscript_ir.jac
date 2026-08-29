# A representative of the subscript `del` sites in the tree whose container
# type can never hold a graph object. The peek and the destroy are elided, so
# every one of them lowers to the bare Python statement.
def evict(cache: dict[str, int], key: str) {
    del cache[key];
}

def evict_many(keys: list[str], cache: dict[str, int]) {
    for key in keys {
        del cache[key];
    }
}

def trim(items: list[int]) {
    del items[0];
    del items[1:3];
}
