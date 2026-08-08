"""GraphMend: Graph-Epilogue Deferred Side Effects transformation.

Side-effecting calls (print / logger.*) inside a compiled region force a graph
break because they touch the Python runtime mid-graph. This pass defers them:
each tagged call (`side_effect` from GraphBreakDetectPass) is replaced by an
append into a per-function buffer, and the buffer is flushed -- in original
program order -- after the compiled graph has run (paper Figs. 5-6).

  @torch.compile
  def fn(x):                          @torch.compile
      x = torch.relu(x)               def fn(x):
      print("t:", x)          ->          _gm_se_buffer = []
      return torch.sin(x)                 x = torch.relu(x)
                                          _gm_se_buffer.append((print, ("t:", x), {}))
                                          __jac_flush_se_buffer__(_gm_se_buffer)
                                          return torch.sin(x)

list.append is a side effect TorchDynamo tracks and replays, so the appends do
not break the graph; only the trailing flush touches the runtime, after all
compute. Each buffer entry is a (callee, args, kwargs) triple so values are
captured at the original call site; mutable positional args are snapshotted
(hoisted to a temp and cloned when they are tensors) so a later in-place
mutation cannot corrupt the deferred value (paper Table 1, clone(args)). Gated
by --graphmend.
"""
import ast as ast3;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.constant { GraphBreakKind, Tokens as Tok }

"""Defer print/logger side effects to a post-graph buffer flush."""
obj DeferSideEffectPass(UniPass) {
    has _enabled: bool = False,
        _counter: int = 0,
        _se_arg_counter: int = 0,
        _pending_regs: list = [];

    """Logger methods whose calls break tracing (logging.Logger API)."""
    static has _LOG_METHODS: set[str] = {
        'debug',
        'info',
        'warning',
        'warning_once',
        'error',
        'exception',
        'critical',
        'fatal',
        'log',
        'warn'
    };

    """Gate the pass on the --graphmend flag."""
    def before_pass {
        self._enabled = self.prog._compile_options.graphmend;
        if not self._enabled {
            self.prune_signal = True;
        }
        self._pending_regs = [];
    }

    """Replace a tagged side-effect call.

    Two distinct mechanisms, because they break for different reasons:
      - `print(...)`  -> buffer the (callee, args, kwargs) triple and flush after
        the graph. `print` is a plain global, so storing it in the graph is fine.
      - `logger.X(...)` -> Dynamo cannot trace a `logging.Logger` METHOD at all,
        even to store it. So we never let the Logger touch the graph: register the
        bound method to an int slot at module load, and inside the forward only
        append `(slot, args, kwargs)` (ints/constants). A forward hook replays it
        after the graph. Only applied inside `forward` (the traced entry); logger
        calls elsewhere are not traced, so they are left untouched.
    """
    def exit_func_call(nd: uni.FuncCall) -> None {
        if not self._enabled {
            return;
        }
        if self.prog.graphmend_breaks.get(id(nd)) != GraphBreakKind.SIDE_EFFECT {
            return;
        }
        parent = nd.parent;
        if not isinstance(parent, uni.ExprStmt) {
            return;
        }
        ability = nd.find_parent_of_type(uni.Ability);
        if ability is None {
            return;
        }
        # The break-free logger mechanism needs a forward hook to flush, so it
        # only applies to `forward` methods (nn.Module). Elsewhere -- standalone
        # decorated functions, non-forward methods -- fall back to buffer+flush.
        if self._is_logger_call(nd) and (ability?.sym_name == 'forward') {
            emit_call = self._logger_emit(nd);
            if emit_call is not None {
                parent.expr = emit_call;
                parent.set_kids([emit_call]);
                return;
            }
        }
        (entry, hoists) = self._buffer_entry(nd);
        append_call = self._buffer_append(nd, entry);
        parent.expr = append_call;
        parent.set_kids([append_call]);
        # Snapshot temps are bound just before the (replayable) append so the
        # buffered values are captured at the original call site, not at flush.
        for h in hoists {
            self._insert_before(parent, h);
        }
        ability._gm_needs_se = True;
    }

    """True if `nd` is a `<logger>.<method>(...)` call whose receiver is a bare
    module-level name (so its bound method can be registered at module load).
    Excludes `self.`/`cls.` receivers, which are not module-level resolvable."""
    def _is_logger_call(nd: uni.FuncCall) -> bool {
        t = nd.target;
        if not isinstance(t, uni.AtomTrailer) {
            return False;
        }
        if (not isinstance(t.right, uni.Name))
            or (t.right.value not in self._LOG_METHODS) {
            return False;
        }
        base = t.target;
        return isinstance(base, uni.Name) and (base.value not in {'self', 'cls'});
    }

    """Build the `__jac_log_emit__(slot, *args, **kwargs)` replacement call and
    queue the module-level slot registration. The original callee (a Logger bound
    method) is salvaged into the registration so it never enters the graph."""
    def _logger_emit(nd: uni.FuncCall) -> (uni.FuncCall | None) {
        callee = nd.target;
        n = self._counter;
        self._counter += 1;
        # Single leading underscore: a `__`-prefixed name would be Python
        # name-mangled inside the class method but not at module scope.
        slot_name = f"_gm_log_slot_{n}";
        reg = self._register_assignment(nd, slot_name, callee);
        # Register right after the top-level class holding this forward, so the
        # slot is bound before any instance's forward runs (the torch.compile call
        # and forward execution may live in this same module, below the class).
        self._pending_regs.append((self._toplevel_archetype(nd), reg));
        # `__jac_log_emit__(slot, (args...), {kwargs})`. args/kwargs are explicit
        # tuple/dict literals (not *args/**kwargs) because the runtime helper is
        # dispatched through the plugin proxy, which drops variadic parameters.
        (pos, kws) = self._split_params(nd.params);
        emit = self._gen_name(nd, '__jac_log_emit__', False);
        slot_ref = self._gen_name(nd, slot_name, False);
        args_tuple = self._tuple(nd, pos);
        kwargs_dict = self._dict_from_kws(nd, kws);
        params = [slot_ref, args_tuple, kwargs_dict];
        return uni.FuncCall(
            target=emit, params=params, genai_call=None, kid=[emit] + params
        );
    }

    """Build `<slot_name> = __jac_log_register__(<callee>)` for module scope."""
    def _register_assignment(
        at: uni.UniNode, slot_name: str, callee: uni.Expr
    ) -> uni.Assignment {
        reg_fn = self._gen_name(at, '__jac_log_register__', False);
        reg_call = uni.FuncCall(
            target=reg_fn, params=[callee], genai_call=None, kid=[reg_fn, callee]
        );
        slot = self._gen_name(at, slot_name, True);
        return uni.Assignment(
            target=[slot],
            value=reg_call,
            type_tag=None,
            mutable=True,
            kid=[slot, reg_call]
        );
    }

    """Emit queued slot registrations: each is inserted right after the top-level
    class that holds its forward (so the slot binds before forward runs), or at
    module end as a fallback. Flush-hook injection is per-assignment elsewhere."""
    def exit_module(nd: uni.Module) -> None {
        if not self._enabled {
            return;
        }
        # Guard every compiled entry in a module that defers anything, not just
        # entries that contain a deferred call themselves. A `print` inside a
        # helper is buffered while the caller's region is open, so the CALLER is
        # what must open it -- and the caller may hold no side effect of its own.
        # Without this the depth stays 0, `se_emit` takes its eager-call branch,
        # and that untraceable call splits the very graph deferral exists to keep
        # whole. Run at module exit so it does not depend on traversal order.
        if getattr(nd, '_gm_needs_se_emit', False) {
            for ab in nd.get_all_sub_nodes(uni.Ability) {
                if self._has_torch_compile_decorator(ab)
                    and (not getattr(ab, '_gm_se_guarded', False)) {
                    self._attach_se_guard(ab);
                    nd._gm_needs_se_guard = True;
                }
            }
        }
        if not self._pending_regs {
            return;
        }
        nd._gm_needs_log_register = True;
        nd._gm_needs_log_emit = True;
        for (anchor, reg) in self._pending_regs {
            if (anchor is not None) and (anchor.parent is nd) and (anchor in nd.kid) {
                self._insert_after(anchor, reg);
            } else {
                self._append_module_stmt(nd, reg);
            }
        }
        self._pending_regs = [];
    }

    """Return the outermost (module-level) Archetype enclosing `nd`, else None."""
    def _toplevel_archetype(nd: uni.UniNode) -> (uni.Archetype | None) {
        top = None;
        cur = nd.parent;
        while cur is not None {
            if isinstance(cur, uni.Module) {
                break;
            }
            if isinstance(cur, uni.Archetype) {
                top = cur;
            }
            cur = cur.parent;
        }
        return top;
    }

    """Inject `<m>.register_forward_hook(__jac_log_flush_hook__)` after
    `<m> = torch.compile(...)` so buffered logger calls flush after the graph."""
    def exit_assignment(nd: uni.Assignment) -> None {
        if not self._enabled {
            return;
        }
        if (nd.value is None) or (not self._is_torch_compile_call(nd.value)) {
            return;
        }
        if (not nd.target) or (len(nd.target) != 1) {
            return;
        }
        tgt = nd.target[0];
        if not isinstance(tgt, uni.Name) {
            return;
        }
        # Pre-hook first so the region is open for the whole forward: helpers
        # inlined into it then buffer rather than emitting mid-graph. The
        # always_call post-hook closes it and flushes, on normal and raising
        # exits alike.
        self._insert_after(nd, self._hook_register_stmt(nd, tgt.value));
        self._insert_after(nd, self._pre_hook_register_stmt(nd, tgt.value));
        mod = nd.find_parent_of_type(uni.Module);
        if mod is not None {
            mod._gm_needs_log_flush = True;
        }
    }

    """Build `<name>.register_forward_pre_hook(__jac_se_region_open__)`."""
    def _pre_hook_register_stmt(at: uni.UniNode, name: str) -> uni.ExprStmt {
        recv = self._gen_name(at, name, False);
        meth = self._gen_name(at, 'register_forward_pre_hook', False);
        target = uni.AtomTrailer(
            target=recv, right=meth, is_attr=True, is_null_ok=False, kid=[recv, meth]
        );
        hook = self._gen_name(at, '__jac_se_region_open__', False);
        call = uni.FuncCall(
            target=target, params=[hook], genai_call=None, kid=[target, hook]
        );
        return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
    }

    """True if `e` is a structural `torch.compile(...)` call."""
    def _is_torch_compile_call(e: uni.Expr) -> bool {
        if not isinstance(e, uni.FuncCall) {
            return False;
        }
        t = e.target;
        return (
            isinstance(t, uni.AtomTrailer)
            and isinstance(t.right, uni.Name)
            and (t.right.value == 'compile')
            and isinstance(t.target, uni.Name)
            and (t.target.value == 'torch')
        );
    }

    """Build `<name>.register_forward_hook(__jac_log_flush_hook__, always_call=True)`.

    `always_call=True` is what makes the logger deferral correct on an
    exceptional exit. A plain forward hook runs only after `forward` RETURNS, so
    a raising forward would drop every buffered logger call; with always_call the
    hook still runs and replays them in FIFO order before the exception
    propagates. This is the hook-path counterpart to the `try`/`finally` that
    `exit_ability` wraps around the buffered (print) path.
    """
    def _hook_register_stmt(at: uni.UniNode, name: str) -> uni.ExprStmt {
        recv = self._gen_name(at, name, False);
        meth = self._gen_name(at, 'register_forward_hook', False);
        target = uni.AtomTrailer(
            target=recv, right=meth, is_attr=True, is_null_ok=False, kid=[recv, meth]
        );
        hook = self._gen_name(at, '__jac_log_flush_hook__', False);
        kw_key = self._gen_name(at, 'always_call', False);
        kw_val = self._gen_name(at, 'True', False);
        always = uni.KWPair(key=kw_key, value=kw_val, kid=[kw_key, kw_val]);
        params = [hook, always];
        call = uni.FuncCall(
            target=target, params=params, genai_call=None, kid=[target] + params
        );
        return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
    }

    """Flush the buffer before any return inside a buffering function.

    A `return <expr>` is rewritten to `__gm_ret = <expr>; flush(); return __gm_ret`
    so the return value's computation runs BEFORE the flush. This keeps the
    flush (a trailing eager epilogue) after all tensor compute, so the compiled
    graph stays contiguous instead of splitting before the return expression.
    """
    def exit_return_stmt(nd: uni.ReturnStmt) -> None {
        if not self._enabled {
            return;
        }
        ability = nd.find_parent_of_type(uni.Ability);
        if (ability is None) or (not getattr(ability, '_gm_needs_se', False)) {
            return;
        }
        # Only a compiled entry flushes. An inlined helper leaves its effects
        # buffered for the enclosing region's exit; a flush here would split the
        # caller's graph, which is the whole thing deferral is avoiding. The
        # return-value hoist exists solely to order the flush after the compute,
        # so it is unnecessary too.
        if not self._is_compiled_entry(ability) {
            return;
        }
        if nd.expr is None {
            self._insert_before(nd, self._flush_stmt(nd));
            return;
        }
        n = self._counter;
        self._counter += 1;
        tmp = self._gen_name(nd, f"__gm_ret_{n}", True);
        ret_assign = uni.Assignment(
            target=[tmp], value=nd.expr, type_tag=None, mutable=True, kid=[tmp, nd.expr]
        );
        ref = self._gen_name(nd, f"__gm_ret_{n}", False);
        nd.expr = ref;
        nd.set_kids([ref]);
        self._insert_before(nd, ret_assign);
        self._insert_before(nd, self._flush_stmt(nd));
    }

    """Initialize the buffer and add a trailing flush for a buffering function.

    NOTE on exceptional exits: the obvious fix -- wrapping the body in
    `try { ... } finally { flush(...) }` -- is NOT usable here. The flush is
    deliberately untraceable (it performs the real I/O), and TorchDynamo 2.12
    responds to an untraceable call inside a `finally` by abandoning the whole
    frame: the function compiles to ZERO FX graphs instead of one, i.e. full
    eager fallback. That trades the graph break we are removing for something
    strictly worse. Verified on torch 2.12; see the exceptional-exit tests.

    The buffered (print) path therefore still flushes only on normal exits. The
    logger path IS correct on exceptional exits -- see `_hook_register_stmt`,
    where `always_call=True` makes the forward hook fire even when `forward`
    raises. Closing the same gap here needs the buffer to outlive the frame (a
    module-global buffer plus an eager boundary guard, as `[Trap]` does with
    `__jac_trap_guard__`), not a `finally` inside the compiled region.
    """
    def exit_ability(nd: uni.Ability) -> None {
        if not self._enabled {
            return;
        }
        if not getattr(nd, '_gm_needs_se', False) {
            return;
        }
        body = nd.body;
        if (not isinstance(body, list)) or (not body) {
            return;
        }
        mod = nd.find_parent_of_type(uni.Module);
        if mod is not None {
            mod._gm_needs_se_emit = True;
        }
        # A function that is NOT itself a compiled entry emits no flush of its
        # own. Dynamo inlines such a helper into its caller's graph, so a flush
        # here would split that graph from the inside -- the effect is buffered
        # and drained at the enclosing region's exit instead, which is what lets
        # deferral reach the end of the whole compiled computation rather than
        # the end of the inner function. When no region is active `se_emit`
        # performs the call immediately, so nothing is left buffered.
        if not self._is_compiled_entry(nd) {
            return;
        }
        # If control can fall off the end, flush there too (returns are handled
        # in exit_return_stmt; se_flush drains, so double-flush is safe).
        tail = nd.body[-1];
        if not isinstance(tail, uni.ReturnStmt) {
            self._append_stmt(nd, self._flush_stmt(nd));
        }
        # Boundary guard for the exceptional exit. Only for a function that
        # carries @torch.compile itself: prepended, the decorator sits ABOVE
        # torch.compile, so its try/finally is eager code Dynamo never traces.
        # On an nn.Module `forward` there is no such boundary here -- the
        # torch.compile happens at the call site, so a decorator on `forward`
        # would be INSIDE the compiled region and its finally would make Dynamo
        # abandon the frame. Those flush via the always_call forward hook
        # instead (see _hook_register_stmt).
        if self._has_torch_compile_decorator(nd) {
            self._attach_se_guard(nd);
            if mod is not None {
                mod._gm_needs_se_guard = True;
            }
        }
    }

    """Prepend `@__jac_se_guard__` so it wraps the compiled callable from eager.

    Idempotent: `_gm_se_guarded` marks an ability already handled, since
    exit_ability and the module-level sweep can both reach the same entry."""
    def _attach_se_guard(nd: uni.Ability) -> None {
        if getattr(nd, '_gm_se_guarded', False) {
            return;
        }
        guard = self._gen_name(nd, '__jac_se_guard__', False);
        nd.decorators = [guard] + list(nd.decorators or []);
        nd.set_kids([guard] + list(nd.kid));
        guard.parent = nd;
        nd._gm_se_guarded = True;
    }

    # ---- node construction helpers ----
    """Mint a synthetic Name anchored at `at`, with Store context if `store`."""
    def _gen_name(at: uni.UniNode, value: str, store: bool) -> uni.Name {
        nm = uni.Name.gen_stub_from_node(at, value);
        if store {
            nm.expr_ctx = uni.ExprCtx.STORE;
        }
        return nm;
    }

    """Mint a synthetic string literal (value carries its quotes)."""
    def _str(at: uni.UniNode, text: str) -> uni.String {
        return uni.String(
            orig_src=at.loc.orig_src,
            name='STRING',
            value=f'"{text}"',
            line=at.loc.first_line,
            end_line=at.loc.last_line,
            col_start=at.loc.col_start,
            col_end=at.loc.col_end,
            pos_start=at.loc.pos_start,
            pos_end=at.loc.pos_end
        );
    }

    """Split call params into positional args and KWPair list."""
    def _split_params(params: any) -> tuple[(list, list)] {
        pos = [];
        kws = [];
        for p in (params or []) {
            if isinstance(p, uni.KWPair) {
                kws.append(p);
            } else {
                pos.append(p);
            }
        }
        return (pos, kws);
    }

    """Build a tuple literal anchored at `at`."""
    def _tuple(at: uni.UniNode, values: list) -> uni.TupleVal {
        kid = values or [at.gen_token(Tok.LPAREN, '('), at.gen_token(Tok.RPAREN, ')')];
        return uni.TupleVal(values=values, kid=kid);
    }

    """Build a dict literal from a list of KWPair nodes (keys become strings)."""
    def _dict_from_kws(at: uni.UniNode, kws: list) -> uni.DictVal {
        pairs = [];
        for kw in kws {
            key = self._str(at, kw.key.value);
            pairs.append(uni.KVPair(key=key, value=kw.value, kid=[key, kw.value]));
        }
        kid = pairs or [at.gen_token(Tok.LBRACE, '{'), at.gen_token(Tok.RBRACE, '}')];
        return uni.DictVal(kv_pairs=pairs, kid=kid);
    }

    """Build the `(callee, (args...), {kwargs})` buffer entry for a call, plus the
    list of temp-assignment statements that snapshot its non-constant positional
    args. Returns `(entry, hoists)`.

    Each mutable positional arg is hoisted to `__gm_se_arg_N = <arg>` and stored
    in the entry as `__gm_se_arg_N.clone() if hasattr(__gm_se_arg_N, 'clone') else
    __gm_se_arg_N` -- cloning tensors so a later in-place mutation cannot corrupt
    the value the deferred call observes (paper Table 1, `clone(args)`). The
    `hasattr` guard is resolved statically by Dynamo, so the clone is a native
    in-graph op for tensors and a no-op for everything else; literals (immutable)
    are buffered as-is. Logger calls do not pass through here -- their args cross
    the opaque `log_emit` boundary, so they are constant-only by construction."""
    def _buffer_entry(call: uni.FuncCall) -> tuple[(uni.TupleVal, list[uni.UniNode])] {
        (pos, kws) = self._split_params(call.params);
        hoists = [];
        new_pos = [];
        for p in pos {
            if isinstance(p, (uni.Literal, uni.MultiString, uni.FString)) {
                new_pos.append(p);
            } else {
                n = self._se_arg_counter;
                self._se_arg_counter += 1;
                tmp = f"__gm_se_arg_{n}";
                store = self._gen_name(call, tmp, True);
                hoists.append(
                    uni.Assignment(
                        target=[store],
                        value=p,
                        type_tag=None,
                        mutable=True,
                        kid=[store, p]
                    )
                );
                new_pos.append(self._clone_guard(call, tmp));
            }
        }
        args_tuple = self._tuple(call, new_pos);
        kwargs_dict = self._dict_from_kws(call, kws);
        items = [call.target, args_tuple, kwargs_dict];
        return (uni.TupleVal(values=items, kid=items), hoists);
    }

    """Build `<tmp>.clone() if hasattr(<tmp>, 'clone') else <tmp>` over a hoisted
    snapshot temp. Three fresh Name nodes reference the temp, so no AST node is
    aliased into more than one parent."""
    def _clone_guard(at: uni.UniNode, tmp: str) -> uni.IfElseExpr {
        recv = self._gen_name(at, tmp, False);
        clone_nm = self._gen_name(at, 'clone', False);
        trailer = uni.AtomTrailer(
            target=recv,
            right=clone_nm,
            is_attr=True,
            is_null_ok=False,
            kid=[recv, clone_nm]
        );
        clone_call = uni.FuncCall(
            target=trailer, params=[], genai_call=None, kid=[trailer]
        );
        has_nm = self._gen_name(at, 'hasattr', False);
        test_recv = self._gen_name(at, tmp, False);
        attr_name = self._str(at, 'clone');
        test = uni.FuncCall(
            target=has_nm,
            params=[test_recv, attr_name],
            genai_call=None,
            kid=[has_nm, test_recv, attr_name]
        );
        else_recv = self._gen_name(at, tmp, False);
        val_cfg = uni.CfgExpr(expr=clone_call, kid=[clone_call]);
        cond_cfg = uni.CfgExpr(expr=test, kid=[test]);
        else_cfg = uni.CfgExpr(expr=else_recv, kid=[else_recv]);
        return uni.IfElseExpr(
            value=val_cfg,
            condition=cond_cfg,
            else_value=else_cfg,
            kid=[val_cfg, cond_cfg, else_cfg]
        );
    }

    """Build `__jac_se_emit__(callee, args, kwargs)` from the snapshotted triple.

    The buffer is process-global (see `_gm_se_buffer` in runtime.jac), not a
    function-local list, so it survives a frame that exits by raising and the
    `se_guard` boundary can still drain it. A global list append traces exactly
    like a local one, so this costs no additional graph break.
    """
    def _buffer_append(at: uni.UniNode, ent: uni.Expr) -> uni.FuncCall {
        emit = self._gen_name(at, '__jac_se_emit__', False);
        # `ent` is the (callee, args, kwargs) TupleVal built by _buffer_entry;
        # pass its members positionally -- the runtime interface dispatches
        # through the plugin proxy, which does not forward variadic parameters.
        params = list(ent.values);
        return uni.FuncCall(
            target=emit, params=params, genai_call=None, kid=[emit] + params
        );
    }

    """Build `__jac_se_flush__()` as a statement."""
    def _flush_stmt(at: uni.UniNode) -> uni.ExprStmt {
        helper = self._gen_name(at, '__jac_se_flush__', False);
        call = uni.FuncCall(target=helper, params=[], genai_call=None, kid=[helper]);
        return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
    }

    """True if `nd` is the entry of a compiled region rather than an inlined helper.

    Two shapes qualify: a function carrying `@torch.compile` (guarded by the
    prepended `__jac_se_guard__`), and an `nn.Module.forward` (bracketed by the
    injected forward pre/post hooks). Anything else is a helper that Dynamo
    inlines, and it must not flush.
    """
    def _is_compiled_entry(nd: uni.Ability) -> bool {
        return self._has_torch_compile_decorator(nd) or (nd?.sym_name == 'forward');
    }

    """True if `nd` carries a `@torch.compile` / `@torch.compile(...)` decorator."""
    def _has_torch_compile_decorator(nd: uni.UniNode) -> bool {
        for dec in (nd?.decorators or []) {
            target = dec.target if isinstance(dec, uni.FuncCall) else dec;
            if (
                isinstance(target, uni.AtomTrailer)
                and isinstance(target.right, uni.Name)
                and (target.right.value == 'compile')
                and isinstance(target.target, uni.Name)
                and (target.target.value == 'torch')
            ) {
                return True;
            }
        }
        return False;
    }

    # ---- body splicing helpers ----
    """Insert `new_stmt` at the front of an ability's body."""
    def _insert_front(ability: uni.Ability, new_stmt: uni.UniNode) {
        body = ability.body;
        first = body[0];
        ability.body = [new_stmt] + list(body);
        if first in ability.kid {
            j = ability.kid.index(first);
            ability.set_kids(
                list(ability.kid[:j]) + [new_stmt] + list(ability.kid[j:])
            );
        }
        new_stmt.parent = ability;
    }

    """Append `new_stmt` to the end of an ability's body."""
    def _append_stmt(ability: uni.Ability, new_stmt: uni.UniNode) {
        body = ability.body;
        last = body[-1];
        ability.body = list(body) + [new_stmt];
        if last in ability.kid {
            j = ability.kid.index(last);
            ability.set_kids(
                list(ability.kid[:(j + 1)]) + [new_stmt] + list(ability.kid[(j + 1):])
            );
        }
        new_stmt.parent = ability;
    }

    """Append `new_stmt` to the end of a module's body and kid."""
    def _append_module_stmt(mod: uni.Module, new_stmt: uni.UniNode) -> None {
        body = mod.body;
        if not isinstance(body, list) {
            return;
        }
        if body {
            last = body[-1];
            mod.body = list(body) + [new_stmt];
            if last in mod.kid {
                j = mod.kid.index(last);
                mod.set_kids(
                    list(mod.kid[:(j + 1)]) + [new_stmt] + list(mod.kid[(j + 1):])
                );
            } else {
                mod.set_kids(list(mod.kid) + [new_stmt]);
            }
        } else {
            mod.body = [new_stmt];
            mod.set_kids(list(mod.kid) + [new_stmt]);
        }
        new_stmt.parent = mod;
    }

    """Insert `new_stmt` immediately after `stmt` in its parent body and kid."""
    def _insert_after(stmt: uni.UniNode, new_stmt: uni.UniNode) -> None {
        parent = stmt.parent;
        if parent is None {
            return;
        }
        body = parent?.body;
        if isinstance(body, list) and (stmt in body) {
            i = body.index(stmt);
            parent.body = body[:(i + 1)] + [new_stmt] + body[(i + 1):];
        }
        if stmt in parent.kid {
            j = parent.kid.index(stmt);
            parent.set_kids(
                list(parent.kid[:(j + 1)]) + [new_stmt] + list(parent.kid[(j + 1):])
            );
        }
        new_stmt.parent = parent;
    }

    """Insert `new_stmt` immediately before `stmt` in its parent body and kid."""
    def _insert_before(stmt: uni.UniNode, new_stmt: uni.UniNode) -> None {
        parent = stmt.parent;
        if parent is None {
            return;
        }
        body = parent?.body;
        if isinstance(body, list) and (stmt in body) {
            i = body.index(stmt);
            parent.body = body[:i] + [new_stmt] + body[i:];
        }
        if stmt in parent.kid {
            j = parent.kid.index(stmt);
            parent.set_kids(list(parent.kid[:j]) + [new_stmt] + list(parent.kid[j:]));
        }
        new_stmt.parent = parent;
    }
}
