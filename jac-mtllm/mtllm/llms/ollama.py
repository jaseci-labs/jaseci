"""Ollama client for MTLLM."""

from mtllm.llms.base import (
    BaseLLM,
    CompletionRequest,
    CompletionResult,
    Tool,
    ToolCall,
)

REASON_SUFFIX = """
Reason and return the output result(s) only, adhering to the provided Type in the following format

[Reasoning] <Reason>
[Output] <Result>
"""

NORMAL_SUFFIX = """Generate and return the output result(s) only, adhering to the provided Type in the following format

[Output] <result>
"""  # noqa E501

CHAIN_OF_THOUGHT_SUFFIX = """
Generate and return the output result(s) only, adhering to the provided Type in the following format. Perform the operation in a chain of thoughts.(Think Step by Step)

[Chain of Thoughts] <Chain of Thoughts>
[Output] <Result>
"""  # noqa E501

REACT_SUFFIX = """
You are given with a list of tools you can use to do different things. To achieve the given [Action], incrementally think and provide tool_usage necessary to achieve what is thought.
Provide your answer adhering in the following format. tool_usage is a function call with the necessary arguments. Only provide one [THOUGHT] and [TOOL USAGE] at a time.

[Thought] <Thought>
[Tool Usage] <tool_usage>
"""  # noqa E501


class Ollama(BaseLLM):
    """Ollama API client for Large Language Models (LLMs)."""

    MTLLM_METHOD_PROMPTS: dict[str, str] = {
        "Normal": NORMAL_SUFFIX,
        "Reason": REASON_SUFFIX,
        "Chain-of-Thoughts": CHAIN_OF_THOUGHT_SUFFIX,
        "ReAct": REACT_SUFFIX,
    }

    def __init__(self, verbose: bool = False, **kwargs: dict) -> None:
        """Initialize the Ollama API client."""
        import ollama  # type: ignore

        super().__init__(verbose)
        self.client = ollama.Client(host=kwargs.get("host", "http://localhost:11434"))  # type: ignore
        self.model_name: str = kwargs.pop("model_name", "llama3.2:1b")  # type: ignore
        self.default_model_params = kwargs
        if not self.check_model(self.model_name):
            self.download_model(self.model_name)

    def completion(self, req: CompletionRequest) -> CompletionResult:
        """Return the completion result."""
        messages = req.get_msg_list()
        tools = req.get_tool_list()
        output = self.client.chat(
            model=self.model_name,
            messages=messages,
            tools=tools,
            format=req.get_output_schema(),
            options={**self.default_model_params, **req.params},
        )

        output_str = output["message"]["content"]
        output_value = req.parse_response(output_str)

        tool_calls: list[ToolCall] = []
        for tool_call in output["message"].get("tool_calls", []):
            if tool := req.get_tool(tool_call["function"]["name"]):
                args = tool.parse_arguments(tool_call["function"]["arguments"])
                tool_calls.append(ToolCall(tool=tool, args=args))
            else:
                raise RuntimeError(
                    f"Attempted to call tool: '{tool_call['function']['name']}' which was not present."
                )

        return CompletionResult(
            output=output_value,
            tool_calls=tool_calls,
        )


    def __infer__(self, meaning_in: str | list[dict], **kwargs: dict) -> str:
        """Infer a response from the input meaning."""
        assert isinstance(
            meaning_in, str
        ), "Currently Multimodal models are not supported. Please provide a string input."
        model = str(kwargs.get("model_name", self.model_name))
        if not self.check_model(model):
            self.download_model(model)
        model_params = {k: v for k, v in kwargs.items() if k not in ["model_name"]}
        messages = [{"role": "user", "content": meaning_in}]

        output = self.client.chat(
            model=model,
            messages=messages,
            options={**self.default_model_params, **model_params},
        )
        return output["message"]["content"]

    def check_model(self, model_name: str) -> bool:
        """Check if the model is available."""
        try:
            self.client.show(model_name)
            return True
        except Exception:
            return False

    def download_model(self, model_name: str) -> None:
        """Download the model."""
        self.client.pull(model_name)
