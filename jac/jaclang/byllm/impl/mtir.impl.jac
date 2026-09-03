glob SYSTEM_PERSONA = """\
    This is a task you must complete by returning only the output.
    Do not include explanations, code, or extra text—only the result.
    """,
     INSTRUCTION_TOOL = """
    Use the tools provided to reach the goal. Call one tool at a time with \
    proper args—no explanations, no narration. Think step by step, invoking tools \
    as needed. When done, always call finish_tool(output) to return the final
    output. Only use tools.
    """;

impl MTRuntime.factory(mtir: MTIR) -> MTRuntime {
    caller = mtir.caller;
    args = mtir.args;
    call_params = mtir.call_params;
    ir_info = mtir.ir_info;

    if "method" in call_params {
        import warnings;
        warnings.warn(
            "'method' parameter is deprecated and has no effect. "
            "For tool usage, just pass tools=[...] directly to by llm().",
            DeprecationWarning,
            stacklevel=2
        );
        del call_params["method"];
    }

    has_mtir = ir_info is not None;
    fn_info = ir_info if isinstance(ir_info, FunctionInfo) else None;
    ir_tools = fn_info.tools if fn_info else None;

    raw_tools_arg = call_params.get("tools", []);
    raw_tools: list[Callable | Tool | McpTool] = raw_tools_arg
        if isinstance(raw_tools_arg, list)
        else [];
    tools: list[Tool | McpTool] = [];
    local_idx = 0;
    for func in raw_tools {
        if isinstance(func, (Tool, McpTool)) {
            tools.append(func);
            continue;
        }
        if ir_tools is not None and local_idx < len(ir_tools) {
            tools.append(Tool(func, info=ir_tools[local_idx]));
        } else {
            tools.append(Tool(func));
        }
        local_idx += 1;
    }

    input_entries: list[tuple] = [];
    media_inputs: list = [];
    media_params: list[str] = [];
    if fn_info is not None and fn_info.params is not None {
        params = [param for param in fn_info.params];
        for (key, value) in args.items() {
            idx = list(args.keys()).index(key);
            `sem = params[idx].semstr or "";
            if isinstance(value, Media) {
                media_inputs.append((value, `sem));
                media_params.append(params[idx].name);
                continue;
            }

            if isinstance(key, str) {
                label = key;
            } elif key < len(params) {
                label = params[key].name;
            } else {
                label = "arg";
            }
            input_entries.append((label, f"{label} = {(value, `sem)}", value));
        }
    } else {
        param_names = list(inspect.signature(caller).parameters.keys());
        for (key, value) in args.items() {
            if isinstance(value, Media) {
                media_inputs.append((value, ""));
                continue;
            }

            if isinstance(key, str) {
                label = key;
            } elif key < len(param_names) {
                label = param_names[key];
            } else {
                label = "arg";
            }
            input_entries.append((label, f"{label} = {value}", value));
        }
    }
    incl_info = call_params.get("incl_info");
    if incl_info and isinstance(incl_info, dict) {
        for (key, value) in incl_info.items() {
            if isinstance(value, Media) {
                media_inputs.append((value, ""));
            } else {
                input_entries.append(
                    (
                        key,
                        f"{key} = {(value, "")}" if has_mtir else f"{key} = {value}",
                        value
                    )
                );
            }
        }
    }
    caller_obj: object = caller;
    if isinstance(caller_obj, MethodType) {
        bound_self = caller_obj.__self__;
        parent_info = fn_info.parent_class if isinstance(fn_info, MethodInfo) else None;
        input_entries.insert(
            0,
            (
                "self",
                f"self = {(bound_self, parent_info.semstr if parent_info else '')}"
                    if has_mtir
                    else f"self = {bound_self}",
                bound_self
            )
        );
    }

    system_content = SYSTEM_PERSONA;
    try {
        import from jaclang.project.config { find_project_root }
        import from pathlib { Path }

        caller_file = inspect.getfile(caller);
        project_root_result = find_project_root(Path(caller_file).parent);
        project_dir = project_root_result[0] if project_root_result else None;

        config_system_prompt = get_byllm_config(project_dir).get_system_prompt();
        if config_system_prompt {
            system_content = config_system_prompt;
        }
    } except Exception {}

    call_system_prompt = call_params.get("system_prompt");
    if callable(call_system_prompt) {
        try {
            call_system_prompt = call_system_prompt();
        } except Exception {
            call_system_prompt = None;
        }
    }
    call_sp_text = str(call_system_prompt) if call_system_prompt else "";
    if call_sp_text {
        system_content += "\n\n" + call_sp_text;
    }

    return_type = get_type_hints(caller).get("return");
    description = Tool.get_func_description(caller);
    include_schema_hint = len(tools) == 0;

    plan = invariant_plan_of(fn_info);
    sp_volatile = bool(call_sp_text) and not (plan or {}).get("system_prompt", True);
    hoist = (
        plan is not None
        and bool(input_entries or media_inputs)
        and not sp_volatile
        and hoisting_enabled()
    );
    contract_text = "";
    if hoist {
        contract_text = render_contract_block(
            fn_info,
            description,
            return_type,
            include_schema_hint,
            tuple(media_params),
            tuple(tool.get_name() for tool in tools)
        );
        hoist = bool(contract_text);
    }

    inputs_detail: list[str] = [
        f"{item[0]} = {repr(item[2])}" if hoist else item[1] for item in input_entries
    ];

    conv_arg = call_params.get("conversation");
    conv_msgs: list[MessageType] = [];
    conv_list_ref: object = None;
    if isinstance(conv_arg, list) {
        conv_list_ref = conv_arg;
        for item in conv_arg {
            m: any = item;
            if isinstance(m, Message) {
                conv_msgs.append(m);
            } elif isinstance(m, dict) {
                reconstructed: any = Message.from_dict(m);
                conv_msgs.append(reconstructed);
            } else {
                conv_msgs.append(m);
            }
        }
    }

    sys_msg = Message(
        role=MessageRole.SYSTEM,
        content=system_content + (INSTRUCTION_TOOL if tools else ""),
    );
    body = "\n".join(inputs_detail);
    user_content: list = [];
    if not hoist {
        user_content.append(Text(description + "\n\n" + body));
    } elif body {
        user_content.append(Text(body));
    }
    user_content.extend(media_inputs);
    user_msg = Message(role=MessageRole.USER, content=user_content);

    contract_msg: Message | None = (
        Message(role=MessageRole.SYSTEM, content=contract_text) if hoist else None
    );
    messages: list[MessageType] = (
        [sys_msg, contract_msg, *conv_msgs, user_msg]
            if contract_msg is not None
            else [sys_msg, *conv_msgs, user_msg]
    );

    is_streaming = bool(call_params.get("stream", False));
    if is_streaming
        and return_type is not str
        and call_params.get("stream_handler") is None {
        raise ConfigurationError(
            "Streaming responses are only supported for str return types. "
            "Pass a stream_handler to receive stream events for a structured "
            "return type (e.g. `visit [-->] by model(stream=True, "
            "stream_handler=fn)`)."
        );
    }
    if len(tools) > 0 {
        if return_type is None {
            tools.append(Tool.make_finish_tool(str));
        } else {
            tools.append(Tool.make_finish_tool(return_type));
        }
    }
    mt_run = MTRuntime(
        messages=messages,
        tools=tools,
        resp_type=return_type,
        stream=is_streaming,
        call_params=call_params,
        mtir=mtir
    );

    if conv_list_ref is not None {
        mt_run._scaffolding_ids.append(id(sys_msg));
        mt_run._conversation_list = conv_list_ref;
    }
    if contract_msg is not None {
        mt_run._scaffolding_ids.append(id(contract_msg));
        mt_run._hoisted = True;
        mt_run._invariant_text = str(sys_msg.content) + "\n\n" + contract_text;
        mt_run._schema_hint_hoisted = include_schema_hint
            and bool((plan or {}).get("schema", False));
    }

    return mt_run;
}

impl MTRuntime.add_message(message: MessageType) -> None {
    self.messages.append(message);
}


impl MTRuntime.add_scaffolding_message(message: MessageType) -> None {
    self.messages.append(message);
    self._scaffolding_ids.append(id(message));
}

impl MTRuntime.get_msg_list -> list[dict[str, object] | LiteLLMMessage] {
    return [
        msg.to_dict() if isinstance(msg, Message) else msg for msg in self.messages
    ];
}


impl MTRuntime.write_back_conversation -> None {
    if self._conversation_list is None {
        return;
    }
    out: list = [];
    for msg in self.get_history_for_persist() {
        m: any = msg;
        if hasattr(m, "to_dict") {
            out.append(m.to_dict());
        } elif isinstance(m, dict) {
            out.append(dict(m));
        } elif hasattr(m, "model_dump") {
            try {
                out.append(m.model_dump());
            } except Exception {
                out.append({"raw": str(m)});
            }
        }
    }
    conv_list = self._conversation_list;
    if conv_list is not None {
        conv_list[:] = out;
    }
}


def _is_finish_tool_call(tc: any) -> bool {
    if tc?.function and hasattr(tc.function, "name") {
        return tc.function.name == "finish_tool";
    }
    if isinstance(tc, dict) {
        return (tc.get("function") or {}).get("name", "") == "finish_tool";
    }
    return False;
}


impl MTRuntime.get_history_for_persist -> list[MessageType] {
    scaff_ids = set(self._scaffolding_ids);
    out: list = [];
    for msg in self.messages {
        if id(msg) in scaff_ids {
            continue;
        }

        if not (
            isinstance(msg, Message)
            or isinstance(msg, dict)
            or hasattr(msg, "to_dict")
            or hasattr(msg, "model_dump")
        ) {
            continue;
        }
        if isinstance(msg, ToolCallResultMsg) and msg.name == "finish_tool" {
            continue;
        }
        tool_calls = msg?.tool_calls;
        if tool_calls is None and isinstance(msg, dict) {
            tool_calls = msg.get("tool_calls");
        }
        if tool_calls and all(_is_finish_tool_call(tc) for tc in tool_calls) {
            continue;
        }
        out.append(msg);
    }
    return out;
}

impl MTRuntime.parse_response(response: str) -> any {
    if self.resp_type is None or self.resp_type is str or response.strip() == "" {
        return response;
    }
    if self.resp_type {
        try {
            json_dict = json.loads(response);
            return json_to_instance(json_dict, self.resp_type);
        } except OutputConversionError {
            raise;
        } except Exception as e {
            err = OutputConversionError(
                f"Failed to convert LLM output to '{self.resp_type.__name__}': {e}"
            );
            setattr(err, "raw_output", response);
            raise err;
        }
    }
    return response;
}

impl MTRuntime.get_tool(tool_name: str) -> Tool | McpTool | None {
    for tool in self.tools {
        if tool.get_name() == tool_name {
            return tool;
        }
    }
    return None;
}

impl MTRuntime.get_tool_list -> list[dict] {
    return [tool.get_json_schema() for tool in self.tools];
}

impl MTRuntime.get_output_schema -> dict | None {
    assert (len(self.tools) == 0 or self.get_tool("finish_tool") is not None);
    if len(self.tools) == 0 {
        return self.get_typed_output_schema();
    }

    return None;
}

impl MTRuntime.get_typed_output_schema -> dict | None {
    if self.resp_type is None or self.resp_type is str {
        return None;
    }

    owner = self.mtir;
    owner_info = owner.ir_info if owner else None;
    return_type_info = owner_info.return_type
        if isinstance(owner_info, FunctionInfo)
        else None;
    return type_to_schema(resp_type=self.resp_type, info=return_type_info);
}

impl MTIR.runtime.getter -> MTRuntime {
    return MTRuntime.factory(self);
}
