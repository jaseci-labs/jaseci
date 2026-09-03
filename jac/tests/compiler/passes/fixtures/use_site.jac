"""Fixture for the use-site analysis pass.

Every ``by llm()`` ability below is a producer whose result flows (or fails to
flow) into a downstream consumer. The names are read by
``test_use_site_pass.jac`` through substring matching on the MTIR scope key.
"""

obj MockLLM {
    def __call__(**kwargs: dict) -> MockLLM {
        return self;
    }
}

glob llm = MockLLM();

obj Claim {
    has text: str,
        cited_span: str,
        score: float;
}

obj Checker {
    def run(items: list[Claim]) -> bool {
        return len(items) > 0;
    }
}

class PyChecker {
    def check(self: PyChecker, items: list[Claim]) -> bool {
        return len(items) > 0;
    }
}

def verify(claims: list[Claim], sources: list[str]) -> bool {
    return len(claims) > 0 and len(sources) >= 0;
}

def audit(claims: list[Claim]) -> bool {
    return len(claims) > 0;
}

# --- A1: bound to a local, one consumer, field reads -------------------------
def extract_claims(doc: str) -> list[Claim] by llm();

def use_extract(doc: str) -> bool {
    claims = extract_claims(doc);
    span = claims[0].cited_span;
    body = claims[0].text;
    again = claims[0].text;
    print(span, body, again);
    return verify(claims, []);
}

# --- A2: passed straight in as an argument ----------------------------------
def direct_claims(doc: str) -> list[Claim] by llm();

def use_direct(doc: str) -> bool {
    return verify(direct_claims(doc), []);
}

# --- A3: keyword argument ----------------------------------------------------
def kw_claims(doc: str) -> list[Claim] by llm();

def use_kw(doc: str) -> bool {
    found = kw_claims(doc);
    return verify(claims=found, sources=[]);
}

# --- A4: method consumer on an obj (no declared self) ------------------------
def method_claims(doc: str) -> list[Claim] by llm();

def use_method(doc: str, checker: Checker) -> bool {
    found = method_claims(doc);
    return checker.run(found);
}

# --- A5: method consumer on a class (declared self, needs the offset) --------
def cls_claims(doc: str) -> list[Claim] by llm();

def use_cls(doc: str, checker: PyChecker) -> bool {
    found = cls_claims(doc);
    return checker.check(found);
}

# --- R1: two distinct callees consume the value ------------------------------
def two_consumers(doc: str) -> list[Claim] by llm();

def use_two(doc: str) -> bool {
    found = two_consumers(doc);
    return verify(found, []) and audit(found);
}

# --- R2: escapes via return --------------------------------------------------
def escape_ret(doc: str) -> list[Claim] by llm();

def use_ret(doc: str) -> list[Claim] {
    found = escape_ret(doc);
    return found;
}

# --- R3/R4/R5: escapes into a list, a tuple and a dict -----------------------
def escape_list(doc: str) -> list[Claim] by llm();

def use_escape_list(doc: str) -> bool {
    found = escape_list(doc);
    bag = [found];
    print(bag);
    return True;
}

def escape_tuple(doc: str) -> list[Claim] by llm();

def use_escape_tuple(doc: str) -> bool {
    found = escape_tuple(doc);
    bag = (found, 1);
    print(bag);
    return True;
}

def escape_dict(doc: str) -> list[Claim] by llm();

def use_escape_dict(doc: str) -> bool {
    found = escape_dict(doc);
    bag = {"claims": found};
    print(bag);
    return True;
}

# --- R6: the callee is not statically resolvable -----------------------------
def builtin_claims(doc: str) -> list[Claim] by llm();

def use_builtin(doc: str) -> int {
    found = builtin_claims(doc);
    return len(found);
}

# --- R7: two call sites resolving to different consumers ---------------------
def multi_site(doc: str) -> list[Claim] by llm();

def site_one(doc: str) -> bool {
    found = multi_site(doc);
    return verify(found, []);
}

def site_two(doc: str) -> bool {
    found = multi_site(doc);
    return audit(found);
}

# --- R8: never called at all -------------------------------------------------
def orphan_claims(doc: str) -> list[Claim] by llm();

sem Claim = "A factual claim.";
sem Claim.text = "The claim text.";
sem Claim.cited_span = "The supporting span.";

sem verify = "Checks each claim against the provided sources.";
sem verify.claims = "list of verifiable factual assertions";
sem verify.sources = "the sources to check against";

sem Checker.run = "Runs the configured checks.";
sem Checker.run.items = "the claims to check";

sem PyChecker.check = "Runs the configured checks.";
sem PyChecker.check.items = "the claims to check";
