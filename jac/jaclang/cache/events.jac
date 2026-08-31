glob EV_COMPILE_END: str = "compile_end",
     EV_MODULE_FORGOTTEN: str = "module_forgotten",
     EV_PROGRAM_RELEASED: str = "program_released",
     EV_PROCESS_RESET: str = "process_reset",
     EV_CONFIG_CHANGED: str = "config_changed",
     EV_POST_FORK: str = "post_fork";


glob _subscribers: dict[str, list] = {};


def subscribe(event: str, handler: any) {
    bucket = _subscribers.get(event);
    if bucket is None {
        bucket = [];
        _subscribers[event] = bucket;
    }
    if handler not in bucket {
        bucket.append(handler);
    }
}


def unsubscribe(event: str, handler: any) {
    bucket = _subscribers.get(event);
    if bucket is not None and handler in bucket {
        bucket.remove(handler);
    }
}


def emit(event: str, payload: any = None) {
    for handler in list(_subscribers.get(event, [])) {
        try {
            handler(payload);
        } except Exception { }
    }
}
