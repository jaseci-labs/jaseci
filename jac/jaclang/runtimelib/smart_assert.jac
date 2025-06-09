import from mtllm.llms {Gemini, OpenAI}

glob llm = OpenAI();

def smart_assert_explanation(condition:str, assert_obj:AssertionError) -> str by llm();

def help_func() {
    return 'Helper function called' ;
}