edge SymOf {}

edge Defines {}

edge Uses {}

edge InScope {}

edge ScopePrimary {}

edge ScopeOverload {}

edge ScopeChild {}

edge ScopeParent {}

edge CfgSucc {}

edge CfgTrue {}

edge CfgFalse {}

edge PlacedIn {}

edge DecidedCodespace {}

edge CalleeDecl {}

edge Absorbs {}

node Codespace {
    has kind: str = "";
}

glob _CODESPACES: dict[str, Codespace] = {
         "server": Codespace(kind="server"),
         "client": Codespace(kind="client"),
         "native": Codespace(kind="native")
     };

def codespace_node(kind: str) -> Codespace {
    found = _CODESPACES.get(kind);
    if found is None {
        found = Codespace(kind=kind);
        _CODESPACES[kind] = found;
    }
    return found;
}

edge TypeOf {}

edge NarrowedTypeOf {}

edge EventTriggerOf {}

edge SharedOf {}

edge PrivOf {}

edge BaseOf {}

edge MroOf {}

edge TypeParamOf {}

edge TypeArgOf {}

edge ParamOf {}

edge ReturnsOf {}

edge GuardOf {}

edge ParamTypeOf {}

edge ParamDefaultOf {}

edge UnionMemberOf {}

edge BoundOf {}

edge ConstraintOf {}

edge OverloadOf {}

edge EnumClassOf {}

edge ValueTypeOf {}

edge MemberInfoOf {}

edge TypeMemberOf {
    has name: str = "";
}

edge EnumMemberOf {
    has name: str = "";
}

edge DeclScopeOf {}
