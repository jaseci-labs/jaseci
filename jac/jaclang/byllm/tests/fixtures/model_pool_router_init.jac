"""Test ModelPool LiteLLM Router initialisation structure.

postinit builds a litellm.Router with a specific model_list structure
depending on the chosen strategy:

- "fallback": each model gets a unique alias (pool-primary, pool-fallback-1, ...)
  and a fallbacks list is set on the router.
- load-balance strategies (e.g. "simple-shuffle", "least-busy"): all models
  share the "pool-model" alias so the router treats them as equivalent
  deployments and selects via routing_strategy.

This fixture exercises both cases without making any real API calls.
"""
import from jaclang.byllm.lib { MockLLM, ModelPool }

"""Identity cast that keeps duck-typed test payloads out of nominal checks."""
def _as_any(v: any) -> any {
    return v;
}

glob model1 = MockLLM(model_name="gpt-3.5-turbo", config={"outputs": []}),
     model2 = MockLLM(model_name="gpt-4", config={"outputs": []}),
     model3 = MockLLM(model_name="gpt-4o", config={"outputs": []}),
     pool_fb = ModelPool(models=[model1, model2], strategy="fallback"),
     pool_lb = ModelPool(models=[model1, model2, model3], strategy="simple-shuffle");

# --- Fallback pool (2 models) ---

# --- Load-balance pool (3 models) ---
with entry {
    # ---- Fallback pool: print router configuration for test verification ----
    ml_fb: list[dict[str, any]] = _as_any(pool_fb._router).model_list;
    fb_list: list[dict[str, list[str]]] = _as_any(pool_fb._router).fallbacks;

    print(f"fb_pool_alias:{pool_fb.model_name}");
    print(f"fb_deploy_count:{len(ml_fb)}");  # type: ignore
    print(f"fb_alias_0:{ml_fb[0]['model_name']}");
    print(f"fb_model_0:{ml_fb[0]['litellm_params']['model']}");
    print(f"fb_id_0:{ml_fb[0]['model_info']['id']}");
    print(f"fb_alias_1:{ml_fb[1]['model_name']}");
    print(f"fb_model_1:{ml_fb[1]['litellm_params']['model']}");
    print(f"fb_id_1:{ml_fb[1]['model_info']['id']}");
    print(f"fb_fallbacks_has_primary:{'pool-primary' in fb_list[0]}");
    print(
        f"fb_fallbacks_has_chain:{'pool-fallback-1'
            in fb_list[0].get('pool-primary', [])}"
    );

    # ---- Load-balance pool: print router configuration for test verification ----
    ml_lb: list[dict[str, any]] = _as_any(pool_lb._router).model_list;
    all_same = all(m["model_name"] == "pool-model" for m in ml_lb);  # type: ignore

    print(f"lb_pool_alias:{pool_lb.model_name}");
    print(f"lb_deploy_count:{len(ml_lb)}");  # type: ignore
    print(f"lb_all_share_alias:{all_same}");
}
