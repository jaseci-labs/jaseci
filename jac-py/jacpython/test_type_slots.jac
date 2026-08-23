"""PyType_Ready ``__slots__`` layout helpers (type_slots.jac leaf — no OSP)."""
import from type_slots {
    type_ready,
    Py_TPFLAGS_READY,
    Py_TPFLAGS_READYING,
    type_slots_filter_members,
    type_slots_wants_dict,
    type_slots_wants_weakref,
    type_slots_merge_names,
    type_slots_has_dict,
    type_slots_has_weakrefs,
    type_slots_attr_allowed,
    type_slots_dict_visible,
    slots_is_dict_name,
    slots_is_weakref_name,
    type_slots_in_dict_view,
    type_slots_should_install_member,
    type_slots_member_repr,
}

test "type_ready sets READY and rejects nested READYING" {
    assert type_ready(0) == Py_TPFLAGS_READY;
    assert type_ready(Py_TPFLAGS_READY) == Py_TPFLAGS_READY;
    assert type_ready(Py_TPFLAGS_READYING) == -1;
}

test "slots filter drops dict/weakref specials and dedupes" {
    names = ["x", "__dict__", "y", "x", "__weakref__", "z"];
    filtered = type_slots_filter_members(names);
    assert filtered == ["x", "y", "z"];
    assert slots_is_dict_name("__dict__");
    assert slots_is_weakref_name("__weakref__");
    assert not slots_is_dict_name("x");
}

test "slots wants dict/weakref from declaration" {
    with_dict = ["a", "__dict__"];
    no_dict = ["a", "b"];
    with_wr = ["__weakref__"];
    no_wr = ["a"];
    assert type_slots_wants_dict(with_dict);
    assert not type_slots_wants_dict(no_dict);
    assert type_slots_wants_weakref(with_wr);
    assert not type_slots_wants_weakref(no_wr);
}

test "slots merge local then inherited" {
    local_names = ["b"];
    inherited = ["a", "b", "c"];
    merged = type_slots_merge_names(local_names, inherited);
    assert merged == ["b", "a", "c"];
}

test "slots has_dict inheritance rules" {
    assert type_slots_has_dict(False, False, False);
    assert not type_slots_has_dict(True, False, False);
    assert type_slots_has_dict(True, True, False);
    assert type_slots_has_dict(True, False, True);
}

test "slots has_weakrefs inheritance rules" {
    assert type_slots_has_weakrefs(False, False, False);
    assert not type_slots_has_weakrefs(True, False, False);
    assert type_slots_has_weakrefs(True, True, False);
    assert type_slots_has_weakrefs(True, False, True);
}

test "slots attr allowed gate" {
    slots = ["x", "y"];
    assert type_slots_attr_allowed("z", True, slots);
    assert type_slots_attr_allowed("x", False, slots);
    assert not type_slots_attr_allowed("z", False, slots);
    assert type_slots_dict_visible(True);
    assert not type_slots_dict_visible(False);
}

test "slots dict view excludes members; install gate; member repr" {
    assert type_slots_in_dict_view("b", ["x", "y"]);
    assert not type_slots_in_dict_view("x", ["x", "y"]);
    assert type_slots_should_install_member(False);
    assert not type_slots_should_install_member(True);
    assert (
        type_slots_member_repr("x", "C")
        == "<member 'x' of 'C' objects>"
    );
}
