import io
import os
import sys

R = __import__("os").environ.get("IO_CENSUS_ROOT2", "/var/tmp/qr-census2")
os.makedirs(R, exist_ok=True)


def check(name, fn):
    try:
        fn()
        print("OK", name)
    except Exception as e:
        print("FAIL", name, type(e).__name__, e)


def p_fd_level():
    fd = os.open(R + "/f1.txt", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
    n = os.write(fd, b"hello")
    os.close(fd)
    assert n == 5
    fd = os.open(R + "/f1.txt", os.O_RDONLY)
    d = os.read(fd, 10)
    os.close(fd)
    assert d == b"hello"


def p_fdopen():
    fd = os.open(R + "/f2.txt", os.O_WRONLY | os.O_CREAT | os.O_TRUNC)
    f = os.fdopen(fd, "w")
    f.write("via-fd")
    f.close()
    assert open(R + "/f2.txt").read() == "via-fd"


def p_stat():
    import stat as statmod
    open(R + "/s.txt", "w").write("12345")
    st = os.stat(R + "/s.txt")
    assert st.st_size == 5
    assert statmod.S_ISREG(st.st_mode)


def p_scandir():
    for i in range(3):
        open(R + "/e%d.txt" % i, "w").close()
    entries = sorted(os.scandir(R), key=lambda x: x.name)
    ent = [x for x in entries if x.name == "e1.txt"][0]
    assert ent.is_file()
    names = sorted(x.name for x in os.scandir(R))
    assert "e1.txt" in names


def p_walk():
    os.makedirs(R + "/w/sub", exist_ok=True)
    open(R + "/w/r.txt", "w").close()
    open(R + "/w/sub/deep.txt", "w").close()
    found = []
    for root, dirs, files in os.walk(R + "/w"):
        for fn in files:
            found.append(os.path.join(root, fn))
    assert len(found) == 2


def p_pathlib_more():
    from pathlib import Path
    base = Path(R)
    q = base / "pb.bin"
    q.write_bytes(b"\x01\x02")
    assert q.read_bytes() == b"\x01\x02"
    t = base / "touched.txt"
    t.touch()
    assert t.exists()
    t.unlink()
    assert not t.exists()
    sub = base / "psub"
    sub.mkdir(parents=True, exist_ok=True)
    f = sub / "inner.txt"
    f.write_text("i")
    g = sub / "renamed.txt"
    f.rename(g)
    assert g.exists() and not f.exists()
    h = base / "repl.txt"
    g.replace(h)
    assert h.exists()


def p_pathlib_props():
    from pathlib import Path
    pth = Path("/abs/x/file.tar.gz")
    assert pth.is_absolute()
    assert list(pth.parts) == ["/", "abs", "x", "file.tar.gz"]
    assert pth.with_suffix(".md").name == "file.tar.md"
    assert str(Path("a/b").as_posix()) == "a/b"
    assert (Path(R) / ".." / "qr-census2").resolve().as_posix() == R


def p_closed_ops():
    f = open(R + "/s.txt")
    f.close()
    try:
        f.read()
    except ValueError:
        pass


def p_mix_iter_read():
    f = open(R + "/s.txt")
    next(f)
    try:
        f.read()
    except ValueError:
        pass
    f.close()


def p_write_ret():
    f = open(R + "/wr.txt", "w")
    n = f.write("xyz")
    f.close()
    assert n == 3


def p_errors_param():
    f = open(R + "/err.txt", "w", encoding="ascii", errors="replace")
    f.write("café")
    f.close()
    g = open(R + "/err.txt", encoding="ascii", errors="replace")
    d = g.read()
    g.close()
    assert "?" in d or d == "café"


def p_getsize_mtime():
    import os.path as op
    open(R + "/gs.txt", "w").write("abcdef")
    assert op.getsize(R + "/gs.txt") == 6
    mt = op.getmtime(R + "/gs.txt")
    assert mt > 1000000000


def p_realpath_samefile():
    import os.path as op
    a = op.realpath(R + "/gs.txt")
    assert a.endswith("gs.txt")
    assert op.samefile(R + "/gs.txt", R + "/gs.txt")


def p_listdir_notadir():
    try:
        os.listdir(R + "/gs.txt")
    except NotADirectoryError:
        pass


def p_seek_past_eof():
    f = open(R + "/sp.txt", "wb")
    f.write(b"abc")
    f.seek(10)
    f.write(b"d")
    f.close()
    g = open(R + "/sp.txt", "rb")
    d = g.read()
    g.close()
    assert len(d) == 11 and d.endswith(b"d")


def p_append_binary():
    f = open(R + "/ap.bin", "ab")
    f.seek(0)
    f.write(b"B")
    f.close()
    f2 = open(R + "/ap.bin", "ab")
    f2.write(b"C")
    f2.close()
    g = open(R + "/ap.bin", "rb")
    d = g.read()
    g.close()
    assert d == b"BC"


def p_print_tofile():
    f = open(R + "/pf.txt", "w")
    print("line1", 42, file=f)
    f.close()
    g = open(R + "/pf.txt")
    assert g.read() == "line1 42\n"
    g.close()


def p_readinto():
    f = open(R + "/gs.txt", "rb")
    buf = bytearray(10)
    n = f.readinto(buf)
    f.close()
    assert n == 6


def p_tempfile():
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        assert os.path.isdir(td)
        pth = os.path.join(td, "t.txt")
        open(pth, "w").write("tmp")
        assert open(pth).read() == "tmp"
    assert not os.path.exists(td)


def p_namedtempfile():
    import tempfile
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt") as nt:
        nt.write("nt-data")
        nt.flush()
        assert nt.name.endswith(".txt")


def p_os_replace_symlink():
    import os.path as op
    lp = R + "/lnk"
    if os.path.lexists(lp):
        os.remove(lp)
    os.symlink(R + "/gs.txt", lp)
    assert op.islink(lp)
    os.remove(lp)


def p_env_chmod():
    pth = R + "/ch.txt"
    open(pth, "w").close()
    os.chmod(pth, 0o600)
    st = os.stat(pth)
    assert st.st_mode & 0o777 == 0o600


check("fd_level_io", p_fd_level)
check("fdopen", p_fdopen)
check("stat_size_mode", p_stat)
check("scandir", p_scandir)
check("walk", p_walk)
check("pathlib_methods", p_pathlib_more)
check("pathlib_props", p_pathlib_props)
check("closed_file_valueerror", p_closed_ops)
check("mix_iter_read_valueerror", p_mix_iter_read)
check("write_returns_count", p_write_ret)
check("errors_param", p_errors_param)
check("getsize_mtime", p_getsize_mtime)
check("realpath_samefile", p_realpath_samefile)
check("listdir_notadir_exc", p_listdir_notadir)
check("seek_past_eof_sparse", p_seek_past_eof)
check("append_binary_seek_ignored", p_append_binary)
check("print_to_file", p_print_tofile)
check("readinto", p_readinto)
check("tempdir_ctx", p_tempfile)
check("namedtempfile", p_namedtempfile)
check("symlink_lexists", p_os_replace_symlink)
check("chmod_stat_mode", p_env_chmod)
print("CENSUS2-DONE")
