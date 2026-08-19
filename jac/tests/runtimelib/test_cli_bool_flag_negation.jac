"""Regression test for #7464: --no-X twins exist only where negation is
meaningful, i.e. bool flags that default to True. A default-off flag gets no
twin, so help can no longer advertise a negation the handler cannot see."""

import argparse;
import from jaclang.cli.manifest { ArgMeta }
import from jaclang.cli.manifest_parse { add_argument }


def option_strings(parser: argparse.ArgumentParser) -> list {
    return [s for a in parser._actions for s in a.option_strings];
}


test "default=True bool flag keeps its --X/--no-X pair" {
    parser = argparse.ArgumentParser();
    add_argument(parser, ArgMeta(name="cache", typ="bool", default=True, help="x"));
    assert vars(parser.parse_args([]))["cache"] is True;
    assert vars(parser.parse_args(["--cache"]))["cache"] is True;
    assert vars(parser.parse_args(["--no-cache"]))["cache"] is False;
}

test "default=False bool flag gets no --no-X twin" {
    parser = argparse.ArgumentParser();
    add_argument(parser, ArgMeta(name="npm", typ="bool", default=False, help="x"));
    assert vars(parser.parse_args([]))["npm"] is False;
    assert vars(parser.parse_args(["--npm"]))["npm"] is True;
    assert "--no-npm" not in option_strings(parser);
    (_, extra) = parser.parse_known_args(["--no-npm"]);
    assert extra == ["--no-npm"];
}

test "bool flag without a declared default parses as plain False" {
    parser = argparse.ArgumentParser();
    add_argument(parser, ArgMeta(name="scrub", typ="bool", help="x"));
    assert vars(parser.parse_args([]))["scrub"] is False;
    assert vars(parser.parse_args(["--scrub"]))["scrub"] is True;
    assert "--no-scrub" not in option_strings(parser);
}

test "no-* named flag keeps its spelling and gains no double negation" {
    parser = argparse.ArgumentParser();
    add_argument(parser, ArgMeta(name="no-save", typ="bool", default=False, help="x"));
    assert vars(parser.parse_args(["--no-save"]))["no_save"] is True;
    assert vars(parser.parse_args([]))["no_save"] is False;
    assert "--no-no-save" not in option_strings(parser);
}
