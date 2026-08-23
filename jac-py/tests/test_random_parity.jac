"""P2 wave 18 facade parity: native _random MT19937 vs host stdlib.

jac-py/Modules/randommodule.{c,jac} stay the staged c2jac corpus pair
(staging=lift); this file gates the product-path facade semantics in
jac-py/jacpython/_randommodule.jac against the pinned host oracle.
Expected streams were captured from the host stdlib ``_random``
(CPython 3.14.x; the MT19937 kernel is unchanged since 3.11) at
authoring time and are bit-exact: uint32 words, 53-bit doubles, the
625-tuple state shape, and getrandbits word assembly all match.

``jumpahead`` was removed in Python 3.11 and is intentionally absent.
"""

import from _randommodule { Random_new }
import os;


# Host-captured uint32 streams: ten getrandbits(32) draws per seed.
def _golden_words(seed: int) -> list[int] {
    r = Random_new(seed);
    out: list[int] = [];
    for _ in range(10) {
        out.append(r.getrandbits(32));
    }
    return out;
}


def _expect_setstate_error(label: str, state: any, want_type_name: str,
                           want_msg: str) {
    raised = False;
    got_type = "";
    got_msg = "";
    try {
        r = Random_new(42);
        r.setstate(state);
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got_msg = str(e);
    }
    assert raised , label + ": expected an error";
    assert got_type == want_type_name , (label, got_type, want_type_name);
    assert got_msg == want_msg , (label, got_msg, want_msg);
}


def _expect_getrandbits_error(label: str, k: any, want_type_name: str,
                              want_msg: str) {
    raised = False;
    got_type = "";
    got_msg = "";
    try {
        r = Random_new(42);
        r.getrandbits(k);
    } except Exception as e {
        raised = True;
        got_type = type(e).__name__;
        got_msg = str(e);
    }
    assert raised , label + ": expected an error";
    assert got_type == want_type_name , (label, got_type, want_type_name);
    assert got_msg == want_msg , (label, got_msg, want_msg);
}


test "wave18 seeded uint32 streams are bit-exact" {
    cases: list = [
        (0, [3626764237, 1654615998, 3255389356, 3823568514, 1806341205,
             173879092, 1112038970, 4146640122, 2195908194, 2087043557]),
        (1, [577090037, 2444712010, 3639700191, 3445702192, 3280387012,
             271041745, 1095513148, 506456969, 2127877499, 3268308804]),
        (42, [2746317213, 478163327, 107420369, 3184935163, 1181241943,
              1051802512, 958682846, 599310825, 3163119785, 440213415]),
        # 2**32-1: single-word key of all ones.
        (4294967295, [2728839433, 2661025012, 872737089, 924893097,
                      2608619700, 2243681748, 1251276551, 2590083323,
                      1460408326, 4130059007]),
        # 2**64: key splits into two words (low, high) = (0, 1).
        (18446744073709551616,
         [4198958755, 3158798261, 1593907883, 395124210, 2146018685,
          4228699401, 2682463428, 598568243, 2673150525, 2212753496]),
        # Negative ints take abs(); -5 == 5 for seeding.
        (-5, [2675342405, 1097127993, 3185950873, 1539898300, 3415330359,
              2965446622, 4047793130, 3614262064, 3177840169, 2800454814]),
        # Multi-word big int: three 32-bit key words plus carry word.
        (123456789012345678901234567890,
         [3124625047, 947073620, 685135262, 3525393358, 50734197,
          2263638147, 1156635141, 4102715694, 3788331372, 3203362323]),
    ];
    for c in cases {
        lbl: str = "words seed=" + str(c[0]);
        assert _golden_words(c[0]) == c[1] , lbl;
    }
}


test "wave18 random() doubles match the host to all 53 bits" {
    # genrand_res53 composition: exact power-of-two scaling, so the repr
    # must equal the host stdlib digit for digit.
    cases: list = [
        (42, ["0.6394267984578837", "0.025010755222666936",
              "0.27502931836911926", "0.22321073814882275",
              "0.7364712141640124"]),
        (0, ["0.8444218515250481", "0.7579544029403025", "0.420571580830845",
             "0.25891675029296335", "0.5112747213686085"]),
        (123456789012345678901234567890,
         ["0.7275084571578186", "0.1595204831720859",
          "0.011812474780114934", "0.2693001103046382",
          "0.8820396344798871"]),
    ];
    for c in cases {
        r = Random_new(c[0]);
        for want in c[1] {
            got = repr(r.random());
            assert got == want , ("random seed=" + str(c[0]), got, want);
        }
    }
}


test "wave18 getrandbits edge sizes match host word order" {
    g = Random_new(42);
    # k == 0 consumes no draw and returns 0.
    assert g.getrandbits(0) == 0 , "k=0";
    # k <= 32 is the fast path: one draw, top k bits.
    k1: list[int] = [];
    for _ in range(4) {
        k1.append(g.getrandbits(1));
    }
    assert k1 == [1, 0, 0, 1] , k1;
    assert g.getrandbits(31) == 590620971 , "k=31";
    assert g.getrandbits(32) == 1051802512 , "k=32 full word";
    # Multi-word: little-endian assembly, last word right-truncated.
    seq: list[int] = [];
    for k in [33, 64, 65, 96, 128, 100] {
        seq.append(g.getrandbits(k));
    }
    assert seq == [
        958682846,
        1890702223848595625,
        32109652365136375149,
        46783636658334524660808229940,
        31882839497307630496007576300860674457,
        753091833484192460678735898763,
    ] , seq;
    # A wide result keeps its low words intact (host-checked modulus).
    big = Random_new(42).getrandbits(2048);
    assert big % 18446744073709551616 == 2053695854357871005 , "k=2048 low";
}


test "wave18 getstate/setstate round trip is exact" {
    ra = Random_new(42);
    for _ in range(17) {
        ra.random();
    }
    st = ra.getstate();
    assert len(st) == 625 , len(st);
    assert list(st[:8]) == [2468570525, 44967195, 2667364560, 2449893699,
                            1652692239, 766678126, 273175325, 1513475390] , (
        "state head"
    );
    assert st[624] == 34 , "index element";

    rb = Random_new(0);
    rb.setstate(st);
    restored: list = [];
    orig: list = [];
    for _ in range(3) {
        restored.append(repr(rb.random()));
        orig.append(repr(ra.random()));
    }
    assert restored == orig , "restored instance continues the stream";
    assert restored == ["0.5892656838759087", "0.8094304566778266",
                        "0.006498759678061017"] , restored;

    # index == N is the legal wrap boundary from the C validation.
    boundary: list = [0] * 625;
    boundary[624] = 624;
    rb.setstate(tuple(boundary));
    assert rb.index == 624 , "boundary accepted";
    assert rb.getrandbits(32) == 0 , "zero state draws zero after twist";
    assert rb.index == 1 , "wrap regenerated and consumed one word";
}


test "wave18 setstate/getrandbits raise oracle messages" {
    bad: list = [0] * 625;

    _expect_setstate_error("list state", [1] * 625, "TypeError",
                           "state vector must be a tuple");
    _expect_setstate_error("short state", tuple(range(624)), "ValueError",
                           "state vector is the wrong size");
    bad[0] = -1;
    _expect_setstate_error("negative word", tuple(bad), "OverflowError",
                           "can't convert negative value to unsigned int");
    bad[0] = 0;
    bad[624] = 625;
    _expect_setstate_error("index too big", tuple(bad), "ValueError",
                           "invalid state");
    bad[624] = -1;
    _expect_setstate_error("index negative", tuple(bad), "ValueError",
                           "invalid state");
    bad[624] = "x";
    _expect_setstate_error("non-int index", tuple(bad), "TypeError",
                           "an integer is required");

    _expect_getrandbits_error("getrandbits negative", -1, "ValueError",
                              "Cannot convert negative int");
    _expect_getrandbits_error("getrandbits float", 1.5, "TypeError",
                              "'float' object cannot be interpreted as an integer");
    _expect_getrandbits_error("getrandbits str", "x", "TypeError",
                              "'str' object cannot be interpreted as an integer");
    _expect_getrandbits_error("getrandbits overflow", 18446744073709551616,
                              "OverflowError",
                              "Python int too large for C uint64_t");
}


test "wave18 non-int seeding hashes then splits like size_t" {
    # seed(str/bytes/float) == seed(unsigned size_t of hash(arg)): this
    # internal-consistency pin holds regardless of the process hash secret.
    r1 = Random_new("spam");
    h = hash("spam");
    if h < 0 {
        h = h + 18446744073709551616;
    }
    r2 = Random_new(h);
    for _ in range(5) {
        assert repr(r1.random()) == repr(r2.random()) , "str vs hash seed";
    }

    # Absolute host goldens: they depend on the process-wide SipHash secret
    # matching the capture conditions (PYTHONHASHSEED=0, CPython 3.14.x,
    # zero key), so gate on both the env var and a runtime digest check
    # before arming. Under any other secret the pins would be meaningless.
    if os.environ.get("PYTHONHASHSEED") != "0" {
        return;
    }
    if hash("spam") != -7643603308804133256 {
        # Runtime str hashing diverges from the host seed-0 digest; skip
        # rather than fail spuriously (the int-seed suites above still
        # cover the full seeding path bit-exactly).
        return;
    }
    abc = Random_new(b"abc");
    wa: list[int] = [];
    for _ in range(10) {
        wa.append(abc.getrandbits(32));
    }
    # Captured from host CPython 3.14.6 with PYTHONHASHSEED=0:
    # _random.Random().seed(b"abc") then ten getrandbits(32) draws.
    assert wa == [1399766851, 1564118375, 2785668419, 1563851763,
                  3101890135, 3843218830, 4087631572, 3024535857,
                  3531209205, 2721367187] , wa;
    spam = Random_new("spam");
    ws: list[int] = [];
    for _ in range(10) {
        ws.append(spam.getrandbits(32));
    }
    # Captured from host CPython 3.14.6 with PYTHONHASHSEED=0:
    # _random.Random().seed("spam") then ten getrandbits(32) draws.
    assert ws == [4173631440, 81402601, 2196835559, 2439179921,
                  3761322200, 1838750950, 3875367247, 1645180411,
                  499267165, 2764153328] , ws;
}


test "wave18 default construction seeds from urandom" {
    # Mirrors _random.Random(): tp_init defaults to an urandom key. Values
    # cannot be pinned; verify the surface behaves (draws differ, range ok).
    a = Random_new();
    b = Random_new();
    x = a.random();
    y = a.random();
    assert 0.0 <= x < 1.0 and 0.0 <= y < 1.0 , (x, y);
    assert x != y , "consecutive draws differ";
    assert repr(b.random()) != "" , "second instance usable";
    # explicit None matches the default path
    c = Random_new(None);
    z = c.random();
    assert 0.0 <= z < 1.0 , z;
}
