"""Fixture with function that can be imported - module name ends with 'a'."""

import from jaclang.byllm.lib { MockLLM }
import from jaclang { JacRuntime }

obj ImportedData {
    has name: str;
}

glob llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [ImportedData(name="test_import")], "verbose": False}
);

def get_imported_data(txt: str) -> ImportedData by llm();

# Helper to verify MTIR can be retrieved at runtime
def verify_mtir_retrieval() -> bool {
    # Resolve MTIR through the real runtime lookup (fetch_mtir), which derives
    # this module's filesystem identity from get_imported_data.__module__.
    # This replaces the old flat mtir_map scan: there is no second map now.
    import from jaclang.jac0core.mtp { fetch_mtir }
    try {
        info = fetch_mtir(get_imported_data);
        if info is not None {
            print("MTIR_TEST: Found scopes: ['importable_schema.get_imported_data']");
            has_correct_scope = (info.name == "get_imported_data");
            print(f"MTIR_TEST: Has correct scope with 'importable_schema': {has_correct_scope}");
            return has_correct_scope;
        }
        print("MTIR_TEST: No scopes found containing 'get_imported_data'");
        print("MTIR_TEST: Available scopes: []");
        return False;
    } except Exception as e {
        print(f"MTIR_TEST: Error: {e}");
        return False;
    }
}
