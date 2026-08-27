import from collections.abc { Callable }
import from dataclasses { asdict, dataclass, field, fields, is_dataclass }
import from functools { cached_property }
import from inspect { _empty, signature }
import from logging { getLogger }
import from pickle { dumps }
import from threading { Lock }
import from types { UnionType }
import from typing { ClassVar, TypeAlias, TypeVar }
import from uuid { UUID, uuid4 }
import from jaclang.compiler.frontend.constant { EdgeDir }
glob logger = getLogger(__name__),
     TARCH = TypeVar('TARCH', bound='Archetype'),
     TANCH = TypeVar('TANCH', bound='Anchor'),
     T = TypeVar('T');

glob _NO_TRIGGER = object(),
     _subclass_hook_lock = Lock();

enum AccessLevel { NO_ACCESS = -1, READ = 0, CONNECT = 1, WRITE = 2 }

def access_level_cast(val: int | str | AccessLevel) -> AccessLevel {
    if isinstance(val, AccessLevel) {
        return val;
    }
    if isinstance(val, str) {
        val = val.upper();
    }
    _map: dict = {
        -1: AccessLevel.NO_ACCESS,
        0: AccessLevel.READ,
        1: AccessLevel.CONNECT,
        2: AccessLevel.WRITE,
        "NO_ACCESS": AccessLevel.NO_ACCESS,
        "READ": AccessLevel.READ,
        "CONNECT": AccessLevel.CONNECT,
        "WRITE": AccessLevel.WRITE
    };
    return _map[val];
}

obj Access {
    has anchors: dict[(str, AccessLevel)] = field(default_factory=`dict);

    def check(anchor: str) -> (AccessLevel | None);
}

obj Permission {
    has all: AccessLevel = AccessLevel.NO_ACCESS,
        roots: Access = field(default_factory=Access),
        groups: Access = field(default_factory=Access);
}

@dataclass
obj PermissionDenied {
    has operation: str,
        target_id: str,
        target_type: str,
        target_owner: (str | None),
        required: AccessLevel,
        actual: AccessLevel;

    def to_dict -> dict[(str, any)];
    def message -> str;
}

obj AnchorReport {
    has id: str,
        context: dict[(str, any)];
}


"""An anchor is what persistence needs to know about an archetype.

Everything below `archetype` is persistence machinery, and a graph that is
never connected to a root and never reaches a store needs none of it, so none
of it is allocated up front. Every field below it is
`init=False` with a class-level default, which means the dataclass `__init__`
never writes it into the instance dict: a transient `NodeAnchor` is exactly
`{archetype, edges}`, and a field only starts costing a dict slot once
something assigns it. `access` is `None` -- not a shared
default object -- until someone grants something, so an anchor that has been
granted nothing does not allocate a `Permission` and two `Access` objects, and
no amount of `anchor.access.all = ...` can silently rewrite the grants of every
other anchor in the process. Writers go through `own_access`, which materializes
this anchor's own `Permission` the first time it is needed.

`id` in particular stays `None` until something actually needs a store key:
`ensure_id` mints it, and `Session.put`, `save`, `make_stub` and the
serializer -- every door into persistence -- call it. Until then an anchor is
identified by object identity, which is what `__hash__` and `__eq__` fall back
to and what the sv driver keys its registries by.
"""
obj Anchor {
    has archetype: Archetype,
        id: (UUID | None) = field(`init=False, default=None),
        `root: (UUID | None) = field(`init=False, default=None),
        access: (Permission | None) = field(`init=False, default=None),
        persistent: bool = field(`init=False, default=False),
        hash: int = field(`init=False, default=0);

    def ensure_id -> UUID;
    def own_access -> Permission;
    def is_populated -> bool;
    def make_stub -> TANCH;
    def populate -> None;
    def __getattr__(name: str) -> object;
    def __getstate__ -> dict[(str, any)];
    def __setstate__(state: dict[(str, any)]) -> None;
    def __repr__ -> str;
    def `report -> AnchorReport;
    def __hash__ -> int;
    def __eq__(other: object) -> bool;
}

obj NodeAnchor(Anchor) {
    has archetype: NodeArchetype,
        edges: list[EdgeAnchor],
        version: int = field(`init=False, default=0);

    def __getstate__ -> dict[(str, object)];
    def is_populated -> bool;
    def edge_delta -> (tuple[(set[UUID], set[UUID])] | None);
    def remove_edge(`edge: EdgeAnchor) -> None;
}

obj EdgeAnchor(Anchor) {
    has archetype: EdgeArchetype,
        source: NodeAnchor,
        target: NodeAnchor,
        is_undirected: bool;

    def is_populated -> bool;
    def __getstate__ -> dict[(str, object)];
    def detach -> None;
}

obj WalkerAnchor(Anchor) {
    has archetype: WalkerArchetype,
        path: list[(NodeAnchor | EdgeAnchor)] = field(default_factory=`list),
        next: list[(NodeAnchor | EdgeAnchor)] = field(default_factory=`list),
        ignores: list[NodeAnchor] = field(default_factory=`list),
        disengaged: bool = False;
}

obj ObjectAnchor(Anchor) {
    has archetype: ObjectArchetype;
}

"""Do two anchor references denote the same anchor?

Object identity alone is not enough: a persisted anchor can be present as both
a stub and the populated record. The store key alone is not enough either: a
transient anchor does not have one. So identity first, key second.
"""
def same_anchor(a: (Anchor | None), b: (Anchor | None)) -> bool {
    if a is b {
        return True;
    }
    if a is None or b is None {
        return False;
    }
    aid = a.id;
    return aid is not None and aid == b.id;
}

"""What identifies an anchor to a keyed collection.

The store key while the anchor has one, its object identity while it does not.
The two never collide: a `UUID` never compares equal to an `int`.
"""
def anchor_key(anchor: Anchor) -> any {
    aid = anchor.id;
    return aid if aid is not None else id(anchor);
}

obj Archetype {
    with entry {
        _jac_entry_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
        _jac_exit_funcs_: ClassVar[list[ObjectSpatialFunction]] = [];
        _subclass_hooks: ClassVar[tuple[Callable[[type], None], ...]] = ();
    }

    @cached_property
    def __jac__ -> Anchor;

    def __init_subclass__(cls: any, **kwargs: object) -> None;
    static def install_subclass_hook(hook: Callable[[type], None]) -> None;
    static def uninstall_subclass_hook(hook: Callable[[type], None]) -> None;
    static def _subclass_tree -> list[type];
    def postinit -> None;
    def __setattr__(name: str, value: any) -> None;
    def __repr__ -> str;
    def __jac_access__ -> (AccessLevel | str | int | None);
}

class NodeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: NodeArchetype) -> NodeAnchor {
        return NodeAnchor(archetype=self, edges=[]);
    }
}

class EdgeArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
        __jac__: EdgeAnchor;
    }
}

class WalkerArchetype(Archetype) {
    with entry {
        __jac_async__: ClassVar[bool] = False;
        __jac_base__: ClassVar[bool] = True;
        reports: list[any] = field(default_factory=`list);
    }

    @cached_property
    def __jac__(self: WalkerArchetype) -> WalkerAnchor {
        return WalkerAnchor(archetype=self);
    }
}

class ObjectArchetype(Archetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__(self: ObjectArchetype) -> ObjectAnchor {
        return ObjectAnchor(archetype=self);
    }
}

obj GenericEdge(EdgeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    def __repr__ -> str;
}

obj Root(NodeArchetype) {
    with entry {
        __jac_base__: ClassVar[bool] = True;
    }

    @cached_property
    def __jac__ -> NodeAnchor;

    def __getattr__(name: str) -> Root;
    def __repr__ -> str;
}

obj ObjectSpatialFunction {
    has name: str,
        func: Callable[([any, any], any)],
        trigger_override: any = _NO_TRIGGER;

    @cached_property
    def trigger -> (type | UnionType | tuple[((type | UnionType), ...)] | None);
}

obj JsxElement {
    has tag: object,
        `props: dict[(str, object)],
        children: list;
}
