import from z {
    def compress2(dst: bytes, dlen: bytes, src: bytes, slen: u64, lvl: i32) -> i32;
}
import from z {
    def uncompress(dst: bytes, dlen: bytes, src: bytes, slen: u64) -> i32;
}
import from z {
    def uncompress2(dst: bytes, dlen: bytes, src: bytes, slen: bytes) -> i32;
}
import from z { def compressBound(slen: u64) -> u64;  }
import from z { def crc32_z(crc: u64, buf: bytes, n: u64) -> u64;  }
import from z { def adler32_z(adler: u64, buf: bytes, n: u64) -> u64;  }


def _signed32(status: int) -> int {
    if status >= 2147483648 {
        return status - 4294967296;
    }
    return status;
}


def:pub z_compress_bound(source_len: int) -> int {
    return int(compressBound(u64(source_len)));
}


def:pub z_compress2(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int, level: int
) -> int {
    return _signed32(compress2(dest, dest_len, source, u64(source_len), i32(level)));
}


def:pub z_uncompress(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int
) -> int {
    return _signed32(uncompress(dest, dest_len, source, u64(source_len)));
}


def:pub z_uncompress2(
    dest: bytes, dest_len: bytes, source: bytes, source_len: bytes
) -> int {
    return _signed32(uncompress2(dest, dest_len, source, source_len));
}


def:pub z_crc32(crc: int, buf: bytes, n: int) -> int {
    return int(crc32_z(u64(crc), buf, u64(n)));
}


def:pub z_adler32(adler: int, buf: bytes, n: int) -> int {
    return int(adler32_z(u64(adler), buf, u64(n)));
}
