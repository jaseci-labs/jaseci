"""Native `tty` floor (Mechanism F over libc, POSIX host only).

`setraw` / `setcbreak`, a direct port of CPython's `tty.py` over the
bundled `termios` floor. `when` defaults to `termios.TCSADRAIN`, exactly
as CPython. Divergence: errors raise ValueError where CPython propagates
`termios.error`.
"""
import termios;

glob O_NONBLOCK: int = 2048;


def:pub setraw(fd: int, when: int = 1) -> None {  # TCSADRAIN
    mode = termios.tcgetattr(fd);
    mode[0] = mode[0] & ~(
        termios.BRKINT | termios.ICRNL | termios.INPCK
        | termios.ISTRIP | termios.IXON
    );
    mode[1] = mode[1] & ~termios.OPOST;
    mode[2] = mode[2] & ~(termios.CSIZE | termios.PARENB);
    mode[2] = mode[2] | termios.CS8;
    mode[3] = mode[3] & ~(
        termios.ECHO | termios.ICANON | termios.IEXTEN | termios.ISIG
    );
    cc: list[int] = mode[6];
    if len(cc) > termios.VMIN {
        cc[termios.VMIN] = 1;
    }
    if len(cc) > termios.VTIME {
        cc[termios.VTIME] = 0;
    }
    termios.tcsetattr(fd, when, mode);
}


def:pub setcbreak(fd: int, when: int = 1) -> None {  # TCSADRAIN
    mode = termios.tcgetattr(fd);
    mode[3] = mode[3] & ~(termios.ECHO | termios.ICANON);
    cc: list[int] = mode[6];
    if len(cc) > termios.VMIN {
        cc[termios.VMIN] = 1;
    }
    if len(cc) > termios.VTIME {
        cc[termios.VTIME] = 0;
    }
    termios.tcsetattr(fd, when, mode);
}
