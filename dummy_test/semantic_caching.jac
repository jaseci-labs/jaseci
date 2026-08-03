import from jaclang.byllm.lib { MockLLM }

glob llm = MockLLM(
         model_name="mockllm",
         config={
             "outputs": ["Good morning, Ada — take it easy today."],
             "verbose": True,
             "show_params": False
         }
     );

obj Invoice {
    has vendor: str;
    has amount: float;
}
sem Invoice.vendor = "The vendor from which the invoice is issued";
sem Invoice.amount = "The amount of the invoice";

obj Context{
    has cooperations: str;
    has history: str;
}
sem Context.cooperations = "The cooperations of the user";
sem Context.history = "The history of the user";
node Dummy{
    has whoami:str = "I am a dummy node for testing semantic caching.";
    def extract_invoice(cont: Context ,doc: str, user:int) -> Invoice by llm();
}

sem Dummy.extract_invoice = "extract invoice for the given user from the doc";
sem Dummy.extract_invoice.doc = "The document to extract the invoice from";
sem Dummy.extract_invoice.user = "The user ID for which to extract the invoice";

with entry{
    Dummy().extract_invoice( Context(cooperations="Acme Corp", history="Previous invoices processed."),
        "Please process the invoice from Acme Corp for $1,200.00.", 8964);
}
