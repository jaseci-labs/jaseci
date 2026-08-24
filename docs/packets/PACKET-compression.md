# PACKET: Compression trio (zlib / bz2 / lzma guest facades)

Executor contract: three independent sub-jobs, landable in any order but
recommended order below (zlib first: most of it already exists as a
template). Each sub-job ends with its own commit and green pin file.
This is the smallest cbindgen-style packet in the batch; do it before
PACKET-subprocess if you need a warm-up.

## 1. Prerequisites

- Working `.venv` jac toolchain; local gate `.venv/bin/jac check <file>`.
- Host `python3` for oracle capture of expected stdout values.
- System libs: libz (always present), libbz2, liblzma. Check with
  `ldconfig -p | grep -E "libbz2|liblzma"`. If a lib is missing, skip that
  sub-job and note it in the commit-free report; do not substitute pure-Jac
  implementations.
- FFI smoke: run PACKET-subprocess.md Section 2 (Step 0) first. If it
  fails, STOP for all three sub-jobs.

## 2. Files

Create (all under jac-py/jacpython/):

- `_zlib_native.jac` - copy of `jac/jaclang/runtimelib/na_stdlib/_zlib_native.jac`
  verbatim (it already wraps compress2/uncompress/compressBound/crc32_z/
  adler32_z from lib z with sign normalization).
- `zlib.jac` - start from `jac/jaclang/runtimelib/na_stdlib/zlib.jac`
  (crc32/adler32/compress/decompress already written) and EXTEND per Step A.
- `_bz2_native.jac` - copy of `jac/jaclang/runtimelib/na_stdlib/_bz2_native.jac`
  verbatim (BZ2_bzBuffToBuffCompress/Decompress externs + sign wrapper).
- `bz2.jac` - new facade; template style: na_stdlib zlib.jac.
- `_lzma_native.jac`, `lzma.jac` - new; no template exists. Follow the
  two-file split and the dest_len bytes-slot idiom exactly as in the copied
  zlib pair.
- `test_zlib_native.jac`, `test_bz2_native.jac`,
  `test_lzma_native.jac` - pin files. Pin style template:
  `jac-py/jacpython/test_stdlib_delegate.jac`.
Touch:
- Shim registration site following the pattern in
  `jac-py/jacpython/layer_p2_libtest.jac` lines 780-830:
  build attrs dict, then register_shim_module("zlib", PyModule(...)) and
  same for bz2/lzma.
- `jac-py/jacpython/ceval.jac`: after each facade lands, DELETE its entry
  from the delegate_modules glob (`"zlib": "full"` today). Native shims win
  by precedence anyway; deleting keeps the registry honest. Do this only in
  the same commit as the green pins.

## 3. Binding function list (exact C signatures)

zlib: none new; the copied _zlib_native.jac covers
`compress2(dst, dlen, src, slen, lvl) -> i32`,
`uncompress(dst, dlen, src, slen) -> i32`,
`compressBound(slen) -> u64`, `crc32_z(crc, buf, n) -> u64`,
`adler32_z(adler, buf, n) -> u64`.

bz2: none new beyond the copied pair:
`BZ2_bzBuffToBuffCompress(dst, dlen(bytes slot), src, slen(u32),
blockSize100k(i32), verbosity(i32), workFactor(i32)) -> i32`;
`BZ2_bzBuffToBuffDecompress(dst, dlen, src, slen, small(i32),
verbosity(i32)) -> i32`.

lzma (declare fresh via `import from lzma { ... }`):

```
def lzma_easy_buffer_encode(preset: u32, check: i32, allocator: int,
    inp: bytes, in_size: u64, out: bytes, out_pos: bytes, out_size: u64) -> i32;
def lzma_stream_buffer_bound(uncompressed_size: u64) -> u64;
def lzma_stream_buffer_decode(memlimit: bytes, flags: u32, allocator: int,
    inp: bytes, in_pos: bytes, in_size: u64, out: bytes,
    out_pos: bytes, out_size: u64) -> i32;
```

allocator passes as null (0 held in an 8-byte bytes slot); check uses
LZMA_CHECK_CRC64 = 4. memlimit/in_pos/out_pos are pointer slots: pass
8-byte little-endian slots like the dest_len idiom in the zlib copy.
Link flag: -llzma (the build links C libs automatically once externs are
declared; if a link error names liblzma, report STOP, do not edit build
scripts without instruction).

## 4. Facade surface steps

### Sub-job A: zlib (extend the copied facade)

1. Add Z_* constants used by tests: Z_BEST_SPEED=1, Z_BEST_COMPRESSION=9,
   Z_DEFAULT_COMPRESSION=-1, Z_OK=0, Z_STREAM_END=1 (some exist already).
2. Add `error` exception type exposed as a guest-visible class proxy so
   `except zlib.error` works; error text must match host format
   ("Error N while compressing"/decompressing forms). Capture exact host
   strings with python3 and paste into pins.
3. Add `compressobj(level)/decompressobj()` minimal classes backed by
   repeated uncompress/compress calls on accumulated buffers ONLY IF a pin
   needs them; otherwise defer and note deferral in README comment.
   Do NOT implement streaming z_stream state machine in v1.
4. Keep crc32/adler32/decompress/compress from the template as-is.

### Sub-job B: bz2 facade

Implement: compress(data, compresslevel=9), decompress(data),
BZ2_* constant set (BZ_RUN=0 etc. only those referenced by pins),
bz2.error class, crc32-equivalent not needed. Decompression sizing: use
grow-and-retry loop copying zlib.jac's Z_BUF_ERROR doubling pattern
(start cap = len*4 min 256, ceiling = len*1024 + 64MB).

### Sub-job C: lzma facade

Implement: compress(data, format=FORMAT_XZ, preset=6) via easy_buffer_encode,
decompress(data) via stream_buffer_decode with grow loop, FORMAT_XZ=1 /
FORMAT_ALONE=2 constants, LZMAError class (text "Corrupt input data"
captured from host oracle), is_compatible_format optional skip.

## 5. Acceptance criteria

Per sub-job, pins through `p2_libtest_expect_ok` with host-oracle stdout:

- test_zlib_native.jac: 15 pins minimum. Behaviors mapped to
  reference/cpython/Lib/test/test_zlib.py (cite source test per pin):
  roundtrip at levels 1/6/9, empty input, 1MB random-ish payload
  (deterministic bytes, e.g. repeating patterns; NEVER os.urandom),
  crc32 known vectors (b"hello" -> 907060870, empty -> 0),
  adler32 vectors (b"hello" -> 103908119, empty -> 1),
  decompress of truncated stream raises zlib.error,
  decompress of garbage raises zlib.error,
  compress(decompress(x)) == x identity across all levels,
  level=0 stored roundtrip, big-literal 100KB zeros compression ratio
  sanity (< compressed size 2000).
- test_bz2_native.jac: 10 pins minimum mapped to Lib/test/test_bz2.py:
  roundtrip levels 1/5/9, empty input raises or returns per HOST behavior
  (capture oracle; do not guess), b"hello world" known vector, truncated
  stream raises bz2.error or OSError family per host, decompress(garbage)
  raises, 100KB zeros ratio sanity, interleaved compress calls identity.
- test_lzma_native.jac: 10 pins minimum mapped to Lib/test/test_lzma.py:
  roundtrip presets 0/6/9, empty input, 100KB zeros, decompress(garbage)
  raises LZMAError with exact host text, cross-check: host-python-produced
  xz bytes literal decompressed by guest (embed a fixed base64 blob in the
  pin), guest-produced bytes decompressed back, FORMAT_ALONE compress
  produces header byte 0x5d, wrong-preset decode still succeeds.

Expected totals: 35 pins green locally (15+10+10). CI matrix lines added to
`.github/workflows/jacpy-gates.yml` one per file as landed.

## 6. Verification commands

```bash
ldconfig -p | grep -E "libz|libbz2|liblzma"
.venv/bin/jac check jac-py/jacpython/zlib.jac jac-py/jacpython/bz2.jac jac-py/jacpython/lzma.jac
.venv/bin/jac test jac-py/jacpython/test_zlib_native.jac
.venv/bin/jac test jac-py/jacpython/test_bz2_native.jac
.venv/bin/jac test jac-py/jacpython/test_lzma_native.jac
git log origin/..HEAD --oneline
```

## 7. Effort estimate

zlib half-day (mostly copy+extend+pins), bz2 half-day, lzma 1-2 days
(fresh bindings). Total 2.5 to 3 executor-days.

## 8. STOP conditions

- FFI smoke fails (Section 1).
- Link errors naming liblzma/libbz2 absent on the box: skip that sub-job
  and report; never vendor library sources.
- Decompressor grow-loop ceiling hit on valid input (means the length-slot
  convention is misunderstood): re-read _socket_native.jac buffer idioms
  once, then escalate if still failing.
- Any pin whose host oracle output cannot be reproduced twice in a row:
  mark and skip that pin, note in commit message, continue; escalate only
  if more than 2 pins are unstable.
