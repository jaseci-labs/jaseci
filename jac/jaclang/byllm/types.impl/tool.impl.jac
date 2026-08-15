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
        return self.func(*args, **_coerce_kwargs(self.func, kwargs));
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

"""Get the description of the function: its name, plus semstring or docstring.

The semstring AUGMENTS the identifier rather than replacing it. Returning the
sem alone made an annotated function strictly lossier than a bare one -- the
model saw `generate_code` without a sem, but lost that name the moment one was
attached, even though the identifier is often the most informative token in the
prompt. Callers that want the name on its own use `get_name`.
"""
impl Tool.get_func_description(func: Callable) -> str {
    name = func.__name__;
    detail = ((func?._jac_semstr or func.__doc__) or "").strip();
    return f"{name}: {detail}" if detail else name;
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
    # `get_type_hints` first, NOT `__annotations__`: the raw mapping holds
    # unresolved strings ('Date'), and `postinit` cannot cache the resolved
    # ones when `func` is a bound method -- assigning to a method's
    # `__annotations__` raises and is suppressed. Feeding a forward-ref string
    # to `TypeAdapter` fails with "not fully defined", which upstream reports
    # as "invalid tool arguments".
    annotations: dict = {};
    try {
        annotations = get_type_hints(self.func);
    } except Exception {
        annotations = getattr(self.func, "__annotations__", None) or {};
    }
    for (arg_name, arg_json) in args_json.items() {
        if arg_type := annotations.get(arg_name) {
            args[arg_name] = _coerce_arg(arg_json, arg_type);
        }
    }
    return args;
}


"""Coerce every keyword argument against the callable's annotations.

Unlike `parse_arguments`, an unannotated argument is kept rather than dropped:
this runs on the direct-call path, where the caller picked the arguments.
"""
def _coerce_kwargs(func: Callable, kwargs: dict) -> dict {
    annotations: dict = {};
    with suppress(Exception) {
        annotations = get_type_hints(func);
    }
    if not annotations {
        with suppress(Exception) {
            annotations = getattr(func, "__annotations__", None) or {};
        }
    }
    return {
        key: _coerce_arg(value, annotations.get(key))
        for (key, value) in kwargs.items()
    };
}


"""Coerce one JSON-decoded value into its annotated type.

Pydantic covers the ordinary cases, but `TypeAdapter` cannot always build an
adapter for a Jac-compiled archetype -- it raises `PydanticUserError: ... is
not fully defined`, which upstream turns into an "invalid tool arguments"
error the model can only guess at. Fall back to constructing the dataclass
directly in that case. A value that cannot be converted is passed through
untouched, so the tool (or its own error) stays the decider.
"""
def _coerce_arg(value: object, ty: object) -> object {
    if ty is None {
        return value;
    }
    with suppress(Exception) {
        return TypeAdapter(ty).validate_python(value);
    }
    return _coerce_structurally(value, ty);
}


"""Structural coercion used when pydantic cannot build an adapter for `ty`."""
def _coerce_structurally(value: object, ty: object) -> object {
    if get_origin(ty) is list and isinstance(value, list) {
        members = get_args(ty);
        return [_coerce_arg(item, members[0]) for item in value] if members else value;
    }
    # An enum argument arrives as its member name ("HIGH") at least as often as
    # its value (3) -- the tool schema advertises both, and `TypeAdapter` only
    # ever matches by value. Without this the bare string reached the tool and
    # it died on `.name`/`.value`, which the model saw as an opaque
    # "Tool error: 'str' object has no attribute 'name'".
    # `[ty] + get_args(ty)` covers a plain enum and `Priority | None` alike.
    for candidate in [ty] + list(get_args(ty)) {
        if isinstance(candidate, type) and issubclass(candidate, Enum) {
            member = _coerce_enum(value, candidate);
            if member is not None {
                return member;
            }
        }
    }
    if not isinstance(value, dict) {
        return value;
    }
    # `obj` directly, or wrapped as `obj | None` / `Optional[obj]` -- get_args
    # is empty for a plain class, so this covers both without naming UnionType.
    for candidate in [ty] + list(get_args(ty)) {
        if is_dataclass(candidate) {
            with suppress(Exception) {
                return _build_dataclass(value, candidate);
            }
        }
    }
    return value;
}


"""Resolve an enum member from its value or its name; None when neither matches.

Returning None rather than raising keeps `_coerce_structurally` free to fall
through to its remaining strategies and, ultimately, to pass the value on
untouched so the tool stays the decider.
"""
def _coerce_enum(value: object, ty: type) -> object {
    if isinstance(value, ty) {
        return value;
    }
    with suppress(Exception) {
        return ty(value);  # by value: 3 -> HIGH, "open" -> OPEN
    }
    if not isinstance(value, str) {
        return None;
    }
    with suppress(Exception) {
        return ty[value];  # by exact name: "HIGH" -> HIGH
    }
    # Case-insensitive name match, then a stringified value ("3" for HIGH = 3).
    lowered = value.strip().lower();
    for member in ty {
        if member.name.lower() == lowered or str(member.value).lower() == lowered {
            return member;
        }
    }
    return None;
}


"""Build a dataclass from a JSON object, coercing each field the same way."""
def _build_dataclass(value: dict, ty: type) -> object {
    hints: dict = {};
    with suppress(Exception) {
        hints = get_type_hints(ty);
    }
    return ty(
        **{
            key: _coerce_arg(item, hints.get(key))
            for (key, item) in value.items()
            if not key.startswith("_")
        }
    );
}
