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

def extract_invoice(doc: str) -> Invoice by llm();

with entry{
    extract_invoice("Please process the invoice from Acme Corp for $1,200.00.");
}
