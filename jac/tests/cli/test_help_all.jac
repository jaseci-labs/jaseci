"""`jac --help` lists the visible surface; `jac --help --all` also lists the hidden long tail.

Hidden commands (#7255) stay out of the default listing and out of the verb
budget, but they need a front door: plain `--help` says how many it omits and
which flag shows them, and `--help --all` renders them under `Hidden:`.
"""

import contextlib;
import io;
import re;

import from jaclang.cli.manifest { iter_command_meta }
import from jaclang.cli.manifest_help { format_verbose_help }
import from jaclang.cli.manifest_route { handle_manifest_route }


def _strip_ansi(s: str) -> str {
    return re.sub("\033\\[[0-9;]*m", "", s);
}


def _hidden_names -> list[str] {
    return sorted(
        [
            m.name
            for m in iter_command_meta(include_hidden=True)
            if m.hidden
        ]
    );
}


test "plain --help omits hidden commands but counts them and names the flag" {
    hidden = _hidden_names();
    assert hidden , "expected at least one hidden command in the manifest";
    out = _strip_ansi(format_verbose_help(prog="jac"));
    for name in hidden {
        assert f"    {name} " not in out , f"hidden command {name!r} leaked into plain --help";
    }
    assert "Hidden:" not in out , "plain --help must not render the Hidden section";
    assert f"{len(hidden)} hidden command" in out , f"hidden count missing; captured={out!r}";
    assert "jac --help --all" in out , f"--all hint missing; captured={out!r}";
    assert "--all" in out.split("Program Execution:")[0] , "--all missing from Options";
}


test "--help --all lists hidden commands under their own section" {
    hidden = _hidden_names();
    out = _strip_ansi(format_verbose_help(prog="jac", include_hidden=True));
    assert "Hidden:" in out , f"Hidden section missing; captured={out!r}";
    tail = out.split("Hidden:")[1];
    for name in hidden {
        assert f"    {name} " in tail , f"hidden command {name!r} missing from Hidden section";
    }
    assert "    run " in out , "visible commands must still be listed";
    assert "hidden command" not in out.split("Hidden:")[1].split("See '")[1] , "the not-listed hint must not appear when everything is listed";
}


test "the manifest route honours --all after --help" {
    buf = io.StringIO();
    with contextlib.redirect_stdout(buf) {
        handle_manifest_route(["--help", "--all"]);
    }
    out = _strip_ansi(buf.getvalue());
    assert "Hidden:" in out , f"route ignored --all; captured={out!r}";
    for name in _hidden_names() {
        assert f"    {name} " in out , f"{name!r} missing from routed --help --all";
    }
}
