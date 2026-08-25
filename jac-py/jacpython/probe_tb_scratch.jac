# Scratch discovery probe for traceback-surface differential lane (delete before commit).
import from product_compile { compile_source }
import from pyc_first { exec_code }
import from objects { PyObj, PyStr, PyCode, PyError, is_error }


glob RESULTS: list[str] = [];

def _probe(src: str) -> str {
    # Compile natively, exec on ceval, report guest outcome through the error
    # channel only (no globals readback).
    co = compile_source(src, "<tb_probe>", "exec", 0);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    out = exec_code(co as PyCode, [], ns);
    if is_error(out) {
        e = out as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    return "ok";
}


glob SRC_BASIC = (
    "def f():\n"
    "    raise ValueError('x')\n"
    "try:\n"
    "    f()\n"
    "except ValueError as e:\n"
    "    tb = e.__traceback__\n"
    "    obs = [tb is None, type(tb).__name__]\n"
    "raise RuntimeError('OBS ' + repr(obs))\n"
);

glob SRC_LINENO = (
    "def g():\n"
    "\n"
    "    x = 1\n"
    "    y = 2\n"
    "    raise ValueError('at line 5')\n"
    "try:\n"
    "    g()\n"
    "except ValueError as e:\n"
    "    t = e.__traceback__\n"
    "    raise RuntimeError('OBS head_lineno=%r head_name=%r next=%r' % (t.tb_lineno, t.tb_frame.f_code.co_name, t.tb_next))\n"
);

glob SRC_CHAIN = (
    "def h():\n"
    "    raise ValueError('deep')\n"
    "def g():\n"
    "    h()\n"
    "def f():\n"
    "    g()\n"
    "try:\n"
    "    f()\n"
    "except ValueError as e:\n"
    "    parts = []\n"
    "    t = e.__traceback__\n"
    "    while t is not None:\n"
    "        parts.append((t.tb_frame.f_code.co_name, t.tb_lineno))\n"
    "        t = t.tb_next\n"
    "    raise RuntimeError('OBS ' + repr(parts))\n"
);

glob SRC_LASTI = (
    "try:\n"
    "    raise ValueError('l')\n"
    "except ValueError as e:\n"
    "    t = e.__traceback__\n"
    "    raise RuntimeError('OBS lasti_type=%s lasti_val=%r lineno_type=%s' % (type(t.tb_lasti).__name__, t.tb_lasti, type(t.tb_lineno).__name__))\n"
);

glob SRC_TBMOD_DIR = (
    "import traceback\n"
    "names = sorted(n for n in dir(traceback) if not n.startswith('_'))\n"
    "raise RuntimeError('OBS ' + repr(names))\n"
);

glob SRC_FMTTB = (
    "import traceback\n"
    "def h():\n"
    "    raise ValueError('deep')\n"
    "def g():\n"
    "    h()\n"
    "def f():\n"
    "    g()\n"
    "try:\n"
    "    f()\n"
    "except ValueError as e:\n"
    "    out = traceback.format_tb(e.__traceback__)\n"
    "    raise RuntimeError('OBS type=%s len=%d text=%r' % (type(out).__name__, len(out), ''.join(out)))\n"
);

glob SRC_FMTEXC = (
    "import traceback\n"
    "try:\n"
    "    raise ValueError('boom')\n"
    "except ValueError as e:\n"
    "    out = traceback.format_exception(e)\n"
    "    raise RuntimeError('OBS type=%s val=%r' % (type(out).__name__, out))\n"
);

glob SRC_PRINTEXC_MISSING = (
    "import traceback\n"
    "has_pe = hasattr(traceback, 'print_exception')\n"
    "has_fe = hasattr(traceback, 'format_exc')\n"
    "raise RuntimeError('OBS print_exception=%r format_exc=%r' % (has_pe, has_fe))\n"
);

glob SRC_WALKTAB = (
    "import traceback\n"
    "def h():\n"
    "    raise ValueError('w')\n"
    "try:\n"
    "    h()\n"
    "except ValueError as e:\n"
    "    frames = list(traceback.walk_tb(e.__traceback__))\n"
    "    raise RuntimeError('OBS wtype=%s names=%r' % (type(frames).__name__, [fr.f_code.co_name for fr in frames]))\n"
);

glob SRC_EXTRACT = (
    "import traceback\n"
    "try:\n"
    "    raise ValueError('ex')\n"
    "except ValueError as e:\n"
    "    st = traceback.extract_tb(e.__traceback__)\n"
    "    fs = st[0]\n"
    "    raise RuntimeError('OBS len=%d fname=%r name=%r lineno=%r line=%r' % (len(st), fs.filename, fs.name, fs.lineno, fs.line))\n"
);


test "probe basic" { RESULTS.append("basic => " + _probe(SRC_BASIC)); }
test "probe lineno" { RESULTS.append("lineno => " + _probe(SRC_LINENO)); }
test "probe chain" { RESULTS.append("chain => " + _probe(SRC_CHAIN)); }
test "probe lasti" { RESULTS.append("lasti => " + _probe(SRC_LASTI)); }
test "probe tbmod dir" { RESULTS.append("tbmod_dir => " + _probe(SRC_TBMOD_DIR)); }
test "probe format_tb" { RESULTS.append("format_tb => " + _probe(SRC_FMTTB)); }
test "probe format_exception" { RESULTS.append("format_exception => " + _probe(SRC_FMTEXC)); }
test "probe missing fns" { RESULTS.append("missing_fns => " + _probe(SRC_PRINTEXC_MISSING)); }
test "probe walk_tb" { RESULTS.append("walk_tb => " + _probe(SRC_WALKTAB)); }
test "probe extract_tb" { RESULTS.append("extract_tb => " + _probe(SRC_EXTRACT)); }

test "dump results" { assert len(RESULTS) == 99, "\n".join(RESULTS); }
