"""ECMAScript/JavaScript AST generation for Jac.

This package provides ECMAScript AST generation capabilities following the ESTree
specification, allowing Jac code to be transpiled to JavaScript/ECMAScript.
"""

from jaclang.compiler.backends.es.esast_gen_pass import EsastGenPass
from jaclang.compiler.backends.es.estree import (
    Declaration,
    Expression,
    Pattern,
    Program,
    Statement,
    es_node_to_dict,
)

__all__ = [
    "EsastGenPass",
    "Expression",
    "Declaration",
    "Pattern",
    "Program",
    "Statement",
    "es_node_to_dict",
]
