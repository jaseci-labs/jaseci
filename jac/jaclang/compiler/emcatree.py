"""JavaScript AST nodes based on ECMA-262 specification, derived from UniNode."""

from __future__ import annotations

from typing import Optional, Sequence, Union, Any
from dataclasses import dataclass

from jaclang.compiler.unitree import (
    UniNode,
    Expr,
    CodeBlockStmt,
    UniScopeNode,
    AstSymbolNode,
    SymbolType,
    Token,
    Source,
    Name,
    UniCFGNode,
    Symbol,
)


# Base JavaScript AST Node
class JSNode(UniNode):
    """Base JavaScript AST node."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        super().__init__(kid=kid or [])

    def to_dict(self) -> dict:
        """Return dict representation of node."""
        d = {"node": self.__class__.__name__}
        for field in [
            f
            for f in dir(self)
            if not f.startswith("_")
            and f
            not in [
                "kid",
                "parent",
                "loc",
                "gen",
                "name",
                "pp",
                "to_dict",
                "pp_walk",
                "unparse",
                "format",
            ]
        ]:
            try:
                attr = getattr(self, field)
                if isinstance(attr, (str, int, float, bool, type(None))):
                    d[field] = attr
                elif isinstance(attr, list) and all(
                    isinstance(x, (str, int, float, bool, type(None))) for x in attr
                ):
                    d[field] = attr
            except Exception:
                pass

        return d

    def pp(self, depth: Optional[int] = None) -> str:
        """Pretty print."""
        return self._pp_walk(depth=0 if depth is None else depth)

    def _pp_walk(self, depth: int = 0, prefix: str = "") -> str:
        """Walk the tree and pretty print."""
        res = f"{prefix}{type(self).__name__}:"
        node_dict = self.to_dict()
        for k, v in node_dict.items():
            if k == "node":
                continue
            res += f"\n{prefix}  {k}: {v}"

        for i in self.kid:
            if isinstance(i, JSNode):
                res += "\n" + i._pp_walk(depth=depth + 1, prefix=prefix + "  ")
        return res


# Expression Nodes
class JSExpr(JSNode, Expr):
    """Base JavaScript expression node."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        UniNode.__init__(self, kid=kid or [])
        self._expr_type: str = "Any"
        self._type_sym_tab: Optional[UniScopeNode] = None


# Statement Nodes
class JSStmt(JSNode, CodeBlockStmt):
    """Base JavaScript statement node."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        UniNode.__init__(self, kid=kid or [])
        self.edges: list[UniCFGNode] = []
        self.control_flow_cond: Optional[bool] = None


class JSScopedExpr(JSExpr, UniScopeNode):
    """Base for JS expressions that have a scope."""

    def __init__(self, name: str, kid: Sequence[UniNode]) -> None:
        """Initialize."""
        JSExpr.__init__(self, kid=kid)
        self._name = name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSScopedStmt(JSStmt, UniScopeNode):
    """Base for JS statements that have a scope."""

    def __init__(self, name: str, kid: Sequence[UniNode]) -> None:
        """Initialize."""
        JSStmt.__init__(self, kid=kid)
        self._name = name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


# Literals and Identifiers
class JSIdentifier(JSExpr, AstSymbolNode):
    """JavaScript Identifier node."""

    def __init__(self, name: str, kid: Sequence[UniNode]) -> None:
        self.name = name
        JSExpr.__init__(self, kid=kid)
        # Create a stub name token for the symbol system
        name_token = Name(
            orig_src=(
                self.loc.orig_src
                if hasattr(self, "loc") and self.loc.orig_src
                else Source("", "")
            ),
            name="NAME",
            value=name,
            line=0,
            end_line=0,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0,
        )
        AstSymbolNode.__init__(
            self, sym_name=name, name_spec=name_token, sym_category=SymbolType.VAR
        )


class JSLiteral(JSExpr):
    """JavaScript Literal node."""

    def __init__(self, value: Any, raw: str, kid: Sequence[UniNode]) -> None:
        self.value = value
        self.raw = raw
        super().__init__(kid=kid)


class JSRegexLiteral(JSLiteral):
    """JavaScript Regular Expression Literal node."""

    def __init__(
        self,
        value: Any,
        raw: str,
        pattern: str,
        flags: str,
        kid: Sequence[UniNode],
    ) -> None:
        super().__init__(value, raw, kid=kid)
        self.pattern = pattern
        self.flags = flags


# Array and Object Expressions
class JSArrayExpression(JSExpr):
    """JavaScript Array Expression node."""

    def __init__(
        self, elements: Sequence[Optional[JSExpr]], kid: Sequence[UniNode]
    ) -> None:
        self.elements = list(elements)
        super().__init__(kid=kid)


class JSObjectExpression(JSExpr):
    """JavaScript Object Expression node."""

    def __init__(
        self, properties: Sequence[JSProperty], kid: Sequence[UniNode]
    ) -> None:
        self.properties = list(properties)
        super().__init__(kid=kid)


class JSProperty(JSNode):
    """JavaScript Property node."""

    def __init__(
        self,
        kind: str,
        key: JSExpr,
        computed: bool,
        value: JSExpr,
        method: bool,
        shorthand: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.kind = kind  # "init", "get", "set"
        self.key = key
        self.computed = computed
        self.value = value
        self.method = method
        self.shorthand = shorthand
        super().__init__(kid=kid)


# Function Expressions
class JSFunctionExpression(JSExpr, UniScopeNode):
    """JavaScript Function Expression node."""

    def __init__(
        self,
        id: Optional[JSIdentifier],
        params: Sequence[JSNode],
        body: JSBlockStatement,
        kid: Sequence[UniNode],
        generator: bool = False,
        is_async: bool = False,
    ) -> None:
        self.id = id
        self.params = list(params)
        self.body = body
        self.generator = generator
        self.is_async = is_async
        self.expression = False
        scope_name = (
            id.name
            if id
            else f"anonymous_func_{self.loc.mod_path}_{self.loc.first_line}"
        )
        JSExpr.__init__(self, kid=kid)
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSArrowFunctionExpression(JSExpr, UniScopeNode):
    """JavaScript Arrow Function Expression node."""

    def __init__(
        self,
        params: Sequence[JSNode],
        body: Union[JSExpr, JSBlockStatement],
        expression: bool,
        kid: Sequence[UniNode],
        generator: bool = False,
        is_async: bool = False,
    ) -> None:
        self.params = list(params)
        self.body = body
        self.expression = expression
        self.generator = generator
        self.is_async = is_async

        JSExpr.__init__(self, kid=kid)
        scope_name = f"arrow_func_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


# Binary and Unary Expressions
class JSBinaryExpression(JSExpr):
    """JavaScript Binary Expression node."""

    def __init__(
        self, operator: str, left: JSExpr, right: JSExpr, kid: Sequence[UniNode]
    ) -> None:
        self.operator = operator
        self.left = left
        self.right = right
        super().__init__(kid=kid)


class JSLogicalExpression(JSExpr):
    """JavaScript Logical Expression node."""

    def __init__(
        self, operator: str, left: JSExpr, right: JSExpr, kid: Sequence[UniNode]
    ) -> None:
        self.operator = operator  # "||", "&&", "??"
        self.left = left
        self.right = right
        super().__init__(kid=kid)


class JSUnaryExpression(JSExpr):
    """JavaScript Unary Expression node."""

    def __init__(
        self,
        operator: str,
        argument: JSExpr,
        kid: Sequence[UniNode],
        prefix: bool = True,
    ) -> None:
        self.operator = operator
        self.argument = argument
        self.prefix = prefix
        super().__init__(kid=kid)


class JSUpdateExpression(JSExpr):
    """JavaScript Update Expression node."""

    def __init__(
        self,
        operator: str,
        argument: JSExpr,
        prefix: bool,
        kid: Sequence[UniNode],
    ) -> None:
        self.operator = operator  # "++" or "--"
        self.argument = argument
        self.prefix = prefix
        super().__init__(kid=kid)


# Assignment and Member Expressions
class JSAssignmentExpression(JSExpr):
    """JavaScript Assignment Expression node."""

    def __init__(
        self, operator: str, left: JSExpr, right: JSExpr, kid: Sequence[UniNode]
    ) -> None:
        self.operator = operator
        self.left = left
        self.right = right
        super().__init__(kid=kid)


class JSMemberExpression(JSExpr):
    """JavaScript Member Expression node."""

    def __init__(
        self,
        object: JSExpr,
        property: JSExpr,
        computed: bool,
        kid: Sequence[UniNode],
        optional: bool = False,
    ) -> None:
        self.object = object
        self.property = property
        self.computed = computed
        self.optional = optional
        super().__init__(kid=kid)


class JSConditionalExpression(JSExpr):
    """JavaScript Conditional (Ternary) Expression node."""

    def __init__(
        self,
        test: JSExpr,
        consequent: JSExpr,
        alternate: JSExpr,
        kid: Sequence[UniNode],
    ) -> None:
        self.test = test
        self.consequent = consequent
        self.alternate = alternate
        super().__init__(kid=kid)


class JSCallExpression(JSExpr):
    """JavaScript Call Expression node."""

    def __init__(
        self,
        callee: JSExpr,
        arguments: Sequence[JSExpr],
        kid: Sequence[UniNode],
        optional: bool = False,
    ) -> None:
        self.callee = callee
        self.arguments = list(arguments)
        self.optional = optional
        super().__init__(kid=kid)


class JSNewExpression(JSExpr):
    """JavaScript New Expression node."""

    def __init__(
        self, callee: JSExpr, arguments: Sequence[JSExpr], kid: Sequence[UniNode]
    ) -> None:
        self.callee = callee
        self.arguments = list(arguments)
        super().__init__(kid=kid)


class JSSequenceExpression(JSExpr):
    """JavaScript Sequence Expression node."""

    def __init__(self, expressions: Sequence[JSExpr], kid: Sequence[UniNode]) -> None:
        self.expressions = list(expressions)
        super().__init__(kid=kid)


# Statements
class JSBlockStatement(JSStmt, UniScopeNode):
    """JavaScript Block Statement node."""

    def __init__(self, body: Sequence[JSStmt], kid: Sequence[UniNode]) -> None:
        self.body = list(body)
        JSStmt.__init__(self, kid=kid)
        scope_name = f"block_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSExpressionStatement(JSStmt):
    """JavaScript Expression Statement node."""

    def __init__(self, expression: JSExpr, kid: Sequence[UniNode]) -> None:
        self.expression = expression
        super().__init__(kid=kid)


class JSEmptyStatement(JSStmt):
    """JavaScript Empty Statement node."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        super().__init__(kid=kid)


class JSDebuggerStatement(JSStmt):
    """JavaScript Debugger Statement node."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        super().__init__(kid=kid)


# Control Flow Statements
class JSIfStatement(JSStmt, UniScopeNode):
    """JavaScript If Statement node."""

    def __init__(
        self,
        test: JSExpr,
        consequent: JSStmt,
        kid: Sequence[UniNode],
        alternate: Optional[JSStmt] = None,
    ) -> None:
        self.test = test
        self.consequent = consequent
        self.alternate = alternate
        JSStmt.__init__(self, kid=kid)
        scope_name = f"if_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSWhileStatement(JSStmt, UniScopeNode):
    """JavaScript While Statement node."""

    def __init__(self, test: JSExpr, body: JSStmt, kid: Sequence[UniNode]) -> None:
        self.test = test
        self.body = body
        JSStmt.__init__(self, kid=kid)
        scope_name = f"while_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSDoWhileStatement(JSStmt, UniScopeNode):
    """JavaScript Do-While Statement node."""

    def __init__(self, body: JSStmt, test: JSExpr, kid: Sequence[UniNode]) -> None:
        self.body = body
        self.test = test
        JSStmt.__init__(self, kid=kid)
        scope_name = f"dowhile_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSForStatement(JSStmt, UniScopeNode):
    """JavaScript For Statement node."""

    def __init__(
        self,
        init: Optional[Union[JSExpr, JSVariableDeclaration]],
        test: Optional[JSExpr],
        update: Optional[JSExpr],
        body: JSStmt,
        kid: Sequence[UniNode],
    ) -> None:
        self.init = init
        self.test = test
        self.update = update
        self.body = body
        JSStmt.__init__(self, kid=kid)
        scope_name = f"for_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSForInStatement(JSStmt, UniScopeNode):
    """JavaScript For-In Statement node."""

    def __init__(
        self,
        left: Union[JSExpr, JSVariableDeclaration],
        right: JSExpr,
        body: JSStmt,
        kid: Sequence[UniNode],
        each: bool = False,
    ) -> None:
        self.left = left
        self.right = right
        self.body = body
        self.each = each
        JSStmt.__init__(self, kid=kid)
        scope_name = f"forin_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSForOfStatement(JSStmt, UniScopeNode):
    """JavaScript For-Of Statement node."""

    def __init__(
        self,
        left: Union[JSExpr, JSVariableDeclaration],
        right: JSExpr,
        body: JSStmt,
        kid: Sequence[UniNode],
    ) -> None:
        self.left = left
        self.right = right
        self.body = body
        JSStmt.__init__(self, kid=kid)
        scope_name = f"forof_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


# Jump Statements
class JSBreakStatement(JSStmt):
    """JavaScript Break Statement node."""

    def __init__(
        self, kid: Sequence[UniNode], label: Optional[JSIdentifier] = None
    ) -> None:
        self.label = label
        super().__init__(kid=kid)


class JSContinueStatement(JSStmt):
    """JavaScript Continue Statement node."""

    def __init__(
        self, kid: Sequence[UniNode], label: Optional[JSIdentifier] = None
    ) -> None:
        self.label = label
        super().__init__(kid=kid)


class JSReturnStatement(JSStmt):
    """JavaScript Return Statement node."""

    def __init__(
        self, kid: Sequence[UniNode], argument: Optional[JSExpr] = None
    ) -> None:
        self.argument = argument
        super().__init__(kid=kid)


class JSThrowStatement(JSStmt):
    """JavaScript Throw Statement node."""

    def __init__(self, argument: JSExpr, kid: Sequence[UniNode]) -> None:
        self.argument = argument
        super().__init__(kid=kid)


# Try/Catch Statements
class JSTryStatement(JSStmt):
    """JavaScript Try Statement node."""

    def __init__(
        self,
        block: JSBlockStatement,
        kid: Sequence[UniNode],
        handler: Optional[JSCatchClause] = None,
        finalizer: Optional[JSBlockStatement] = None,
    ) -> None:
        self.block = block
        self.handler = handler
        self.finalizer = finalizer
        super().__init__(kid=kid)


class JSCatchClause(JSNode, UniScopeNode):
    """JavaScript Catch Clause node."""

    def __init__(
        self,
        kid: Sequence[UniNode],
        param: Optional[JSNode],
        body: JSBlockStatement,
    ) -> None:
        self.param = param
        self.body = body
        UniNode.__init__(self, kid=kid)
        scope_name = f"catch_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


# Variable and Function Declarations
class JSVariableDeclaration(JSStmt):
    """JavaScript Variable Declaration node."""

    def __init__(
        self,
        kid: Sequence[UniNode],
        declarations: Sequence[JSVariableDeclarator],
        kind: str,
    ) -> None:
        self.declarations = list(declarations)
        self.kind = kind  # "var", "let", "const"
        super().__init__(kid=[*kid, *declarations])


class JSVariableDeclarator(JSNode):
    """JavaScript Variable Declarator node."""

    def __init__(
        self, kid: Sequence[UniNode], id: JSNode, init: Optional[JSExpr] = None
    ) -> None:
        self.id = id
        self.init = init
        super().__init__(kid=kid)


class JSFunctionDeclaration(JSStmt, UniScopeNode):
    """JavaScript Function Declaration node."""

    def __init__(
        self,
        id: JSIdentifier,
        params: Sequence[JSNode],
        body: JSBlockStatement,
        kid: Sequence[UniNode],
        generator: bool = False,
        is_async: bool = False,
    ) -> None:
        self.id = id
        self.params = list(params)
        self.body = body
        self.generator = generator
        self.is_async = is_async
        self.expression = False

        JSStmt.__init__(self, kid=kid)
        scope_name = (
            id.name
            if id
            else f"anonymous_func_{self.loc.mod_path}_{self.loc.first_line}"
        )
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


# Class Declarations
class JSClassDeclaration(JSStmt, UniScopeNode):
    """JavaScript Class Declaration node."""

    def __init__(
        self,
        id: Optional[JSIdentifier],
        superClass: Optional[JSExpr],
        body: JSClassBody,
        kid: Sequence[UniNode],
        decorators: Optional[Sequence[JSDecorator]] = None,
    ) -> None:
        self.id = id
        self.superClass = superClass
        self.body = body
        self.decorators = list(decorators) if decorators else []
        JSStmt.__init__(self, kid=kid)
        scope_name = (
            id.name
            if id
            else f"anonymous_class_{self.loc.mod_path}_{self.loc.first_line}"
        )
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSClassExpression(JSExpr, UniScopeNode):
    """JavaScript Class Expression node."""

    def __init__(
        self,
        id: Optional[JSIdentifier],
        superClass: Optional[JSExpr],
        body: JSClassBody,
        kid: Sequence[UniNode],
        decorators: Optional[Sequence[JSDecorator]] = None,
    ) -> None:
        self.id = id
        self.superClass = superClass
        self.body = body
        self.decorators = list(decorators) if decorators else []
        JSExpr.__init__(self, kid=kid)
        scope_name = (
            id.name
            if id
            else f"anonymous_class_{self.loc.mod_path}_{self.loc.first_line}"
        )
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSClassBody(JSNode):
    """JavaScript Class Body node."""

    def __init__(
        self,
        body: Sequence[Union[JSMethodDefinition, JSProperty, JSStaticBlock]],
        kid: Sequence[UniNode],
    ) -> None:
        self.body = list(body)
        super().__init__(kid=kid)


class JSMethodDefinition(JSNode):
    """JavaScript Method Definition node."""

    def __init__(
        self,
        key: JSExpr,
        computed: bool,
        value: JSFunctionExpression,
        kind: str,
        kid: Sequence[UniNode],
        static: bool = False,
        decorators: Optional[Sequence[JSDecorator]] = None,
    ) -> None:
        self.key = key
        self.computed = computed
        self.value = value
        self.kind = kind  # "constructor", "method", "get", "set"
        self.static = static
        self.decorators = list(decorators) if decorators else []
        super().__init__(kid=kid)


# Module-related nodes
class JSImportDeclaration(JSStmt):
    """JavaScript Import Declaration node."""

    def __init__(
        self,
        specifiers: Sequence[
            Union[
                JSImportSpecifier, JSImportDefaultSpecifier, JSImportNamespaceSpecifier
            ]
        ],
        source: JSLiteral,
        kid: Sequence[UniNode],
        attributes: Optional[Sequence[JSImportAttribute]] = None,
    ) -> None:
        self.specifiers = list(specifiers)
        self.source = source
        self.attributes = list(attributes) if attributes else []
        super().__init__(kid=kid)


class JSImportSpecifier(JSNode):
    """JavaScript Import Specifier node."""

    def __init__(
        self, local: JSIdentifier, imported: JSIdentifier, kid: Sequence[UniNode]
    ) -> None:
        self.local = local
        self.imported = imported
        super().__init__(kid=kid)


class JSImportDefaultSpecifier(JSNode):
    """JavaScript Import Default Specifier node."""

    def __init__(self, local: JSIdentifier, kid: Sequence[UniNode]) -> None:
        self.local = local
        super().__init__(kid=kid)


class JSImportNamespaceSpecifier(JSNode):
    """JavaScript Import Namespace Specifier node."""

    def __init__(self, local: JSIdentifier, kid: Sequence[UniNode]) -> None:
        self.local = local
        super().__init__(kid=kid)


class JSExportNamedDeclaration(JSStmt):
    """JavaScript Export Named Declaration node."""

    def __init__(
        self,
        kid: Sequence[UniNode],
        declaration: Optional[JSStmt] = None,
        specifiers: Optional[Sequence[JSExportSpecifier]] = None,
        source: Optional[JSLiteral] = None,
    ) -> None:
        self.declaration = declaration
        self.specifiers = list(specifiers) if specifiers else []
        self.source = source
        super().__init__(kid=kid)


class JSExportDefaultDeclaration(JSStmt):
    """JavaScript Export Default Declaration node."""

    def __init__(
        self, kid: Sequence[UniNode], declaration: Union[JSExpr, JSStmt]
    ) -> None:
        self.declaration = declaration
        super().__init__(kid=kid)


class JSExportAllDeclaration(JSStmt):
    """JavaScript Export All Declaration node."""

    def __init__(self, source: JSLiteral, kid: Sequence[UniNode]) -> None:
        self.source = source
        super().__init__(kid=kid)


class JSExportSpecifier(JSNode):
    """JavaScript Export Specifier node."""

    def __init__(
        self, local: JSIdentifier, exported: JSIdentifier, kid: Sequence[UniNode]
    ) -> None:
        self.local = local
        self.exported = exported
        super().__init__(kid=kid)


# Patterns (for destructuring)
class JSArrayPattern(JSNode):
    """JavaScript Array Pattern node."""

    def __init__(
        self, elements: Sequence[Optional[JSNode]], kid: Sequence[UniNode]
    ) -> None:
        self.elements = list(elements)
        super().__init__(kid=kid)


class JSObjectPattern(JSNode):
    """JavaScript Object Pattern node."""

    def __init__(
        self,
        properties: Sequence[Union[JSProperty, JSRestElement]],
        kid: Sequence[UniNode],
    ) -> None:
        self.properties = list(properties)
        super().__init__(kid=kid)


class JSRestElement(JSNode):
    """JavaScript Rest Element node."""

    def __init__(self, argument: JSNode, kid: Sequence[UniNode]) -> None:
        self.argument = argument
        super().__init__(kid=kid)


class JSAssignmentPattern(JSNode):
    """JavaScript Assignment Pattern node."""

    def __init__(self, left: JSNode, right: JSExpr, kid: Sequence[UniNode]) -> None:
        self.left = left
        self.right = right
        super().__init__(kid=kid)


# Other expressions
class JSThisExpression(JSExpr):
    """JavaScript This Expression node."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        super().__init__(kid=kid)


class JSSuper(JSExpr):
    """JavaScript Super node."""

    def __init__(self, kid: Sequence[UniNode]) -> None:
        super().__init__(kid=kid)


class JSSpreadElement(JSNode):
    """JavaScript Spread Element node."""

    def __init__(self, argument: JSExpr, kid: Sequence[UniNode]) -> None:
        self.argument = argument
        super().__init__(kid=kid)


class JSYieldExpression(JSExpr):
    """JavaScript Yield Expression node."""

    def __init__(
        self,
        kid: Sequence[UniNode],
        argument: Optional[JSExpr] = None,
        delegate: bool = False,
    ) -> None:
        self.argument = argument
        self.delegate = delegate
        super().__init__(kid=kid)


class JSAwaitExpression(JSExpr):
    """JavaScript Await Expression node."""

    def __init__(self, argument: JSExpr, kid: Sequence[UniNode]) -> None:
        self.argument = argument
        super().__init__(kid=kid)


# Template Literals
class JSTemplateLiteral(JSExpr):
    """JavaScript Template Literal node."""

    def __init__(
        self,
        quasis: Sequence[JSTemplateElement],
        expressions: Sequence[JSExpr],
        kid: Sequence[UniNode],
    ) -> None:
        self.quasis = list(quasis)
        self.expressions = list(expressions)
        super().__init__(kid=kid)


class JSTemplateElement(JSNode):
    """JavaScript Template Element node."""

    @dataclass
    class Value:
        raw: str
        cooked: Optional[str]

    def __init__(
        self, raw: str, cooked: Optional[str], tail: bool, kid: Sequence[UniNode]
    ) -> None:
        self.value = self.Value(raw=raw, cooked=cooked)
        self.tail = tail
        super().__init__(kid=kid)


class JSTaggedTemplateExpression(JSExpr):
    """JavaScript Tagged Template Expression node."""

    def __init__(
        self, tag: JSExpr, quasi: JSTemplateLiteral, kid: Sequence[UniNode]
    ) -> None:
        self.tag = tag
        self.quasi = quasi
        super().__init__(kid=kid)


# Switch Statement
class JSSwitchStatement(JSStmt, UniScopeNode):
    """JavaScript Switch Statement node."""

    def __init__(
        self,
        discriminant: JSExpr,
        cases: Sequence[JSSwitchCase],
        kid: Sequence[UniNode],
        lexical: bool = False,
    ) -> None:
        self.discriminant = discriminant
        self.cases = list(cases)
        self.lexical = lexical
        JSStmt.__init__(self, kid=kid)
        scope_name = f"switch_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSSwitchCase(JSNode):
    """JavaScript Switch Case node."""

    def __init__(
        self,
        test: Optional[JSExpr],
        consequent: Sequence[JSStmt],
        kid: Sequence[UniNode],
    ) -> None:
        self.test = test  # None for default case
        self.consequent = list(consequent)
        super().__init__(kid=kid)


# With Statement (deprecated but part of spec)
class JSWithStatement(JSStmt, UniScopeNode):
    """JavaScript With Statement node."""

    def __init__(self, object: JSExpr, body: JSStmt, kid: Sequence[UniNode]) -> None:
        self.object = object
        self.body = body
        JSStmt.__init__(self, kid=kid)
        scope_name = f"with_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


# Labeled Statement
class JSLabeledStatement(JSStmt):
    """JavaScript Labeled Statement node."""

    def __init__(
        self, label: JSIdentifier, body: JSStmt, kid: Sequence[UniNode]
    ) -> None:
        self.label = label
        self.body = body
        super().__init__(kid=kid)


# Program (top-level)
class JSProgram(JSNode, UniScopeNode):
    """JavaScript Program node (top-level)."""

    def __init__(
        self,
        body: Sequence[Union[JSStmt, JSExpr]],
        kid: Sequence[UniNode],
        source_type: str = "script",
        type: str = "Program",
        hashbang: Optional[JSHashbang] = None,
    ) -> None:
        self.body = list(body)
        self.source_type = source_type
        self.type = type
        self.hashbang = hashbang
        UniNode.__init__(self, kid=kid)
        self._name = "program"
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


# Comments (for completeness)
class JSComment(JSNode):
    """JavaScript Comment node."""

    def __init__(self, value: str, comment_type: str, kid: Sequence[UniNode]) -> None:
        self.value = value
        self.type = comment_type  # "Block" or "Line"
        super().__init__(kid=kid)


class JSHashbang(JSComment):
    """JavaScript Hashbang node."""

    def __init__(self, value: str, kid: Sequence[UniNode]) -> None:
        super().__init__(value, "Hashbang", kid)


# Meta Property (for new.target, import.meta)
class JSMetaProperty(JSExpr):
    """JavaScript Meta Property node."""

    def __init__(
        self, meta: JSIdentifier, property: JSIdentifier, kid: Sequence[UniNode]
    ) -> None:
        self.meta = meta
        self.property = property
        super().__init__(kid=kid)


# Import Expression (dynamic import)
class JSImportExpression(JSExpr):
    """JavaScript Import Expression node (dynamic import)."""

    def __init__(
        self, source: JSExpr, kid: Sequence[UniNode], options: Optional[JSExpr] = None
    ) -> None:
        self.source = source
        self.options = options
        super().__init__(kid=kid)


class JSPrivateIdentifier(JSIdentifier):
    """JavaScript Private Identifier node."""

    def __init__(self, name: str, kid: Sequence[UniNode]) -> None:
        super().__init__(f"#{name}", kid=kid)


class JSStaticBlock(JSStmt, UniScopeNode):
    """JavaScript Static Block node."""

    def __init__(self, body: Sequence[JSStmt], kid: Sequence[UniNode]) -> None:
        self.body = list(body)
        JSStmt.__init__(self, kid=kid)
        scope_name = f"static_block_{self.loc.mod_path}_{self.loc.first_line}"
        self._name = scope_name
        self._sym_tab: dict[str, Symbol] = {}
        self._parent_scope: Optional[UniScopeNode] = None
        self._uses: list[AstSymbolNode] = []
        self._defs: list[AstSymbolNode] = []
        self.name: str = self._name


class JSDecorator(JSNode):
    """JavaScript Decorator node."""

    def __init__(self, expression: JSExpr, kid: Sequence[UniNode]) -> None:
        self.expression = expression
        super().__init__(kid)


class JSAccessorProperty(JSMethodDefinition):
    """JavaScript Accessor Property node."""

    def __init__(
        self,
        key: JSExpr,
        computed: bool,
        value: Optional[JSFunctionExpression],
        kind: str,
        kid: Sequence[UniNode],
        static: bool = False,
        decorators: Optional[Sequence[JSDecorator]] = None,
    ) -> None:
        super().__init__(
            key,
            computed,
            (
                value
                if value
                else JSFunctionExpression(None, [], JSBlockStatement([], []), [])
            ),
            kind,
            kid,
            static,
            decorators,
        )


class JSImportAttribute(JSNode):
    """JavaScript Import Attribute node."""

    def __init__(self, key: JSIdentifier, value: JSLiteral, kid: Sequence[UniNode]):
        self.key = key
        self.value = value
        super().__init__(kid)


class JSChainExpression(JSExpr):
    """JavaScript Chain Expression node."""

    def __init__(
        self,
        expression: Union[JSCallExpression, JSMemberExpression],
        kid: Sequence[UniNode],
    ) -> None:
        self.expression = expression
        super().__init__(kid=kid)
