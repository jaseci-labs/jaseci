import asyncio;
import contextvars;
import json;
import from collections.abc { AsyncGenerator, Callable, Generator }
import from inspect { isgenerator }


def context_bound_stream(
    source: Generator, captured: contextvars.Context, teardown: Callable[[], None]
) -> Generator {
    try {
        while True {
            try {
                item = captured.run(next, source);
            } except StopIteration {
                break;
            }
            yield item;
        }
    } finally {
        captured.run(teardown);
    }
}


async def _anext_value(source: AsyncGenerator) -> any {
    return await source.__anext__();
}


async def _aclose_value(source: AsyncGenerator) {
    await source.aclose();
}


async def context_bound_async_stream(
    source: AsyncGenerator, captured: contextvars.Context, teardown: Callable[[], None]
) -> any {
    try {
        while True {
            loop = asyncio.get_running_loop();

            step = loop.create_task(_anext_value(source), context=captured);
            try {
                item = await step;
            } except StopAsyncIteration {
                break;
            }
            yield item;
        }
    } finally {
        try {
            closer = asyncio.get_running_loop().create_task(
                _aclose_value(source), context=captured
            );
            await closer;
        } except Exception {
            ;
        }
        captured.run(teardown);
    }
}


def iter_sync_or_async(gen: any) -> Generator {
    if isgenerator(gen) {
        for item in gen {
            yield item;
        }
    } elif isinstance(gen, AsyncGenerator) {
        loop = asyncio.new_event_loop();
        try {
            while True {
                try {
                    item = loop.run_until_complete(gen.__anext__());
                } except StopAsyncIteration {
                    break;
                }
                yield item;
            }
        } finally {
            loop.close();
        }
    } else {
        raise TypeError(
            f"expected a generator or async generator, got {type(gen).__name__}"
        );
    }
}


def drain_sse(gen: any, write: Callable[[bytes], None]) {
    items = iter_sync_or_async(gen);
    try {
        for item in items {
            write(f"data: {json.dumps(item, default=str)}\n\n".encode());
        }
        write(b"event: end\ndata: {}\n\n");
    } except TypeError {
        try {
            err = {
                "error_type": "TypeError",
                "message": f"sse expected a generator, got {type(gen).__name__}"
            };
            write(f"event: error\ndata: {json.dumps(err, default=str)}\n\n".encode());
        } except Exception {
            ;
        }
    } except (BrokenPipeError, ConnectionResetError, OSError) {
        ;
    } except Exception as e {
        try {
            err = {"error_type": type(e).__name__, "message": str(e)};
            write(f"event: error\ndata: {json.dumps(err, default=str)}\n\n".encode());
        } except Exception {
            ;
        }
    } finally {
        try {
            items.close();
        } except Exception {
            ;
        }
        close_fn = gen?.close;
        if close_fn {
            try {
                close_fn();
            } except Exception {
                ;
            }
        }
    }
}
