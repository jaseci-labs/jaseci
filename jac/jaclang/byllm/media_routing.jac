import from jaclang.byllm._optdeps.litellm { litellm, HAS_LITELLM }
import from jaclang.byllm.types {
    DEFAULT_AUDIO_FORMAT,
    KIND_AUDIO,
    KIND_IMAGE,
    KIND_NONE,
    KIND_VIDEO,
    media_kind
}

glob ROUTE_CHAT = "chat",
     ROUTE_IMAGE_ENDPOINT = "image_endpoint",
     ROUTE_SPEECH_ENDPOINT = "speech_endpoint",
     ROUTE_VIDEO_ENDPOINT = "video_endpoint",
     ROUTE_TRANSCRIPTION_ENDPOINT = "transcription_endpoint",
     ROUTE_UNSUPPORTED = "unsupported";

glob MODE_IMAGE = "image_generation",
     MODE_SPEECH = "audio_speech",
     MODE_TRANSCRIPTION = "audio_transcription",
     MODE_VIDEO = "video_generation";

glob DEFAULT_VOICE = "alloy";


def model_entry(model_name: str) -> dict {
    if not HAS_LITELLM or not model_name {
        return {};
    }
    try {
        cost_map: any = litellm.model_cost;
    } except Exception {
        return {};
    }
    found = cost_map.get(model_name);
    if isinstance(found, dict) {
        return found;
    }

    if "/" in model_name {
        found = cost_map.get(model_name.split("/", 1)[1]);
        if isinstance(found, dict) {
            return found;
        }
    }
    return {};
}


def output_modalities(model_name: str) -> list[str] {
    mods = model_entry(model_name).get("supported_output_modalities");
    return [str(m) for m in mods] if isinstance(mods, list) else [];
}


def model_mode(model_name: str) -> str {
    return str(model_entry(model_name).get("mode") or "");
}


def is_known_model(model_name: str) -> bool {
    return bool(model_entry(model_name));
}


def chat_emits_audio(model_name: str) -> bool {
    if not HAS_LITELLM {
        return False;
    }
    try {
        return bool(litellm.supports_audio_output(model_name));
    } except Exception {
        return False;
    }
}


glob _INLINE_IMAGE_PROVIDERS: tuple = ("gemini", "vertex_ai");


def chat_emits_image(model_name: str) -> bool {
    if KIND_IMAGE not in output_modalities(model_name) {
        return False;
    }
    lowered = model_name.lower();
    return any(p in lowered for p in _INLINE_IMAGE_PROVIDERS);
}


def resolve_route(
    resp_type: type | None, model_name: str, input_kinds: list = []
) -> str {
    kind = media_kind(resp_type);
    mode = model_mode(model_name);
    unknown = not is_known_model(model_name);

    if kind == KIND_NONE {
        if mode == MODE_TRANSCRIPTION and KIND_AUDIO in input_kinds {
            return ROUTE_TRANSCRIPTION_ENDPOINT;
        }
        return ROUTE_CHAT;
    }
    if kind == KIND_VIDEO {
        if mode == MODE_VIDEO or unknown {
            return ROUTE_VIDEO_ENDPOINT;
        }
        return ROUTE_UNSUPPORTED;
    }
    if kind == KIND_IMAGE {
        if chat_emits_image(model_name) or unknown {
            return ROUTE_CHAT;
        }
        if mode == MODE_IMAGE {
            return ROUTE_IMAGE_ENDPOINT;
        }
        return ROUTE_UNSUPPORTED;
    }
    if chat_emits_audio(model_name) or unknown {
        return ROUTE_CHAT;
    }
    if mode == MODE_SPEECH {
        return ROUTE_SPEECH_ENDPOINT;
    }
    return ROUTE_UNSUPPORTED;
}


def route_error(route: str, resp_type: type | None, model_name: str) -> str {
    if route != ROUTE_UNSUPPORTED {
        return "";
    }
    kind = media_kind(resp_type);
    mode = model_mode(model_name) or "chat";
    hint = {
        KIND_IMAGE: "an image model such as `dall-e-3`, or an image-capable "
        "chat model such as `gemini/gemini-2.5-flash-image`",
        KIND_AUDIO: "a text-to-speech model such as `tts-1`, or an "
        "audio-capable chat model such as `gpt-audio`",
        KIND_VIDEO: "a video model such as `sora-2`"
    }.get(
        kind, "a model that can produce it"
    );
    return (f"Model `{model_name}` (mode `{mode}`) cannot produce {kind}. Use {hint}.");
}


def audio_output_params(call_params: dict) -> dict {
    return {
        "modalities": ["text", KIND_AUDIO],
        "audio": {
            "voice": str(call_params.get("voice") or DEFAULT_VOICE),
            "format": str(call_params.get("audio_format") or DEFAULT_AUDIO_FORMAT),

        },

    };
}
