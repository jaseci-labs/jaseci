"""ESTree leaf types for the JavaScript intent adapter."""
import jaclang.compiler.passes.ecmascript.estree as es;
import from typing { TypeAlias }

glob IntentExpr: TypeAlias = es.Expression;
glob IntentStmt: TypeAlias = es.Statement;
