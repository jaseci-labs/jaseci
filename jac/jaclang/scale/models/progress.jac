obj ProgressEvent {
    has phase: str,
        step: str = "",
        status: str = "info",
        message: str = "",
        detail: dict[str, any] = {};
}

class EventSink {
    def emit(self: EventSink, event: ProgressEvent) -> None;
}

obj CallbackSink(EventSink) {
    has callback: any;

    def emit(event: ProgressEvent) {
        self.callback(event);
    }
}
