impl JScaleExecutionContext.init(self: JScaleExecutionContext) -> None {
    import from jaclang.scale.memory.memory_hierarchy {
        ScaleTieredMemory,
        _process_cache
    }
    import from jaclang.jac0core.constructs {
        Anchor,
        NodeAnchor,
        PermissionDenied,
        Root
    }

    self.mem = ScaleTieredMemory();
    self.reports: list[any] = [];
    self.diagnostics: list[PermissionDenied] = [];
    self.pending_effects = [];
    self.read_versions = {};
    self.custom: any = MISSING;
    topology_index_enabled = False;
    try {
        import os;
        env = os.environ.get("JAC_TOPOLOGY_INDEX");
        if env is not None {
            topology_index_enabled = env.lower() in ("1", "true", "yes", "on");
        } else {
            import from jaclang.project.config { get_config }
            cfg = get_config();
            topology_index_enabled = cfg is not None and cfg.run.topology_index;
        }
    } except Exception { }
    if topology_index_enabled {
        _process_cache.pop('system_root', None);
    } else {
        cached_root = _process_cache.get('system_root');
        if cached_root is not None {
            self.mem.__mem__[cached_root.id] = cached_root;
        }
    }
    system_root_anchor: (Anchor | None) = self.mem.get(UUID(Con.SUPER_ROOT_UUID));
    if not isinstance(system_root_anchor, NodeAnchor) {
        system_root_anchor = Root().__jac__;
        system_root_anchor.id = UUID(Con.SUPER_ROOT_UUID);
        self.mem.put(system_root_anchor);
    }
    if not topology_index_enabled {
        _process_cache['system_root'] = system_root_anchor;
    }
    self.system_root = system_root_anchor;

    self.user_root = self.system_root;
    self.entry_node = self.system_root;
    self.call_state: ContextVar[CallState] = ContextVar('call_state');
}
