# A representative of the 116 subscript `del` sites in the tree. Every one of
# them used to emit a pointless `destroy()` alongside the `__delitem__`.
import sys;

def evict(key: str) {
    del sys.modules[key];
}

def evict_many(keys: list[str], cache: dict[str, int]) {
    for key in keys {
        del cache[key];
    }
}
