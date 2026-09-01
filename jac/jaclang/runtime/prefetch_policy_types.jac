"""Shared types and helpers for prefetch prediction policies."""

import from uuid { UUID }

obj PrefetchPlanRequest {
    has policy: str = "",
        warch: any = None,
        start_anchor: any = None,
        start_id: UUID | None = None,
        mem: any = None,
        max_length: int = 200,
        config: any = None;
}

obj PrefetchPlanResult {
    has ids: list[UUID] = [],
        topology_ms: float = 0.0,
        plan_ms: float = 0.0,
        resolve_ms: float = 0.0,
        single_query: bool = False;
}

def prefetch_walker_keys(warch: any) -> list[str] {
    if warch is None {
        return ["None"];
    }
    cls = `type(warch);
    simple = getattr(cls, "__name__", str(cls));
    module = getattr(cls, "__module__", "");
    if module {
        return [f"{module}.{simple}", simple];
    }
    return [simple];
}

def dedupe_cap_uuid_list(ids: list, max_length: int) -> list[UUID] {
    if max_length <= 0 {
        return [];
    }
    out: list[UUID] = [];
    seen: set[UUID] = set();
    for raw in ids {
        try {
            uid = raw if isinstance(raw, UUID) else UUID(str(raw));
        } except Exception {
            continue;
        }
        if uid in seen {
            continue;
        }
        seen.add(uid);
        out.append(uid);
        if len(out) >= max_length {
            break;
        }
    }
    return out;
}
