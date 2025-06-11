import from mtllm.llms {Gemini, OpenAI}

glob llm = OpenAI(verbose = False, model = 'gpt-4o-mini', temperature = 0.1);

def smart_assert_explanation(
        condition:str,
        traceback:str,
        call_stack:str,
        msg:str = '',
        variable_context:list[dict]
    ) -> str by llm(context = 'Explain why this assert was triggered. Give details about what the root cause can be in the code.');

def help_func() {
    return 'Helper function called' ;
}