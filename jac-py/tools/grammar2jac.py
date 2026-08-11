"""grammar2jac - emit Jac PEG parser rules from CPython's python.gram.

P0.7 backend for the pegen grammar model (PLAN.md). Reuses
reference/cpython/Tools/peg_generator to parse the frozen grammar, then emits
checked-in Jac rule functions that call peg_runtime + parser_actions.

Usage:
    python jac-py/tools/grammar2jac.py --profile expr
    python jac-py/tools/grammar2jac.py --check
    python jac-py/tools/grammar2jac.py --stdout --profile expr
"""

from __future__ import annotations

import argparse
import ast as py_ast
import os
import re
import sys
import tokenize
from collections.abc import Iterable, Sequence
from io import StringIO
from typing import IO, Any

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(os.path.dirname(_HERE))
_PEGEN = os.path.join(_REPO, "reference", "cpython", "Tools", "peg_generator")
sys.path.insert(0, _PEGEN)

from pegen.build import build_parser, generate_token_definitions  # noqa: E402
from pegen.grammar import (  # noqa: E402
    Alt,
    Cut,
    Forced,
    Gather,
    Grammar,
    GrammarVisitor,
    Group,
    Lookahead,
    NamedItem,
    NameLeaf,
    NegativeLookahead,
    Opt,
    PositiveLookahead,
    Repeat0,
    Repeat1,
    Rhs,
    Rule,
    StringLeaf,
)
from pegen.parser_generator import (  # noqa: E402
    KeywordCollectorVisitor,
    ParserGenerator,
    RuleCollectorVisitor,
)

GRAMMAR_PATH = os.path.join(_REPO, "reference", "cpython", "Grammar", "python.gram")
TOKENS_PATH = os.path.join(_REPO, "reference", "cpython", "Grammar", "Tokens")
OUT_PATH = os.path.join(_REPO, "jac-py", "jacpython", "parser_expr.jac")

# Jac type mapping for grammar return types.
JAC_TYPES: dict[str, str] = {
    "expr_ty": "expr",
    "mod_ty": "mod",
    "stmt_ty": "stmt",
    "arguments_ty": "arguments",
    "asdl_expr_seq*": "list[expr]",
    "asdl_stmt_seq*": "list[stmt]",
    "asdl_int_seq*": "list[cmpop]",
    "CmpopExprPair*": "pa_cmpop_expr_pair",
    "Token*": "peg_token",
    "comprehension_ty": "comprehension",
    "asdl_comprehension_seq*": "list[comprehension]",
    "keyword_ty": "keyword",
    "arg_ty": "arg",
    "KeyValuePair*": "pa_key_value_pair",
    "KeywordOrStarred*": "pa_keyword_or_starred",
}

BINOP_OPS = {
    "Add": "Add",
    "Sub": "Sub",
    "Mult": "Mult",
    "Div": "Div",
    "FloorDiv": "FloorDiv",
    "Mod": "Mod",
    "MatMult": "MatMult",
    "Pow": "Pow",
    "LShift": "LShift",
    "RShift": "RShift",
    "BitOr": "BitOr",
    "BitXor": "BitXor",
    "BitAnd": "BitAnd",
}

UNARY_OPS = {"UAdd": "UAdd", "USub": "USub", "Invert": "Invert", "Not": "Not"}
BOOL_OPS = {"And": "And", "Or": "Or"}
CMP_OPS = {
    "Eq": "Eq",
    "NotEq": "NotEq",
    "Lt": "Lt",
    "LtE": "LtE",
    "Gt": "Gt",
    "GtE": "GtE",
    "Is": "Is",
    "IsNot": "IsNot",
    "In": "In",
    "NotIn": "NotIn",
}

TOKEN_CALLS = {
    "NAME": ("name_var", "pa_name_from_token(peg_expect_token(p, NAME))"),
    "NUMBER": ("number_var", "pa_number_from_token(peg_expect_token(p, NUMBER))"),
    "STRING": ("string_var", "peg_expect_token(p, STRING)"),
    "OP": ("op_var", "peg_expect_token(p, OP)"),
}


def _refs_in_node(node: Any) -> set[str]:
    names: set[str] = set()

    def walk(n: Any) -> None:
        if isinstance(n, NameLeaf):
            names.add(n.value)
        elif hasattr(n, "__dict__"):
            for v in n.__dict__.values():
                if isinstance(v, list):
                    for x in v:
                        walk(x)
                elif v is not None and not isinstance(v, (str, int, bool)):
                    walk(v)

    walk(node)
    return names


def _alt_uses_rule(alt: Alt, name: str) -> bool:
    return name in _refs_in_node(alt)


def _filter_rule(rule: Rule, allowed: set[str], all_rules: dict[str, Rule]) -> Rule:
    """Drop alternatives that reference disallowed or invalid_* rules."""
    kept: list[Alt] = []
    for alt in rule.rhs.alts:
        refs = _refs_in_node(alt)
        if any(r.startswith("invalid") for r in refs):
            continue
        if any(r in all_rules and r not in allowed for r in refs):
            continue
        kept.append(alt)
    if not kept:
        kept = list(rule.rhs.alts[:1])
    return Rule(rule.name, rule.type, Rhs(kept), rule.memo)


# Expression-eval profile: rules required for compiler_slice fixtures
# (1+1, -x, a*b+c, f(x,1), x<y<z) plus transitive deps inside this band.
EXPR_PROFILE_RULES: set[str] = {
    "eval",
    "expressions",
    "expression",
    "disjunction",
    "conjunction",
    "inversion",
    "comparison",
    "compare_op_bitwise_or_pair",
    "eq_bitwise_or",
    "noteq_bitwise_or",
    "lte_bitwise_or",
    "lt_bitwise_or",
    "gte_bitwise_or",
    "gt_bitwise_or",
    "notin_bitwise_or",
    "in_bitwise_or",
    "isnot_bitwise_or",
    "is_bitwise_or",
    "bitwise_or",
    "bitwise_xor",
    "bitwise_and",
    "shift_expr",
    "sum",
    "term",
    "factor",
    "power",
    "await_primary",
    "primary",
    "atom",
    "arguments",
    "args",
    "named_expression",
    "assignment_expression",
    "starred_expression",
    "kwarg_or_starred",
    "kwarg_or_double_starred",
    "kwargs",
}


def rule_closure_bounded(
    grammar: Grammar, start: str, allowed_names: set[str]
) -> set[str]:
    needed: set[str] = set()
    queue = [start]
    while queue:
        name = queue.pop()
        if name in needed or name not in allowed_names or name not in grammar.rules:
            continue
        needed.add(name)
        for ref in _refs_in_node(grammar.rules[name]):
            if ref in allowed_names and ref in grammar.rules and ref not in needed:
                queue.append(ref)
    return needed


def jac_type(c_type: str | None, *, is_seq: bool = False) -> str:
    if c_type is None:
        return "object"
    if c_type in JAC_TYPES:
        return JAC_TYPES[c_type]
    if c_type.endswith("*"):
        inner = jac_type(c_type[:-1])
        if inner.startswith("list["):
            return inner
        return f"list[{inner}]"
    return "object"


def jac_cast_type(ret: str) -> str:
    return ret.replace(" | None", "").strip()


def jac_return_type(c_type: str | None, *, is_seq: bool = False) -> str:
    base = jac_type(c_type, is_seq=is_seq)
    if base.endswith("| None"):
        return base
    return f"{base} | None"


class ActionLowerer:
    """Translate C grammar actions to Jac parser_actions calls."""

    def __init__(self) -> None:
        self._loc = "start_lineno, start_col_offset, end_lineno, end_col_offset"

    def lower(self, action: str) -> str:
        action = " ".join(action.split())
        if re.fullmatch(r"[a-zA-Z_]\w*", action):
            return action
        action = action.replace("p->arena", "")
        action = re.sub(r"p\s*->\s*arena", "", action)
        action = re.sub(r",\s*\)", ")", action)
        action = action.replace("NULL", "None")
        action = re.sub(r"\bp\s*,\s*", "", action)
        action = action.replace("EXTRA", self._loc)
        action = re.sub(r"->v\.Name\.id", "", action)
        action = re.sub(r"\(expr_ty\)\s*", "", action)
        action = re.sub(r"\(asdl_expr_seq\*\)\s*", "", action)
        action = re.sub(r"CHECK_NULL_ALLOWED\s*\(\s*[^,]+,\s*([^)]+)\)", r"pa_check(\1)", action)
        action = re.sub(r"CHECK\s*\(\s*[^,]+,\s*([^)]+)\)", r"pa_check(\1)", action)
        action = re.sub(
            r"CHECK_VERSION\([^,]+,\s*\d+,\s*\"[^\"]*\",\s*",
            'pa_check_version("", ',
            action,
        )
        for c_name, j_name in {**BINOP_OPS, **UNARY_OPS, **BOOL_OPS, **CMP_OPS}.items():
            action = re.sub(rf"\b{c_name}\b", f"{j_name}()", action)
        action = re.sub(r"\bLoad\b", "Load()", action)
        action = re.sub(r"\bStore\b", "Store()", action)
        action = action.replace("Py_True", "True")
        action = action.replace("Py_False", "False")
        action = action.replace("Py_None", "None")
        action = action.replace("Py_Ellipsis", "None")
        action = re.sub(
            r"_PyAST_BinOp\s*\(\s*(\w+)\s*,\s*(\w+)\(\)\s*,\s*(\w+)\s*,\s*",
            r"pa_ast_binop(\1, \2(), \3, ",
            action,
        )
        action = re.sub(
            r"_PyAST_UnaryOp\s*\(\s*(\w+)\(\)\s*,\s*(\w+)\s*,\s*",
            r"pa_ast_unaryop(\1(), \2, ",
            action,
        )
        action = re.sub(
            r"_PyAST_BoolOp\s*\(\s*(\w+)\(\)\s*,\s*([^,]+)\s*,\s*",
            r"pa_ast_boolop(\1(), \2, ",
            action,
        )
        action = re.sub(
            r"_PyAST_Compare\s*\(\s*(\w+)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*",
            r"pa_ast_compare(\1, \2, \3, ",
            action,
        )
        if "_PyAST_Call" in action and "?" in action:
            m = re.search(r"_PyAST_Call\s*\(\s*(\w+)\s*,", action)
            if m:
                return f"pa_call_from_optional_args({m.group(1)}, b, {self._loc})"
        action = re.sub(
            r"_PyAST_Call\s*\(\s*(\w+)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*",
            r"pa_ast_call(\1, \2, \3, ",
            action,
        )
        action = re.sub(
            r"_PyAST_IfExp\s*\(\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*",
            r"pa_ast_ifexp(\1, \2, \3, ",
            action,
        )
        action = re.sub(
            r"_PyAST_Starred\s*\(\s*(\w+)\s*,\s*Load\(\)\s*,\s*",
            r"pa_ast_starred(\1, ",
            action,
        )
        action = re.sub(
            r"_PyAST_Starred\s*\(\s*(\w+)\s*,\s*Load\s*,\s*",
            r"pa_ast_starred(\1, ",
            action,
        )
        action = re.sub(
            r"_PyAST_Constant\(True,\s*None,\s*",
            "pa_constant_bool(True, ",
            action,
        )
        action = re.sub(
            r"_PyAST_Constant\(False,\s*None,\s*",
            "pa_constant_bool(False, ",
            action,
        )
        action = re.sub(
            r"_PyAST_Constant\(None,\s*None,\s*",
            "pa_constant_none(",
            action,
        )
        action = re.sub(
            r"_PyPegen_singleton_seq\s*\(\s*(\w+)\s*\)",
            r"pa_singleton_seq(\1)",
            action,
        )
        action = re.sub(
            r"_PyPegen_seq_insert_in_front\s*\(\s*(\w+)\s*,\s*(\w+)\s*\)",
            r"pa_seq_insert_front(\1, \2)",
            action,
        )
        action = re.sub(
            r"_PyPegen_get_cmpops\s*\(\s*(\w+)\s*\)",
            r"pa_get_cmpops(\1)",
            action,
        )
        action = re.sub(
            r"_PyPegen_get_exprs\s*\(\s*(\w+)\s*\)",
            r"pa_get_exprs(\1)",
            action,
        )
        action = re.sub(
            r"_PyPegen_cmpop_expr_pair\s*\(\s*(\w+)\(\)\s*,\s*(\w+)\s*\)",
            r"pa_make_cmpop_pair(\1(), \2)",
            action,
        )
        action = re.sub(
            r"_PyPegen_collect_call_seqs\s*\(\s*(\w+)\s*,\s*(\w+)\s*,\s*",
            r"pa_collect_call_seqs(\1, \2, ",
            action,
        )
        action = re.sub(
            r"_PyAST_Expression\s*\(\s*(\w+)\s*\)",
            r"pa_ast_expression(\1)",
            action,
        )
        action = action.replace("( b )", "(b)")
        if "_PyAST_" in action or "_PyPegen_" in action or "RAISE_" in action:
            safe = action.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")
            return f'pa_unsupported_action(p, "{safe[:80]}")'
        return action


def _rule_fn(name: str) -> str:
    return f"rule_{name}"


class JacCallMakerVisitor(GrammarVisitor):
    def __init__(self, gen: "JacParserGenerator", exact_tokens: dict[str, int]) -> None:
        self.gen = gen
        self.exact_tokens = exact_tokens
        self.cache: dict[str, tuple[str, str]] = {}

    def visit_NameLeaf(self, node: NameLeaf) -> tuple[str | None, str]:
        name = node.value
        if name == "SOFT_KEYWORD":
            return "soft_kw", "peg_expect_soft_keyword(p, \"\")"
        if name in TOKEN_CALLS:
            var, call = TOKEN_CALLS[name]
            return var, call
        if name in ("NEWLINE", "DEDENT", "INDENT", "ENDMARKER"):
            return f"_{name.lower()}", f"peg_expect_token(p, {name})"
        if name in self.gen.tokens:
            return f"{name.lower()}_tok", f"peg_expect_token(p, {name})"
        return name, f"{_rule_fn(name)}(p)"

    def visit_StringLeaf(self, node: StringLeaf) -> tuple[str, str]:
        val = py_ast.literal_eval(node.value)
        if re.match(r"[a-zA-Z_]\w*\Z", val):
            if node.value.endswith("'"):
                kw = self.gen.keywords[val]
                return "kw", f"peg_expect_token(p, {kw})"
            return "soft", f"peg_expect_soft_keyword(p, {node.value.replace('\"', '')})"
        tok = self.exact_tokens[val]
        return "lit", f"peg_expect_token(p, {tok})"

    def visit_NamedItem(self, node: NamedItem) -> tuple[str | None, str]:
        name, call = self.visit(node.item)
        if node.name:
            name = node.name
        return name, call

    def visit_PositiveLookahead(self, node: PositiveLookahead) -> tuple[None, str]:
        _, inner = self.visit(node.node)
        if "peg_expect_token(p," in inner:
            tok = inner.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_positive_lookahead_token(p, {tok})"
        return None, f"({inner} is not None)"

    def visit_NegativeLookahead(self, node: NegativeLookahead) -> tuple[None, str]:
        _, inner = self.visit(node.node)
        if "peg_expect_token(p," in inner:
            tok = inner.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_negative_lookahead_token(p, {tok})"
        return None, f"({inner} is None)"

    def visit_Opt(self, node: Opt) -> tuple[str, str]:
        name, call = self.visit(node.node)
        return name or "opt", call

    def _artificial(
        self, node: Any, prefix: str, maker: Any, trailing_comma: bool = False
    ) -> tuple[str, str]:
        key = f"{prefix}_{node}"
        if key in self.cache:
            return self.cache[key]
        rule_name = maker()
        call = f"{_rule_fn(rule_name)}(p)" + ("," if trailing_comma else "")
        self.cache[key] = (rule_name, call)
        return rule_name, call

    def visit_Rhs(self, node: Rhs) -> tuple[str, str]:
        if len(node.alts) == 1 and len(node.alts[0].items) == 1:
            return self.visit(node.alts[0].items[0])
        _, call = self._artificial(node, "rhs", lambda: self.gen.artificial_rule_from_rhs(node))
        return "rhs", call

    def visit_Repeat0(self, node: Repeat0) -> tuple[str, str]:
        _, call = self._artificial(
            node,
            "repeat0",
            lambda: self.gen.artificial_rule_from_repeat(node.node, is_repeat1=False),
            trailing_comma=False,
        )
        return "seq", call

    def visit_Repeat1(self, node: Repeat1) -> tuple[str, str]:
        _, call = self._artificial(
            node,
            "repeat1",
            lambda: self.gen.artificial_rule_from_repeat(node.node, is_repeat1=True),
        )
        return "seq", call

    def visit_Gather(self, node: Gather) -> tuple[str, str]:
        _, call = self._artificial(
            node, "gather", lambda: self.gen.artificial_rule_from_gather(node)
        )
        return "gather", call

    def visit_Group(self, node: Group) -> tuple[str | None, str]:
        return self.visit(node.rhs)

    def visit_Cut(self, node: Cut) -> tuple[str, str]:
        return "cut", "True"

    def visit_Forced(self, node: Forced) -> tuple[str, str]:
        if isinstance(node.node, StringLeaf):
            val = py_ast.literal_eval(node.node.value)
            tok = self.exact_tokens[val]
            return (
                "forced",
                f"peg_expect_forced_token(p, {tok}, '{val}')",
            )
        if isinstance(node.node, Group):
            _, inner = self.visit(node.node.rhs)
            rhs_s = str(node.node.rhs).replace('"', '\\"')
            return (
                "forced",
                f'peg_expect_forced_result(p, {inner}, "{rhs_s}")',
            )
        raise NotImplementedError(f"forced node {node.node!r}")


class JacParserGenerator(ParserGenerator, GrammarVisitor):
    def __init__(
        self,
        grammar: Grammar,
        tokens: set[str],
        file: IO[str] | None,
        *,
        allowed_rules: set[str] | None = None,
    ) -> None:
        super().__init__(grammar, tokens, file)
        self.allowed_rules = allowed_rules
        self.exact_token_map: dict[str, int] = {}
        self.callmakervisitor = JacCallMakerVisitor(self, self.exact_token_map)
        self.action_lower = ActionLowerer()
        self.rule_ids: dict[str, int] = {}
        self._rule_name = ""
        self._rule_ret = "object | None"
        self._rule_memo = False

    def set_exact_tokens(self, exact: dict[str, int]) -> None:
        self.exact_token_map = exact
        self.callmakervisitor.exact_tokens = exact

    def collect_rules(self) -> None:
        """Collect artificial rules in stable order for deterministic output."""
        keyword_collector = KeywordCollectorVisitor(
            self, self.keywords, self.soft_keywords
        )
        for rule in sorted(self.all_rules.values(), key=lambda r: r.name):
            keyword_collector.visit(rule)

        rule_collector = RuleCollectorVisitor(self.rules, self.callmakervisitor)
        done: set[str] = set()
        while True:
            todo = sorted(n for n in self.all_rules if n not in done)
            if not todo:
                break
            done = set(self.all_rules)
            for rulename in todo:
                rule_collector.visit(self.all_rules[rulename])

    def generate(self, filename: str) -> None:
        self.collect_rules()
        rules_to_emit = sorted(
            (r for r in self.all_rules.values() if self._emit_rule(r.name)),
            key=lambda r: r.name,
        )
        for i, rule in enumerate(rules_to_emit):
            self.rule_ids[rule.name] = i
        self._emit_header(filename)
        self._emit_rule_constants(rules_to_emit)
        for rule in rules_to_emit:
            self.visit(rule)
        self._emit_keywords()
        self._emit_entry_points()

    def _emit_rule(self, name: str) -> bool:
        # Artificial helpers (_loop*, _gather*, _tmp*) are created during
        # collect_rules() and must always be emitted (cpython pegen does the same).
        if name.startswith("_"):
            return True
        if self.allowed_rules is None:
            return True
        return name in self.allowed_rules

    def _emit_header(self, filename: str) -> None:
        base = os.path.basename(filename)
        self.print('"""jacpython generated PEG parser (expression eval profile).')
        self.print("")
        self.print(
            f"GENERATED by jac-py/tools/grammar2jac.py from {GRAMMAR_PATH}"
        )
        self.print(f"(profile expr, source tag: {base}). Do not edit by hand.")
        self.print('"""')
        self.print("")
        self.print("import from token_model {")
        self.print("    ENDMARKER, NAME, NUMBER, STRING, OP, NT_OFFSET, NEWLINE,")
        self.print("}")
        self.print("import from peg_runtime {")
        self.print("    peg_parser, peg_parser_from_source, peg_set_keywords,")
        self.print("    peg_set_soft_keywords, peg_keyword_entry, peg_mark, peg_reset,")
        self.print("    peg_check_memo, peg_insert_memo, peg_update_memo,")
        self.print("    peg_expect_token, peg_expect_soft_keyword, peg_expect_forced_token,")
        self.print("    peg_expect_forced_result, peg_has_error, peg_fill_token,")
        self.print("    peg_positive_lookahead_token, peg_negative_lookahead_token,")
        self.print("    peg_left_rec_finish, peg_token,")
        self.print("}")
        self.print("import from parser_actions {")
        self.print("    pa_cmpop_expr_pair, pa_make_cmpop_pair, pa_name_from_token, pa_number_from_token,")
        self.print("    pa_ast_expression, pa_ast_binop, pa_ast_unaryop, pa_ast_boolop,")
        self.print("    pa_ast_compare, pa_ast_call, pa_ast_ifexp, pa_constant_bool,")
        self.print("    pa_constant_none, pa_singleton_seq, pa_seq_insert_front,")
        self.print("    pa_get_cmpops, pa_get_exprs,")
        self.print("    pa_collect_call_seqs, pa_call_from_optional_args, pa_ast_starred,")
        self.print("    pa_check, pa_check_version, pa_unsupported_action,")
        self.print("}")
        self.print("import from ast_nodes {")
        self.print("    expr, mod, Expression, Name, Load,")
        self.print("    Add, Sub, Mult, Div, USub, UAdd, Not, Invert,")
        self.print("    Or, And, Lt, LtE, Gt, GtE, Eq, NotEq, In, NotIn, Is, IsNot,")
        self.print("}")
        self.print("")

    def _emit_rule_constants(self, rules: Sequence[Rule]) -> None:
        parts = [f"RULE_{r.name}: int = NT_OFFSET + {i}" for i, r in enumerate(rules)]
        self.print("glob " + parts[0] + ",")
        for part in parts[1:-1]:
            self.print(f"     {part},")
        if len(parts) > 1:
            self.print(f"     {parts[-1]};")
        else:
            self.print(";")
        self.print("")

    def _emit_keywords(self) -> None:
        self.print("def _build_keyword_lists() -> list[list[peg_keyword_entry]] {")
        with self.indent():
            max_len = 0
            for spelling in self.keywords:
                max_len = max(max_len, len(spelling))
            self.print(f"lists: list[list[peg_keyword_entry]] = [];")
            self.print(f"i = 0;")
            self.print(f"while i <= {max_len} {{")
            with self.indent():
                self.print("lists.append([]);")
                self.print("i = i + 1;")
            self.print("}")
            for spelling, tok_id in sorted(self.keywords.items(), key=lambda x: len(x[0])):
                self.print(
                    f'lists[{len(spelling)}].append(peg_keyword_entry(spelling="{spelling}", tok_type={tok_id}));'
                )
            self.print("return lists;")
        self.print("}")
        soft = sorted(self.soft_keywords)
        self.print(f"glob SOFT_KEYWORDS: list[str] = {[repr(s) for s in soft]};")
        self.print("")

    def _emit_entry_points(self) -> None:
        self.print("def parse_eval_module(p: peg_parser) -> mod | None {")
        with self.indent():
            self.print("res = rule_eval(p);")
            self.print("if res is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if peg_expect_token(p, ENDMARKER) is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("return res;")
        self.print("}")
        self.print("")
        self.print("def parse_eval_source(source: str, filename: str) -> mod | None {")
        with self.indent():
            self.print("p = peg_parser_from_source(source, filename, True);")
            self.print("peg_set_keywords(p, _build_keyword_lists());")
            self.print("peg_set_soft_keywords(p, SOFT_KEYWORDS);")
            self.print("return parse_eval_module(p);")
        self.print("}")
        self.print("")
        self.print("def parse_eval_expr(source: str, filename: str) -> expr | None {")
        with self.indent():
            self.print("mod = parse_eval_source(source, filename);")
            self.print("if mod is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if isinstance(mod, Expression) {")
            with self.indent():
                self.print("return (mod as Expression).body;")
            self.print("}")
            self.print("return None;")
        self.print("}")

    def visit_Rule(self, node: Rule) -> None:
        is_loop = node.is_loop()
        is_gather = node.is_gather()
        rhs = node.flatten()
        ret = jac_return_type(node.type, is_seq=is_loop or is_gather)
        rule_id = self.rule_ids[node.name]
        if node.left_recursive and node.leader:
            self._emit_left_rec_leader(node, rhs, ret, rule_id)
            return
        if node.left_recursive:
            self.print(f"def {_rule_fn(node.name)}(p: peg_parser) -> {ret} {{")
            with self.indent():
                self.print(f"return {_rule_fn(node.name)}_raw(p);")
            self.print("}")
            self.print("")
            self._emit_left_rec_raw(node, rhs, ret)
            return
        memo = node.memo and not node.left_recursive
        self.print(f"def {_rule_fn(node.name)}(p: peg_parser) -> {ret} {{")
        with self.indent():
            if memo:
                self.print(f"hit = peg_check_memo(p, RULE_{node.name});")
                self.print("if hit.hit {")
                with self.indent():
                    self.print(f"return hit.result as {jac_cast_type(ret)};")
                self.print("}")
            self.print("mark = peg_mark(p);")
            if self._uses_extra(rhs):
                self.print("start_lineno = 1;")
                self.print("start_col_offset = 0;")
                self.print("end_lineno = 1;")
                self.print("end_col_offset = 0;")
                self.print("if peg_fill_token(p) {")
                with self.indent():
                    self.print("t0 = p.tokens[p.mark];")
                    self.print("start_lineno = t0.lineno;")
                    self.print("start_col_offset = t0.col_offset;")
                self.print("}")
            if is_loop:
                self.print("children: list[object] = [];")
            self._rule_name = node.name
            self._rule_ret = ret
            self._rule_memo = memo
            self.visit(rhs, is_loop=is_loop, is_gather=is_gather)
            if is_loop:
                if node.name.startswith("_loop1"):
                    self.print("if len(children) == 0 {")
                    with self.indent():
                        self.print("return None;")
                    self.print("}")
                self.print("return children as list[expr];")
            else:
                if memo:
                    self.print(f"peg_insert_memo(p, mark, RULE_{node.name}, None);")
                self.print("return None;")
        self.print("}")
        self.print("")

    def _emit_left_rec_leader(self, node: Rule, rhs: Rhs, ret: str, rule_id: int) -> None:
        self.print(f"def {_rule_fn(node.name)}(p: peg_parser) -> {ret} {{")
        with self.indent():
            self.print(f"hit = peg_check_memo(p, RULE_{node.name});")
            self.print("if hit.hit {")
            with self.indent():
                self.print(f"return hit.result as {ret};")
            self.print("}")
            self.print("mark = peg_mark(p);")
            self.print(f"res: {ret} = None;")
            self.print("resmark = mark;")
            self.print("while True {")
            with self.indent():
                self.print(f"peg_update_memo(p, mark, RULE_{node.name}, res);")
                self.print("peg_reset(p, mark);")
                self.print(f"raw = {_rule_fn(node.name)}_raw(p);")
                self.print("if peg_has_error(p) {")
                with self.indent():
                    self.print("return None;")
                self.print("}")
                self.print("if raw is None or peg_mark(p) <= resmark {")
                with self.indent():
                    self.print("break;")
                self.print("}")
                self.print("resmark = peg_mark(p);")
                self.print("res = raw;")
            self.print("}")
            self.print(f"return peg_left_rec_finish(p, resmark, res) as {jac_cast_type(ret)};")
        self.print("}")
        self.print("")
        self._emit_left_rec_raw(node, rhs, ret)

    def _emit_left_rec_raw(self, node: Rule, rhs: Rhs, ret: str) -> None:
        self.print(f"def {_rule_fn(node.name)}_raw(p: peg_parser) -> {ret} {{")
        with self.indent():
            self._rule_name = node.name
            self._rule_memo = False
            self.print("mark = peg_mark(p);")
            if self._uses_extra(rhs):
                self.print("start_lineno = 1;")
                self.print("start_col_offset = 0;")
                self.print("end_lineno = 1;")
                self.print("end_col_offset = 0;")
            self.visit(rhs, is_loop=False, is_gather=False)
            self.print("return None;")
        self.print("}")
        self.print("")

    def _uses_extra(self, rhs: Rhs) -> bool:
        for alt in rhs.alts:
            if alt.action and "EXTRA" in alt.action:
                return True
        return False

    def visit_Rhs(
        self,
        node: Rhs,
        *,
        is_loop: bool = False,
        is_gather: bool = False,
    ) -> None:
        for alt in node.alts:
            self.visit(alt, is_loop=is_loop, is_gather=is_gather)
            if not is_loop:
                self.print("peg_reset(p, mark);")

    def visit_Alt(self, node: Alt, is_loop: bool = False, is_gather: bool = False) -> None:
        if is_loop:
            self._visit_alt_loop(node, is_gather)
            return
        has_cut = any(isinstance(i.item, Cut) for i in node.items)
        with self.local_variable_context():
            self._emit_alt_body_nested(node.items, 0, node, is_gather, has_cut)

    def _emit_alt_body_nested(
        self,
        items: list,
        idx: int,
        node: Alt,
        is_gather: bool,
        has_cut: bool,
    ) -> None:
        if idx >= len(items):
            if node.action and "EXTRA" in node.action:
                self.print("end_tok = p.tokens[p.mark - 1];")
                self.print("end_lineno = end_tok.end_lineno;")
                self.print("end_col_offset = end_tok.end_col_offset;")
            action = self._emit_action(node, is_gather)
            self.print(f"res = {action};")
            if self._rule_memo:
                self.print(f"peg_insert_memo(p, mark, RULE_{self._rule_name}, res);")
            self.print("return res;")
            return
        item = items[idx]
        if isinstance(item.item, Cut):
            self.print("cut = True;")
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        if isinstance(item.item, Opt):
            name, call = self.callmakervisitor.visit(item)
            v = self.dedupe(name if name else "opt")
            call_clean = call[:-1] if call.endswith(",") else call
            self.print(f"{v} = {call_clean};")
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        name, call = self.callmakervisitor.visit(item)
        if name == "cut":
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        if name:
            v = self.dedupe(name)
            call_clean = call[:-1] if call.endswith(",") else call
            self.print(f"{v} = {call_clean};")
            self.print(f"if {v} is not None {{")
            with self.indent():
                self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            self.print("}")
            return
        self.print(f"if ({call}) {{")
        with self.indent():
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
        self.print("}")

    def _visit_alt_loop(self, node: Alt, is_gather: bool) -> None:
        has_cut = any(isinstance(i.item, Cut) for i in node.items)
        if has_cut:
            self.print("cut = False;")
        self.print("while True {")
        with self.indent():
            with self.local_variable_context():
                self._emit_loop_body_nested(node.items, 0, node, is_gather, has_cut)
        self.print("}")

    def _emit_loop_body_nested(
        self,
        items: list,
        idx: int,
        node: Alt,
        is_gather: bool,
        has_cut: bool,
    ) -> None:
        if idx >= len(items):
            if node.action and "EXTRA" in node.action:
                self.print("end_tok = p.tokens[p.mark - 1];")
                self.print("end_lineno = end_tok.end_lineno;")
                self.print("end_col_offset = end_tok.end_col_offset;")
            action = self._emit_action(node, is_gather)
            self.print(f"children.append({action});")
            self.print("mark = peg_mark(p);")
            return
        item = items[idx]
        if isinstance(item.item, Cut):
            self.print("cut = True;")
            self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        name, call = self.callmakervisitor.visit(item)
        if name == "cut":
            self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        if name:
            v = self.dedupe(name)
            call_clean = call[:-1] if call.endswith(",") else call
            self.print(f"{v} = {call_clean};")
            self.print(f"if {v} is None {{")
            with self.indent():
                self.print("break;")
            self.print("}")
            self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        self.print(f"if not ({call}) {{")
        with self.indent():
            self.print("break;")
        self.print("}")
        self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)

    def _emit_action(self, node: Alt, is_gather: bool) -> str:
        if node.action:
            try:
                return self.action_lower.lower(node.action)
            except ValueError as err:
                raise ValueError(f"in alt {node!s}: {err}") from err
        names = list(self.local_variable_names)
        if is_gather:
            return f"pa_seq_insert_front({names[0]}, {names[1]})"
        if len(names) == 1:
            return names[0]
        return f"[{', '.join(names)}]"


def load_token_sets() -> tuple[set[str], dict[str, int]]:
    with open(TOKENS_PATH) as fh:
        _, exact, non_exact = generate_token_definitions(fh)
    tokens = set(non_exact) | set(exact.keys())
    return tokens, exact


def filtered_grammar(grammar: Grammar, profile: str) -> tuple[Grammar, set[str]]:
    if profile != "expr":
        raise ValueError(f"unknown profile {profile!r}")
    allowed = rule_closure_bounded(grammar, "eval", EXPR_PROFILE_RULES)
    new_rules: dict[str, Rule] = {}
    for name in allowed:
        new_rules[name] = _filter_rule(grammar.rules[name], allowed, grammar.rules)
    return Grammar(new_rules.values(), grammar.metas.items()), allowed


def generate_text(*, profile: str = "expr") -> str:
    grammar, _, _ = build_parser(GRAMMAR_PATH)
    if profile:
        grammar, allowed = filtered_grammar(grammar, profile)
    else:
        allowed = set(grammar.rules)
    tokens, exact = load_token_sets()
    buf = StringIO()
    gen = JacParserGenerator(grammar, tokens, buf, allowed_rules=allowed)
    gen.set_exact_tokens(exact)
    gen.generate(OUT_PATH)
    return buf.getvalue()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Emit Jac parser from python.gram")
    parser.add_argument("--stdout", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--profile", default="expr", help="grammar profile (expr)")
    args = parser.parse_args(argv)
    text = generate_text(profile=args.profile)
    if args.stdout:
        sys.stdout.write(text)
        return 0
    if args.check:
        try:
            on_disk = open(OUT_PATH).read()
        except FileNotFoundError:
            print(f"{OUT_PATH} missing; run grammar2jac.py", file=sys.stderr)
            return 1
        if on_disk != text:
            print(f"{OUT_PATH} is stale; regenerate with grammar2jac.py", file=sys.stderr)
            return 1
        print(f"{OUT_PATH} up to date")
        return 0
    with open(OUT_PATH, "w") as fh:
        fh.write(text)
    print(f"wrote {OUT_PATH} ({len(text.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
