impl TypeEvaluator._get_ts_declared_item_type(
    from_loc: uni.ModulePath, item_name: str
) -> (TypeBase | None) {
    if from_loc.string_path_value is None {
        return None;
    }
    if not from_loc.in_client_context() {
        return None;
    }
    mod_path = from_loc.loc.mod_path if from_loc.loc else None;
    if not mod_path {
        return None;
    }
    spec = from_loc.path[0].lit_value;
    if not isinstance(spec, str) or not spec {
        return None;
    }

    cache_key = spec + "\n" + mod_path;
    if cache_key in self._ts_decl_path_cache {
        dts_path = self._ts_decl_path_cache[cache_key];
    } else {
        import from jaclang.jac0core.modresolver {
            resolve_client_npm_declarations,
            sibling_declaration_file
        }
        dts_path: (str | None) = None;
        try {
            if spec.startswith('.') {
                js_path = from_loc.resolve_relative_path();
                if js_path {
                    dts_path = sibling_declaration_file(js_path);
                }
            } else {
                base = self._client_npm_base(spec, mod_path);
                if base is not None {
                    dts_path = resolve_client_npm_declarations(spec, base);
                }
            }
        } except Exception {
            dts_path = None;
        }
        self._ts_decl_path_cache[cache_key] = dts_path;
    }
    if dts_path is None {
        return None;
    }
    return self._ts_declared_type_from_file(dts_path, item_name);
}

impl TypeEvaluator._ts_declared_type_from_file(
    dts_path: str, item_name: str
) -> (TypeBase | None) {
    decls = self._load_ts_declarations(dts_path);
    if not decls {
        return None;
    }
    decl = decls.get(item_name);
    if decl is None {
        return None;
    }
    return self._map_ts_decl(decl, decls, item_name);
}

impl TypeEvaluator._load_ts_declarations(dts_path: str) -> (dict[str, TsDecl] | None) {
    if dts_path in self._ts_decl_cache {
        return self._ts_decl_cache[dts_path];
    }
    import from jaclang.compiler.type_system.ts_decl_parser { parse_dts }
    decls: (dict[str, TsDecl] | None) = None;
    try {
        with open(dts_path, 'r', encoding='utf-8', errors='replace') as f {
            source = f.read();
        }
        decls = parse_dts(source);
    } except Exception {
        decls = None;
    }
    self._ts_decl_cache[dts_path] = decls;
    return decls;
}

impl TypeEvaluator._map_ts_decl(
    decl: TsDecl, decls: dict[str, TsDecl], item_name: str
) -> (TypeBase | None) {
    if decl.kind == TsDeclKind.FUNCTION and decl.ty is not None {
        mapped = self._map_ts_type(decl.ty, decls);
        if isinstance(mapped, types.FunctionType) {
            mapped.func_name = item_name;
        }
        return mapped;
    }
    if (
        decl.kind in (TsDeclKind.CONST, TsDeclKind.TYPEALIAS) and decl.ty is not None
    ) {
        return self._map_ts_type(decl.ty, decls);
    }
    if decl.kind in (TsDeclKind.INTERFACE, TsDeclKind.CLASS) {
        synth = self._synthesize_ts_decl_class(decls, item_name);
        if synth is not None {
            return synth;
        }
    }
    return types.AnyType(is_foreign=True);
}

impl TypeEvaluator._map_ts_type(
    ts: (TsType | None),
    decls: dict[str, TsDecl],
    seen: (set[str] | None) = None,
    shells: (dict[str, types.ClassType] | None) = None
) -> TypeBase {
    foreign_any = types.AnyType(is_foreign=True);
    if ts is None or self.prefetch is None {
        return foreign_any;
    }
    k = ts.kind;
    if k == TsTypeKind.ANY {
        return foreign_any;
    }
    if k == TsTypeKind.NEVER {
        return types.NeverType();
    }
    if k == TsTypeKind.VOID {
        return self._convert_to_instance(self.get_none_type());
    }
    if k == TsTypeKind.PRIM {
        prim_cls = {
            'string': self.prefetch.str_class,
            'number': self.prefetch.float_class,
            'boolean': self.prefetch.bool_class,
            'object': self.prefetch.object_class,
            'symbol': self.prefetch.object_class,
            'bigint': self.prefetch.int_class,

        }.get(
            ts.name
        );
        if prim_cls is None {
            return foreign_any;
        }
        return self._convert_to_instance(prim_cls);
    }
    if (k == TsTypeKind.LITERAL_STR and self.prefetch.str_class) {
        return self._convert_to_instance(
            self.prefetch.str_class.clone_with_literal(ts.name)
        );
    }
    if k == TsTypeKind.LITERAL_NUM {
        int_val: (int | None) = None;
        try {
            int_val = int(ts.name);
        } except ValueError { }
        if (int_val is not None and self.prefetch.int_class) {
            return self._convert_to_instance(
                self.prefetch.int_class.clone_with_literal(int_val)
            );
        }
        if self.prefetch.float_class {
            return self._convert_to_instance(self.prefetch.float_class);
        }
        return foreign_any;
    }
    if (k == TsTypeKind.LITERAL_BOOL and self.prefetch.bool_class) {
        return self._convert_to_instance(
            self.prefetch.bool_class.clone_with_literal(ts.name == 'true')
        );
    }
    if k == TsTypeKind.UNION {
        return types.UnionType(
            types=[self._map_ts_type(m, decls, seen, shells) for m in ts.args]
        );
    }
    if (k in (TsTypeKind.ARRAY, TsTypeKind.TUPLE) and self.prefetch.list_class) {
        elem: TypeBase = foreign_any;
        if k == TsTypeKind.ARRAY and ts.args {
            elem = self._map_ts_type(ts.args[0], decls, seen, shells);
        } elif (k == TsTypeKind.TUPLE and ts.args) {
            mapped = [self._map_ts_type(a, decls, seen, shells) for a in ts.args];
            elem = mapped[0] if len(mapped) == 1 else types.UnionType(types=mapped);
        }
        lst = self.prefetch.list_class.clone_as_instance();
        lst.private.type_args = [elem];
        return lst;
    }
    if k == TsTypeKind.FUNC {
        parameters: list[types.Parameter] = [];
        for (idx, p) in enumerate(ts.params) {
            if p.rest {
                elem_ty: TypeBase = types.AnyType(is_foreign=True);
                if (p.ty is not None and p.ty.kind == TsTypeKind.ARRAY and p.ty.args) {
                    elem_ty = self._map_ts_type(p.ty.args[0], decls, seen, shells);
                }
                parameters.append(
                    types.Parameter(
                        name=p.name or f"p{idx}",
                        category=types.ParameterCategory.ArgsList,
                        param_type=elem_ty,
                        param_kind=types.ParamKind.VARARG,
                    )
                );
                continue;
            }
            parameters.append(
                types.Parameter(
                    name=p.name or f"p{idx}",
                    category=types.ParameterCategory.Positional,
                    param_type=self._map_ts_type(p.ty, decls, seen, shells)
                        if p.ty is not None
                        else types.AnyType(is_foreign=True),
                    has_default=p.optional,
                )
            );
        }
        ret: TypeBase = types.AnyType(is_foreign=True);
        if ts.ret is not None {
            ret = self._map_ts_type(ts.ret, decls, seen, shells);
        }
        return types.FunctionType(func_name='', return_type=ret, parameters=parameters);
    }
    if k == TsTypeKind.REF {
        if seen is None {
            seen = set();
        }
        if ts.name in seen {
            return foreign_any;
        }
        target = decls.get(ts.name);
        if (
            target is not None
            and target.kind == TsDeclKind.TYPEALIAS
            and target.ty is not None
        ) {
            seen.add(ts.name);
            return self._map_ts_type(target.ty, decls, seen, shells);
        }
        if target is not None
        and target.kind in (TsDeclKind.INTERFACE, TsDeclKind.CLASS) {
            if shells is not None and ts.name in shells {
                return self._convert_to_instance(shells[ts.name]);
            }
            synth = self._synthesize_ts_decl_class(decls, ts.name);
            if synth is not None {
                return self._convert_to_instance(synth);
            }
        }
        return foreign_any;
    }
    return foreign_any;
}

impl TypeEvaluator._ts_synth_class_types(
    decls: dict[str, TsDecl]
) -> (dict[str, types.ClassType] | None) {
    key = id(decls);
    if key in self._ts_synth_class_cache {
        return self._ts_synth_class_cache[key];
    }
    self._ts_synth_class_cache[key] = None;

    synth_src = uni.Source('', '<ts-synth>');

    shells: dict[str, types.ClassType] = {};
    for (name, decl) in decls.items() {
        if (
            decl.kind not in (TsDeclKind.INTERFACE, TsDeclKind.CLASS)
            or not name.isidentifier()
        ) {
            continue;
        }
        shells[name] = types.ClassType(
            _shared=types.ClassType.ClassDetailsShared(
                class_name=name, symbol_table=uni.Module.make_stub(inject_name=name),
            ),
            flags=types.TypeFlags.Instantiable,
        );
    }
    if not shells {
        return None;
    }

    direct_bases: dict[str, list[str]] = {};
    for (name, decl) in decls.items() {
        if name not in shells {
            continue;
        }
        picked: list[str] = [];
        seen: set[str] = set();
        for b in decl.heritage {
            if b != name and b in shells and b not in seen {
                seen.add(b);
                picked.append(b);
            }
        }
        direct_bases[name] = picked;
    }
    WHITE = 0;
    GRAY = 1;
    BLACK = 2;
    color: dict[str, int] = {n: WHITE for n in shells};
    back_edges: set[tuple[(str, str)]] = set();
    for start in shells {
        if color[start] != WHITE {
            continue;
        }
        color[start] = GRAY;
        stack: list[tuple[(str, int)]] = [(start, 0)];
        while stack {
            top = stack[-1];
            cur = top[0];
            idx = top[1];
            nbrs = direct_bases.get(cur, []);
            if idx < len(nbrs) {
                stack[-1] = (cur, idx + 1);
                v = nbrs[idx];
                cv = color[v];
                if cv == GRAY {
                    back_edges.add((cur, v));
                } elif cv == WHITE {
                    color[v] = GRAY;
                    stack.append((v, 0));
                }
            } else {
                stack.pop();
                color[cur] = BLACK;
            }
        }
    }

    for (name, decl) in decls.items() {
        cls_type = shells.get(name);
        if cls_type is None {
            continue;
        }
        scope = cls_type.shared.symbol_table;

        kept_by_name: dict[str, list[TsMember]] = {};
        for m in decl.members {
            if (not m.name or not m.name.isidentifier()) {
                continue;
            }
            if m.is_static or m.access in (TsAccess.PRIVATE, TsAccess.PROTECTED) {
                continue;
            }
            kept_by_name.setdefault(m.name, []).append(m);
        }
        for (mname, group) in kept_by_name.items() {
            if len(group) > 1 {
                member_type = types.AnyType(is_foreign=True);
            } else {
                m = group[0];
                member_type = self._map_ts_type(m.ty, decls, None, shells);
                if m.optional {
                    member_type = types.UnionType(
                        types=[
                            member_type,
                            self._convert_to_instance(self.get_none_type())
                        ]
                    );
                }
            }
            self._install_synth_member(scope, synth_src, mname, member_type);
        }
        if decl.call_sig is not None {
            self._install_synth_member(
                scope,
                synth_src,
                "__call__",
                self._map_ts_type(decl.call_sig, decls, None, shells)
            );
        }
        base_classes: list[types.TypeBase] = [];
        for b in direct_bases.get(name, []) {
            if (name, b) in back_edges {
                continue;
            }
            base = shells.get(b);
            if base is not None {
                base_classes.append(base);
            }
        }
        if not base_classes and self.prefetch and self.prefetch.object_class {
            base_classes.append(self.prefetch.object_class);
        }
        cls_type.shared.base_classes = base_classes;
    }

    for cls_type in shells.values() {
        type_utils.compute_mro_linearization(cls_type);
    }

    self._ts_synth_class_cache[key] = shells;
    return shells;
}

impl TypeEvaluator._install_synth_member(
    scope: uni.UniScopeNode, synth_src: uni.Source, mname: str, member_type: TypeBase
) -> None {
    field_node = uni.Name(
        orig_src=synth_src,
        name=Tok.NAME.value,
        value=mname,
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0,
    );
    field_node.type = member_type;
    scope.names_in_scope[mname] = uni.Symbol(
        defn=field_node, access=SymbolAccess.PUBLIC, parent_tab=scope
    );
}

impl TypeEvaluator._install_compose_extensions -> None {
    # Compose-dialect member extensions on builtin numerics/containers. These
    # reopen the *prefetched builtin's own* shared symbol table and install the
    # members there, so a literal receiver (`24.dp` — an int_class clone) resolves
    # them: member lookup walks receiver.shared.mro and every literal clone shares
    # `_shared` (clone_with_literal passes _shared=self.shared), so what we write
    # here is visible to the clone. Compose lowers `.dp`/`.sp` to Kotlin unit
    # extensions and `.len` to `.size`; nothing dispatches at runtime — this is a
    # checker-only surface that lets the Kotlin idioms type-check.
    if self.prefetch is None {
        return;
    }
    synth_src = uni.Source('', '<compose-synth>');
    foreign_any = types.AnyType(is_foreign=True);

    dp_type: TypeBase = foreign_any;
    dp_cls = self._get_type_from_module(self.js_globals_module, "Dp");
    if isinstance(dp_cls, types.ClassType) {
        dp_type = self._convert_to_instance(dp_cls);
    }

    for num_cls in (self.prefetch.int_class, self.prefetch.float_class) {
        if num_cls is None {
            continue;
        }
        scope = num_cls.shared.symbol_table;
        self._install_synth_member(scope, synth_src, "dp", dp_type);
        self._install_synth_member(scope, synth_src, "sp", foreign_any);
    }

    if self.prefetch.int_class and self.prefetch.list_class {
        self._install_synth_member(
            self.prefetch.list_class.shared.symbol_table,
            synth_src,
            "len",
            self._convert_to_instance(self.prefetch.int_class)
        );
    }
}

impl TypeEvaluator._install_compose_widgets -> None {
    # Ingest the bundled AndroidX metalava signatures into the client ambient
    # scope: every @Composable UI method becomes a typed module-scope symbol so
    # `Button(onClick=.., modifier=..)` type-checks as a call returning Composable.
    # Installed into js_globals_module, so — like the other client globals — it
    # only resolves under `expr.in_client_context()`; ordinary Jac never sees it.
    # This replaces the hand-written compose_runtime.cl.jac / stub-gen `.cl.jac`
    # output with types read straight from the upstream signature file.
    if self.js_globals_module is None {
        return;
    }
    # The fixed namespace singletons/classes declared in js_globals.pyi are
    # Compose-only ambient globals; record them unconditionally so the resolver
    # gates `Modifier`/`Arrangement`/`Color`/`Dp` on `_is_compose_module` even
    # if the bundled widget signature file is absent.
    self._compose_global_names = {
        "Modifier", "Typography", "Arrangement", "Alignment", "Color",
        "Dp", "ModifierChain", "TypographyStyles", "ArrangementNamespace",
        "AlignmentNamespace", "ColorNamespace"
    };
    path = self._COMPOSE_WIDGETS_FILE_PATH;
    if not os.path.exists(path) {
        return;
    }
    try {
        with open(path, 'r', encoding='utf-8', errors='replace') as f {
            text = f.read();
        }
    } except OSError {
        return;
    }
    sigs = parse_signature_text(text);
    self._kotlin_synth_surface(sigs, self.js_globals_module);
    # Record each ingested widget name as a Compose-only ambient global so the
    # resolver gates it on `_is_compose_module`, not generic client context.
    for sig in sigs {
        self._compose_global_names.add(sig.name);
    }
}

impl TypeEvaluator._install_compose_modifiers -> None {
    # Ingest the bundled AndroidX Modifier extension functions into the
    # `ModifierChain` class, so `Modifier.padding(8.dp).fillMaxWidth().clickable(..)`
    # type-checks and chains — each method returns a ModifierChain instance.
    # This replaces the hand-transcribed ~12-method ModifierChain stub in
    # js_globals.pyi with the full surface read straight from the signature file,
    # tracking upstream Compose the same way _install_compose_widgets does.
    if self.js_globals_module is None {
        return;
    }
    mc = self._get_type_from_module(self.js_globals_module, "ModifierChain");
    if not isinstance(mc, types.ClassType) {
        return;
    }
    path = self._COMPOSE_MODIFIERS_FILE_PATH;
    if not os.path.exists(path) {
        return;
    }
    try {
        with open(path, 'r', encoding='utf-8', errors='replace') as f {
            text = f.read();
        }
    } except OSError {
        return;
    }
    chain_inst = self._convert_to_instance(mc);
    synth_src = uni.Source('', '<compose-modifiers>');
    scope = mc.shared.symbol_table;
    for sig in parse_modifier_text(text) {
        self._install_synth_member(
            scope, synth_src, sig.name,
            self._compose_modifier_functype(sig, chain_inst)
        );
    }
}

impl TypeEvaluator._install_compose_consts -> None {
    # Ingest the bundled Compose constant namespaces (Arrangement/Alignment/Color)
    # into their `<Name>Namespace` classes in js_globals.pyi, so `Arrangement.Center`
    # / `Alignment.CenterVertically` / `Color.Red` type-check and a typo is flagged
    # under `[client.android] type_check = true`. Mirrors _install_compose_modifiers:
    # members installed on the class symbol table, read live from a signature file.
    if self.js_globals_module is None {
        return;
    }
    path = self._COMPOSE_CONSTS_FILE_PATH;
    if not os.path.exists(path) {
        return;
    }
    try {
        with open(path, 'r', encoding='utf-8', errors='replace') as f {
            text = f.read();
        }
    } except OSError {
        return;
    }
    synth_src = uni.Source('', '<compose-consts>');
    for (ns, members) in parse_const_text(text).items() {
        cls = self._get_type_from_module(self.js_globals_module, f"{ns}Namespace");
        if not isinstance(cls, types.ClassType) {
            continue;
        }
        scope = cls.shared.symbol_table;
        for m in members {
            self._install_synth_member(
                scope, synth_src, m.name, self._map_kotlin_type(m.ptype)
            );
        }
    }
}

impl TypeEvaluator._compose_modifier_functype(
    sig: ComposeSig, chain_inst: TypeBase
) -> types.FunctionType {
    # A Modifier extension -> a bound method on ModifierChain. The leading
    # is_self parameter is dropped on a bound call (`Modifier.foo(..)`), and the
    # return is a ModifierChain instance so calls chain. Argument params carry
    # defaults (every Compose modifier arg is optional in practice) and map their
    # Kotlin types via the same _map_compose_param used for widget params.
    parameters: list[types.Parameter] = [
        types.Parameter(
            name="self",
            category=types.ParameterCategory.Positional,
            param_type=None,
            is_self=True,
            param_kind=types.ParamKind.NORMAL
        )
    ];
    for p in sig.params {
        parameters.append(
            types.Parameter(
                name=p.name,
                category=types.ParameterCategory.Positional,
                param_type=self._map_compose_param(p),
                has_default=True
            )
        );
    }
    return types.FunctionType(
        func_name=sig.name, return_type=chain_inst, parameters=parameters
    );
}

impl TypeEvaluator._is_compose_gated_member(sym: uni.Symbol) -> bool {
    # True for a member installed by `_install_compose_extensions` (`.dp`/`.sp`/
    # `.len`). These are Compose-dialect idioms and must only resolve inside a
    # client codespace; the resolver gates on this so `16.dp` stays an
    # unknown-member error in ordinary server/native Jac. Identified by the
    # sentinel synth Source below — same tag `_install_compose_extensions` stamps.
    if not sym.defn {
        return False;
    }
    src = sym.defn[0].orig_src;
    return src is not None and src.file_path == '<compose-synth>';
}

impl TypeEvaluator._compose_composable_instance -> TypeBase {
    # The @Composable return type (declared in jac_builtins.pyi as a nominal
    # class), as an instance — what every synthesized widget call yields.
    c = self._get_type_from_module(self.jac_builtins_module, "Composable");
    if isinstance(c, types.ClassType) {
        return self._convert_to_instance(c);
    }
    return types.AnyType(is_foreign=True);
}

impl TypeEvaluator._map_compose_param(p: SigParam) -> TypeBase {
    # SigParam.kind (from compose_stub_gen's metalava classifier) -> Jac type:
    #   modifier -> ModifierChain instance   (chainable Compose modifier)
    #   slot     -> () -> Composable          (a @Composable content lambda)
    #   event    -> () -> None                (onClick / onValueChange handler)
    #   value    -> the real Jac prim mapped from the param's Kotlin type
    #              (SigParam.ptype), mirroring how the React `.d.ts` path maps
    #              TS prims via _map_ts_type — so `Button(enabled="yes")` is a
    #              Jac type error before Kotlin ever sees it. Non-primitive
    #              Compose value types (Color/TextStyle/enums) fall back to
    #              foreign-any: still name/arity-checked, just not deeply typed.
    foreign_any = types.AnyType(is_foreign=True);
    if p.kind == "modifier" {
        mc = self._get_type_from_module(self.js_globals_module, "ModifierChain");
        if isinstance(mc, types.ClassType) {
            return self._convert_to_instance(mc);
        }
        return foreign_any;
    }
    if p.kind == "slot" {
        return types.FunctionType(
            func_name='',
            return_type=self._compose_composable_instance(),
            parameters=[]
        );
    }
    if p.kind == "event" {
        # onClick / onValueChange / onCheckedChange → a handler lambda whose
        # argument types come from the Kotlin FunctionN<..> generic (parsed from
        # SigParam.ptype), so `onValueChange=fn(x: str)` is caught where the
        # widget passes a Float. Empty ptype (pre-type callers) → () -> None.
        return self._map_kotlin_lambda(p.ptype);
    }
    return self._map_kotlin_type(p.ptype);
}

impl TypeEvaluator._map_kotlin_lambda(ktype: str) -> TypeBase {
    # Map a Kotlin `kotlin.jvm.functions.FunctionN<A, B, .., kotlin.Unit>` type to
    # a Jac FunctionType. The generic args are the lambda's parameter types
    # followed by its return type; Compose event handlers always return Unit, so
    # we drop the trailing arg and model the return as None. Each parameter type
    # rides _map_kotlin_type (prims deeply typed, everything else foreign-any).
    none_ret = self._convert_to_instance(self.get_none_type());
    empty = types.FunctionType(func_name='', return_type=none_ret, parameters=[]);
    t = ktype.strip();
    lt = t.find("<");
    if lt < 0 or not t.endswith(">") {
        # No generic payload (bare Function0 or a non-lambda) → nullary handler.
        return empty;
    }
    inner = t[lt + 1:len(t) - 1];
    # Split the generic args on top-level commas (they nest inside `<..>` for
    # generic argument types), then drop the trailing return type (Unit).
    args: list[str] = [];
    depth = 0;
    cur = "";
    for ch in inner {
        if ch == '<' {
            depth += 1;
            cur += ch;
        } elif ch == '>' {
            depth -= 1;
            cur += ch;
        } elif ch == ',' and depth == 0 {
            args.append(cur);
            cur = "";
        } else {
            cur += ch;
        }
    }
    if cur.strip() {
        args.append(cur);
    }
    if len(args) <= 1 {
        # Only the Unit return type is present → the handler takes no arguments.
        return empty;
    }
    parameters: list[types.Parameter] = [];
    i = 0;
    for a in args[:len(args) - 1] {
        at = a.strip();
        # Kotlin variance markers (`? super T` / `? extends T`) are not part of
        # the type token; strip them before mapping.
        if at.startswith("? super ") {
            at = at[8:].strip();
        } elif at.startswith("? extends ") {
            at = at[10:].strip();
        }
        parameters.append(
            types.Parameter(
                name=f"arg{i}",
                category=types.ParameterCategory.Positional,
                param_type=self._map_kotlin_type(at),
                has_default=False
            )
        );
        i += 1;
    }
    return types.FunctionType(func_name='', return_type=none_ret, parameters=parameters);
}

impl TypeEvaluator._map_kotlin_type(ktype: str) -> TypeBase {
    # Map a metalava Kotlin/Java type string (as carried on SigParam.ptype) to a
    # Jac type. Kotlin↔Jac analogue of _map_ts_type's PRIM arm. Only scalar value
    # types are modelled — everything richer (Compose value classes, enums,
    # collections) returns foreign-any, keeping the call name/arity-checked
    # without over-claiming a type we cannot faithfully represent.
    foreign_any = types.AnyType(is_foreign=True);
    if self.prefetch is None {
        return foreign_any;
    }
    t = ktype.strip();
    # Drop generics (rare on value params) and any leading annotations
    # (@Nullable / @IntRange(...)) so we compare on the bare type token.
    lt = t.find("<");
    if lt >= 0 {
        t = t[:lt];
    }
    if " " in t {
        t = t.rsplit(" ", 1)[-1];
    }
    # Reduce a fully-qualified name to its simple form (kotlin.String -> String).
    if "." in t {
        t = t.rsplit(".", 1)[-1];
    }
    t = t.strip();
    # metalava emits Java primitive spellings for Kotlin scalars; long is used
    # for Compose's ULong-backed Color, and CharSequence/char read as str.
    prim = {
        'boolean': self.prefetch.bool_class,
        'Boolean': self.prefetch.bool_class,
        'int': self.prefetch.int_class,
        'Int': self.prefetch.int_class,
        'long': self.prefetch.int_class,
        'Long': self.prefetch.int_class,
        'short': self.prefetch.int_class,
        'byte': self.prefetch.int_class,
        'float': self.prefetch.float_class,
        'Float': self.prefetch.float_class,
        'double': self.prefetch.float_class,
        'Double': self.prefetch.float_class,
        'String': self.prefetch.str_class,
        'CharSequence': self.prefetch.str_class,
        'char': self.prefetch.str_class,
        'Char': self.prefetch.str_class,
    }.get(t);
    if prim is None {
        return foreign_any;
    }
    return self._convert_to_instance(prim);
}

impl TypeEvaluator._compose_sig_to_functype(sig: ComposeSig) -> types.FunctionType {
    # A whole @Composable fun -> a FunctionType, faithful to Kotlin's required-ness
    # (metalava's absent `optional` marker, carried on SigParam.has_default). A
    # required handler (Button.onClick), a required value (Slider.value / Text.text)
    # and a required content slot (Button.content) all stay required, so omitting
    # any of them is a Jac error — it was erased before (every param defaulted).
    #
    # The primary content — Text's `text`, or a widget's trailing content slot — is
    # passed as *children* in JSX (`<Text>"Hi"</Text>`, `<Button>..</Button>`), not
    # an attribute. The JSX prop validator (_validate_component_jsx_props) is now
    # children-aware: it routes content-bearing children into that param, mirroring
    # the emitter's Text->`text` / else->content-slot mapping, so the dominant JSX
    # form still type-checks while a bare `<Text/>` or `Text(color=0)` that supplies
    # neither children nor the required value is correctly flagged.
    parameters: list[types.Parameter] = [];
    for p in sig.params {
        parameters.append(
            types.Parameter(
                name=p.name,
                category=types.ParameterCategory.Positional,
                param_type=self._map_compose_param(p),
                has_default=p.has_default
            )
        );
    }
    return types.FunctionType(
        func_name=sig.name,
        return_type=self._compose_composable_instance(),
        parameters=parameters
    );
}

impl TypeEvaluator._kotlin_synth_surface(
    sigs: list[ComposeSig], scope: uni.UniScopeNode
) -> None {
    # Install every composable as a module-scope symbol in `scope` (the client
    # ambient globals), replacing the hand-written compose_runtime.cl.jac and the
    # spliced stub-gen .cl.jac output with ingested types that track upstream
    # AndroidX signature files.
    synth_src = uni.Source('', '<compose-surface>');
    for sig in sigs {
        self._install_synth_member(
            scope, synth_src, sig.name, self._compose_sig_to_functype(sig)
        );
    }
}

impl TypeEvaluator._synthesize_ts_decl_class(
    decls: dict[str, TsDecl], item_name: str
) -> (TypeBase | None) {
    classes = self._ts_synth_class_types(decls);
    if classes is None {
        return None;
    }
    return classes.get(item_name);
}

impl TypeEvaluator._emit_untyped_external(
    name_node: uni.Name, name: str, module: str
) -> None {
    if self._untyped_external_is_error(name_node) {
        self.emit_diag(E1120, name_node, name=name, module=module);
    } else {
        self.emit_diag(W1102, name_node, name=name, module=module);
    }
}

impl TypeEvaluator._untyped_external_is_error(node_: uni.UniNode) -> bool {
    mod_path = node_.loc.mod_path if node_.loc else None;
    if not mod_path {
        return False;
    }
    import from jaclang.jac0core.modresolver { find_jac_project_root }
    proj_root = find_jac_project_root(mod_path);
    if not proj_root {
        return False;
    }
    if proj_root in self._untyped_external_cfg_cache {
        return self._untyped_external_cfg_cache[proj_root];
    }
    import os;
    result = False;
    try {
        import from jaclang.jac0core.helpers { read_toml_with_encoding }
        data = read_toml_with_encoding(os.path.join(proj_root, 'jac.toml'));
        check_cfg = data.get('check', {}) if isinstance(data, dict) else {};
        result = (
            isinstance(check_cfg, dict) and check_cfg.get('untyped-external') == 'error'
        );
    } except Exception {
        result = False;
    }
    self._untyped_external_cfg_cache[proj_root] = result;
    return result;
}
