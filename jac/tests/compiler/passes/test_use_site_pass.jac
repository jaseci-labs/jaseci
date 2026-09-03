"""Use-site analysis pass tests.

The pass runs last in the analysis schedule and stamps a `UseSiteInfo` onto
every `FunctionInfo` registered in `mtir_map` for a declared `by llm()`
ability, whether or not a consumer could be resolved.
"""

import contextlib;
import io;
import os;
import pickle;
import from tests.support { JAC_ROOT }
import from jaclang { JacRuntime as Jac }
import from jaclang.compiler.driver.mtp { UseSiteInfo }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "passes", "fixtures"),
     _CACHE: dict[str, any] = {},
     ALL_PRODUCERS = [
         "extract_claims",
         "direct_claims",
         "kw_claims",
         "method_claims",
         "cls_claims",
         "two_consumers",
         "escape_ret",
         "escape_list",
         "escape_tuple",
         "escape_dict",
         "builtin_claims",
         "multi_site",
         "orphan_claims"
     ];


"""Compile the fixture and key every recorded use site by its ability name."""
def compile_fixture -> dict[str, any] {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "use_site.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert Jac.program is not None;
    out: dict[str, any] = {};
    for (scope, info) in Jac.program.mtir_map.items() {
        any_info: any = info;
        out[str(scope).split(".")[-1]] = any_info.use_site;
    }
    return out;
}


"""Memoized fixture compile, so the suite pays for one compile only."""
def sites -> dict[str, any] {
    if not _CACHE {
        _CACHE.update(compile_fixture());
    }
    return _CACHE;
}


"""Flatten a UseSiteInfo into a comparable tuple."""
def as_tuple(us: any) -> tuple {
    return (
        us.resolved,
        us.reason,
        us.consumer_name,
        us.consumer_semstr,
        us.consumer_parent_class,
        us.param_name,
        us.param_semstr,
        us.param_type,
        tuple(us.fields_read or [])
    );
}


test "every genai ability carries a use site record" {
    found = sites();
    for name in ALL_PRODUCERS {
        assert name in found , f"{name} missing from mtir_map. Have: {sorted(
            found.keys()
        )}";
        assert isinstance(found[name], UseSiteInfo) , f"{name} has no UseSiteInfo";
    }
}

test "single consumer through a local is fully resolved" {
    us = sites()["extract_claims"];
    assert us.resolved , f"expected resolved, reason was {us.reason!r}";
    assert us.reason == "";
    assert us.consumer_name == "verify";
    assert us.consumer_parent_class is None;
    assert us.consumer_semstr == "Checks each claim against the provided sources.";
    assert us.param_name == "claims";
    assert us.param_semstr == "list of verifiable factual assertions";
    assert us.param_type == "list[Claim]";
    assert us.consumer_module is not None;
    assert us.consumer_module.endswith("use_site.jac");
}

test "result passed straight in as an argument is resolved" {
    us = sites()["direct_claims"];
    assert us.resolved , f"expected resolved, reason was {us.reason!r}";
    assert us.consumer_name == "verify";
    assert us.param_name == "claims";
    assert us.param_type == "list[Claim]";
    assert us.fields_read == [];
}

test "field reads are collected deduplicated and in source order" {
    us = sites()["extract_claims"];
    assert us.fields_read == ["cited_span", "text"] , f"got {us.fields_read}";
}

test "keyword argument consumer is resolved to the named parameter" {
    us = sites()["kw_claims"];
    assert us.resolved , f"expected resolved, reason was {us.reason!r}";
    assert us.consumer_name == "verify";
    assert us.param_name == "claims";
    assert us.param_semstr == "list of verifiable factual assertions";
}

test "obj method consumer is resolved with its parent class" {
    us = sites()["method_claims"];
    assert us.resolved , f"expected resolved, reason was {us.reason!r}";
    assert us.consumer_name == "run";
    assert us.consumer_parent_class == "Checker";
    assert us.param_name == "items";
    assert us.param_semstr == "the claims to check";
    assert us.param_type == "list[Claim]";
}

test "class method consumer skips the declared self parameter" {
    us = sites()["cls_claims"];
    assert us.resolved , f"expected resolved, reason was {us.reason!r}";
    assert us.consumer_name == "check";
    assert us.consumer_parent_class == "PyChecker";
    assert us.param_name == "items" , f"self offset not applied, got {us.param_name!r}";
    assert us.param_type == "list[Claim]";
}

test "two distinct callees consuming the value is rejected" {
    us = sites()["two_consumers"];
    assert not us.resolved;
    assert us.reason == "uses reach more than one consumer";
}

test "escaping via return is rejected" {
    us = sites()["escape_ret"];
    assert not us.resolved;
    assert us.reason == "result escapes via return";
}

test "escaping into a list tuple or dict is rejected" {
    found = sites();
    for name in ["escape_list", "escape_tuple", "escape_dict"] {
        us = found[name];
        assert not us.resolved , f"{name} should not resolve";
        assert us.reason == "result escapes into a container" , f"{name}: {us.reason!r}";
    }
}

test "an unresolvable callee is rejected" {
    us = sites()["builtin_claims"];
    assert not us.resolved;
    assert us.reason == "consumer could not be resolved";
}

test "call sites reaching different consumers are rejected" {
    us = sites()["multi_site"];
    assert not us.resolved;
    assert us.reason == "call sites resolve to different consumers";
}

test "a producer with no call site is rejected" {
    us = sites()["orphan_claims"];
    assert not us.resolved;
    assert us.reason == "no call site in declaring module";
}

test "rejected use sites record a reason and nothing else" {
    found = sites();
    rejected = [
        "two_consumers",
        "escape_ret",
        "escape_list",
        "escape_tuple",
        "escape_dict",
        "builtin_claims",
        "multi_site",
        "orphan_claims"
    ];
    reasons: set = set();
    for name in rejected {
        us = found[name];
        assert not us.resolved;
        assert us.reason , f"{name} has no reason";
        assert us.consumer_name == "" , f"{name} leaked a consumer name";
        assert us.consumer_semstr is None;
        assert us.consumer_module is None;
        assert us.consumer_parent_class is None;
        assert us.param_name == "";
        assert us.param_semstr is None;
        assert us.param_type == "";
        assert us.fields_read == [];
        reasons.add(us.reason);
    }
    assert len(reasons) == 6 , f"reject reasons not distinguishable: {sorted(reasons)}";
}

test "use site analysis is deterministic across compiles" {
    first = {k: as_tuple(v) for (k, v) in sites().items()};
    second = {k: as_tuple(v) for (k, v) in compile_fixture().items()};
    assert first == second , "use site analysis differed between two compiles";
}

test "use site info survives a pickle round trip" {
    original = {k: as_tuple(v) for (k, v) in sites().items()};
    blob = pickle.dumps(sites());
    restored = {k: as_tuple(v) for (k, v) in pickle.loads(blob).items()};
    assert restored == original;
}

test "a function info without a use site attribute reads as none" {
    import from jaclang.compiler.driver.mtp { FunctionInfo }

    legacy = FunctionInfo(name="legacy", semstr="");
    legacy.__dict__.pop("use_site", None);
    assert legacy?.use_site is None;
}

test "a default use site info normalizes its field list" {
    fresh = UseSiteInfo();
    assert fresh.fields_read == [];
    assert fresh.resolved is False;
    assert fresh.reason == "";
}

test "the compile time report stays silent without the env var" {
    prev = os.environ.get("JAC_USE_SITE_REPORT");
    os.environ.pop("JAC_USE_SITE_REPORT", None);
    buf = io.StringIO();
    try {
        with contextlib.redirect_stderr(buf) {
            compile_fixture();
        }
    } finally {
        if prev is not None {
            os.environ["JAC_USE_SITE_REPORT"] = prev;
        }
    }
    assert "[use-site]" not in buf.getvalue();
}

test "the compile time report names every ability when enabled" {
    prev = os.environ.get("JAC_USE_SITE_REPORT");
    os.environ["JAC_USE_SITE_REPORT"] = "1";
    buf = io.StringIO();
    try {
        with contextlib.redirect_stderr(buf) {
            compile_fixture();
        }
    } finally {
        if prev is None {
            os.environ.pop("JAC_USE_SITE_REPORT", None);
        } else {
            os.environ["JAC_USE_SITE_REPORT"] = prev;
        }
    }
    lines = [
        ln
        for ln in buf.getvalue().splitlines()
        if ln.startswith("[use-site]")
    ];
    assert len(lines) == len(ALL_PRODUCERS) , f"got {len(lines)} report lines";
    joined = "\n".join(lines);
    for name in ALL_PRODUCERS {
        assert f"scope=use_site.{name} " in joined , f"{name} missing from the report";
    }
    assert 'consumer=verify param=claims type=list[Claim] fields=cited_span,text'
        in joined;
    assert 'resolved=no reason="result escapes via return"' in joined;
}
