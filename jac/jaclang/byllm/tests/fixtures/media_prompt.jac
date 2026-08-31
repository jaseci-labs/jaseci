"""The generation routes get a flat prompt, not the chat message list.

An image model receives `media_prompt` verbatim, so the system persona and the
tuple-repr argument lines that suit a chat completion must not appear in it.
"""

import from jaclang.byllm.lib { Image, MockLLM }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { CompletionResult }

obj CaptureLLM(MockLLM) {
    has seen: list = [];

    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
        self.seen.append(
            (mt_run.media_prompt, mt_run.get_msg_list(), mt_run.media_text)
        );
        return super.dispatch_no_streaming(mt_run);
    }
}

glob llm = CaptureLLM(
         model_name="mockllm", config={"outputs": [Image("https://e.com/a.png")]}
     );

"""Draw the described picture."""
def draw(subject: str, palette: str) -> Image by llm();

with entry {
    draw("a red fox in snow", "muted blues");
    (prompt, messages, spoken) = llm.seen[0];
    print(f"PROMPT:{prompt}");
    print(f"NO_PERSONA:{'return only the output' not in prompt.lower()}");
    print(f"NO_TUPLE_REPR:{'(' not in prompt}");
    print(f"HAS_DOCSTRING:{'Draw the described picture.' in prompt}");
    print(f"HAS_VALUES:{'a red fox in snow' in prompt and 'muted blues' in prompt}");
    # The chat message list is still built; only the media route bypasses it.
    print(f"CHAT_MSGS_INTACT:{len(messages) >= 2}");
    # A speech endpoint reads its input verbatim, so the docstring would be
    # spoken as content rather than obeyed as direction.
    print(f"SPOKEN_TEXT:{spoken!r}");
    print(f"SPOKEN_NO_DOCSTRING:{'Draw the described picture' not in spoken}");
    print(f"SPOKEN_NO_LABELS:{'subject:' not in spoken}");
    print(f"SPOKEN_HAS_VALUES:{'a red fox in snow' in spoken}");
}
