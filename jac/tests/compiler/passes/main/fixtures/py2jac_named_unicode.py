r"""The one Python escape Jac has no exact rendering for.

Resolving `\N{name}` needs the Unicode name database, which the compiler does
not carry into a native unit, so `unitree.decode_string_literal` refuses it
and the lexer reports E0108 on Jac sources that spell it. Converting this file
therefore has to fail out loud: emitting the escape verbatim would produce Jac
whose string is silently a different value than the Python original.
"""

unicode_named = "\N{LATIN SMALL LETTER A}"
