impl Model.postinit -> None {
    self.proxy = bool(self.config.get("proxy", _model_config.get("proxy", False)));
    self.http_client = bool(
        self.config.get("http_client", _model_config.get("http_client", False))
    );

    if not self.api_key {
        self.api_key = self.config.get("api_key", "")
            or _model_config.get("api_key", "");
    }

    if self.model_name == MODEL_MOCK {
        self._mock_delegate = MockLLM(model_name=self.model_name, config=self.config);
    }

    if self.model_name.startswith("local:") {
        self._local_delegate = LocalLLM(
            model_name=self.model_name,
            ctx_window=self.ctx_window,
            config=self.config,
            call_params=self.call_params
        );
    }
    if not self._mock_delegate and not self._local_delegate {
        import from jaclang.byllm._optdeps.litellm { HAS_LITELLM }
        logging.getLogger("httpx").setLevel(logging.WARNING);
        if HAS_LITELLM {
            if not _litellm_config.get("debug", False) {
                _disable_debugging();
            }
            litellm.drop_params = _litellm_config.get("drop_params", True);
        }

        native_override = self.config.get(
            "native_tools", _model_config.get("native_tools")
        );
        if native_override is not None {
            self.supports_native_tools = bool(native_override);
        } elif _model_lacks_tool_role(self.model_name) {
            self.supports_native_tools = False;
        }
    }
}


glob _NO_TOOL_ROLE_FAMILIES: list[str] = ["gemma"];

def _model_lacks_tool_role(model_name: str) -> bool {
    lowered = model_name.lower();
    for fam in _NO_TOOL_ROLE_FAMILIES {
        if fam in lowered {
            return True;
        }
    }
    return False;
}

impl Model.invoke(mt_run: MTRuntime) -> any {
    import types as _types_mod;
    (ctx_token, start) = _begin_invocation(mt_run);
    try {
        if self._mock_delegate {
            result = self._mock_delegate.invoke(mt_run);
        } elif self._local_delegate {
            result = self._local_delegate.invoke(mt_run);
        } else {
            result = super.invoke(mt_run);
        }
        if isinstance(result, _types_mod.GeneratorType) {
            _current_invocation_id.reset(ctx_token);
            return _stream_with_telemetry(result, mt_run, self.model_name, start);
        }
        _end_invocation(mt_run, result, self.model_name, start, ctx_token);
        return result;
    } except Exception as e {
        _fail_invocation(mt_run, e, self.model_name, start, ctx_token);
        raise;
    }
}

# BaseLLM.ainvoke serves the no-tools shapes itself and hands every other
# shape to invoke, which already reports; only the direct shapes need wrapping.
impl Model.ainvoke(mt_run: MTRuntime) -> any {
    import types as _types_mod;
    logging_stream = mt_run.stream and mt_run.call_params.get("logging", False);
    if mt_run.tools or logging_stream {
        return await super.ainvoke(mt_run);
    }
    (ctx_token, start) = _begin_invocation(mt_run);
    try {
        result = await super.ainvoke(mt_run);
        if isinstance(result, _types_mod.AsyncGeneratorType) {
            _current_invocation_id.reset(ctx_token);
            return _astream_with_telemetry(result, mt_run, self.model_name, start);
        }
        _end_invocation(mt_run, result, self.model_name, start, ctx_token);
        return result;
    } except Exception as e {
        _fail_invocation(mt_run, e, self.model_name, start, ctx_token);
        raise;
    }
}

def _begin_invocation(mt_run: MTRuntime) -> tuple {
    import uuid;
    import time;
    invocation_id = str(uuid.uuid4());
    setattr(mt_run, "_parent_invocation_id", _current_invocation_id.get(None));
    setattr(mt_run, "_invocation_id", invocation_id);
    return (_current_invocation_id.set(invocation_id), time.time());
}

def _end_invocation(
    mt_run: MTRuntime, result: object, model_name: str, start: float, ctx_token: any
) -> None {
    import time;
    _emit_agent_telemetry(
        mt_run, result, model_name, (time.time() - start) * 1000, "success", None
    );
    _current_invocation_id.reset(ctx_token);
}

def _fail_invocation(
    mt_run: MTRuntime,
    error: Exception,
    model_name: str,
    start: float,
    ctx_token: any
) -> None {
    import time;
    _emit_agent_telemetry(
        mt_run, None, model_name, (time.time() - start) * 1000, "error", error
    );
    _current_invocation_id.reset(ctx_token);
}

"""Iterate `gen` with the invocation id in scope and report once it finishes."""
def _stream_with_telemetry(
    gen: object, mt: object, model_name: str, start: float
) -> object {
    import contextvars;
    import time;

    ctx = _invocation_context(mt);
    _completed = False;
    try {
        while True {
            try {
                item = ctx.run(next, gen);
            } except StopIteration {
                _completed = True;
                break;
            }
            yield item;
        }
    } except Exception as inner_e {
        _emit_agent_telemetry(
            mt, None, model_name, (time.time() - start) * 1000, "error", inner_e
        );
        raise;
    } finally {
        if _completed {
            _emit_agent_telemetry(
                mt,
                "[streaming]",
                model_name,
                (time.time() - start) * 1000,
                "success",
                None
            );
        }
    }
}

async def _astream_with_telemetry(
    agen: any, mt: object, model_name: str, start: float
) -> object {
    import asyncio;
    import time;

    ctx = _invocation_context(mt);
    _completed = False;
    try {
        while True {
            try {
                item = await asyncio.create_task(agen.__anext__(), context=ctx);
            } except StopAsyncIteration {
                _completed = True;
                break;
            }
            yield item;
        }
    } except Exception as inner_e {
        _emit_agent_telemetry(
            mt, None, model_name, (time.time() - start) * 1000, "error", inner_e
        );
        raise;
    } finally {
        if _completed {
            _emit_agent_telemetry(
                mt,
                "[streaming]",
                model_name,
                (time.time() - start) * 1000,
                "success",
                None
            );
        }
    }
}

def _invocation_context(mt: object) -> any {
    import contextvars;
    ctx = contextvars.copy_context();
    invocation_id = mt?._invocation_id;
    if invocation_id is not None {
        ctx.run(_current_invocation_id.set, invocation_id);
    }
    return ctx;
}

impl Model._raise_mapped_provider_error(e: Exception) -> None {
    if isinstance(
        e, (litellm.exceptions.AuthenticationError, openai.AuthenticationError)
    ) {
        logger.error(f"LLM AuthenticationError: {e}");
        raise AuthenticationError(str(e));
    }
    if isinstance(e, (litellm.exceptions.RateLimitError, openai.RateLimitError)) {
        logger.error(f"LLM RateLimitError: {e}");
        raise RateLimitError(str(e));
    }
    if isinstance(e, (litellm.exceptions.NotFoundError, openai.NotFoundError)) {
        logger.error(f"LLM ModelNotFoundError: {e}");
        raise ModelNotFoundError(str(e));
    }
    logger.error(f"LLM call failed with {type(e).__name__}: {e}");
    raise;
}

impl Model.model_call_no_stream(params: dict) -> dict {
    try {
        if self.http_client {
            response = self.model_call_http(
                url=self.api_base,
                token=self.api_key,
                payload=params,
                ca_bundle=self.config.get("ca_bundle", None),
            );
        } elif self.proxy {
            require_optional("openai", "llm");
            client = OpenAI(base_url=self.api_base, api_key=self.api_key or None);
            response = client.chat.completions.create(**params);
        } else {
            require_optional("litellm", "llm");
            response = litellm.completion(
                api_key=self.api_key or None, api_base=self.api_base or None, **params
            );
        }
    } except Exception as e {
        self._raise_mapped_provider_error(e);
    }
    return response;
}

impl Model.model_call_with_stream(params: dict) {
    params["stream_options"] = (params.get("stream_options") or {})
        | {"include_usage": True};
    try {
        if self.proxy {
            require_optional("openai", "llm");
            client = OpenAI(base_url=self.api_base, api_key=self.api_key or None);
            response = client.chat.completions.create(stream=True, **params);
        } else {
            require_optional("litellm", "llm");
            response = litellm.completion(
                stream=True,
                api_key=self.api_key or None,
                api_base=self.api_base or None,
                **params
            );
        }
    } except litellm.exceptions.AuthenticationError as e {
        raise AuthenticationError(str(e));
    } except openai.AuthenticationError as e {
        raise AuthenticationError(str(e));
    } except litellm.exceptions.RateLimitError as e {
        raise RateLimitError(str(e));
    } except openai.RateLimitError as e {
        raise RateLimitError(str(e));
    } except litellm.exceptions.NotFoundError as e {
        raise ModelNotFoundError(str(e));
    } except openai.NotFoundError as e {
        raise ModelNotFoundError(str(e));
    }
    return response;
}

impl Model.model_call_http(
    url: str, token: str, payload: dict, ca_bundle: (str | bool | None)
) -> object {
    import httpx;
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}"};
    client = httpx.Client(verify=ca_bundle or True, timeout=60.0);
    with client {
        response = client.post(url=url, headers=headers, json=payload);
    }
    return response.json();
}

impl Model.model_call_no_stream_async(params: dict) -> dict {
    try {
        if self.http_client {
            response = await self.model_call_http_async(
                url=self.api_base,
                token=self.api_key,
                payload=params,
                ca_bundle=self.config.get("ca_bundle", None),
            );
        } elif self.proxy {
            require_optional("openai", "llm");
            if not self._async_proxy_client {
                self._async_proxy_client = AsyncOpenAI(
                    base_url=self.api_base, api_key=self.api_key or None
                );
            }
            async_client = self._async_proxy_client;
            assert async_client is not None;
            response = await async_client.chat.completions.create(**params);
        } else {
            require_optional("litellm", "llm");
            response = await litellm.acompletion(
                api_key=self.api_key or None, api_base=self.api_base or None, **params
            );
        }
    } except Exception as e {
        self._raise_mapped_provider_error(e);
    }
    return response;
}

impl Model.model_call_with_stream_async(params: dict) {
    params["stream_options"] = (params.get("stream_options") or {})
        | {"include_usage": True};
    try {
        if self.http_client {
            response = await self.model_call_http_async(
                url=self.api_base,
                token=self.api_key,
                payload=params | {"stream": True},
                ca_bundle=self.config.get("ca_bundle", None),
            );
        } elif self.proxy {
            require_optional("openai", "llm");
            if not self._async_proxy_client {
                self._async_proxy_client = AsyncOpenAI(
                    base_url=self.api_base, api_key=self.api_key or None
                );
            }
            async_client = self._async_proxy_client;
            assert async_client is not None;
            response = await async_client.chat.completions.create(
                stream=True, **params
            );
        } else {
            require_optional("litellm", "llm");
            response = await litellm.acompletion(
                stream=True,
                api_key=self.api_key or None,
                api_base=self.api_base or None,
                **params
            );
        }
    } except Exception as e {
        self._raise_mapped_provider_error(e);
    }
    return response;
}

impl Model.model_call_http_async(
    url: str, token: str, payload: dict, ca_bundle: (str | bool | None)
) -> object {
    import httpx;
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}"};
    client = httpx.AsyncClient(verify=ca_bundle or True, timeout=60.0);
    async with client {
        response = await client.post(url=url, headers=headers, json=payload);
    }
    return response.json();
}
