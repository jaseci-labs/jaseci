"""Native demotion classification (#8030 B1): a pass crash is an ICE,
not a placement decision. ICE demotions get a distinct census outcome
and a loud (non-dim) note; diagnostic demotions stay dim."""

import os;
import from jaclang.jac0core.compiler {
    na_census_begin,
    na_census_end,
    na_census_record,
    na_demotion_note
}


test "ICE note is loud and self-identifies as a compiler bug" {
    (msg, style) = na_demotion_note("m.jac", "AttributeError: width", True);
    assert style != "dim";
    assert "internal" in msg;
    assert "m.jac" in msg;
}


test "diagnostic demotion note stays dim" {
    (msg, style) = na_demotion_note("m.jac", "error[E5092]: nope", False);
    assert style == "dim";
    assert "preferred native" in msg;
}


test "census records ice as a distinct sticky outcome" {
    na_census_begin();
    key = "/tmp/jac_test_ice_probe.jac";
    na_census_record(key, "ice", "AttributeError", "boom");
    na_census_record(key, "native");
    snap = na_census_end();
    rec = snap[os.path.realpath(key)];
    assert rec["outcome"] == "ice";
    assert rec["code"] == "AttributeError";
}
