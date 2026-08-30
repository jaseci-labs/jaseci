import from collections.abc { Callable }
import from dataclasses { asdict, dataclass, field, fields, is_dataclass }
import from functools { cached_property }
import from inspect { _empty, signature }
import from logging { getLogger }
import from pickle { dumps }
import from threading { Lock }
import from types { UnionType }
import from typing { ClassVar, TypeVar }
import from uuid { UUID, uuid4 }
import from jaclang.compiler.frontend.constant { EdgeDir }
glob logger = getLogger(__name__),
     TARCH = TypeVar('TARCH', bound='Archetype'),
     TANCH = TypeVar('TANCH', bound='Anchor'),
     T = TypeVar('T');

glob _NO_TRIGGER = object(),
     _subclass_hook_lock = Lock();

glob _light_edge_types: dict[type, bool] = {},
     _tracked_classes: dict[type, type] = {};

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


obj Anchor {
    has archetype: Archetype,
        id: (UUID | None) = field(`init=False, `default=None),
        `root: (UUID | None) = field(`init=False, `default=None),
        access: (Permission | None) = field(`init=False, `default=None),
        _persistent: bool = field(`init=False, `default=False),
        destroyed: bool = field(`init=False, `default=False),
        hash: int = field(`init=False, `default=0);

    has persistent: bool { getter; setter(persistent: bool); }

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
        version: int = field(`init=False, `default=0),
        mixed: bool = field(`init=False, `default=False);

    def __getstate__ -> dict[(str, object)];
    def __setstate__(state: dict[(str, object)]) -> None;
    def is_populated -> bool;
    def edge_delta -> (tuple[(set[UUID], set[UUID])] | None);
    def remove_edge(`edge: EdgeAnchor) -> None;
    def all_edges -> list[EdgeAnchor];
    def has_heavy_edges -> bool;
    def detach_light -> None;
}

obj EdgeAnchor(Anchor) {
    has archetype: EdgeArchetype,
        source: NodeAnchor,
        target: NodeAnchor,
        is_undirected: bool,
        light: bool = field(`init=False, `default=False);

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

    def __eq__(other: object) -> bool {
        if self is other {
            return True;
        }
        mine = self.__dict__.get('__jac__');
        theirs = other.__dict__.get('__jac__')
            if isinstance(other, EdgeArchetype)
            else None;
        if mine is None or theirs is None or not (mine.light and theirs.light) {
            return False;
        }
        return (
            `type(self) is `type(other)
            and mine.source is theirs.source
            and mine.target is theirs.target
        );
    }

    def __hash__ -> int {
        mine = self.__dict__.get('__jac__');
        if mine is not None and mine.light {
            return hash((`type(self), id(mine.source), id(mine.target)));
        }
        return id(self);
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


def is_light_edge_type(cls: type) -> bool {
    known = _light_edge_types.get(cls);
    if known is not None {
        return known;
    }
    light = isinstance(cls, `type) and issubclass(cls, EdgeArchetype);
    if light and is_dataclass(cls) {
        for f in fields(cls) {
            light = False;
            break;
        }
    }
    _light_edge_types[cls] = light;
    return light;
}

glob _light_reg: set = set();

def _light_tag(cls: type) -> any {
    if cls not in _light_reg {
        import from jaclang.runtime.osp_graph { osp_register_type }
        bases: list = [];
        for c in cls.__mro__[1:] {
            if c is not object {
                bases.append(c);
            }
        }
        t: any = cls;
        osp_register_type(t, bases);
        _light_reg.add(cls);
    }
    return cls;
}

def _light_pairs_of(anchor: NodeAnchor, outgoing: bool) -> list {
    import from jaclang.runtime.osp_graph { osp_light_pairs }
    me: any = anchor.archetype;
    return osp_light_pairs(me, 1 if outgoing else 0);
}

def light_connect(src: NodeAnchor, cls: type, tgt: NodeAnchor) {
    import from jaclang.runtime.osp_graph { osp_conn_light }
    sh: any = src.archetype;
    th: any = tgt.archetype;
    osp_conn_light(sh, th, _light_tag(cls), 0);
}

def light_disconnect(src: NodeAnchor, cls: type, tgt: NodeAnchor) -> bool {
    import from jaclang.runtime.osp_graph { osp_light_remove }
    sh: any = src.archetype;
    th: any = tgt.archetype;
    return osp_light_remove(sh, th, _light_tag(cls)) != 0;
}

def _light_clear_pairs(
    anchor: NodeAnchor, cls: (type | None), outgoing: bool, exact: bool
) -> bool {
    import from jaclang.runtime.osp_graph { osp_light_remove }
    me: any = anchor.archetype;
    pairs = _light_pairs_of(anchor, outgoing);
    hit = False;
    i = 0;
    while i < len(pairs) {
        k = pairs[i];
        other = pairs[i + 1];
        i += 2;
        if cls is not None {
            if exact {
                if k is not cls {
                    continue;
                }
            } elif not issubclass(k, cls) {
                continue;
            }
        }
        removed = osp_light_remove(me, other, k)
            if outgoing
            else osp_light_remove(other, me, k);
        if removed != 0 {
            hit = True;
        }
    }
    return hit;
}

def light_clear(anchor: NodeAnchor, cls: type, outgoing: bool = True) -> bool {
    return _light_clear_pairs(anchor, cls, outgoing, True);
}

def light_clear_matching(
    anchor: NodeAnchor, cls: (type | None), outgoing: bool
) -> bool {
    return _light_clear_pairs(anchor, cls, outgoing, False);
}

def light_out(anchor: NodeAnchor, cls: (type | None)) -> list {
    return light_hop(anchor, 2, cls, False);
}

def light_in(anchor: NodeAnchor, cls: (type | None)) -> list {
    return light_hop(anchor, 1, cls, False);
}

def light_hop(
    anchor: NodeAnchor, dir: int, cls: (type | None), edges_only: bool
) -> list {
    if edges_only {
        out: list = [];
        if dir != 1 {
            for ea in light_edge_views(anchor, cls, True) {
                out.append(ea.archetype);
            }
        }
        if dir != 2 {
            for ea in light_edge_views(anchor, cls, False) {
                out.append(ea.archetype);
            }
        }
        return out;
    }
    import from jaclang.runtime.osp_graph { DEFAULT_GRAPH }
    me: any = anchor.archetype;
    tag: any = _light_tag(cls) if cls is not None else -1;
    return DEFAULT_GRAPH.refs(me, dir, tag, False);
}

def light_hop_answers(anchor: NodeAnchor, cls: (type | None)) -> bool {
    if anchor.persistent {
        return False;
    }
    if not anchor.has_heavy_edges() {
        return True;
    }
    return cls is not None and not anchor.mixed and is_light_edge_type(cls);
}

def light_clear_hop(anchor: NodeAnchor, dir: int, cls: (type | None)) -> bool {
    hit = False;
    if dir != 1 and light_clear_matching(anchor, cls, True) {
        hit = True;
    }
    if dir != 2 and light_clear_matching(anchor, cls, False) {
        hit = True;
    }
    return hit;
}

def light_edge_view(
    cls: type[EdgeArchetype], src: NodeAnchor, tgt: NodeAnchor
) -> EdgeArchetype {
    e = cls.__new__(cls);
    ea = EdgeAnchor(archetype=e, source=src, target=tgt, is_undirected=False);
    ea.light = True;
    e.__jac__ = ea;
    return e;
}

def light_edge_views(
    anchor: NodeAnchor, cls: (type | None), outgoing: bool
) -> list[EdgeAnchor] {
    out: list[EdgeAnchor] = [];
    pairs = _light_pairs_of(anchor, outgoing);
    i = 0;
    while i < len(pairs) {
        k = pairs[i];
        other = pairs[i + 1];
        i += 2;
        if cls is not None and not issubclass(k, cls) {
            continue;
        }
        oa = other.__jac__;
        e = light_edge_view(k, anchor, oa)
            if outgoing
            else light_edge_view(k, oa, anchor);
        out.append(e.__jac__);
    }
    return out;
}

def _dirty_setattr(self: any, name: str, value: any) -> None {
    object.__setattr__(self, name, value);
    an = self.__dict__.get('__jac__');
    if an is None or not an.persistent {
        return;
    }
    import from jaclang.runtime.runtime { JacRuntime }
    ctx = JacRuntime.exec_ctx;
    if ctx is not None {
        md = ctx.mem?.mark_dirty;
        if md is not None {
            md(an);
        }
    }
}

def untracked_class(cls: type[Archetype]) -> type[Archetype] {
    return cls.__dict__.get('__jac_untracked__', cls);
}

def _untracked_new(cls: type[Archetype]) -> Archetype {
    return object.__new__(cls);
}

def _tracked_reduce_ex(self: any, protocol: int) -> tuple {
    return (_untracked_new, (untracked_class(`type(self)), ), self.__dict__);
}

def track_writes(arch: Archetype) -> None {
    cls = `type(arch);
    if cls.__dict__.get('__jac_tracked__', False) {
        return;
    }
    tracked = _tracked_classes.get(cls);
    if tracked is None {
        tracked = `type(
            cls.__name__,
            (cls, ),
            {
                '__module__': cls.__module__,
                '__qualname__': cls.__qualname__,
                '__jac_base__': True,
                '__jac_tracked__': True,
                '__jac_untracked__': cls,
                '__setattr__': _dirty_setattr,
                '__reduce_ex__': _tracked_reduce_ex
            }
        );
        _tracked_classes[cls] = tracked;
    }
    object.__setattr__(arch, '__class__', tracked);
}
