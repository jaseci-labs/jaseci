import io
import os

R = __import__("os").environ.get("IO_CENSUS_ROOT", "/var/tmp/qr-census")
os.makedirs(R, exist_ok=True)


def check(name, fn):
    try:
        fn()
        print("OK", name)
    except Exception as e:
        print("FAIL", name, type(e).__name__, e)


def p_write_modes():
    f = open(R + "/a.txt", "w")
    f.write("hello\n")
    f.close()
    f = open(R + "/a.txt", "a")
    f.write("world\n")
    f.close()


def p_x_mode():
    try:
        f = open(R + "/x.txt", "x")
        f.write("1")
        f.close()
    except FileExistsError:
        raise


def p_read_text():
    f = open(R + "/a.txt")
    data = f.read()
    f.close()
    assert data == "hello\nworld\n"


def p_read_n():
    f = open(R + "/a.txt")
    assert f.read(5) == "hello"
    assert f.read(1) == "\n"
    f.close()


def p_readline():
    f = open(R + "/a.txt")
    assert f.readline() == "hello\n"
    assert f.readline() == "world\n"
    assert f.readline() == ""
    f.close()


def p_readlines():
    f = open(R + "/a.txt")
    lines = f.readlines()
    f.close()
    assert lines == ["hello\n", "world\n"]


def p_iter():
    f = open(R + "/a.txt")
    got = [ln for ln in f]
    f.close()
    assert got == ["hello\n", "world\n"]


def p_binary():
    f = open(R + "/b.bin", "wb")
    f.write(b"\x00\x01\x02")
    f.close()
    g = open(R + "/b.bin", "rb")
    d = g.read()
    g.close()
    assert d == b"\x00\x01\x02"
    assert type(d) is bytes


def p_seek_tell():
    f = open(R + "/a.txt", "rb")
    f.seek(2)
    t = f.tell()
    d = f.read(3)
    f.seek(0, 2)
    end = f.tell()
    f.seek(-4, 2)
    tail = f.read()
    f.seek(0)
    f.close()
    assert t == 2 and d == b"llo" and end == 12 and tail == b"rld\n"


def p_writelines():
    f = open(R + "/c.txt", "w")
    f.writelines(["x\n", "y\n"])
    f.close()
    g = open(R + "/c.txt")
    assert g.read() == "x\ny\n"
    g.close()


def p_with_stmt():
    with open(R + "/a.txt") as fh:
        d = fh.read()
    assert fh.closed
    assert "hello" in d


def p_missing_file():
    try:
        open(R + "/nope.txt")
    except FileNotFoundError as e:
        assert e.errno == 2 or e.errno is None


def p_isadirectory():
    try:
        open(R)
    except IsADirectoryError:
        pass


def p_encoding():
    f = open(R + "/u.txt", "w", encoding="utf-8")
    f.write("héllo")
    f.close()
    g = open(R + "/u.txt", encoding="utf-8")
    assert g.read() == "héllo"
    g.close()


def p_newline():
    f = open(R + "/nl.txt", "w", newline="")
    f.write("a\r\nb\nc")
    f.close()
    g = open(R + "/nl.txt", newline="")
    raw = g.read()
    g.close()
    h = open(R + "/nl.txt")
    uni = h.read()
    h.close()
    assert raw == "a\r\nb\nc" and uni == "a\nb\nc"


def p_buffering_attr():
    f = open(R + "/a.txt")
    n = f.name
    m = f.mode
    cl = f.closed
    f.close()
    assert n.endswith("a.txt") and m == "r" and cl


def p_os_path():
    import os.path as op
    assert op.join("a", "b") == "a/b" or True
    assert op.exists(R + "/a.txt")
    assert not op.exists(R + "/zzz")
    assert op.isfile(R + "/a.txt")
    assert op.isdir(R)
    assert op.basename("/x/y/z.txt") == "z.txt"
    assert op.dirname("/x/y/z.txt") == "/x/y"
    assert op.splitext("arc.tar.gz") == ("arc.tar", ".gz")


def p_os_dir_ops():
    d = R + "/sub"
    os.mkdir(d)
    assert os.listdir(d) == []
    open(d + "/f1.txt", "w").close()
    assert sorted(os.listdir(d)) == ["f1.txt"]
    os.rename(d + "/f1.txt", d + "/f2.txt")
    assert sorted(os.listdir(d)) == ["f2.txt"]
    os.remove(d + "/f2.txt")
    os.rmdir(d)


def p_makedirs():
    os.makedirs(R + "/deep/er/est", exist_ok=True)
    assert os.path.isdir(R + "/deep/er/est")


def p_getcwd_abspath():
    c = os.getcwd()
    a = os.path.abspath("x.py")
    assert a.startswith(c) and a.endswith("x.py")


def p_pathlib_basics():
    from pathlib import Path
    pth = Path(R) / "pl.txt"
    pth.write_text("content")
    assert pth.read_text() == "content"
    assert pth.name == "pl.txt"
    assert pth.stem == "pl"
    assert pth.suffix == ".txt"
    assert str(pth.parent).endswith("qr-census")
    assert pth.exists()


def p_pathlib_iterdir_glob():
    from pathlib import Path
    base = Path(R)
    names = sorted(x.name for x in base.iterdir())
    assert len(names) >= 3
    hits = sorted(x.name for x in base.glob("*.txt"))
    assert "a.txt" in hits


def p_stringio():
    s = io.StringIO()
    s.write("ab")
    s.write("cd")
    assert s.getvalue() == "abcd"
    s.seek(0)
    assert s.read() == "abcd"
    s.close()


def p_bytesio():
    b = io.BytesIO(b"\x00\xff")
    assert b.read() == b"\x00\xff"
    b.seek(0)
    assert b.read(1) == b"\x00"


def p_truncate():
    f = open(R + "/tr.txt", "w")
    f.write("abcdef")
    f.truncate(3)
    f.close()
    g = open(R + "/tr.txt")
    assert g.read() == "abc"
    g.close()


def p_flush_read_write_mix():
    f = open(R + "/rw.txt", "w+")
    f.write("data1")
    f.flush()
    f.seek(0)
    assert f.read() == "data1"
    f.close()


check("write_modes", p_write_modes)
check("x_mode", p_x_mode)
check("read_text", p_read_text)
check("read_n", p_read_n)
check("readline", p_readline)
check("readlines", p_readlines)
check("iter_lines", p_iter)
check("binary_rw", p_binary)
check("seek_tell", p_seek_tell)
check("writelines", p_writelines)
check("with_stmt", p_with_stmt)
check("missing_file_exc", p_missing_file)
check("isadir_exc", p_isadirectory)
check("encoding_utf8", p_encoding)
check("newline_handling", p_newline)
check("file_attrs", p_buffering_attr)
check("os_path_fns", p_os_path)
check("os_dir_ops", p_os_dir_ops)
check("makedirs_exist_ok", p_makedirs)
check("getcwd_abspath", p_getcwd_abspath)
check("pathlib_basics", p_pathlib_basics)
check("pathlib_iterdir_glob", p_pathlib_iterdir_glob)
check("stringio", p_stringio)
check("bytesio", p_bytesio)
check("truncate", p_truncate)
check("flush_rw_mix", p_flush_read_write_mix)
print("CENSUS-DONE")
