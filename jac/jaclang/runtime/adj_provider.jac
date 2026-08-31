obj AdjProviderSlot {
    has provider: any = None;
}

obj _Unhandled {}

glob SLOT: AdjProviderSlot = AdjProviderSlot(),
     UNHANDLED: _Unhandled = _Unhandled();

def install_adjacency_provider(p: any) -> None {
    SLOT.provider = p;
}

def adj_provider -> any {
    return SLOT.provider;
}
