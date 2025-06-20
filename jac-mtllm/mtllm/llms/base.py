"""Base Large Language Model (LLM) class."""

import json
import logging
import re
from dataclasses import dataclass
from enum import StrEnum
from pydantic import TypeAdapter
from typing import Any, Callable, Mapping, Optional, get_type_hints

from loguru import logger

from mtllm.types import InputInformation, ReActOutput


httpx_logger = logging.getLogger("httpx")
httpx_logger.setLevel(logging.WARNING)

SYSTEM_PROMPT = """
[System Prompt]
This is an operation you must perform and return the output values. Neither, the methodology, extra sentences nor the code are not needed.
Input/Type formatting: Explanation of the Input (variable_name) (type) = value
"""  # noqa E501

PROMPT_TEMPLATE = """
[Information]
{information}

[Context]
{context}

[Inputs Information]
{inputs_information}

[Output Information]
{output_information}

[Type Explanations]
{type_explanations}

[Action]
{action}
"""  # noqa E501

NORMAL_SUFFIX = """Generate and return the output result(s) only, adhering to the provided Type in the following format

[Output] <result>
"""  # noqa E501

REASON_SUFFIX = """
Reason and return the output result(s) only, adhering to the provided Type in the following format

[Reasoning] <Reason>
[Output] <Result>
"""

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

MTLLM_OUTPUT_EXTRACT_PROMPT = """
[Output]
{model_output}

[Previous Result You Provided]
{previous_output}

[Desired Output Type]
{output_info}

[Type Explanations]
{output_type_info}

Above output is not in the desired Output Format/Type. Please provide the output in the desired type. Do not repeat the previously provided output.
Important: Do not provide the code or the methodology. Only provide the output in the desired format.
"""  # noqa E501

OUTPUT_CHECK_PROMPT = """
[Output]
{model_output}

[Desired Output Type]
{output_type}

[Type Explanations]
{output_type_info}

Check if the output is exactly in the desired Output Type. Important: Just say 'Yes' or 'No'.
"""  # noqa E501

OUTPUT_FIX_PROMPT = """
[Previous Output]
{model_output}

[Desired Output Type]
{output_type}

[Type Explanations]
{output_type_info}

[Error]
{error}

Above output is not in the desired Output Format/Type. Please provide the output in the desired type. Do not repeat the previously provided output.
Important: Do not provide the code or the methodology. Only provide the output in the desired format.
"""  # noqa E501

REACT_OUTPUT_FIX_PROMPT = """
[Previous Output]
{model_output}

[Error]
{error}

[Tool Explanations]
{tool_explanations}

[Type Explanations]
{type_explanations}

Above output is not in the desired Output Format/Type. Please provide the output in the desired type. Do not repeat the previously provided output.
Provide the output in the below format. Where tool_usage is a function call with the necessary arguments. Only provide one [THOUGHT] and [TOOL USAGE] at a time.

[Thought] <Thought>
[Tool Usage] <tool_usage>
"""  # noqa E501


SYSTEM_PERSONA = """\
This is a task you must complete by returning only the output.
Do not include explanations, code, or extra text—only the result.
"""  # noqa E501

INSTRUCTION_TOOL = """
Use the tools provided to reach the goal. Call one tool at a time with \
proper args—no explanations, no narration. Think step by step, invoking tools \
as needed. When done, always call finish_tool(output) to return the final \
output. Only use tools.
"""  # noqa E501


class MessageRole(StrEnum):
    """Enum for message roles in LLM interactions."""

    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"
    TOOL = "tool"


@dataclass
class Message:
    """Message class for LLM interactions."""
    role: MessageRole
    content: str

@dataclass
class Tool:
    """Tool class for LLM interactions."""
    func: Callable
    description: str

    def __post_init__(self) -> None:
        """Post-initialization to validate the function."""
        self.func.__annotations__ = get_type_hints(self.func)

    def __call__(self, *args: Any, **kwargs: Any) -> Any:
        """Call the tool function with the provided arguments."""
        # If there is an error with the finish tool, we throw the exception.
        # Since it's the user's responsibility to handle it.
        if self.is_finish_tool():
            return self.func(*args, **kwargs)
        try:
            # TODO: Shoud I json serialize or this is fine?
            return self.func(*args, **kwargs)
        except Exception as e:
            # For the LLM if the tool failed, it'll see the error message
            # and make decision based on that.
            return str(e)

    def get_name(self) -> str:
        """Return the name of the tool function."""
        return self.func.__name__

    @staticmethod
    def from_function(func: Callable) -> "Tool":
        """Create a Tool instance from a function."""
        return Tool(
            func=func,
            description=func.__doc__ or "",  # TODO: Use semstring.
        )

    @staticmethod
    def make_finish_tool(resp_type: Any) -> "Tool":
        def finish_tool(final_output: Any) -> Any:
            typeadop = TypeAdapter(resp_type)
            return typeadop.validate_python(final_output)
        finish_tool.__annotations__['return'] = resp_type
        finish_tool.__annotations__['final_output'] = resp_type
        return Tool(
            func=finish_tool,
            description="This tool is used to finish the tool calls and return the final output.",
        )

    def is_finish_tool(self) -> bool:
        """Check if the tool is a finish tool."""
        return self.get_name() == "finish_tool"

    def get_json_schema(self) -> dict[str, Any]:
        """Return the JSON schema for the tool function."""
        schema = TypeAdapter(self.func).json_schema()
        schema.pop("type", "")
        return {
            "type": "function",
            "function": {
                "name": self.func.__name__,
                "description": self.description,
                "parameters": {
                    "type": "object",
                    "properties": schema.pop("properties", {}),
                },
            },
            "strict": True,
            **schema,
        }

    def parse_arguments(self, args_json: dict[str, Any]) -> dict[str, Any]:
        """Parse the arguments from JSON to the function's expected format."""
        args = {}
        annotations = self.func.__annotations__
        for arg_name, arg_json in args_json.items():
            if arg_type := annotations.get(arg_name, None):
                args[arg_name] = TypeAdapter(arg_type).validate_python(arg_json)
        return args

@dataclass
class ToolCall:
    """Tool call class for LLM interactions."""
    tool: Tool
    args: dict[str, Any]

    def __call__(self) -> Message:
        """Call the tool with the provided arguments."""
        result = self.tool(**self.args)
        params = ", ".join(f"{k}={v}" for k, v in self.args.items())
        return Message(
            role=MessageRole.TOOL,
            content=f"{self.tool.get_name()}({params}) = {result}",
        )

    def is_finish_tool(self) -> bool:
        """Check if the tool is a finish tool."""
        return self.tool.is_finish_tool()

    def get_output(self) -> Any:
        """Get the output from the finish tool call."""
        assert self.is_finish_tool(), "This method should only be called for finish tools."
        return self.tool(**self.args)

@dataclass
class CompletionRequest:
    """Request for completion from the LLM."""
    messages: list[Message]
    tools: list[Tool]
    params: dict[str, Any]  # Additional parameters for the LLM request.
    resp_type: Any = None  # Type from which the json schema is generated.

    def __post_init__(self) -> None:
        if len(self.tools) > 0:
            finish_tool = Tool.make_finish_tool(self.resp_type)
            self.tools.append(finish_tool)

    def get_msg_list(self) -> list[dict[str, str]]:
        """Return the messages in a format suitable for LLM API."""
        return [{"role": msg.role.value, "content": msg.content} for msg in self.messages]

    def get_tool_list(self) -> list[dict[str, Any]]:
        """Return the tools in a format suitable for LLM API."""
        return [ tool.get_json_schema() for tool in self.tools ]

    def get_output_schema(self) -> dict[str, Any] | None:
        """Return the JSON schema for the response type."""
        assert len(self.tools) == 0 or self.get_tool("finish_tool") is not None, \
            "Finish tool should be present in the tools list."
        if len(self.tools) == 0 and self.resp_type:
            if self.resp_type is str:
                return None  # Strings are default and not using a schema.
            return TypeAdapter(self.resp_type).json_schema()
        # If the are tools, the final output will be sent to the finish_tool
        # thus there is no output schema.
        return None

    def parse_response(self, response: str) -> Any:
        """Parse the response from the LLM."""
        # To use validate_json the string should contains quotes.
        #     example: '"The weather at New York is sunny."'
        # but the response from LLM will not have quotes, so
        # we need to check if it's string and return early.
        if self.resp_type is str or response.strip() == '':
            return response
        if self.resp_type:
            return TypeAdapter(self.resp_type).validate_json(response)
        return response

    def add_message(self, message: Message) -> None:
        """Add a message to the request."""
        self.messages.append(message)

    def get_tool(self, tool_name: str) -> Tool | None:
        """Get a tool by its name."""
        for tool in self.tools:
            if tool.func.__name__ == tool_name:
                return tool
        return None


@dataclass
class CompletionResult:
    """Result of the completion from the LLM."""
    output: Any
    tool_calls: list[ToolCall]


class BaseLLM:
    """Base Large Language Model (LLM) class."""

    MTLLM_SYSTEM_PROMPT: str = SYSTEM_PROMPT
    MTLLM_PROMPT: str = PROMPT_TEMPLATE
    MTLLM_METHOD_PROMPTS: dict[str, str] = {
        "Normal": NORMAL_SUFFIX,
        "Reason": REASON_SUFFIX,
        "Chain-of-Thoughts": CHAIN_OF_THOUGHT_SUFFIX,
        "ReAct": REACT_SUFFIX,
    }
    OUTPUT_EXTRACT_PROMPT: str = MTLLM_OUTPUT_EXTRACT_PROMPT
    OUTPUT_CHECK_PROMPT: str = OUTPUT_CHECK_PROMPT
    OUTPUT_FIX_PROMPT: str = OUTPUT_FIX_PROMPT
    REACT_OUTPUT_FIX_PROMPT: str = REACT_OUTPUT_FIX_PROMPT

    def __init__(self, verbose: bool = False) -> None:
        """Initialize the Large Language Model (LLM) client."""
        self.verbose = verbose

    def completion(self, req: CompletionRequest) -> CompletionResult:
        """Return the completion result."""
        raise NotImplementedError("This method should be implemented by subclasses.")

    def __infer__(self, meaning_in: str | list[dict], **kwargs: dict) -> str:
        """Infer a response from the input meaning."""
        raise NotImplementedError

    def __call__(
        self,
        input_text: str | list[dict],
        media: list[Optional[InputInformation]],
        **kwargs: dict,
    ) -> str:
        """Infer a response from the input text."""
        if self.verbose:
            logger.info(f"Meaning In\n{input_text}")
        return self.__infer__(input_text, **kwargs)

    def resolve_output(
        self,
        meaning_out: str,
        _eval_output: bool,  # FIXME: This will be removed after structured output.
        _globals: dict,
        _locals: Mapping,
    ) -> Any:  # noqa: ANN401
        """Resolve the output string to return the reasoning and output."""
        if output_match := re.search(r"\[Output\](.*)", meaning_out, re.DOTALL):
            output = output_match.group(1).strip()
            if _eval_output:
                return eval(output, _globals, _locals)
            return output
        raise ValueError("Failed to parse LLM output.")

    def resolve_react_output(
        self,
        meaning_out: str,
        _globals: dict,
        _locals: Mapping,
    ) -> ReActOutput:
        """Resolve the output string to return the reasoning and output."""
        if output_match := re.search(
            r"\[Thought\](.*)\[Tool Usage\](.*)", meaning_out, re.DOTALL
        ):
            thought = output_match.group(1).strip()
            tool_usage = output_match.group(2).strip()
            try:
                output = eval(tool_usage, _globals, _locals)
            except Exception as err:
                output = str(err)
            return ReActOutput(thought=thought, action=tool_usage, observation=output)
        raise ValueError("Failed to parse ReAct LLM output.")
