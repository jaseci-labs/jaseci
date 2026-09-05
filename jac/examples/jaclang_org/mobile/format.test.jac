test "display_name drops an email domain and leaves plain names alone" {
    assert display_name("ada@example.com") == "ada";
    assert display_name("ada") == "ada";
    assert display_name("") == "";
}

test "initial_of upper-cases the first letter and is safe on empty" {
    assert initial_of("grace") == "G";
    assert initial_of("Linus") == "L";
    assert initial_of("") == "?";
}

test "avatar_url is keyed by the username" {
    assert avatar_url("ada").endswith("fake@ada");
    assert avatar_url("ada") != avatar_url("bob");
}

test "count_label picks the singular form only for one" {
    assert count_label(0, "member", "members") == "0 members";
    assert count_label(1, "member", "members") == "1 member";
    assert count_label(2, "member", "members") == "2 members";
}

test "chars_left counts down from the post limit" {
    assert chars_left("") == POST_LIMIT;
    assert chars_left("hello") == POST_LIMIT - 5;
    assert chars_left("x" * (POST_LIMIT + 3)) == -3;
}
