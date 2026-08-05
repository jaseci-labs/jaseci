"""Python-source fixture: tensor-bool validation guard -> torch._assert_async."""

import torch


@torch.compile()
def f(x: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
    x = torch.relu(x)
    if not mask.all():
        raise ValueError("mask must be all true")
    return torch.sin(x) * 2.0
