"""Fake LLM for testing."""

import json

from mtllm.llms.base import (
    BaseLLM,
    NORMAL_SUFFIX,
    REASON_SUFFIX,
    CHAIN_OF_THOUGHT_SUFFIX,
    REACT_SUFFIX,
)


class FakeLLM(BaseLLM):
    """Fake LLM for testing."""

    MTLLM_METHOD_PROMPTS: dict[str, str] = {
        "Normal": NORMAL_SUFFIX,
        "Reason": REASON_SUFFIX,
        "Chain-of-Thoughts": CHAIN_OF_THOUGHT_SUFFIX,
        "ReAct": REACT_SUFFIX,
    }

    def __init__(
        self,
        verbose: bool = False,
        max_tries: int = 10,
        type_check: bool = False,
        **kwargs: dict
    ) -> None:
        """Initialize the FakeLLM client."""
        super().__init__(verbose, max_tries, type_check)
        self.responses = self.get_responses(**kwargs)
        self.default: str | None = kwargs.get("default")
        self.print_prompt: bool = kwargs.get("print_prompt", False)


    def __infer__(self, meaning_in: str | list[dict], **kwargs: dict) -> str:
        """Infer a response from the input meaning."""
        if self.print_prompt:
            print(meaning_in)
        if isinstance(meaning_in, str):
            if meaning_in not in self.responses:
                if self.default is not None:
                    return self.default
                if not self.print_prompt:
                    print(meaning_in)
                print(json.dumps(meaning_in))
                print()
            return self.responses[meaning_in]
        return self.default or ""


    def get_responses(self, **kwargs: dict) -> dict[str, str]:
        if responses := kwargs.get("responses"):
            return responses
        if responses_file := kwargs.get("responses_file"):
            with open(responses_file, 'r') as file:
                return json.load(file)
        return {}

