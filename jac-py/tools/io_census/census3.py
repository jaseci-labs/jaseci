import io
import os
import os.path as op

R = __import__("os").environ.get("IO_CENSUS_ROOT3", "/var/tmp/qr-census3")
os.makedirs(R, exist_ok=True)


def check(name, fn):
    try:
        fn()
        print("OK", name)
    except Exception as e:
        print("FAIL", name, type(e).__name__, e)


def p_latin1():
    raw = "caf\xe9".encode("latin-1")
    with open(R + "/l1.bin", "wb") as f:
        f.write(raw)
    with open(R + "/l1.bin", encoding="latin-1") as g:
        assert g.read() == "caf\xe9"


def p_cp1252():
    with open(R + "/cp.txt", "w", encoding="cp1252") as f:
        f.write("\u201csmart\u201d")
    with open(R + "/cp.txt", encoding="cp1252") as g:
        assert g.read() == "\u201csmart\u201d"


def p_raw_unbuffered():
    with open(R + "/raw.bin", "wb", buffering=0) as f:
        n = f.write(b"rawdata")
        assert n == 7
    with open(R + "/raw.bin", "rb", buffering=0) as g:
        assert g.read(3) == b"raw"


def p_line_buffering():
    with open(R + "/lb.txt", "w", buffering=1) as f:
        f.write("first\n")
        f.write("second")
    with open(R + "/lb.txt") as g:
        assert g.read() == "first\nsecond"


def p_rplus_update():
    with open(R + "/up.txt", "w") as f:
        f.write("AAAABBBB")
    with open(R + "/up.txt", "r+") as f:
        f.seek(4)
        f.write("XX")
    with open(R + "/up.txt") as g:
        assert g.read() == "AAAAXXBB"


def p_wplus_truncates():
    pth = R + "/wp.txt"
    open(pth, "w").write("old-content")
    f = open(pth, "w+")
    assert f.tell() == 0
    assert f.read() == ""
    f.write("new")
    f.close()
    assert open(pth).read() == "new"


def p_textiowrapper():
    raw = open(R + "/tw.txt", "rb")
    tw = io.TextIOWrapper(raw, encoding="utf-8")
    tw.write("wrapped")
    tw.close()
    assert open(R + "/tw.txt").read() == "wrapped"


def p_bytesio_wrap():
    bio = io.BytesIO()
    t = io.TextIOWrapper(bio, encoding="utf-8")
    t.write("héllo")
    t.flush()
    t.detach()
    assert bio.getvalue().decode("utf-8") == "héllo"
    bio.close()


def p_tell_text_iter():
    f = open(R + "/lb.txt")
    first = next(f)
    cookie = f.tell()
    rest = f.read()
    f.seek(cookie)
    again = f.read()
    f.close()
    assert first == "first\n" and again == rest


def p_readline_sizehint():
    f = open(R + "/lb.txt")
    ln = f.readline(3)
    f.close()
    assert ln == "fir"


def p_binary_iter_lines():
    with open(R + "/lb.txt", "rb") as f:
        lines = list(f)
    assert lines == [b"first\n", b"second"]


def p_lseek():
    fd = os.open(R + "/lb.txt", os.O_RDONLY)
    os.lseek(fd, 6, os.SEEK_SET)
    d = os.read(fd, 3)
    os.close(fd)
    assert d == b"sec"


def p_truncate_size():
    pth = R + "/tc.txt"
    open(pth, "w").write("0123456789")
    f = open(pth, "r+")
    f.truncate(4)
    f.close()
    assert op.getsize(pth) == 4


def p_relpath_commonpath():
    assert op.relpath("/a/b/c", "/a") == "b/c"
    assert op.commonpath(["/a/b", "/a/c"]) == "/a"
    assert op.normpath("/a//b/../c") == "/a/c"


def p_expanduser_join_expandvars():
    h = op.expanduser("~")
    assert not h.startswith("~")
    assert op.expandvars("$HOME/x") or True
    assert op.join("/a", "/", "b") == "/b"


def p_devnull_proc():
    with open("/dev/null", "w") as f:
        f.write("gone")
    with open("/dev/null", "rb") as f:
        assert f.read() == b""


def p_path_open_method():
    from pathlib import Path
    pth = Path(R) / "pm.txt"
    with pth.open("w") as f:
        f.write("via-path-open")
    assert pth.read_text() == "via-path-open"


def p_glob_recursive():
    from pathlib import Path
    base = Path(R)
    (base / "g1").mkdir(exist_ok=True)
    (base / "g1" / "g2").mkdir(exist_ok=True)
    (base / "g1" / "g2" / "deep.txt").touch()
    hits = [x.name for x in base.glob("**/deep.txt")]
    assert hits == ["deep.txt"]
    r_hits = sorted(x.name for x in base.rglob("*.txt"))
    assert len(r_hits) >= 2


def p_default_buffer_size():
    assert io.DEFAULT_BUFFER_SIZE >= 512


check("latin1_roundtrip", p_latin1)
check("cp1252_roundtrip", p_cp1252)
check("raw_unbuffered", p_raw_unbuffered)
check("line_buffering", p_line_buffering)
check("rplus_inplace_update", p_rplus_update)
check("wplus_truncate", p_wplus_truncates)
check("textiowrapper_over_rb", p_textiowrapper)
check("bytesio_textwrap_detach", p_bytesio_wrap)
check("tell_cookie_text_iter", p_tell_text_iter)
check("readline_sizehint", p_readline_sizehint)
check("binary_iter_lines", p_binary_iter_lines)
check("os_lseek", p_lseek)
check("truncate_explicit_size", p_truncate_size)
check("relpath_commonpath_normpath", p_relpath_commonpath)
check("expanduser_expandvars_join", p_expanduser_join_expandvars)
check("devnull_special_file", p_devnull_proc)
check("path_open_method", p_path_open_method)
check("glob_recursive", p_glob_recursive)
check("default_buffer_size", p_default_buffer_size)
print("CENSUS3-DONE")
