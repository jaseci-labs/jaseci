import from mtllm.llms { FakeLLM }

glob llm = FakeLLM(
    print_prompt=True,
    responses={
      '\n[System Prompt]\nThis is an operation you must perform and return the output values. Neither, the methodology, extra sentences nor the code are not needed.\nInput/Type formatting: Explanation of the Input (variable_name) (type) = value\n\n[Inputs_Information]\n(name) (str) = "Alex"\n\n[Output_Information]\n(str)\n\n[Action]\nGreet the user with the given name. (greet)\nGenerate and return the output result(s) only, adhering to the provided Type in the following format\n\n[Output] <result>\n':
      '[Output] Hello there, Alex!',

      '\n[System Prompt]\nThis is an operation you must perform and return the output values. Neither, the methodology, extra sentences nor the code are not needed.\nInput/Type formatting: Explanation of the Input (variable_name) (type) = value\n\n[Inputs_Information]\n(text) (str) = "I love this product!"\n\n[Output_Information]\n(str)\n\n[Action]\nAnalyze the sentiment of the given text. (analyze_sentiment)\nGenerate and return the output result(s) only, adhering to the provided Type in the following format\n\n[Output] <result>\n':
      '[Output] Strongly Positive',

      '\n[System Prompt]\nThis is an operation you must perform and return the output values. Neither, the methodology, extra sentences nor the code are not needed.\nInput/Type formatting: Explanation of the Input (variable_name) (type) = value\n\n[Inputs_Information]\n(text) (str) = "Hello world"\n(target_lang) (str) = "French"\n\n[Output_Information]\n(str)\n\n[Action]\nTranslate text to another language. (translate_text)\nGenerate and return the output result(s) only, adhering to the provided Type in the following format\n\n[Output] <result>\n':
       '[Output] Bonjour le monde!',

      '\n[System Prompt]\nThis is an operation you must perform and return the output values. Neither, the methodology, extra sentences nor the code are not needed.\nInput/Type formatting: Explanation of the Input (variable_name) (type) = value\n\n[Inputs_Information]\n(arg) (int) = 42\n(arg) (str) = "foo"\n(arg) (float) = 3.14\n(arg) (list[int]) = [1]\n\n[Output_Information]\n(str)\n\n[Action]\nJust prints all the arguments passed to this function. (fn_with_more_args)\nGenerate and return the output result(s) only, adhering to the provided Type in the following format\n\n[Output] <result>\n':
      '[Output] \n42\nfoo\n3.14\n[1]',

      '\n[System Prompt]\nThis is an operation you must perform and return the output values. Neither, the methodology, extra sentences nor the code are not needed.\nInput/Type formatting: Explanation of the Input (variable_name) (type) = value\n\n[Inputs_Information]\n(delimeter) (str) = \";\"\n(arg) (int) = 1\n(arg) (int) = 2\n(arg) (int) = 3\n(arg) (int) = 4\n(arg) (int) = 5\n\n[Output_Information]\n(str)\n\n[Action]\nJoin the given numbers with a specified delimiter. (delimeter_join)\nGenerate and return the output result(s) only, adhering to the provided Type in the following format\n\n[Output] <result>\n':
      '[Output] 1;2;3;4;5',

      '\n[System Prompt]\nThis is an operation you must perform and return the output values. Neither, the methodology, extra sentences nor the code are not needed.\nInput/Type formatting: Explanation of the Input (variable_name) (type) = value\n\n[Inputs_Information]\n(key) (str) = "foo"\n(value) (str) = "42"\n\n[Output_Information]\n(str)\n\n[Action]\nReturns the key value pair as a string like ex: {"key": "value"} (str_key_value_pair)\nGenerate and return the output result(s) only, adhering to the provided Type in the following format\n\n[Output] <result>\n':
      '[Output] {"foo": "42"}',

    }
);


"Greet the user with the given name."
def greet(name: str) -> str {
  return "Howdy " + name;
}

"Analyze the sentiment of the given text."
def analyze_sentiment(text: str) -> str {
  return "Neutral";
}

"Translate text to another language."
def translate_text(text: str, target_lang: str) -> str {
  return "Translation not available";
}


# -----------------------------------------------------------------------------
# Parameter count
# -----------------------------------------------------------------------------

# Optional multiple arguments.
"""Just prints all the arguments passed to this function."""
def fn_with_more_args(*args: int) -> str {
  return "Function with defaults called with args: " + str(args);
}

# One positional required and multiple optional arguments.
"""Join the given numbers with a specified delimiter."""
def delimeter_join(delimeter: str, *numbers: int) -> str {
  return "???";
}

# Different order type resolved check.
"""Returns the key value pair as a string like ex: {"key": "value"}"""
def str_key_value_pair(value: str, key: str) -> str {
  return "???";
}


with entry {
  print("Normal function call:", greet("Alex"));
  print("LLM override call:", greet("Alex") by llm());

  print("Normal sentiment:", analyze_sentiment("I love this product!"));
  print("LLM sentiment:", analyze_sentiment("I love this product!") by llm());

  print("Normal translation:", translate_text("Hello world", "French"));
  print("LLM translation:", translate_text("Hello world", "French") by llm());

  print(fn_with_more_args(42, 'foo', 3.14, [1]) by llm());
  print(delimeter_join(';', 1,2,3,4,5) by llm());
  print(str_key_value_pair(key='foo', value='42') by llm());

}
