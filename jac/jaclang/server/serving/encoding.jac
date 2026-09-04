import asyncio;
import inspect;
import zlib;
import from jaclang.server.serving.datatypes { Request, Response }


glob COMPRESSIBLE_TYPES: tuple[str, ...] = (
         'application/json',
         'text/javascript',
         'application/javascript',
         'application/xml',
         'image/svg+xml',
         'application/wasm',
         'application/manifest+json'
     ),
     NGINX_TEXT_TYPES: tuple[str, ...] = (
         'text/plain',
         'text/css',
         'text/xml',
         'text/csv',
         'text/markdown'
     ),
     DEFAULT_MIN_BYTES: int = 1024,
     DEFAULT_LEVEL: int = 4,
     STREAM_FLUSH_BYTES: int = 4096,
     STREAM_IDLE_SECONDS: float = 0.01,
     GZIP_WBITS: int = 31;


def is_compressible_type(content_type: str) -> bool {
    media_type = content_type.split(';')[0].strip().lower();
    if not media_type {
        return False;
    }
    return media_type.startswith('text/') or media_type in COMPRESSIBLE_TYPES;
}


def nginx_gzip_types -> str {
    return ' '.join(list(NGINX_TEXT_TYPES) + list(COMPRESSIBLE_TYPES));
}


def accepts_gzip(accept_encoding: str) -> bool {
    for raw in accept_encoding.split(',') {
        parts = [p.strip() for p in raw.split(';')];
        coding = parts[0].lower();
        if coding not in ('gzip', 'x-gzip', '*') {
            continue;
        }
        for param in parts[1:] {
            (name, _, value) = param.partition('=');
            if name.strip().lower() == 'q' {
                try {
                    return float(value.strip()) > 0.0;
                } except ValueError {
                    return False;
                }
            }
        }
        return True;
    }
    return False;
}


def _as_bytes(chunk: any) -> bytes {
    return chunk if isinstance(chunk, bytes) else str(chunk).encode('utf-8');
}


async def gzip_stream(stream: any, level: int) -> any {
    compressor = zlib.compressobj(level, zlib.DEFLATED, GZIP_WBITS);
    pending = 0;
    if inspect.isasyncgen(stream) or hasattr(stream, '__aiter__') {
        source = aiter(stream);
        upcoming: any = None;
        try {
            while True {
                upcoming = asyncio.ensure_future(anext(source));
                if pending > 0 {
                    (ready, _) = await asyncio.`wait(
                        {upcoming}, timeout=STREAM_IDLE_SECONDS
                    );
                    if not ready {
                        pending = 0;
                        flushed = compressor.flush(zlib.Z_SYNC_FLUSH);
                        if flushed {
                            yield flushed;
                        }
                    }
                }
                try {
                    chunk = await upcoming;
                } except StopAsyncIteration {
                    upcoming = None;
                    break;
                }
                upcoming = None;
                data = _as_bytes(chunk);
                if not data {
                    continue;
                }
                out = compressor.compress(data);
                pending += len(data);
                if pending >= STREAM_FLUSH_BYTES {
                    pending = 0;
                    out += compressor.flush(zlib.Z_SYNC_FLUSH);
                }
                if out {
                    yield out;
                }
            }
        } finally {
            if upcoming is not None and not upcoming.done() {
                upcoming.cancel();
            }
            closer = stream?.aclose;
            if closer is not None {
                await closer();
            }
        }
    } else {
        for chunk in stream {
            data = _as_bytes(chunk);
            if not data {
                continue;
            }
            out = compressor.compress(data);
            pending += len(data);
            if pending >= STREAM_FLUSH_BYTES {
                pending = 0;
                out += compressor.flush(zlib.Z_SYNC_FLUSH);
            }
            if out {
                yield out;
            }
        }
    }
    tail = compressor.flush(zlib.Z_FINISH);
    if tail {
        yield tail;
    }
}


obj EncodingPolicy {
    has enabled: bool = True,
        min_bytes: int = DEFAULT_MIN_BYTES,
        level: int = DEFAULT_LEVEL;

    def negotiable(response: Response) -> bool {
        if not self.enabled {
            return False;
        }
        if response.headers.get('Content-Encoding') is not None {
            return False;
        }
        cache_control = (response.headers.get('Cache-Control') or '').lower();
        if 'no-transform' in cache_control {
            return False;
        }
        content_type = response.headers.get('Content-Type')
            or response.content_type_header();
        return is_compressible_type(content_type);
    }

    def apply(
        request: Request, response: Response, body: bytes, stream: any
    ) -> tuple[bytes, any] {
        if not self.negotiable(response) {
            return (body, stream);
        }
        response.headers.merge('Vary', 'Accept-Encoding');
        if request.method == 'HEAD' {
            return (body, stream);
        }
        if not accepts_gzip(request.headers.get('Accept-Encoding') or '') {
            return (body, stream);
        }
        if stream is not None {
            response.headers.set('Content-Encoding', 'gzip');
            return (body, gzip_stream(stream, self.level));
        }
        if len(body) < self.min_bytes {
            return (body, stream);
        }
        compressor = zlib.compressobj(self.level, zlib.DEFLATED, GZIP_WBITS);
        compressed = compressor.compress(body) + compressor.flush(zlib.Z_FINISH);
        response.headers.remove('Content-Length');
        response.headers.set('Content-Encoding', 'gzip');
        return (compressed, stream);
    }
}


def encoding_policy_from_project -> EncodingPolicy {
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        if cfg is None {
            return EncodingPolicy();
        }
        comp: any = cfg.serve.compression;
        if isinstance(comp, dict) {
            return EncodingPolicy(
                enabled=bool(comp.get('enabled', True)),
                min_bytes=int(comp.get('min_bytes', DEFAULT_MIN_BYTES)),
                level=int(comp.get('level', DEFAULT_LEVEL))
            );
        }
        return EncodingPolicy(
            enabled=bool(comp.enabled),
            min_bytes=int(comp.min_bytes),
            level=int(comp.level)
        );
    } except Exception {
        return EncodingPolicy();
    }
}
