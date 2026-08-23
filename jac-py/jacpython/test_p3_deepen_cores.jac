"""P3 deepen-cores unit ratchet: leaf helper algorithms (no objects / OSP).

Covers the thin P3.2c–e cores that still need algorithm deepening. These
tests gate helper correctness as ports replace stubs; Layer-1 probes stay
in tools/p3_object_core/probes/.
"""
import from rangeobject {
    get_len_of_range, range_contains_longs, range_equals_longs,
}
import from bytearrayobject {
    bytearray_length, bytearray_valid_index, bytearray_adjust_index,
    bytearray_eq_lens,
}
import from unicodeobject {
    PyUnicode_1BYTE_KIND, PyUnicode_2BYTE_KIND, PyUnicode_4BYTE_KIND,
    unicode_kind_is_ascii, unicode_kind_width, unicode_nbytes, unicode_is_empty,
    unicode_lower, unicode_upper, unicode_capitalize, unicode_title, unicode_swapcase,
    unicode_startswith, unicode_endswith, unicode_removeprefix, unicode_removesuffix,
    unicode_split, unicode_rsplit, unicode_splitlines, unicode_join,
    unicode_find, unicode_rfind, unicode_count, unicode_replace,
    unicode_partition, unicode_rpartition,
    unicode_strip, unicode_lstrip, unicode_rstrip,
    unicode_center, unicode_ljust, unicode_rjust, unicode_zfill,
    unicode_isalpha, unicode_isdigit, unicode_isalnum, unicode_isspace,
    unicode_isupper, unicode_islower, unicode_istitle, unicode_isascii,
}
import from unicodectype {
    ALPHA_MASK, DIGIT_MASK, LOWER_MASK, SPACE_MASK, UPPER_MASK,
    unicodectype_isalpha_flags, unicodectype_isdigit_flags,
    unicodectype_isspace_flags, unicodectype_isupper_flags,
    unicodectype_islower_flags,
    ctype_isalpha_ch, ctype_isdigit_ch, ctype_isspace_ch,
    ctype_isupper_ch, ctype_islower_ch, ctype_isalnum_ch,
    ctype_str_isalpha, ctype_str_isdigit, ctype_str_isspace,
    ctype_str_isupper, ctype_str_islower, ctype_str_isalnum,
    ctype_str_istitle, ctype_str_isascii,
}
import from bytes_methods {
    bytes_isupper_byte, bytes_islower_byte, bytes_isdigit_byte,
    bytes_isspace_byte, bytes_isalpha_byte, bytes_isalnum_byte,
    bytes_toupper_byte, bytes_tolower_byte,
    bytes_upper_buf, bytes_lower_buf,
    bytes_isdigit_buf, bytes_isspace_buf, bytes_isalpha_buf, bytes_isalnum_buf,
    bytes_isupper_buf, bytes_islower_buf,
    bytes_startswith_buf, bytes_endswith_buf, bytes_find_buf, bytes_count_buf,
    bytes_split_buf, bytes_join_buf,
    bytes_strip_buf, bytes_lstrip_buf, bytes_rstrip_buf, bytes_replace_buf,
}
import from genobject {
    FRAME_CREATED, FRAME_SUSPENDED, FRAME_EXECUTING, FRAME_COMPLETED,
    gen_is_created, gen_is_suspended, gen_is_executing, gen_is_completed,
    gen_gi_running, gen_state_from_flags, gen_can_send_non_none,
    gen_is_alive, gen_gi_frame_is_none,
}
import from frameobject {
    FRAME_OWNED_BY_THREAD, FRAME_OWNED_BY_GENERATOR,
    frame_owned_by_generator, frame_owned_by_thread,
    frame_lineno_valid, frame_stack_empty, frame_is_cleared,
    frame_owner_for_gen, frame_lineno_from_lasti, frame_f_lineno,
}
import from weakrefobject {
    weakref_is_dead, weakref_has_callback, weakref_call_result_is_none,
    weakref_alive_after_clear, weakref_is_proxy, weakref_eq_same_referent,
    weakref_hash_allowed,
}
import from memoryobject {
    PyBUF_WRITABLE, memoryview_flags_writable, memoryview_nbytes,
    memoryview_ndim_ok, memoryview_itemsize_byte, memoryview_length,
    memoryview_adjust_index, memoryview_valid_index, memoryview_index,
    memoryview_tobytes, memoryview_tolist, memoryview_readonly_from_bytes,
    memoryview_readonly_from_bytearray, memoryview_eq_buf, memoryview_getslice,
}
import from enumobject {
    PY_SSIZE_T_MAX, enum_index_at_max, enum_advance_index,
    reversed_advance_index, reversed_start_index, enum_start_index,
    enum_yield_index, reversed_exhausted, reversed_length_hint,
}
import from iterobject {
    seqiter_length_hint, seqiter_exhausted, seqiter_next_index,
    seqiter_remaining, calliter_has_callable, seqiter_set_exhausted,
}
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
import from odictobject {
    odict_move_to_end_last, odict_eq_requires_order, odict_is_empty,
    odict_contains_key, odict_insert_key, odict_pop_key,
    odict_move_key_to_end, odict_keys_equal_ordered,
}
import from structseq {
    structseq_n_in_sequence, structseq_n_fields, structseq_index_ok,
    structseq_n_unnamed_fields, structseq_visible_length,
    structseq_field_index_ok, structseq_is_named_field, structseq_is_unnamed_field,
}


test "deepen: range length / contains / equals" {
    assert get_len_of_range(0, 5, 1) == 5;
    assert get_len_of_range(1, 10, 2) == 5;
    assert get_len_of_range(0, 5, -1) == 0;
    assert get_len_of_range(5, 0, -1) == 5;
    assert get_len_of_range(5, 0, 1) == 0;
    assert get_len_of_range(0, 0, 1) == 0;
    assert get_len_of_range(10, 0, -3) == 4;

    assert range_contains_longs(0, 5, 1, 3);
    assert not range_contains_longs(0, 5, 1, 5);
    assert not range_contains_longs(0, 5, 1, -1);
    assert range_contains_longs(1, 10, 2, 7);
    assert not range_contains_longs(1, 10, 2, 8);
    assert range_contains_longs(10, 0, -2, 4);
    assert not range_contains_longs(10, 0, -2, 5);

    assert range_equals_longs(0, 3, 1, 0, 3, 1);
    assert range_equals_longs(0, 0, 1, 5, 5, 2);
    assert range_equals_longs(2, 3, 1, 2, 9, 7);
    assert not range_equals_longs(0, 5, 1, 0, 5, 2);
    assert not range_equals_longs(0, 5, 1, 1, 6, 1);
}


test "deepen: bytearray index helpers" {
    assert bytearray_length(0) == 0;
    assert bytearray_length(3) == 3;
    assert bytearray_valid_index(0, 3);
    assert bytearray_valid_index(2, 3);
    assert not bytearray_valid_index(3, 3);
    assert not bytearray_valid_index(-1, 3);
    assert bytearray_adjust_index(0, 3) == 0;
    assert bytearray_adjust_index(-1, 3) == 2;
    assert bytearray_adjust_index(-3, 3) == 0;
    assert bytearray_eq_lens(2, 2);
    assert not bytearray_eq_lens(2, 3);
}


test "deepen: unicode kind / nbytes" {
    assert unicode_kind_is_ascii(PyUnicode_1BYTE_KIND, 0);
    assert unicode_kind_is_ascii(PyUnicode_1BYTE_KIND, 127);
    assert not unicode_kind_is_ascii(PyUnicode_1BYTE_KIND, 128);
    assert not unicode_kind_is_ascii(PyUnicode_2BYTE_KIND, 0);
    assert unicode_kind_width(PyUnicode_1BYTE_KIND) == 1;
    assert unicode_kind_width(PyUnicode_2BYTE_KIND) == 2;
    assert unicode_kind_width(PyUnicode_4BYTE_KIND) == 4;
    assert unicode_nbytes(0, PyUnicode_1BYTE_KIND) == 0;
    assert unicode_nbytes(3, PyUnicode_1BYTE_KIND) == 3;
    assert unicode_nbytes(3, PyUnicode_2BYTE_KIND) == 6;
    assert unicode_nbytes(3, PyUnicode_4BYTE_KIND) == 12;
    assert unicode_is_empty(0);
    assert not unicode_is_empty(1);
}


test "deepen: unicode str methods" {
    assert unicode_lower("AbC") == "abc";
    assert unicode_upper("AbC") == "ABC";
    assert unicode_capitalize("hello") == "Hello";
    assert unicode_title("hello world") == "Hello World";
    assert unicode_swapcase("AbC") == "aBc";
    assert unicode_lower("É") == "é";
    assert unicode_startswith("abc", "ab");
    assert unicode_endswith("abc", "bc");
    assert not unicode_startswith("abc", "x");
    assert unicode_removeprefix("TestCase", "Test") == "Case";
    assert unicode_removesuffix("TestCase", "Case") == "Test";

    assert unicode_split("a,b,c", ",", -1) == ["a", "b", "c"];
    assert unicode_split("a  b\tc", None, -1) == ["a", "b", "c"];
    assert unicode_split("a,b,c", ",", 1) == ["a", "b,c"];
    assert unicode_rsplit("a,b,c", ",", 1) == ["a,b", "c"];
    assert unicode_splitlines("a\nb\rc") == ["a", "b", "c"];
    assert unicode_join("-", ["a", "b"]) == "a-b";
    assert unicode_join("", ["α", "β"]) == "αβ";

    assert unicode_find("banana", "na") == 2;
    assert unicode_rfind("banana", "na") == 4;
    assert unicode_find("banana", "x") == -1;
    assert unicode_count("banana", "a") == 3;
    assert unicode_replace("aaa", "a", "b", 2) == "bba";
    assert unicode_replace("foo", "o", "0", -1) == "f00";
    assert unicode_partition("a,b,c", ",") == ("a", ",", "b,c");
    assert unicode_rpartition("a,b,c", ",") == ("a,b", ",", "c");

    assert unicode_strip("  hi  ", None) == "hi";
    assert unicode_strip("xxhiyy", "xy") == "hi";
    assert unicode_lstrip("  hi  ", None) == "hi  ";
    assert unicode_rstrip("  hi  ", None) == "  hi";
    assert unicode_center("hi", 6, "-") == "--hi--";
    assert unicode_ljust("hi", 5, ".") == "hi...";
    assert unicode_rjust("hi", 5, ".") == "...hi";
    assert unicode_zfill("42", 5) == "00042";
    assert unicode_zfill("-42", 5) == "-0042";

    assert unicode_isalpha("AbC");
    assert unicode_isalpha("α");
    assert not unicode_isalpha("Ab1");
    assert unicode_isdigit("123");
    assert unicode_isalnum("Ab1");
    assert unicode_isspace(" \t\n");
    assert unicode_isupper("ABC");
    assert unicode_islower("abc");
    assert unicode_istitle("Hello World");
    assert unicode_isascii("abc");
    assert not unicode_isascii("α");
    assert unicode_isascii("");
    assert not unicode_isalpha("");
}


test "deepen: unicodectype flag masks" {
    assert unicodectype_isalpha_flags(ALPHA_MASK);
    assert not unicodectype_isalpha_flags(DIGIT_MASK);
    assert unicodectype_isdigit_flags(DIGIT_MASK);
    assert unicodectype_isspace_flags(SPACE_MASK);
    assert unicodectype_isupper_flags(UPPER_MASK);
    assert unicodectype_islower_flags(LOWER_MASK);
    assert unicodectype_isalpha_flags(ALPHA_MASK | UPPER_MASK);
    assert not unicodectype_isdigit_flags(0);
}


test "deepen: unicodectype char / str class" {
    # Char helpers: length-1 ASCII (accented probes live in unicodectype_core.py).
    assert ctype_isalpha_ch("A");
    assert ctype_isalpha_ch("z");
    assert not ctype_isalpha_ch("1");
    assert not ctype_isalpha_ch("Ab");
    assert not ctype_isalpha_ch("");
    assert ctype_isdigit_ch("9");
    assert not ctype_isdigit_ch("a");
    assert ctype_isspace_ch(" ");
    assert ctype_isspace_ch("\t");
    assert ctype_isspace_ch("\n");
    assert not ctype_isspace_ch("x");
    assert ctype_isupper_ch("A");
    assert not ctype_isupper_ch("a");
    assert ctype_islower_ch("a");
    assert not ctype_islower_ch("A");
    assert ctype_isalnum_ch("A");
    assert ctype_isalnum_ch("9");
    assert not ctype_isalnum_ch("!");

    assert ctype_str_isalpha("Abc");
    assert not ctype_str_isalpha("");
    assert not ctype_str_isalpha("A1");
    assert ctype_str_isdigit("42");
    assert not ctype_str_isdigit("");
    assert ctype_str_isspace(" \t\n");
    assert not ctype_str_isspace("");
    assert ctype_str_isupper("ABC");
    assert not ctype_str_isupper("Abc");
    assert ctype_str_islower("abc");
    assert not ctype_str_islower("aBc");
    assert ctype_str_isalnum("A1");
    assert not ctype_str_isalnum("");
    assert ctype_str_istitle("Title Case");
    assert not ctype_str_istitle("TITLE");
    assert not ctype_str_istitle("");
    assert ctype_str_isascii("Ab12");
    assert ctype_str_isascii("");
}


test "deepen: bytes_methods ASCII character class" {
    assert bytes_isupper_byte(65);
    assert bytes_isupper_byte(90);
    assert not bytes_isupper_byte(64);
    assert not bytes_isupper_byte(91);
    assert bytes_islower_byte(97);
    assert bytes_islower_byte(122);
    assert not bytes_islower_byte(96);
    assert bytes_isdigit_byte(48);
    assert bytes_isdigit_byte(57);
    assert not bytes_isdigit_byte(47);
    assert bytes_isspace_byte(32);
    assert bytes_isspace_byte(9);
    assert bytes_isspace_byte(10);
    assert bytes_isspace_byte(13);
    assert bytes_isspace_byte(11);
    assert bytes_isspace_byte(12);
    assert not bytes_isspace_byte(65);
    assert bytes_isalpha_byte(ord("A"));
    assert bytes_isalnum_byte(ord("1"));
    assert not bytes_isalnum_byte(ord("!"));
    assert bytes_toupper_byte(ord("a")) == ord("A");
    assert bytes_toupper_byte(ord("A")) == ord("A");
    assert bytes_tolower_byte(ord("A")) == ord("a");
    assert bytes_tolower_byte(ord("a")) == ord("a");
    assert bytes_tolower_byte(ord("0")) == ord("0");
}


test "deepen: bytes_methods buffer algorithms" {
    assert bytes_upper_buf([97, 66]) == [65, 66];
    assert bytes_lower_buf([65, 98]) == [97, 98];
    assert bytes_isdigit_buf([49, 50]);
    assert not bytes_isdigit_buf([]);
    assert not bytes_isdigit_buf([49, 97]);
    assert bytes_isspace_buf([32, 9]);
    assert not bytes_isspace_buf([]);
    assert bytes_isalpha_buf([65, 98]);
    assert not bytes_isalpha_buf([65, 49]);
    assert bytes_isalnum_buf([65, 49]);
    assert not bytes_isalnum_buf([]);
    assert bytes_isupper_buf([65, 49]);
    assert not bytes_isupper_buf([65, 98]);
    assert not bytes_isupper_buf([]);
    assert bytes_islower_buf([97, 49]);
    assert not bytes_islower_buf([65, 97]);
    assert bytes_startswith_buf([97, 98, 99], [97, 98]);
    assert bytes_endswith_buf([97, 98, 99], [98, 99]);
    assert bytes_find_buf([97, 98, 99], [98]) == 1;
    assert bytes_find_buf([97, 98, 99], [120]) == -1;
    assert bytes_count_buf([97, 97, 97], [97]) == 3;
    assert bytes_count_buf([97, 97, 97], [97, 97]) == 1;
    parts = bytes_split_buf([97, 32, 32, 98], [], True);
    assert len(parts) == 2;
    assert parts[0] == [97];
    assert parts[1] == [98];
    parts2 = bytes_split_buf([97, 44, 44, 98], [44], False);
    assert len(parts2) == 3;
    assert parts2[0] == [97];
    assert parts2[1] == [];
    assert parts2[2] == [98];
    assert bytes_join_buf([44], [[97], [98]]) == [97, 44, 98];
    assert bytes_strip_buf([32, 97, 98, 32], [], True) == [97, 98];
    assert bytes_lstrip_buf([32, 97, 98, 32], [], True) == [97, 98, 32];
    assert bytes_rstrip_buf([32, 97, 98, 32], [], True) == [32, 97, 98];
    assert bytes_replace_buf([97, 97, 97], [97], [98], 2) == [98, 98, 97];
}


test "deepen: genobject frame-state helpers" {
    assert gen_is_created(FRAME_CREATED);
    assert gen_is_suspended(FRAME_SUSPENDED);
    assert gen_is_executing(FRAME_EXECUTING);
    assert gen_is_completed(FRAME_COMPLETED);
    assert not gen_is_created(FRAME_SUSPENDED);
    assert gen_gi_running(FRAME_EXECUTING);
    assert not gen_gi_running(FRAME_SUSPENDED);
    assert not gen_gi_running(FRAME_CREATED);
    assert gen_state_from_flags(False, False, False) == FRAME_CREATED;
    assert gen_state_from_flags(True, False, False) == FRAME_SUSPENDED;
    assert gen_state_from_flags(True, False, True) == FRAME_EXECUTING;
    assert gen_state_from_flags(True, True, False) == FRAME_COMPLETED;
    assert not gen_can_send_non_none(False, False);
    assert gen_can_send_non_none(True, False);
    assert gen_is_alive(True, False);
    assert not gen_is_alive(True, True);
    assert gen_gi_frame_is_none(True, False);
    assert gen_gi_frame_is_none(False, True);
    assert not gen_gi_frame_is_none(False, False);
}


test "deepen: frameobject ownership / lineno" {
    assert frame_owned_by_thread(FRAME_OWNED_BY_THREAD);
    assert frame_owned_by_generator(FRAME_OWNED_BY_GENERATOR);
    assert not frame_owned_by_generator(FRAME_OWNED_BY_THREAD);
    assert frame_lineno_valid(0);
    assert frame_lineno_valid(10);
    assert not frame_lineno_valid(-1);
    assert frame_stack_empty(0);
    assert frame_stack_empty(-1);
    assert not frame_stack_empty(1);
    assert frame_is_cleared(True);
    assert not frame_is_cleared(False);
    assert frame_owner_for_gen(True) == FRAME_OWNED_BY_GENERATOR;
    assert frame_owner_for_gen(False) == FRAME_OWNED_BY_THREAD;
    assert frame_lineno_from_lasti(-1, 10) == 10;
    assert frame_f_lineno(7, True) == 7;
    assert frame_f_lineno(7, False) == -1;
}


test "deepen: weakref alive / callback flags" {
    assert weakref_is_dead(False);
    assert not weakref_is_dead(True);
    assert weakref_has_callback(True);
    assert not weakref_has_callback(False);
    assert weakref_call_result_is_none(False);
    assert not weakref_call_result_is_none(True);
    assert not weakref_alive_after_clear();
    assert weakref_is_proxy(True);
    assert weakref_eq_same_referent(True, True, True);
    assert not weakref_eq_same_referent(True, False, True);
    assert weakref_hash_allowed(True);
    assert not weakref_hash_allowed(False);
}


test "deepen: memoryview flags / nbytes" {
    assert memoryview_flags_writable(PyBUF_WRITABLE);
    assert not memoryview_flags_writable(0);
    assert memoryview_nbytes(4, 1) == 4;
    assert memoryview_nbytes(4, 8) == 32;
    assert memoryview_nbytes(0, 8) == 0;
    assert memoryview_ndim_ok(0);
    assert memoryview_ndim_ok(3);
    assert not memoryview_ndim_ok(-1);
    assert memoryview_itemsize_byte() == 1;
    assert memoryview_length([1, 2, 3]) == 3;
    assert memoryview_adjust_index(-1, 3) == 2;
    assert memoryview_valid_index(0, 3);
    assert not memoryview_valid_index(3, 3);
    assert memoryview_index([10, 20, 30], 1) == 20;
    assert memoryview_tobytes([1, 2]) == [1, 2];
    assert memoryview_tolist([3]) == [3];
    assert memoryview_readonly_from_bytes();
    assert not memoryview_readonly_from_bytearray();
    assert memoryview_eq_buf([1, 2], [1, 2]);
    assert not memoryview_eq_buf([1], [2]);
    assert memoryview_getslice([0, 1, 2, 3], 1, 3, 1) == [1, 2];
}


test "deepen: enum / reversed index helpers" {
    assert enum_index_at_max(PY_SSIZE_T_MAX);
    assert not enum_index_at_max(0);
    assert enum_advance_index(0) == 1;
    assert enum_advance_index(41) == 42;
    assert enum_start_index(5) == 5;
    assert enum_yield_index(9) == 9;
    assert reversed_start_index(5) == 4;
    assert reversed_start_index(1) == 0;
    assert reversed_advance_index(4) == 3;
    assert reversed_exhausted(-1);
    assert not reversed_exhausted(0);
    assert reversed_length_hint(2) == 3;
    assert reversed_length_hint(-1) == 0;
}


test "deepen: seqiter length_hint / exhausted" {
    assert seqiter_length_hint(5, 0, True) == 5;
    assert seqiter_length_hint(5, 2, True) == 3;
    assert seqiter_length_hint(5, 5, True) == 0;
    assert seqiter_length_hint(5, 6, True) == 0;
    assert seqiter_length_hint(5, 0, False) == 0;
    assert seqiter_exhausted(False);
    assert not seqiter_exhausted(True);
    assert seqiter_next_index(0) == 1;
    assert seqiter_next_index(9) == 10;
    assert seqiter_remaining(5, 2) == 3;
    assert seqiter_remaining(5, 8) == 0;
    assert calliter_has_callable(True);
    assert not seqiter_set_exhausted();
}


test "deepen: type_ready / __slots__ layout helpers" {
    assert type_ready(0) == Py_TPFLAGS_READY;
    assert type_ready(Py_TPFLAGS_READY) == Py_TPFLAGS_READY;
    assert type_ready(Py_TPFLAGS_READYING) == -1;

    names = ["x", "__dict__", "y", "x", "__weakref__", "z"];
    assert type_slots_filter_members(names) == ["x", "y", "z"];
    assert slots_is_dict_name("__dict__");
    assert slots_is_weakref_name("__weakref__");

    with_dict = ["a", "__dict__"];
    no_dict = ["a", "b"];
    assert type_slots_wants_dict(with_dict);
    assert not type_slots_wants_dict(no_dict);
    assert type_slots_wants_weakref(["__weakref__"]);
    assert not type_slots_wants_weakref(["a"]);

    local_names = ["b"];
    inherited = ["a", "b", "c"];
    assert type_slots_merge_names(local_names, inherited) == ["b", "a", "c"];

    assert type_slots_has_dict(False, False, False);
    assert not type_slots_has_dict(True, False, False);
    assert type_slots_has_dict(True, True, False);
    assert type_slots_has_dict(True, False, True);

    assert type_slots_has_weakrefs(False, False, False);
    assert not type_slots_has_weakrefs(True, False, False);
    assert type_slots_has_weakrefs(True, True, False);
    assert type_slots_has_weakrefs(True, False, True);

    slots = ["x", "y"];
    assert type_slots_attr_allowed("z", True, slots);
    assert type_slots_attr_allowed("x", False, slots);
    assert not type_slots_attr_allowed("z", False, slots);
    assert type_slots_dict_visible(True);
    assert not type_slots_dict_visible(False);

    assert type_slots_in_dict_view("b", ["x", "y"]);
    assert not type_slots_in_dict_view("x", ["x", "y"]);
    assert type_slots_should_install_member(False);
    assert not type_slots_should_install_member(True);
    assert type_slots_member_repr("x", "C") == "<member 'x' of 'C' objects>";
}


test "deepen: OrderedDict key-order helpers" {
    assert odict_move_to_end_last(True);
    assert not odict_move_to_end_last(False);
    assert odict_eq_requires_order();
    assert odict_is_empty(0);
    assert not odict_is_empty(2);

    order = ["a", "b"];
    assert odict_contains_key(order, "a");
    assert not odict_contains_key(order, "z");
    assert odict_insert_key(order, "c") == ["a", "b", "c"];
    assert odict_insert_key(order, "a") == ["a", "b"];
    assert odict_pop_key(["a", "b", "c"], "b") == ["a", "c"];
    assert odict_move_key_to_end(["a", "b", "c"], "a", True) == ["b", "c", "a"];
    assert odict_move_key_to_end(["a", "b", "c"], "c", False) == ["c", "a", "b"];
    assert odict_keys_equal_ordered(["a", "b"], ["a", "b"]);
    assert not odict_keys_equal_ordered(["a", "b"], ["b", "a"]);
}


test "deepen: structseq field layout helpers" {
    assert structseq_n_in_sequence(3) == 3;
    assert structseq_n_fields(5) == 5;
    assert structseq_index_ok(0, 3);
    assert not structseq_index_ok(3, 3);
    assert structseq_n_unnamed_fields(5, 3) == 2;
    assert structseq_n_unnamed_fields(2, 5) == 0;
    assert structseq_visible_length(4) == 4;
    assert structseq_visible_length(-1) == 0;
    assert structseq_field_index_ok(4, 5);
    assert not structseq_field_index_ok(5, 5);
    assert structseq_is_named_field(2, 3);
    assert not structseq_is_named_field(3, 3);
    assert structseq_is_unnamed_field(3, 5, 3);
    assert not structseq_is_unnamed_field(1, 5, 3);
}

