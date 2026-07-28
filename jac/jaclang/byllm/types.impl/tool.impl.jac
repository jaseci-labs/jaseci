"""Validate the function and extract its type annotations and description."""
impl Tool.postinit -> None {
    try {
        annotations = get_type_hints(self.func);
    } except Exception {
        annotations = getattr(self.func, '__annotations__', {}) or {};
    }
    with suppress(Exception) {
        self.func.__annotations__ = annotations;
    }
    # A description handed to the constructor is deliberate and more specific
    # than anything derivable from the function -- only derive when it is
    # absent. `make_finish_tool` passes both of these, and overwriting them put
    # the bare name "finish_tool" and a `<class '...'>` repr into the prompt.
    if not self.description {
        self.description = Tool.get_func_description(self.func);
    }
    if self.params_desc is None {
        if self.func?._jac_semstr_inner {
            self.params_desc = self.func._jac_semstr_inner;  # type: ignore
        } else {
            self.params_desc = {
                name: str(type) for (name, type) in annotations.items()
            };
        }
    }
    # Pick up serialize/timeout_sec from function attributes if set by the user.
    if self.func?._serialize is not None {
        self.serialize = self.func._serialize;  # type: ignore
    }
    if self.func?._timeout_sec is not None {
        self.timeout_sec = self.func._timeout_sec;  # type: ignore
    }
}

"""Call the tool function with the provided arguments."""
impl Tool.__call__(*args: list, **kwargs: dict) -> object {
    # If there is an error with the finish tool, we throw the exception.
    # Since it's the user's responsibility to handle it.
    if self.is_finish_tool() {
        return self.func(*args, **kwargs);
    }
    try {
        # TODO: Should I json serialize or this is fine?
        return self.func(*args, **kwargs);
    } except Exception as e {
        # For the LLM if the tool failed, it'll see the error message
        logger.exception("Tool execution failed");
        return f"Tool error: {e}";
    }
}

"""Return the name of the tool function."""
impl Tool.get_name -> str {
    return self.func.__name__;
}

"""Get the description of the function from semstring or docstring."""
impl Tool.get_func_description(func: Callable) -> str {
    if func?._jac_semstr {
        return func._jac_semstr;  # type: ignore
    }
    return func.__doc__ or func.__name__;
}

"""Create a finish tool that validates and returns the final output."""
impl Tool.make_finish_tool(resp_type: type, resp_info: Info = None) -> Tool {
    def finish_tool(final_output: object) -> object {
        try {
            return TypeAdapter(resp_type).validate_python(final_output);
        } except Exception as e {
            raise FinishToolError(
                f"finish_tool output does not match expected type '{resp_type.__name__}': {e}"
            );
        }
    }
    finish_tool.__annotations__["return"] = resp_type;
    finish_tool.__annotations__["final_output"] = resp_type;
    # With tools present there is no response_format, so this tool's parameter
    # IS the output contract. Carrying the return type's MTIR info through as a
    # FieldInfo -- the shape `_type_to_schema` already unwraps via
    # `info.type_info.fields` -- keeps every field semstring the schema would
    # have had without tools. Passing nothing dropped them all.
    # tool_to_schema stamps params_desc over the parameter's own description,
    # so fold the return type's semstring in rather than losing it.
    out_desc = "The final output of the tool calls.";
    if resp_info is not None and resp_info?.semstr {
        out_desc += " " + resp_info.semstr;
    }
    info = None;
    if resp_info is not None {
        info = FunctionInfo(
            name="finish_tool",
            semstr="This tool is used to finish the tool calls and return the final output.",
            params=[
                FieldInfo(
                    name="final_output",
                    semstr="The final output of the tool calls.",
                    type_info=resp_info
                )
            ]
        );
    }
    return Tool(
        func=finish_tool,
        description="This tool is used to finish the tool calls and return the final output.",
        params_desc={"final_output": out_desc,},
        info=info,
    );
}

"""Check if the tool is a finish tool."""
impl Tool.is_finish_tool -> bool {
    return self.get_name() == "finish_tool";
}

"""Return the JSON schema for the tool function."""
impl Tool.get_json_schema -> dict[str, object] {
    return tool_to_schema(self.func, self.description, self.params_desc, self.info);
}

"""Parse the arguments from JSON to the function's expected types."""
impl Tool.parse_arguments(args_json: dict) -> dict {
    args = {};
    annotations: dict = {};
    try {
        annotations = self.func.__annotations__;
    } except AttributeError {
        annotations = get_type_hints(self.func);
    }
    for (arg_name, arg_json) in args_json.items() {
        if arg_type := annotations.get(arg_name) {
            args[arg_name] = TypeAdapter(arg_type).validate_python(arg_json);
        }
    }
    return args;
}
