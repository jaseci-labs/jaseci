def stable_osp_tag(name: str) -> int {
    _h = 14695981039346656037;
    for _c in name {
        _h = ((_h ^ ord(_c)) * 1099511628211) & 18446744073709551615;
    }
    return _h & 9007199254740991;
}
