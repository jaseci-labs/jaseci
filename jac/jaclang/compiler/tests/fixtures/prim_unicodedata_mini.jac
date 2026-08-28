
import from unicodedata { category, east_asian_width }

def unicodedata_py() -> dict {
    return {"cat_zhong": category("中"), "cat_A": category("A")};
}
def unicodedata_cl() -> dict { return {}; }
def unicodedata_na() -> dict[str, any] {
    return {"cat_zhong": category("中"), "cat_A": category("A")};
}
