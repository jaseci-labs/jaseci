"""WakePipe — cross-platform self-pipe used to wake the native TUI loop.

Python owns the pipe because it owns the event queue. The dispatcher thread
writes a byte through `notify()` whenever the session queue gains data; the
native poll(2) loop registers the read end and drains it on wakeup. Writes are
nonblocking: a full pipe already carries a pending wake, so EAGAIN is ignored.
"""

import os;


obj WakePipe {
    has read_fd: int = -1,
        write_fd: int = -1,
        _closed: bool = False;

    def notify {
        if self._closed or self.write_fd < 0 {
            return;
        }
        try {
            os.write(self.write_fd, b"\x01");
        } except BlockingIOError {
            # Pipe buffer full: a wake is already pending — nothing more to do.
        } except OSError {
            # Read end gone / fd closed underneath us: drop the wake silently.
        }
    }

    def close {
        if self._closed {
            return;
        }
        self._closed = True;
        for fd in [self.read_fd, self.write_fd] {
            if fd >= 0 {
                try {
                    os.close(fd);
                } except OSError { }
            }
        }
        self.read_fd = -1;
        self.write_fd = -1;
    }
}


def open_wake_pipe -> WakePipe | None {
    try {
        (r, w) = os.pipe();
    } except OSError {
        return None;
    }
    # Read end nonblocking so native tty_drain_wake() stops at EAGAIN; write end
    # nonblocking so notify() never stalls the dispatcher thread.
    os.set_blocking(r, False);
    os.set_blocking(w, False);
    return WakePipe(read_fd=r, write_fd=w);
}
