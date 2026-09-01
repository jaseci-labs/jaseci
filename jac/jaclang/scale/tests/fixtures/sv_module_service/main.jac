sv import from .services.thing { list_items }

def app -> str {
    return str(list_items());
}
