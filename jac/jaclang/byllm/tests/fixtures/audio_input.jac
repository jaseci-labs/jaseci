"""Audio input reaches the provider payload as an `input_audio` block.

Captures the serialized message list the backend would send, so the assertion
is on the real request shape rather than on a stringified prompt.
"""

import os;
import json;
import from jaclang.byllm.lib { Audio, MockLLM }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { CompletionResult }

obj CaptureLLM(MockLLM) {
    has captured: list = [];

    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
        self.captured.append(mt_run.get_msg_list());
        return super.dispatch_no_streaming(mt_run);
    }
}

glob llm = CaptureLLM(model_name="mockllm", config={"outputs": ["a short beep"]});

"""Describe what is audible in this clip."""
def describe_clip(clip: Audio) -> str by llm();

with entry {
    path = os.path.join(os.path.dirname(__file__), "silence.wav");
    answer = describe_clip(Audio(path));
    print(f"ANSWER:{answer}");
    user_msg = [
        m
        for m in llm.captured[0]
        if m["role"] == "user"
    ][0];
    blocks = user_msg["content"];
    kinds = [b["type"] for b in blocks];
    print(f"BLOCK_KINDS:{json.dumps(kinds)}");
    audio_block = [
        b
        for b in blocks
        if b["type"] == "input_audio"
    ][0];
    print(f"AUDIO_FORMAT:{audio_block['input_audio']['format']}");
    print(f"AUDIO_HAS_DATA:{bool(audio_block['input_audio']['data'])}");
    # The semstring rides as a text prelude, not swallowed into the audio block.
    print(f"SEMSTRING_PRESENT:{'audible' in blocks[0]['text']}");
}
