"""Root-level route ownership, learned from each service's own OpenAPI document.

A service's path set is app-defined: `@restspec(path=...)` puts a walker or
function anywhere, so no fixed list of segments can describe it. The gateway
therefore asks each service what it serves instead of guessing.
"""

import logging;
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceStatus
}

glob _rt_logger = logging.getLogger(__name__);


"""The literal head of an OpenAPI path template: /api/items/{id} -> /api/items."""
def literal_prefix(template: str) -> str {
    kept: list[str] = [];
    for segment in template.strip("/").split("/") {
        if not segment or "{" in segment or "*" in segment {
            break;
        }
        kept.append(segment);
    }
    if not kept {
        return "";
    }
    return "/" + "/".join(kept);
}


obj ServiceRouteTable {
    has _owner_of: dict[str, str] = {},
        _by_length: list[tuple[str, str]] = [];

    def learn(service_name: str, templates: list[str]) -> list[str];
    def forget(service_name: str) -> None;
    def owner(path: str) -> str;
    def prefixes -> dict[str, str];
    def _reindex -> None;
}


"""Refresh `table` from every reachable service; returns the number learned."""
async def learn_service_routes(
    registry: ServiceRegistry, table: ServiceRouteTable
) -> int {
    import from jaclang.scale.runtime.gateway.openapi_agg { fetch_service_spec }

    learned: int = 0;
    for (name, service_entry) in registry.entries.items() {
        if service_entry.status
            not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING) {
            continue;
        }
        if not service_entry.url {
            continue;
        }
        doc = await fetch_service_spec(service_entry);
        if doc is None {
            continue;
        }
        clashes = table.learn(name, list((doc.get("paths") or {}).keys()));
        learned += 1;
        if clashes {
            _rt_logger.warning(
                f"service '{name}' declares {clashes}, already claimed by another "
                f"service; reach them under '{service_entry.prefix}' instead"
            );
        }
    }
    return learned;
}
