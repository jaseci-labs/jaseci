import time;
import from jaclang.byllm._optdeps.litellm { litellm }
import from jaclang.project.capabilities { require_optional }
import from jaclang.byllm.types { Audio, Image, Video }
import from jaclang.byllm.exceptions { ByLLMError }

glob VIDEO_POLL_INTERVAL_SEC = 5.0,
     VIDEO_POLL_TIMEOUT_SEC = 600.0;


def _passthrough(call_params: dict, allowed: list[str]) -> dict {
    out: dict = {};
    for key in allowed {
        value = call_params.get(key);
        if value is not None {
            out[key] = value;
        }
    }
    return out;
}


def _image_from_response(response: object) -> Image {
    data = (dict(response).get("data") or []) if response is not None else [];
    for item in data {
        row: any = item;
        url = row.get("url") if isinstance(row, dict) else row?.url;
        if url {
            return Image(url=str(url));
        }
        b64 = row.get("b64_json") if isinstance(row, dict) else row?.b64_json;
        if b64 {
            return Image(url=f"data:image/png;base64,{b64}");
        }
    }
    raise ByLLMError("Image endpoint returned no image data.");
}


def _binary_content(response: object) -> bytes {
    if isinstance(response, bytes) {
        return response;
    }
    content = response?.content;
    if isinstance(content, bytes) {
        return content;
    }
    reader = response?.read;
    if reader and callable(reader) {
        return bytes(reader());
    }
    raise ByLLMError("Endpoint returned no binary content.");
}


glob _IMAGE_PARAMS = ["n", "quality", "size", "style", "response_format", "user"],
     _SPEECH_PARAMS = ["response_format", "speed", "instructions"],
     _TRANSCRIBE_PARAMS = ["language", "prompt", "response_format", "temperature"],
     _VIDEO_PARAMS = ["seconds", "size", "input_reference", "user"];


def generate_image(prompt: str, model: str, api_key: str, call_params: dict) -> Image {
    require_optional("litellm", "llm");
    response: any = litellm.image_generation(
        prompt=prompt,
        model=model,
        api_key=api_key or None,
        **_passthrough(call_params, _IMAGE_PARAMS)
    );
    return _image_from_response(response);
}


async def agenerate_image(
    prompt: str, model: str, api_key: str, call_params: dict
) -> Image {
    require_optional("litellm", "llm");
    response: any = await litellm.aimage_generation(
        prompt=prompt,
        model=model,
        api_key=api_key or None,
        **_passthrough(call_params, _IMAGE_PARAMS)
    );
    return _image_from_response(response);
}


def synthesize_speech(
    prompt: str, model: str, api_key: str, call_params: dict
) -> Audio {
    require_optional("litellm", "llm");
    fmt = str(call_params.get("audio_format") or "mp3");
    params = _passthrough(call_params, _SPEECH_PARAMS);
    params.setdefault("response_format", fmt);
    response: any = litellm.speech(
        model=model,
        input=prompt,
        voice=call_params.get("voice") or "alloy",
        api_key=api_key or None,
        **params
    );
    import base64;
    return Audio.from_b64(
        base64.b64encode(_binary_content(response)).decode("utf-8"),
        str(params["response_format"])
    );
}


async def asynthesize_speech(
    prompt: str, model: str, api_key: str, call_params: dict
) -> Audio {
    require_optional("litellm", "llm");
    fmt = str(call_params.get("audio_format") or "mp3");
    params = _passthrough(call_params, _SPEECH_PARAMS);
    params.setdefault("response_format", fmt);
    response: any = await litellm.aspeech(
        model=model,
        input=prompt,
        voice=call_params.get("voice") or "alloy",
        api_key=api_key or None,
        **params
    );
    import base64;
    return Audio.from_b64(
        base64.b64encode(_binary_content(response)).decode("utf-8"),
        str(params["response_format"])
    );
}


def transcribe(clip: Audio, model: str, api_key: str, call_params: dict) -> str {
    require_optional("litellm", "llm");
    import base64;
    payload = (f"audio.{clip.format or 'wav'}", base64.b64decode(clip._b64));
    response: any = litellm.transcription(
        model=model,
        file=payload,
        api_key=api_key or None,
        **_passthrough(call_params, _TRANSCRIBE_PARAMS)
    );
    return str(response?.text or "");
}


async def atranscribe(clip: Audio, model: str, api_key: str, call_params: dict) -> str {
    require_optional("litellm", "llm");
    import base64;
    payload = (f"audio.{clip.format or 'wav'}", base64.b64decode(clip._b64));
    response: any = await litellm.atranscription(
        model=model,
        file=payload,
        api_key=api_key or None,
        **_passthrough(call_params, _TRANSCRIBE_PARAMS)
    );
    return str(response?.text or "");
}


def _video_budget(call_params: dict) -> tuple {
    interval = float(call_params.get("poll_interval") or VIDEO_POLL_INTERVAL_SEC);
    timeout = float(call_params.get("poll_timeout") or VIDEO_POLL_TIMEOUT_SEC);
    return (interval, timeout);
}


def _video_pending(status: object, video_id: str) -> bool {
    state = str(status?.status or "");
    if state in ("failed", "cancelled", "error") {
        detail = status?.error or state;
        raise ByLLMError(f"Video job {video_id} {state}: {detail}");
    }
    return state != "completed";
}


def generate_video(prompt: str, model: str, api_key: str, call_params: dict) -> Video {
    require_optional("litellm", "llm");
    job: any = litellm.video_generation(
        prompt=prompt,
        model=model,
        api_key=api_key or None,
        **_passthrough(call_params, _VIDEO_PARAMS)
    );
    video_id = str(job?.id or "");
    if not video_id {
        raise ByLLMError("Video endpoint returned no job id.");
    }
    (interval, timeout) = _video_budget(call_params);
    waited = 0.0;
    while _video_pending(litellm.video_status(video_id=video_id), video_id) {
        if waited >= timeout {
            raise ByLLMError(
                f"Video job {video_id} did not finish within {timeout:.0f}s. "
                f"Raise the budget with `by llm(poll_timeout=<seconds>)`."
            );
        }
        time.sleep(interval);
        waited += interval;
    }
    return Video.from_bytes(bytes(litellm.video_content(video_id=video_id)));
}


async def agenerate_video(
    prompt: str, model: str, api_key: str, call_params: dict
) -> Video {
    require_optional("litellm", "llm");
    import asyncio;
    job: any = await litellm.avideo_generation(
        prompt=prompt,
        model=model,
        api_key=api_key or None,
        **_passthrough(call_params, _VIDEO_PARAMS)
    );
    video_id = str(job?.id or "");
    if not video_id {
        raise ByLLMError("Video endpoint returned no job id.");
    }
    (interval, timeout) = _video_budget(call_params);
    waited = 0.0;
    while _video_pending(await litellm.avideo_status(video_id=video_id), video_id) {
        if waited >= timeout {
            raise ByLLMError(
                f"Video job {video_id} did not finish within {timeout:.0f}s. "
                f"Raise the budget with `by llm(poll_timeout=<seconds>)`."
            );
        }
        await asyncio.sleep(interval);
        waited += interval;
    }
    return Video.from_bytes(bytes(await litellm.avideo_content(video_id=video_id)));
}
