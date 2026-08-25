"""InterceptorLLM implementation: server-driven ReAct against the proactive-prefill guard server.

Transport: persistent TCP connection (opened in postinit), length-prefixed JSON
messages (4-byte big-endian length + UTF-8 body). One InterceptorLLMBackend
serves exactly one program; `register` carries the tenant identity
(program_name, pid, model_name) for the multi-tenant layer above.

A byllm function call is one server-driven sub-conversation:

    client -> {"type": "call", "id", "key", "program_name", "pid",
               "args": {name: repr}, "self": repr|null, "schema": response_format|null,
               "call_params"}
    server -> {"type": "tool_call", "call", "name", "arguments", "text"}   # 0..N, one at a time
    client -> {"type": "tool_result", "call", "content"}
    server -> {"type": "final", "call", "output", "text"}
    client -> {"type": "reject", "call", "feedback"}                       # parse failure only

The server owns prompt construction (compiled invariants, warm KV prefix),
generation, tool-call parsing, max_react_iterations and forced finals. This
side only executes tools (their state lives in the program's process) and
constructs the typed return value; a `final` that fails parse_response is
rejected with feedback so the server regenerates on the warm prefix instead
of byllm's reset-based typed retry. Tool calls are strictly sequential by
design: each local tool execution is a window in which the server holds the
full hot prefix for proactive work.

Visit routing (`visit <edges> by llm()`) has no call frame, so it stays on the
single-turn `generate` path with full messages — but it carries a key of its
own, `__visit@<file>.jac:<line>`, derived from the executing .jac stack frame.
The static side derives the same string from the VisitStmt, which is what lets
the server place a routing call in the topology and speculate on the node
abilities it may reach.
"""

impl InterceptorLLM.postinit -> None {
    import threading;
    # Text tool protocol: byllm renders tool schemas into the prompt and recovers
    # tool calls from the reply — the same prompt shape the guard server warms.
    self.supports_native_tools = False;
    if not self.program_name {
        if sys.argv and sys.argv[0] {
            self.program_name = os.path.basename(sys.argv[0]);
        } else {
            self.program_name = "jac-program";
        }
    }
    self._sock_lock = threading.Lock();
    self._connect();
}

impl InterceptorLLM.invoke(mt_run: MTRuntime) -> object {
    if mt_run.stream {
        return self._fallback(mt_run, "streaming not supported by guard server yet");
    }
    if self._sock is None and not self._connect() {
        return self._fallback(mt_run, "guard server not connected");
    }
    if not self._sock_lock.acquire(False) {
        raise RuntimeError("concurrent calls on one InterceptorLLM instance are not allowed");
    }
    try {
        if mt_run.mtir is not None and mt_run.mtir.caller is not None {
            self._current_key = self._callsite_key(mt_run);
            self._current_site = self._call_site(self._current_key.split(".")[-1]);
        } else {
            (self._current_key, self._current_site) = self._visit_key();
        }
        return BaseLLM.invoke(self, mt_run=mt_run);
    } finally {
        self._sock_lock.release();
    }
}

"""Route async calls through the sync invoke so the interceptor path is never bypassed."""
impl InterceptorLLM.ainvoke(mt_run: MTRuntime) -> object {
    import asyncio;
    return await asyncio.to_thread(self.invoke, mt_run);
}

impl InterceptorLLM._invoke_react_loop(mt_run: MTRuntime) -> object {
    if mt_run.mtir is None or mt_run.mtir.caller is None {
        return BaseLLM._invoke_react_loop(self, mt_run=mt_run);  # visit routing: `generate`
    }
    (args, self_view) = self._args_view(mt_run);
    self._req_id += 1;
    call_id = self._req_id;
    rejects_left = self._resolve_output_attempts(mt_run) - 1;
    try {
        self._send_msg({
            "type": "call",
            "id": call_id,
            "key": self._current_key,
            "site": self._current_site,
            "program_name": self.program_name,
            "pid": os.getpid(),
            "args": args,
            "self": self_view,
            # response_format the typed return is validated against (None with
            # tools: the answer then arrives through finish_tool). The server
            # turns it into a decoding grammar so the first answer parses.
            "schema": mt_run.get_output_schema(),
            "call_params": {
                "max_react_iterations": mt_run.call_params.get("max_react_iterations")
                    or self.call_params.get("max_react_iterations")
                    or _call_params_config.get("max_react_iterations"),
                "max_output_retries": rejects_left,
            },
        });
        while True {
            msg = self._recv_msg();
            if msg.get("type") == "error" {
                raise RuntimeError(f"guard server error: {msg.get('error')}");
            }
            if msg.get("call") != call_id {
                raise RuntimeError(f"guard server answered call {msg.get('call')}, expected {call_id}");
            }
            if msg.get("text") {
                mt_run.add_message({"role": "assistant", "content": msg.get("text")});
            }
            if msg.get("type") == "tool_call" {
                content = self._run_tool(mt_run, str(msg.get("name") or ""), msg.get("arguments") or {});
                self._send_msg({"type": "tool_result", "call": call_id, "content": content});
            } elif msg.get("type") == "final" {
                output = msg.get("output");
                if not isinstance(output, str) {
                    output = json.dumps(output);
                }
                try {
                    return mt_run.parse_response(output);
                } except OutputConversionError as e {
                    if rejects_left <= 0 {
                        raise;
                    }
                    rejects_left -= 1;
                    self._send_msg({"type": "reject", "call": call_id, "feedback": str(e)});
                }
            } else {
                raise RuntimeError(f"unexpected message type from guard server: {msg.get('type')}");
            }
        }
    } except OSError as e {
        self._close();
        raise ConnectionError(f"guard server connection lost: {e}");
    }
}

"""Argument str_views for the call frame: ({param_name: repr}, repr(receiver)|None)."""
impl InterceptorLLM._args_view(mt_run: MTRuntime) -> tuple {
    import inspect;
    import from types { MethodType }
    caller = mt_run.mtir.caller;
    names = list(inspect.signature(caller).parameters.keys());
    self_view = None;
    if isinstance(caller, MethodType) {
        self_view = repr(caller.__self__);
    }
    args = {};
    for (k, v) in mt_run.mtir.args.items() {
        if isinstance(k, int) and k < len(names) {
            name = names[k];
        } else {
            name = str(k);
        }
        if name == "self" {
            self_view = repr(v);
        } else {
            args[name] = repr(v);
        }
    }
    return (args, self_view);
}

"""Execute one server-requested tool locally; errors come back as result text for the model."""
impl InterceptorLLM._run_tool(mt_run: MTRuntime, name: str, arguments: dict) -> str {
    tool = mt_run.get_tool(name);
    if tool is None {
        return f"Error: unknown tool '{name}'";
    }
    try {
        tc = ToolCall(call_id=f"call_{self._req_id}", tool=tool, args=tool.parse_arguments(arguments));
        result_msg = tc();
        mt_run.add_message(result_msg);
        return str(result_msg.content);
    } except Exception as e {
        return f"Error: {e}";
    }
}

"""Single-turn completion for the `generate` path (visit routing)."""
impl InterceptorLLM.model_call_no_stream(params: dict) -> dict {
    payload = {
        "type": "generate",
        "key": self._current_key,
        "site": self._current_site,
        "program_name": self.program_name,
        "pid": os.getpid(),
        "messages": params.get("messages", []),
        "schema": params.get("response_format"),
        "temperature": params.get("temperature"),
        "max_tokens": params.get("max_tokens"),
        "stop": params.get("stop"),
    };
    resp = self._request(payload);
    return {
        "model": self.model_name,
        "choices": [
            {
                "index": 0,
                "finish_reason": "stop",
                "message": {"role": "assistant", "content": resp.get("text", "")},
            }
        ],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    };
}

"""Wire identity of a `visit <edges> by llm()` routing call, as (key, site).

A routing call has no callable behind it, so there is no name to key it by; both
ends derive the key from the same two facts instead — source file and line. The
static side reads them off the VisitStmt, this side off the executing .jac stack
frame, which for a routing call is the walker ability running the visit. `None`
when the frame is unresolvable: the server then falls back to prompt shape, the
old behaviour."""
impl InterceptorLLM._visit_key -> tuple {
    site = self._call_site("");  # no decl stub to skip on this path
    if site is None {
        return ("", None);
    }
    return (f"__visit@{site}", site);
}

"""Invocation-site location `file.jac:line` — the first .jac frame outside jaclang
that isn't the byllm def's own stub (its frame carries the decl name and the decl
line, one below the real call). Jac line numbers survive compilation. Lets the
server tell apart multiple invocation sites of one decl (their warm/bind state
differs). None when unresolvable."""
impl InterceptorLLM._call_site(name: str) -> str | None {
    import inspect;
    try {
        for fi in inspect.stack(0) {
            if fi.filename.endswith(".jac")
            and "jaclang" not in fi.filename
            and fi.function != name {
                return f"{os.path.basename(fi.filename)}:{fi.lineno}";
            }
        }
    } except Exception {}
    return None;
}

"""Callsite key matching the side runtime's ability_key: `Owner.name` or `name`."""
impl InterceptorLLM._callsite_key(mt_run: MTRuntime) -> str {
    import from types { MethodType }
    caller = mt_run.mtir.caller;
    if isinstance(caller, MethodType) {
        return f"{type(caller.__self__).__name__}.{caller.__name__}";
    }
    return caller.__name__;
}

"""Open the TCP connection and register this tenant with the guard server."""
impl InterceptorLLM._connect -> bool {
    import socket;
    try {
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
        s.connect((self.comm_ip, self.comm_port));
        self._sock = s;
        self._send_msg({
            "type": "register",
            "program_name": self.program_name,
            "pid": os.getpid(),
            "model_name": self.model_name,
        });
        self._adopt_registered(s);
        return True;
    } except OSError as e {
        logger.warning(f"InterceptorLLM: cannot reach guard server at {self.comm_ip}:{self.comm_port} ({e})");
        self._close();
        return False;
    }
}

"""Read the server's `registered` reply and adopt its routing-prompt layout.

The guard server's static pass and route_visit must emit the visit prompt's
zones in the same order, or the warmed prefix is not a prefix of the served
bytes. The server owns that choice and announces it here; setting
JAC_ROUTE_CACHE_LAYOUT in this process makes route_visit follow it, whatever
the launching shell had. A server that sends no reply (older protocol) leaves
the environment as it was after a short wait."""
impl InterceptorLLM._adopt_registered(sock: object) -> None {
    import socket;
    sock.settimeout(5.0);
    try {
        ack = self._recv_msg();
    } except (socket.timeout, OSError, ValueError) {
        logger.warning("InterceptorLLM: no `registered` reply from the guard server; keeping the local route layout");
        return;
    } finally {
        sock.settimeout(None);
    }
    if ack.get("type") != "registered" {
        logger.warning(f"InterceptorLLM: unexpected reply to register: {ack.get('type')!r}");
        return;
    }
    layout = ack.get("route_layout");
    if layout in ("cache", "default") {
        want = "1" if layout == "cache" else "0";
        had = os.environ.get("JAC_ROUTE_CACHE_LAYOUT");
        if had is not None and had != want {
            logger.warning(f"InterceptorLLM: guard server uses route layout {layout!r}; overriding JAC_ROUTE_CACHE_LAYOUT={had!r}");
        }
        os.environ["JAC_ROUTE_CACHE_LAYOUT"] = want;
    }
}

impl InterceptorLLM._close -> None {
    if self._sock is not None {
        try {
            self._sock.close();
        } except OSError {
            # socket already dead; nothing to release
        }
        self._sock = None;
    }
}

impl InterceptorLLM._send_msg(msg: dict) -> None {
    import struct;
    data = json.dumps(msg).encode("utf-8");
    self._sock.sendall(struct.pack(">I", len(data)) + data);
}

impl InterceptorLLM._recv_msg -> dict {
    import struct;
    length = struct.unpack(">I", self._recv_exact(4))[0];
    return json.loads(self._recv_exact(length).decode("utf-8"));
}

impl InterceptorLLM._recv_exact(n: int) -> bytes {
    buf = b"";
    while len(buf) < n {
        chunk = self._sock.recv(n - len(buf));
        if not chunk {
            raise ConnectionError("guard server closed the connection");
        }
        buf += chunk;
    }
    return buf;
}

"""One request/reply exchange for the `generate` path (invoke already holds the lock)."""
impl InterceptorLLM._request(payload: dict) -> dict {
    self._req_id += 1;
    payload["id"] = self._req_id;
    try {
        self._send_msg(payload);
        resp = self._recv_msg();
    } except OSError as e {
        self._close();
        raise ConnectionError(f"guard server connection lost: {e}");
    }
    if resp.get("id") != payload["id"] {
        raise RuntimeError(f"guard server reply id mismatch: sent {payload['id']}, got {resp.get('id')}");
    }
    if resp.get("type") == "error" {
        raise RuntimeError(f"guard server error: {resp.get('error')}");
    }
    return resp;
}

impl InterceptorLLM._fallback(mt_run: MTRuntime, reason: str) -> object {
    logger.warning(f"InterceptorLLM: falling back to direct model ({reason})");
    if self._delegate is None {
        self._delegate = Model(model_name=self.model_name, config=self.config);
    }
    return self._delegate.invoke(mt_run=mt_run);
}
