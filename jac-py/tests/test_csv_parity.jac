"""P2 wave 17 facade parity: native _csv vs host stdlib _csv.

Staged ``jac-py/Modules/_csv.{c,jac}`` stay the c2jac corpus pair
(staging=lift); this file gates the product-path facade semantics in
jac-py/jacpython/_csvmodule.jac against the pinned host oracle.
Expected values and error messages were verified against the host
stdlib ``_csv`` (CPython 3.14) at authoring time.

Error mapping: the facade raises plain Exception where CPython raises
_csv.Error; TypeError/ValueError keep their builtin types exactly.
"""

import from _csvmodule {
    QUOTE_ALL,
    QUOTE_MINIMAL,
    QUOTE_NONNUMERIC,
    QUOTE_NONE,
    QUOTE_NOTNULL,
    QUOTE_STRINGS,
    field_size_limit,
    get_dialect,
    list_dialects,
    reader,
    register_dialect,
    unregister_dialect,
    writer,
    _UNSET,
}


# Collecting sink standing in for a text-mode file object.
obj _Sink {
    has chunks: list[str] = [];

    def write(s: str) -> int {
        self.chunks.append(s);
        return len(s);
    }

    def value -> str {
        return "".join(self.chunks);
    }
}


# "Parameter not given" marker: the facade's own sentinel, imported so
# the helpers drive the exact not-given semantics (None is a meaningful
# fmtparam value for quotechar/escapechar).


def _rd(rows: list[str], dialect: any = _UNSET, delimiter: any = _UNSET,
        doublequote: any = _UNSET, escapechar: any = _UNSET,
        lineterminator: any = _UNSET, quotechar: any = _UNSET,
        quoting: any = _UNSET, skipinitialspace: any = _UNSET,
        strict: any = _UNSET) -> list {
    return list(reader(rows, dialect, delimiter, doublequote, escapechar,
                       lineterminator, quotechar, quoting,
                       skipinitialspace, strict));
}


def _expect_error(label: str, fn: any, want_type: str, want_msg: str) {
    raised = False;
    got = "";
    got_type = "";
    try {
        fn();
    } except Exception as e {
        raised = True;
        got = str(e);
        got_type = type(e).__name__;
    }
    assert raised , label + ": expected an error";
    assert got == want_msg , (label, got, want_msg);
    assert got_type == want_type , (label, got_type, want_type);
}


def _wr(row: any, dialect: any = None, delimiter: any = None,
        doublequote: any = None, escapechar: any = None,
        lineterminator: any = None, quotechar: any = None,
        quoting: any = None, skipinitialspace: any = None,
        strict: any = None) -> any {
    sink = _Sink();
    w = writer(
        sink, delimiter=delimiter if delimiter is not None else ",",
        doublequote=True if doublequote is None else doublequote,
        escapechar=escapechar,
        lineterminator="\r\n" if lineterminator is None else lineterminator,
        quotechar='"' if quotechar is None else quotechar,
        quoting=QUOTE_MINIMAL if quoting is None else quoting,
        skipinitialspace=False if skipinitialspace is None else skipinitialspace,
        strict=False if strict is None else strict,
    );
    ret = w.writerow(row);
    return (sink.value(), ret);
}


test "wave17 module constants match host" {
    assert QUOTE_MINIMAL == 0;
    assert QUOTE_ALL == 1;
    assert QUOTE_NONNUMERIC == 2;
    assert QUOTE_NONE == 3;
    assert QUOTE_STRINGS == 4;
    assert QUOTE_NOTNULL == 5;
    assert field_size_limit() == 131072;
}


test "wave17 reader basics" {
    assert _rd(["a,b,c", "d,e,f"]) == [["a", "b", "c"], ["d", "e", "f"]];
    # Empty lines yield empty records.
    assert _rd(["a,,c", "", "", "x,y"]) == [
        ["a", "", "c"], [], [], ["x", "y"]];
    assert _rd([""]) == [[]];
    assert _rd([","]) == [["", ""]];
    # Embedded newline inside quotes.
    assert _rd(['"a\nb",c']) == [["a\nb", "c"]];
    assert _rd(['"a\r\nb",x']) == [["a\r\nb", "x"]];
    # Quoted record continued across iterator lines.
    assert _rd(['"a', 'b"', "c,d"]) == [["ab"], ["c", "d"]];
    assert _rd(['"a', 'b"', "c"]) == [["ab"], ["c"]];
    # CR alone terminates a line; CR LF pair splits.
    assert _rd(["a\r", "b"]) == [["a"], ["b"]];
    # Escapes.
    assert _rd(["a\\,b"], escapechar="\\") == [["a,b"]];
    assert list(reader(iter(['"a\\"b"']), escapechar="\\", doublequote=False)) == [
        ['a"b']];
    # Escaped EOL becomes a literal newline.
    assert list(reader(iter(["a\\\nb"]), escapechar="\\")) == [["a\nb"]];
    assert _rd(["ab\\"]) == [["ab\\"]];
    # Doublequote handling.
    assert _rd(['"a""b"']) == [['a"b']];
    assert list(reader(iter(['"a"b"c"']), doublequote=False)) == [['ab"c"']];
    # skipinitialspace eats spaces before a field.
    assert list(reader(iter([" a,  b,c"]), skipinitialspace=True)) == [
        ["a", "b", "c"]];
    # Custom delimiters.
    assert list(reader(iter(["a|b|c"]), delimiter="|")) == [
        ["a", "b", "c"]];
    # QUOTE_NONE reader treats quotes literally.
    assert list(reader(iter(['"a,b"']), quoting=QUOTE_NONE)) == [
        ['"a', 'b"']];
}


test "wave17 reader quoting modes" {
    # QUOTE_NONNUMERIC converts unquoted fields via float(); conversion
    # happens at save time in field order, so a bad field aborts the record.
    _expect_error(
        "NONNUMERIC bad float",
        lambda { list(reader(iter(["1,x"]), quoting=QUOTE_NONNUMERIC)); },
        "ValueError", "could not convert string to float: 'x'");
    rec = list(reader(iter(['1,"x",3']), quoting=QUOTE_NONNUMERIC))[0];
    assert rec[0] == 1.0;
    assert isinstance(rec[0], float);
    assert rec[1] == "x";
    assert rec[2] == 3.0;
    assert isinstance(rec[2], float);
    assert list(reader(iter(['"5",6']), quoting=QUOTE_NONNUMERIC)) == [
        ["5", 6.0]];
    # QUOTE_STRINGS / QUOTE_NOTNULL map empty unquoted fields to None.
    assert list(reader(iter([","]), quoting=QUOTE_STRINGS)) == [[None, None]];
    assert list(reader(iter([","]), quoting=QUOTE_NOTNULL)) == [[None, None]];
    assert list(reader(iter([""]), quoting=QUOTE_STRINGS)) == [[]];
    # Quoted empty stays an empty string.
    assert list(reader(iter(['""']), quoting=QUOTE_STRINGS)) == [[""]];
}


test "wave17 reader strict mode and EOF contract" {
    _expect_error(
        "strict quote-in-quoted",
        lambda {  list(reader(iter(['"ab"x,y']), strict=True)); },
        "Exception", "',' expected after '\"'");
    # Non-strict keeps the stray character in the field.
    assert list(reader(iter(['"ab"x,y']))) == [["abx", "y"]];
    _expect_error(
        "unexpected end of data",
        lambda {  list(reader(iter(['"abc']), strict=True)); },
        "Exception", "unexpected end of data");
    # Non-strict saves the unterminated quoted remainder.
    assert list(reader(iter(['"abc']))) == [["abc"]];
    # Partial trailing unquoted field survives EOF even under strict.
    assert list(reader(iter(["abc"]), strict=True)) == [["abc"]];
    _expect_error(
        "newline in unquoted field",
        lambda {  list(reader(iter(["a\nb"]))); },
        "Exception",
        "new-line character seen in unquoted field - do you need to "
        + "open the file with newline=''?");
    _expect_error(
        "non-string iterator item",
        lambda {  list(reader(iter([1, 2]))); },
        "Exception",
        "iterator should return strings, not int (the file should be "
        + "opened in text mode)");
    r = reader(iter(["a,b", "c,d"]));
    r.__next__();
    assert r.line_num == 1;
    r.__next__();
    assert r.line_num == 2;
}


test "wave17 reader field size limit" {
    old = field_size_limit(5);
    assert old == 131072;
    _expect_error(
        "field limit",
        lambda {  list(reader(iter(["abcdefg"]))); },
        "Exception", "field larger than field limit (5)");
    # Exactly-at-limit parses fine.
    assert list(reader(iter(["abcde"]))) == [["abcde"]];
    field_size_limit(old);
    _expect_error(
        "limit must be int",
        lambda {  field_size_limit("x"); },
        "TypeError", "limit must be an integer");
    _expect_error(
        "limit bool rejected",
        lambda {  field_size_limit(True); },
        "TypeError", "limit must be an integer");
}


test "wave17 dialect validation matches host" {
    _expect_error(
        "delimiter int",
        lambda {  register_dialect("probe_d1", delimiter=5); },
        "TypeError", '"delimiter" must be a unicode character, not int');
    _expect_error(
        "delimiter len 2",
        lambda {  register_dialect("probe_d2", delimiter="ab"); },
        "TypeError",
        '"delimiter" must be a unicode character, not a string of length 2');
    _expect_error(
        "quoting str",
        lambda {  register_dialect("probe_d3", quoting="x"); },
        "TypeError", '"quoting" must be an integer, not str');
    _expect_error(
        "quoting bool not exact int",
        lambda {  register_dialect("probe_d4", quoting=True); },
        "TypeError", '"quoting" must be an integer, not bool');
    _expect_error(
        "quoting bad value",
        lambda {  register_dialect("probe_d5", quoting=99); },
        "TypeError", 'bad "quoting" value');
    _expect_error(
        "lineterminator int",
        lambda {  register_dialect("probe_d6", lineterminator=5); },
        "TypeError", '"lineterminator" must be a string, not int');
    _expect_error(
        "quotechar none with quoting",
        lambda {  register_dialect(
            "probe_d7", quotechar=None, quoting=QUOTE_MINIMAL); },
        "TypeError", "quotechar must be set if quoting enabled");
    _expect_error(
        "delimiter cr",
        lambda {  register_dialect("probe_d8", delimiter="\r"); },
        "ValueError", "bad delimiter value");
    _expect_error(
        "delimiter in lineterminator",
        lambda {  register_dialect(
            "probe_d9", delimiter=";", lineterminator=";;"); },
        "ValueError", "bad delimiter or lineterminator value");
    _expect_error(
        "escapechar space with skipinitialspace",
        lambda {  register_dialect(
            "probe_d10", escapechar=" ", skipinitialspace=True); },
        "ValueError", "bad escapechar value");
    _expect_error(
        "quotechar space with skipinitialspace",
        lambda {  register_dialect(
            "probe_d11", quotechar=" ", skipinitialspace=True); },
        "ValueError", "bad quotechar value");
    _expect_error(
        "delimiter equals quotechar",
        lambda {  register_dialect("probe_d12", delimiter='"'); },
        "ValueError", "bad delimiter or quotechar value");
    _expect_error(
        "delimiter equals escapechar",
        lambda {  register_dialect(
            "probe_d13", delimiter="\\", escapechar="\\"); },
        "ValueError", "bad delimiter or escapechar value");
    _expect_error(
        "escapechar equals quotechar",
        lambda {  register_dialect(
            "probe_d14", escapechar="'", quotechar="'"); },
        "ValueError", "bad escapechar or quotechar value");
}


test "wave17 dialect registry surface" {
    assert list_dialects() == [];
    _expect_error(
        "unknown get", lambda {  get_dialect("nope"); },
        "Exception", "unknown dialect");
    _expect_error(
        "unknown unregister", lambda {  unregister_dialect("nope"); },
        "Exception", "unknown dialect");
    # Instance registration reuses the instance.
    _expect_error(
        "missing lookup", lambda {  get_dialect("__missing__"); },
        "Exception", "unknown dialect");
    register_dialect("mine", delimiter=";");
    assert list_dialects() == ["mine"];
    gd = get_dialect("mine");
    assert gd.delimiter == ord(";") , gd.delimiter;
    assert gd.doublequote == True;
    assert gd.escapechar == -1;
    assert gd.lineterminator == "\r\n";
    assert gd.quotechar == ord('"');
    assert gd.quoting == QUOTE_MINIMAL;
    assert gd.skipinitialspace == False;
    assert gd.strict == False;
    # Name-based base plus kwarg override.
    register_dialect("k", delimiter="|");
    assert list(reader(iter(["a|b"]), "k")) == [["a", "b"]];
    assert list(reader(iter(["a|b,c"]), "k", delimiter=",")) == [
        ["a|b", "c"]];
    # quotechar=None without explicit quoting downgrades to QUOTE_NONE.
    register_dialect("nq", quotechar=None);
    assert get_dialect("nq").quoting == QUOTE_NONE;
    unregister_dialect("mine");
    unregister_dialect("k");
    unregister_dialect("nq");
    assert list_dialects() == [];
}


test "wave17 writer basics" {
    got = _wr([1, 2, "three"]);
    assert got[0] == "1,2,three\r\n" , got;
    assert got[1] == 11 , got;  # writerow returns the write() result
    assert _wr([None])[0] == '""\r\n';
    assert _wr([])[0] == "\r\n";
    assert _wr([""])[0] == '""\r\n';
    assert _wr(['a"b'])[0] == '"a""b"\r\n';
    assert _wr(["a\nb"])[0] == '"a\nb"\r\n';
    assert _wr(["p;q"], delimiter=";")[0] == '"p;q"\r\n';
    assert _wr(["a;b"], delimiter=";")[0] == '"a;b"\r\n';
    assert _wr(["a", "b"], lineterminator="\n")[0] == "a,b\n";
    # Minimal quoting wraps fields containing delimiter/newline/quotes.
    assert _wr(["x,y"])[0] == '"x,y"\r\n';
    assert _wr(["a\rb"])[0] == '"a\rb"\r\n';
}


test "wave17 writer quoting modes" {
    assert _wr(["x", 1, 2.5, True],
               quoting=QUOTE_NONNUMERIC)[0] == '"x",1,2.5,True\r\n';
    assert _wr(["a", None], quoting=QUOTE_ALL)[0] == '"a",""\r\n';
    assert _wr([], quoting=QUOTE_ALL)[0] == "\r\n";
    assert _wr([""], quoting=QUOTE_ALL)[0] == '""\r\n';
    assert _wr(["a", 1, None], quoting=QUOTE_STRINGS)[0] == '"a",1,\r\n';
    assert _wr(["a", None], quoting=QUOTE_NOTNULL)[0] == '"a",\r\n';
    # QUOTE_NONE escapes special characters instead of quoting.
    _expect_error(
        "no escapechar",
        lambda {  _wr(["a,b"], quoting=QUOTE_NONE); },
        "Exception", "need to escape, but no escapechar set");
    assert _wr(["a,b"], escapechar="\\",
               quoting=QUOTE_NONE)[0] == "a\\,b\r\n";
    _expect_error(
        "doublequote off needs escapechar",
        lambda {  _wr(['a"b'], doublequote=False); },
        "Exception", "need to escape, but no escapechar set");
    assert _wr(['a"b'], doublequote=False,
               escapechar="\\")[0] == 'a\\"b\r\n';
}


test "wave17 writer empty-field guards" {
    _expect_error(
        "single empty field QUOTE_NONE",
        lambda {  _wr([None], quoting=QUOTE_NONE); },
        "Exception", "single empty field record must be quoted");
    _expect_error(
        "single empty field QUOTE_STRINGS",
        lambda {  _wr([None], quoting=QUOTE_STRINGS); },
        "Exception", "single empty field record must be quoted");
    _expect_error(
        "single empty field QUOTE_NOTNULL",
        lambda {  _wr([None], quoting=QUOTE_NOTNULL); },
        "Exception", "single empty field record must be quoted");
    assert _wr(["", "b"], delimiter=" ",
               skipinitialspace=True)[0] == '"" b\r\n';
    _expect_error(
        "empty field space delim QUOTE_NONE",
        lambda {  _wr([""], delimiter=" ", skipinitialspace=True,
                    quoting=QUOTE_NONE); },
        "Exception",
        "empty field must be quoted if delimiter is a space and "
        + "skipinitialspace is true");
    _expect_error(
        "null field space delim QUOTE_STRINGS",
        lambda {  _wr([None], delimiter=" ", skipinitialspace=True,
                    quoting=QUOTE_STRINGS); },
        "Exception",
        "empty field must be quoted if delimiter is a space and "
        + "skipinitialspace is true");
}


test "wave17 writer argument surfaces" {
    _expect_error(
        "writer non-writable",
        lambda {  writer(5); },
        "TypeError", 'argument 1 must have a "write" method');
    _expect_error(
        "writerow non-iterable",
        lambda {  _wr(5); },
        "Exception", "iterable expected, not int");
    _expect_error(
        "reader non-iterable",
        lambda {  reader(5); },
        "TypeError", "'int' object is not iterable");
}


test "wave17 writerows matches host" {
    sink = _Sink();
    w = writer(sink);
    w.writerows([[1, "a"], [None]]);
    assert sink.value() == "1,a\r\n\"\"\r\n" , sink.value();
    sink2 = _Sink();
    w2 = writer(sink2, lineterminator="\n");
    w2.writerows([]);
    assert sink2.value() == "";
}
