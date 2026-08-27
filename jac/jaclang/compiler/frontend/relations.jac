
edge SymOf {}

edge Defines {}

edge Uses {}

edge InScope {}

edge ScopePrimary {
    has alias: str = "";
}

edge ScopeOverload {}

edge ScopeChild {
    has in_kids: bool = True;
}

edge CfgSucc {}

edge CfgTrue {}

edge CfgFalse {}

edge PlacedIn {}

edge DecidedCodespace {}

edge CalleeDecl {}

edge Absorbs {}

edge AttachedComment {}

node Codespace {
    has kind: str = "";
}

glob _CODESPACES: dict[str, Codespace] = {};

def codespace_node(kind: str) -> Codespace {
    found = _CODESPACES.get(kind);
    if found is None {
        found = Codespace(kind=kind);
        _CODESPACES[kind] = found;
    }
    return found;
}
