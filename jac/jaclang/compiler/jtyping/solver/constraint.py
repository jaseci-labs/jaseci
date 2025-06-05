from dataclasses import dataclass
from typing import Optional


from jaclang.compiler.jtyping import JType
from jaclang.compiler.unitree import UniNode


@dataclass
class JTypeConstraint:

    left: JType
    right: JType
    source_node: Optional[UniNode] = None

    def __repr__(self) -> str:
        if self.source_node is None:
            return f"{self.left} <: {self.right}"
        return f"{self.left} <: {self.right} at {self.source_node.loc}"
