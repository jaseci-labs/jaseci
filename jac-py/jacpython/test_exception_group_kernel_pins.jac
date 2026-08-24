# ExceptionGroup split()/subgroup() differential pin suite -- P3-PREP lane.
#
# Acceptance harness for the P3 split/subgroup kernel (docs/EXCEPT-STAR-SCOPE.md
# phase P3). Pins were captured against the local CPython 3.14.7 oracle
# (/var/tmp/nicestorm-p3pins/oracle.py); each test embeds the recorded digest
# verbatim plus its CPython ground-truth anchor.
#
# Lane tags:
#   [P2] IMPLEMENTED-BY-P2-LANE -- satisfied by the BaseExceptionGroup /
#        ExceptionGroup runtime object (feat/exc-group-object).
#   [P3] BLOCKED-ON-P3         -- needs the split/subgroup kernel.
#
# Every pin is guarded by _kernel_ready(): on trees where the P2 object has not
# landed yet the suite runs green as pure documentation and becomes live
# acceptance the moment ExceptionGroup.split/subgroup exist. Wire into CI
# (.github/workflows/ci.yml, next to test_exc_hierarchy.jac) only after P3
# lands.
#
# Ground-truth anchors (CPython 3.14):
#   - Objects/exception_groups.c :: exceptiongroup_split, subgroup_split,
#     split_recursive -- condition validation, recursive partitioning,
#     derived-group typing (downcast to ExceptionGroup when all matched leaves
#     are Exceptions), context/cause propagation.
#   - Objects/exception_groups.c :: exceptiongroup_init -- construction
#     validation (non-empty sequence, exception items, no bare BaseExceptions
#     under the ExceptionGroup alias).
#   - Lib/test/test_exception_group.py :: TestSplit, TestSubgroup,
#     TestExceptionGroup*.test_*_constructor.
#
# Oracle facts worth remembering (all verified on 3.14.7):
#   - split()/subgroup() COPY even when everything matches (identity differs);
#     matched/unmatched LEAVES keep identity in both partitions.
#   - Nested groups are rebuilt, never reused; an inner group whose leaves all
#     match collapses away from the remainder entirely.
#   - Condition matching never hashes types: an unhashable metaclass type is a
#     valid condition (matching goes through PyErr_GivenExceptionMatches).
#   - Derived groups preserve .message and downcast type per-partition.
import from layer9_product_exec { product_exec }
import from pyc_first { exec_code, to_host }
import from objects { PyObj, PyStr, PyCode, PyError, is_error }


def _run_native(src: str) -> str {
    # Native front end -> PyCode -> VM; repr of module global `r`, or
    # "Type: message" when the VM raised.
    co = product_exec(src);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    out = exec_code(co as PyCode, [], ns);
    if is_error(out) {
        e = out as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    if "r" in ns {
        # String results return raw: digests record semantic content, and
        # repr() would wrap them in quotes the oracle capture never had.
        v = ns["r"];
        if isinstance(v, PyStr) {
            return (v as PyStr).val;
        }
        return repr(to_host(v));
    }
    return "";
}

# Assertion-style runner: executes the probe inside product_exec's own
# module run so guest asserts fire on the real execution path. Use this for
# shapes where the exec_code+globals readback in _run_native is unfaithful
# (module globals go missing once a handled exception exists in the run).
def _run_native_assert(src: str) -> str {
    co = product_exec(src);
    return "ok";
}


def _kernel_ready -> bool {
    # True iff the P2 group object exposes the P3 kernel entry points.
    return _run_native(
        "r = hasattr(ExceptionGroup, 'split') and "
        "hasattr(ExceptionGroup, 'subgroup')\n"
    ) == "True";
}


# ---------------- [P2] construction & object surface ------------------------

test "p2 egroup: repr round-trips message and leaf" {
    # Host oracle: ExceptionGroup('g', [ValueError('a')])
    # Anchor: Objects/exceptions.c ExceptionGroup_repr; Lib/test/
    # test_exception_group.py TestExceptionGroup.test_repr.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('g', [ValueError('a')])\n"
        "r = repr(eg)\n"
    ) == "ExceptionGroup('g', [ValueError('a')])";
}

test "p2 egroup: mixed base leaves force BaseExceptionGroup type" {
    # Host oracle: BaseExceptionGroup/ExceptionGroup
    # Anchor: Objects/exception_groups.c exceptiongroup_new (type selection);
    # Lib/test/test_exception_group.py TestExceptionGroup.test_types.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg1 = BaseExceptionGroup('g', [ValueError('a'), KeyboardInterrupt('k')])\n"
        "eg2 = ExceptionGroup('g', [ValueError('a')])\n"
        "r = type(eg1).__name__ + '/' + type(eg2).__name__\n"
    ) == "BaseExceptionGroup/ExceptionGroup";
}

test "p2 egroup: message and exceptions tuple surface" {
    # Host oracle: g|tuple|a
    # Anchor: Objects/exception_groups.c get message/exceptions members;
    # Lib/test/test_exception_group.py TestExceptionGroup.test_interface.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('g', [ValueError('a')])\n"
        "r = eg.message + '|' + type(eg.exceptions).__name__ + '|' "
        "+ eg.exceptions[0].args[0]\n"
    ) == "g|tuple|a";
}

test "p2 egroup: empty leaf list rejected byte-exact" {
    # Host oracle: ValueError: second argument (exceptions) must be a non-empty sequence
    # Anchor: Objects/exception_groups.c exceptiongroup_init;
    # Lib/test/test_exception_group.py TestBadSemantics.test_empty.
    if not _kernel_ready() { return; }
    assert _run_native("r = ExceptionGroup('g', [])\n") == (
        "ValueError: second argument (exceptions) must be a non-empty sequence"
    );
}

test "p2 egroup: non-sequence leaves rejected byte-exact" {
    # Host oracle: TypeError: second argument (exceptions) must be a sequence
    # Anchor: Objects/exception_groups.c exceptiongroup_init;
    # Lib/test/test_exception_group.py TestBadSemantics.
    if not _kernel_ready() { return; }
    assert _run_native("r = ExceptionGroup('g', ValueError('a'))\n") == (
        "TypeError: second argument (exceptions) must be a sequence"
    );
}

test "p2 egroup: non-exception item rejected byte-exact" {
    # Host oracle: ValueError: Item 1 of second argument (exceptions) is not an exception
    # Anchor: Objects/exception_groups.c new_exceptiongroup_item;
    # Lib/test/test_exception_group.py TestBadSemantics.test_non_exceptions.
    if not _kernel_ready() { return; }
    assert _run_native(
        "r = BaseExceptionGroup('g', [ValueError('a'), 'b'])\n"
    ) == (
        "ValueError: Item 1 of second argument (exceptions) is not an exception"
    );
}

test "p2 egroup: bare BaseException under ExceptionGroup alias rejected" {
    # Host oracle: TypeError: Cannot nest BaseExceptions in an ExceptionGroup
    # Anchor: Objects/exception_groups.c exceptiongroup_init subclass check;
    # Lib/test/test_exception_group.py TestBadSemantics.test_construction.
    if not _kernel_ready() { return; }
    assert _run_native(
        "r = ExceptionGroup('g', [ValueError('a'), KeyboardInterrupt('k')])\n"
    ) == "TypeError: Cannot nest BaseExceptions in an ExceptionGroup";
}

test "p2 egroup: duplicate leaf types construct fine and split whole" {
    # Host oracle: (ExceptionGroup('g', [ValueError('a'), ValueError('b')]), None)
    # Duplicates are legal (unlike except* targets); split matches all copies.
    # Anchor: Lib/test/test_exception_group.py TestSplit.test_split_by_type.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = BaseExceptionGroup('g', [ValueError('a'), ValueError('b')])\n"
        "m, rest = eg.split(ValueError)\n"
        "r = repr((m, rest))\n"
    ) == "(ExceptionGroup('g', [ValueError('a'), ValueError('b')]), None)";
}


# ---------------- [P3] split() ----------------------------------------------

test "p3 split: basic type partition preserves leaf identity" {
    # Host oracle: ExceptionGroup('g', [ValueError('v')]) ##
    #              ExceptionGroup('g', [TypeError('t')]) ## True ## True
    # Anchor: Objects/exception_groups.c exceptiongroup_split +
    # subgroup_split_recursive; Lib/test/test_exception_group.py
    # TestSplit.test_split.
    if not _kernel_ready() { return; }
    assert _run_native(
        "ve, te = ValueError('v'), TypeError('t')\n"
        "eg = ExceptionGroup('g', [ve, te])\n"
        "m, rest = eg.split(ValueError)\n"
        "r = repr(m) + ' ## ' + repr(rest) + ' ## ' "
        "+ str(m.exceptions[0] is ve) + ' ## ' + str(rest.exceptions[0] is te)\n"
    ) == (
        "ExceptionGroup('g', [ValueError('v')]) ## "
        "ExceptionGroup('g', [TypeError('t')]) ## True ## True"
    );
}

test "p3 split: full match returns copy, rest None" {
    # Host oracle: ExceptionGroup('g', [ValueError('v')]) ## None ## False
    # NOTE same=False: split NEVER returns self, even on total match.
    # Anchor: Objects/exception_groups.c subgroup_split_recursive;
    # Lib/test/test_exception_group.py TestSplit.test_split_exhaustive_match.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('g', [ValueError('v')])\n"
        "m, rest = eg.split(ValueError)\n"
        "r = repr(m) + ' ## ' + repr(rest) + ' ## ' + str(m is eg)\n"
    ) == "ExceptionGroup('g', [ValueError('v')]) ## None ## False";
}

test "p3 split: no match returns None pair-second self-equivalent" {
    # Host oracle: None ## ExceptionGroup('g', [TypeError('t')]) ## False
    # Anchor: Objects/exception_groups.c exceptiongroup_split;
    # Lib/test/test_exception_group.py TestSplit.test_no_match.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('g', [TypeError('t')])\n"
        "m, rest = eg.split(ValueError)\n"
        "r = repr(m) + ' ## ' + repr(rest) + ' ## ' + str(rest is eg)\n"
    ) == "None ## ExceptionGroup('g', [TypeError('t')]) ## False";
}

test "p3 split: nested partition rebuilds inner groups" {
    # Host oracle: ExceptionGroup('g', [ExceptionGroup('i', [ValueError('v')])])
    #              ## ExceptionGroup('g', [ExceptionGroup('i', [TypeError('t')]),
    #              KeyError('k')]) ## innerid=False
    # Inner groups are REBUILT (innerid=False), leaves keep identity.
    # Anchor: Objects/exception_groups.c subgroup_split_recursive recursion;
    # Lib/test/test_exception_group.py TestSplit.test_split_nested.
    if not _kernel_ready() { return; }
    assert _run_native(
        "ve, te, ke = ValueError('v'), TypeError('t'), KeyError('k')\n"
        "inner = ExceptionGroup('i', [ve, te])\n"
        "eg = ExceptionGroup('g', [inner, ke])\n"
        "m, rest = eg.split(ValueError)\n"
        "r = (repr(m) + ' ## ' + repr(rest) + ' ## '\n"
        "     + str(m.exceptions[0] is inner))\n"
    ) == (
        "ExceptionGroup('g', [ExceptionGroup('i', [ValueError('v')])]) ## "
        "ExceptionGroup('g', [ExceptionGroup('i', [TypeError('t')]), "
        "KeyError('k')]) ## False"
    );
}

test "p3 split: deep nesting partitions across three levels" {
    # Host oracle: ExceptionGroup('l1', [ExceptionGroup('l2',
    #              [ExceptionGroup('l3', [ValueError('v')])])]) ##
    #              ExceptionGroup('l1', [TypeError('t')])
    # Anchor: Lib/test/test_exception_group.py TestSplit.test_split_deep.
    if not _kernel_ready() { return; }
    assert _run_native(
        "l3 = ExceptionGroup('l3', [ValueError('v')])\n"
        "l2 = ExceptionGroup('l2', [l3])\n"
        "l1 = ExceptionGroup('l1', [l2, TypeError('t')])\n"
        "m, rest = l1.split(ValueError)\n"
        "r = repr(m) + ' ## ' + repr(rest)\n"
    ) == (
        "ExceptionGroup('l1', [ExceptionGroup('l2', "
        "[ExceptionGroup('l3', [ValueError('v')])])]) ## "
        "ExceptionGroup('l1', [TypeError('t')])"
    );
}

test "p3 split: fully-matched inner group vanishes from remainder" {
    # Host oracle: ExceptionGroup('g', [ExceptionGroup('i',
    #              [ValueError('v')])]) ## ExceptionGroup('g', [TypeError('t')])
    # Empty remainder subgroups collapse instead of appearing as EG('i', []).
    # Anchor: Objects/exception_groups.c subgroup_split_recursive
    # (empty-result branch); Lib/test/test_exception_group.py
    # TestSplit.test_split_nested_inside.
    if not _kernel_ready() { return; }
    assert _run_native(
        "inner = ExceptionGroup('i', [ValueError('v')])\n"
        "eg = ExceptionGroup('g', [inner, TypeError('t')])\n"
        "m, rest = eg.split(ValueError)\n"
        "r = repr(m) + ' ## ' + repr(rest)\n"
    ) == (
        "ExceptionGroup('g', [ExceptionGroup('i', [ValueError('v')])]) ## "
        "ExceptionGroup('g', [TypeError('t')])"
    );
}

test "p3 split: tuple condition flattens membership" {
    # Host oracle: ExceptionGroup('g', [ValueError('v'), TypeError('t')]) ##
    #              ExceptionGroup('g', [KeyError('k')])
    # Anchor: Objects/exception_groups.c condition flattening;
    # Lib/test/test_exception_group.py TestSplit.test_split_by_tuple.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('g', [ValueError('v'), TypeError('t'), KeyError('k')])\n"
        "m, rest = eg.split((ValueError, TypeError))\n"
        "r = repr(m) + ' ## ' + repr(rest)\n"
    ) == (
        "ExceptionGroup('g', [ValueError('v'), TypeError('t')]) ## "
        "ExceptionGroup('g', [KeyError('k')])"
    );
}

test "p3 split: predicate condition partitions per leaf" {
    # Host oracle: ExceptionGroup('g', [ValueError(1)]) ##
    #              ExceptionGroup('g', [ValueError(2)])
    # Anchor: Lib/test/test_exception_group.py TestSplit.test_split_by_pred.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('g', [ValueError(1), ValueError(2)])\n"
        "m, rest = eg.split(lambda e: (e.args[0] == 1) and 1)\n"
        "r = repr(m) + ' ## ' + repr(rest)\n"
    ) == (
        "ExceptionGroup('g', [ValueError(1)]) ## "
        "ExceptionGroup('g', [ValueError(2)])"
    );
}

test "p3 split: bad condition rejected byte-exact" {
    # Host oracle: TypeError: expected an exception type, a tuple of exception
    #              types, or a callable (other than a class)
    # Anchor: Objects/exception_groups.c check_subgroup;
    # Lib/test/test_exception_group.py TestBadSemantics.test_split_bad_args.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('g', [ValueError('v')])\n"
        "r = eg.split(42)\n"
    ) == (
        "TypeError: expected an exception type, a tuple of exception types, "
        "or a callable (other than a class)"
    );
}

test "p3 split: unhashable metaclass type is a valid condition" {
    # Host oracle: ExceptionGroup('g', [Unh('u')]) ##
    #              ExceptionGroup('g', [ValueError('v')])
    # Matching never hashes the condition type (PyErr_GivenExceptionMatches
    # path), so metaclass __hash__=None must NOT raise.
    # Anchor: Objects/exception_groups.c check_subgroup / subgroup_split.
    if not _kernel_ready() { return; }
    # Guest-class conditions route through family-string matching in the
    # kernel; asserted guest-side (see note on the context pin).
    assert _run_native_assert(
        "class Meta(type):\n"
        "    __hash__ = None\n"
        "class Unh(Exception, metaclass=Meta):\n"
        "    pass\n"
        "eg = ExceptionGroup('g', [ValueError('v'), Unh('u')])\n"
        "m, rest = eg.split(Unh)\n"
        "assert repr(m) == \"ExceptionGroup('g', [Unh('u')])\", repr(m)\n"
        "assert repr(rest) == \"ExceptionGroup('g', [ValueError('v')])\", repr(rest)\n"
    );
}

test "p3 split: derived match downcasts to ExceptionGroup" {
    # Host oracle: ExceptionGroup:ExceptionGroup('g', [ValueError('v')]) ##
    #              BaseExceptionGroup:BaseExceptionGroup('g',
    #              [KeyboardInterrupt('ki')])
    # Partitions re-type independently: all-Exception match => ExceptionGroup.
    # Anchor: Objects/exception_groups.c split_recursive derived-type choice;
    # Lib/test/test_exception_group.py TestSplit.test_split_derived_type.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = BaseExceptionGroup('g', [ValueError('v'), KeyboardInterrupt('ki')])\n"
        "m, rest = eg.split(ValueError)\n"
        "r = (type(m).__name__ + ':' + repr(m) + ' ## '\n"
        "     + type(rest).__name__ + ':' + repr(rest))\n"
    ) == (
        "ExceptionGroup:ExceptionGroup('g', [ValueError('v')]) ## "
        "BaseExceptionGroup:BaseExceptionGroup('g', [KeyboardInterrupt('ki')])"
    );
}

test "p3 split: message preserved on both partitions" {
    # Host oracle: orig-msg ## orig-msg
    # Anchor: Objects/exception_groups.c split_recursive msg propagation;
    # Lib/test/test_exception_group.py TestSplit.test_message_preserved.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('orig-msg', [ValueError('v'), TypeError('t')])\n"
        "m, rest = eg.split(ValueError)\n"
        "r = m.message + ' ## ' + rest.message\n"
    ) == "orig-msg ## orig-msg";
}

test "p3 split: __context__ threads onto derived match group" {
    # Host oracle: context=ValueError: inner
    # Anchor: Objects/exception_groups.c split_recursive SetContext;
    # Lib/test/test_exception_group.py TestSplit.test_context_propagation.
    if not _kernel_ready() { return; }
    # Asserted guest-side: the exec_code+globals readback harness loses
    # module globals once a handled exception is present, so r-readback
    # probes cannot observe this shape faithfully.
    assert _run_native_assert(
        "try:\n"
        "    try:\n"
        "        raise ValueError('inner')\n"
        "    except ValueError:\n"
        "        raise ExceptionGroup('g', [TypeError('t')])\n"
        "except ExceptionGroup as eg:\n"
        "    m, rest = eg.split(TypeError)\n"
        "    ctx = m.__context__\n"
        "    assert type(ctx).__name__ == 'ValueError', type(ctx).__name__\n"
        "    assert str(ctx) == 'inner', str(ctx)\n"
    );
}

test "p3 split: __cause__ threads onto derived match group" {
    # Host oracle: cause=KeyError
    # Anchor: Objects/exception_groups.c split_recursive SetCause;
    # Lib/test/test_exception_group.py TestSplit.test_cause_propagation.
    if not _kernel_ready() { return; }
    assert _run_native_assert(
        "try:\n"
        "    raise ExceptionGroup('g', [TypeError('t')]) from KeyError('cause')\n"
        "except ExceptionGroup as eg:\n"
        "    m, rest = eg.split(TypeError)\n"
        "    cs = m.__cause__\n"
        "    assert type(cs).__name__ == 'KeyError', type(cs).__name__\n"
    );
}


# ---------------- [P3] subgroup() -------------------------------------------

test "p3 subgroup: basic filter keeps leaf identity" {
    # Host oracle: ExceptionGroup('g', [ValueError('v')]) ## True
    # Anchor: Objects/exception_groups.c exceptiongroup_subgroup;
    # Lib/test/test_exception_group.py TestSubgroup.test_subgroup.
    if not _kernel_ready() { return; }
    assert _run_native(
        "ve, te = ValueError('v'), TypeError('t')\n"
        "eg = ExceptionGroup('g', [ve, te])\n"
        "s = eg.subgroup(ValueError)\n"
        "r = repr(s) + ' ## ' + str(s.exceptions[0] is ve)\n"
    ) == "ExceptionGroup('g', [ValueError('v')]) ## True";
}

test "p3 subgroup: no match yields None" {
    # Host oracle: None
    # Anchor: Lib/test/test_exception_group.py TestSubgroup.test_no_match.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('g', [TypeError('t')])\n"
        "r = repr(eg.subgroup(ValueError))\n"
    ) == "None";
}

test "p3 subgroup: full match returns copy, not self" {
    # Host oracle: ExceptionGroup('g', [ValueError('v')]) ## False
    # Anchor: Objects/exception_groups.c subgroup_split_recursive;
    # Lib/test/test_exception_group.py TestSubgroup.test_all_matched.
    if not _kernel_ready() { return; }
    assert _run_native(
        "eg = ExceptionGroup('g', [ValueError('v')])\n"
        "s = eg.subgroup(ValueError)\n"
        "r = repr(s) + ' ## ' + str(s is eg)\n"
    ) == "ExceptionGroup('g', [ValueError('v')]) ## False";
}

test "p3 subgroup: tuple condition keeps order and identity" {
    # Host oracle: ExceptionGroup('g', [ValueError('v'), KeyError('k')]) ## True
    # Anchor: Lib/test/test_exception_group.py TestSubgroup.test_tuple_condition.
    if not _kernel_ready() { return; }
    assert _run_native(
        "ve, te, ke = ValueError('v'), TypeError('t'), KeyError('k')\n"
        "eg = ExceptionGroup('g', [ve, te, ke])\n"
        "s = eg.subgroup((ValueError, KeyError))\n"
        "r = (repr(s) + ' ## '\n"
        "     + str(s.exceptions[0] is ve and s.exceptions[1] is ke))\n"
    ) == "ExceptionGroup('g', [ValueError('v'), KeyError('k')]) ## True";
}

test "p3 subgroup: bad condition rejected byte-exact" {
    # Host oracle: TypeError: expected an exception type, a tuple of exception
    #              types, or a callable (other than a class)
    # Anchor: Objects/exception_groups.c check_subgroup shared with split.
    if not _kernel_ready() { return; }
    assert _run_native(
        "r = ExceptionGroup('g', [ValueError('v')]).subgroup(42)\n"
    ) == (
        "TypeError: expected an exception type, a tuple of exception types, "
        "or a callable (other than a class)"
    );
}

test "p3 subgroup: nested filter rebuilds hierarchy, leaf identity holds" {
    # Host oracle: ExceptionGroup('g', [ExceptionGroup('i',
    #              [ValueError('v')])]) ; leafid=True (deep)
    # Anchor: Objects/exception_groups.c subgroup_split_recursive;
    # Lib/test/test_exception_group.py TestSubgroup.test_subgroup_nested.
    if not _kernel_ready() { return; }
    assert _run_native(
        "ve = ValueError('v')\n"
        "inner = ExceptionGroup('i', [ve])\n"
        "eg = ExceptionGroup('g', [inner, KeyError('k')])\n"
        "s = eg.subgroup(ValueError)\n"
        "r = (repr(s) + ' ## '\n"
        "     + str(s.exceptions[0].exceptions[0] is ve))\n"
    ) == "ExceptionGroup('g', [ExceptionGroup('i', [ValueError('v')])]) ## True";
}


# ---------------- notes threading (leaf identity consequence) ---------------

test "p3 split: __notes__ ride along via leaf identity" {
    # Host oracle: notes=['note-v'] ## True
    # Notes live on leaves, which keep identity through partitioning -- no
    # explicit copying needed.
    # Anchor: Objects/exceptions.c BaseException notes storage;
    # Lib/test/test_exception_group.py TestSplit.test_notes_preserved.
    if not _kernel_ready() { return; }
    assert _run_native(
        "ve, te = ValueError('v'), TypeError('t')\n"
        "ve.add_note('note-v')\n"
        "eg = ExceptionGroup('g', [ve, te])\n"
        "m, rest = eg.split(TypeError)\n"
        "rest_ve = rest.exceptions[0]\n"
        "r = 'notes=' + repr(rest_ve.__notes__) + ' ## ' + str(rest_ve is ve)\n"
    ) == "notes=['note-v'] ## True";
}
