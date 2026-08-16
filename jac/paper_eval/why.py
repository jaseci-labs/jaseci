"""Print the REASON for each graph break in a registered model.

Table 2 attributes each model's breaks to a cause (DC / LC / VG / DS / DO / TI).
A row that reads "N -> N, 0% fixed" is only meaningful once you know which of
those causes the N breaks actually are: an unfixed logger break is a bug, an
unfixed dynamic-shape break is the paper's declared out-of-scope category.

Usage: PYTHONPATH=$PWD python -m paper_eval.why <model_key> [on|off]
"""
import sys
import warnings

warnings.filterwarnings("ignore")

import jaclang  # noqa: F401,E402  installs the meta-importer hook
import torch  # noqa: E402

from paper_eval.registry import MODELS  # noqa: E402


def main(key: str, mode: str = "off") -> None:
    spec = MODELS[key]
    if mode == "on":
        from jaclang.jac0core.runtime import JacRuntime as Jac
        from jaclang.meta_importer import install_graphmend_loader_hook

        prog = Jac.get_program()
        prog.graphmend_enabled = True
        prog.graphmend_scope = list(spec["scope"])
        prog.graphmend_scoped_compile = True
        install_graphmend_loader_hook()

    torch.manual_seed(0)
    model, inputs = spec["build"]()
    model.eval()

    torch._dynamo.reset()
    with torch.no_grad():
        explanation = torch._dynamo.explain(model)(**inputs)

    print(f"{key} [{mode}]: graphs={explanation.graph_count} "
          f"breaks={explanation.graph_break_count}")
    for i, reason in enumerate(explanation.break_reasons, 1):
        txt = " ".join(str(reason.reason).split())
        where = ""
        for frame in reversed(getattr(reason, "user_stack", []) or []):
            fname = getattr(frame, "filename", "") or ""
            if "transformers" in fname or "site-packages" not in fname:
                where = f"{fname.split('/')[-1]}:{frame.lineno} in {frame.name}"
                break
        print(f"  {i}. {txt[:150]}")
        if where:
            print(f"     at {where}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "off")
