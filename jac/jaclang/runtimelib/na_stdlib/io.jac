glob:pub SEEK_SET: int = 0,
     SEEK_CUR: int = 1,
     SEEK_END: int = 2,
     DEFAULT_BUFFER_SIZE: int = 131072;


obj:pub UnsupportedOperation(OSError) {}


obj:pub BufferedIOBase {
    has closed: bool = False;

    def readable -> bool {
        return False;
    }

    def writable -> bool {
        return False;
    }

    def seekable -> bool {
        return False;
    }

    def read(size: int = -1) -> bytes {
        raise UnsupportedOperation("read");
    }

    def read1(size: int = -1) -> bytes {
        raise UnsupportedOperation("read1");
    }

    def write(b: bytes) -> int {
        raise UnsupportedOperation("write");
    }

    def seek(pos: int, whence: int = 0) -> int {
        raise UnsupportedOperation("seek");
    }

    def tell -> int {
        raise UnsupportedOperation("tell");
    }

    def flush {
        return;
    }

    def close {
        self.closed = True;
    }

    def __enter__ -> BufferedIOBase {
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.close();
        return False;
    }
}


obj:pub BytesIO {
    has _buf: bytes = b"",
        _pos: int = 0,
        closed: bool = False;

    def init(initial_bytes: bytes = b"") {
        self._buf = initial_bytes;
        self._pos = 0;
        self.closed = False;
    }

    def _check_closed {
        if self.closed {
            raise ValueError("I/O operation on closed file.");
        }
    }

    def readable -> bool {
        self._check_closed();
        return True;
    }

    def writable -> bool {
        self._check_closed();
        return True;
    }

    def seekable -> bool {
        self._check_closed();
        return True;
    }

    def read(size: int = -1) -> bytes {
        self._check_closed();
        total: int = len(self._buf);
        if self._pos >= total {
            return b"";
        }
        end: int = total;
        if size >= 0 and self._pos + size < total {
            end = self._pos + size;
        }
        out = self._buf[self._pos:end];
        self._pos = end;
        return out;
    }

    def read1(size: int = -1) -> bytes {
        return self.read(size);
    }

    def write(b: bytes) -> int {
        self._check_closed();
        n: int = len(b);
        if n == 0 {
            return 0;
        }
        cur: int = len(self._buf);
        if self._pos > cur {
            self._buf = self._buf + b"\x00" * (self._pos - cur);
            cur = self._pos;
        }
        end: int = self._pos + n;
        if end >= cur {
            self._buf = self._buf[0:self._pos] + b;
        } else {
            self._buf = self._buf[0:self._pos] + b + self._buf[end:cur];
        }
        self._pos = end;
        return n;
    }

    def seek(pos: int, whence: int = 0) -> int {
        self._check_closed();
        if whence == 0 {
            if pos < 0 {
                raise ValueError("negative seek value " + str(pos));
            }
            self._pos = pos;
        } elif whence == 1 {
            self._pos = max(0, self._pos + pos);
        } elif whence == 2 {
            self._pos = max(0, len(self._buf) + pos);
        } else {
            raise ValueError(
                "invalid whence (" + str(whence) + ", should be 0, 1 or 2)"
            );
        }
        return self._pos;
    }

    def tell -> int {
        self._check_closed();
        return self._pos;
    }

    def getvalue -> bytes {
        self._check_closed();
        return self._buf;
    }

    def flush {
        self._check_closed();
    }

    def close {
        self._buf = b"";
        self._pos = 0;
        self.closed = True;
    }

    def __enter__ -> BytesIO {
        self._check_closed();
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.close();
        return False;
    }
}
