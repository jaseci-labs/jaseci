import logging;


glob _logger: logging.Logger = logging.getLogger(
         "jaclang.runtimelib.serving.streams"
     );


async def close_stream_like(stream: any, what: str = "stream") {
    try {
        if hasattr(stream, 'aclose') {
            await stream.aclose();
        } elif hasattr(stream, 'close') {
            stream.close();
        }
    } except Exception as e {
        _logger.warning(f"{what} close failed: {type(e).__name__}: {e}");
    }
}
