impl Media.to_dict -> list[dict] {
    raise NotImplementedError("Subclasses must implement this method.");
}

impl Text.to_dict -> list[dict] {
    return [{"type": "text", "text": self.text}];
}

impl Image.postinit -> None {
    value = self.url;

    if isinstance(value, os.PathLike) {
        value = os.fspath(value);
    }

    if isinstance(value, str) {
        s = value.strip();
        if s.startswith(("http://", "https://", "gs://", "data:")) {
            self.url = s;
            return;
        }

        if not os.path.exists(s) {
            raise ValueError(f"Image file does not exist: {s}");
        }
        image = open_image(s);
        fmt = image.format or "PNG";

        self.mime_type = self._format_to_mime(fmt);
        with BytesIO() as buffer {
            image.save(buffer, format=fmt);
            data = buffer.getvalue();
            self.url = self._data_url_from_bytes(data, fmt);
            return;
        }
    }

    if isinstance(value, PILImageCls) {
        fmt = value.format or "PNG";
        with BytesIO() as buffer {
            value.save(buffer, format=fmt);
            data = buffer.getvalue();
            self.url = self._data_url_from_bytes(data, fmt);
            return;
        }
    }

    if isinstance(value, (bytes, bytearray, memoryview)) {
        raw = bytes(value);

        img = open_image(BytesIO(raw));
        fmt = img.format or "PNG";

        try {
            self.url = self._data_url_from_bytes(raw, fmt);
        } except Exception {
            with BytesIO() as buffer {
                img.save(buffer, format=fmt);
                self.url = self._data_url_from_bytes(buffer.getvalue(), fmt);
            }
        }
        return;
    }

    if value?.read and callable(value?.read) {
        pos = None;
        try {
            pos = value?.tell();
        } except Exception {
            pos = None;
        }
        try {
            if value?.getvalue and callable(value?.getvalue) {
                stream_bytes = bytes(value?.getvalue());
            } else {
                if value?.seek {
                    with suppress(Exception) {
                        value?.seek(0);
                    }
                }
                stream_bytes = bytes(value?.read());
            }
            img = open_image(BytesIO(stream_bytes));
            fmt = img.format or "PNG";
            self.url = self._data_url_from_bytes(stream_bytes, fmt);
        } finally {
            if pos is not None and value?.seek {
                with suppress(Exception) {
                    value?.seek(pos);
                }
            }
        }
        return;
    }

    raise TypeError(
        "Unsupported Image input type. Provide a URL/path string, data URL, bytes, "
        "BytesIO, file-like object, os.PathLike, or PIL.Image.Image."
    );
}

impl Image._format_to_mime(fmt: str | None) -> str {
    fmt = (fmt or "PNG").upper();
    if fmt == "WEBP" {
        return "image/webp";
    }
    if fmt == "JPEG" or fmt == "JPG" {
        return "image/jpeg";
    }
    if fmt == "PNG" {
        return "image/png";
    }

    mime = mimetypes.types_map.get("." + fmt.lower());
    return mime or "image/png";
}

impl Image._data_url_from_bytes(data: bytes, fmt: str | None) -> str {
    mime = self.mime_type or self._format_to_mime(fmt);

    self.mime_type = mime;
    b64 = base64.b64encode(data).decode("utf-8");
    return f"data:{mime};base64,{b64}";
}

impl Image.to_dict -> list[dict] {
    image_url = {"url": self.url};
    if self.mime_type {
        image_url["format"] = self.mime_type;
    }
    return [{"type": "image_url", "image_url": image_url,}];
}

impl Image.save(path: str) -> str {
    url = self.url;
    if not isinstance(url, str) {
        raise TypeError("Image.save requires a normalized url; got a raw object.");
    }
    if url.startswith("data:") {
        data = base64.b64decode(url.split(",", 1)[1]);
    } else {
        import from urllib.request { urlopen }
        with urlopen(url) as resp {
            data = resp.read();
        }
    }
    with open(path, "wb") as fh {
        fh.write(data);
    }
    return path;
}

impl Audio.postinit -> None {
    if self._b64 {
        self.format = self.format or DEFAULT_AUDIO_FORMAT;
        return;
    }
    value = self.src;
    if isinstance(value, os.PathLike) {
        value = os.fspath(value);
    }
    if isinstance(value, str) {
        s = value.strip();
        if s.startswith("data:") {
            (header, _, payload) = s.partition(",");
            self._b64 = payload;
            mime = header[5:].split(";")[0];
            self.format = self.format
                or (mime.split("/")[-1] if "/" in mime else DEFAULT_AUDIO_FORMAT);
            return;
        }
        if not os.path.exists(s) {
            raise ValueError(f"Audio file does not exist: {s}");
        }
        with open(s, "rb") as fh {
            raw = fh.read();
        }
        self.format = self.format
            or Audio._format_from_name(s)
            or Audio._format_from_magic(raw)
            or DEFAULT_AUDIO_FORMAT;
        self._b64 = base64.b64encode(raw).decode("utf-8");
        return;
    }
    if isinstance(value, (bytes, bytearray, memoryview)) {
        raw = bytes(value);
        self.format = self.format
            or Audio._format_from_magic(raw)
            or DEFAULT_AUDIO_FORMAT;
        self._b64 = base64.b64encode(raw).decode("utf-8");
        return;
    }
    if value?.read and callable(value?.read) {
        pos = None;
        try {
            pos = value?.tell();
        } except Exception {
            pos = None;
        }
        try {
            if value?.getvalue and callable(value?.getvalue) {
                stream_bytes = bytes(value?.getvalue());
            } else {
                if value?.seek {
                    with suppress(Exception) {
                        value?.seek(0);
                    }
                }
                stream_bytes = bytes(value?.read());
            }
            self.format = self.format
                or Audio._format_from_magic(stream_bytes)
                or DEFAULT_AUDIO_FORMAT;
            self._b64 = base64.b64encode(stream_bytes).decode("utf-8");
        } finally {
            if pos is not None and value?.seek {
                with suppress(Exception) {
                    value?.seek(pos);
                }
            }
        }
        return;
    }
    raise TypeError(
        "Unsupported Audio input type. Provide a file path, data URL, bytes, "
        "BytesIO, file-like object, or os.PathLike."
    );
}

impl Audio.from_b64(data: str, fmt: str = "", transcript: str = "") -> Audio {
    resolved = Audio._format_from_magic(base64.b64decode(data))
        or fmt
        or DEFAULT_AUDIO_FORMAT;
    return Audio(
        src=f"data:audio/{resolved};base64,{data}",
        format=resolved,
        transcript=transcript
    );
}

impl Audio._format_from_name(name: str) -> str | None {
    ext = os.path.splitext(name)[1].lstrip(".").lower();
    if not ext {
        return None;
    }
    return "mp3" if ext in ("mpga", "mpeg") else ext;
}

impl Audio._format_from_magic(data: bytes) -> str {
    for (prefix, at8, fmt) in [
        (b"RIFF", b"WAVE", "wav"),
        (b"FORM", b"AIFF", "aiff"),
        (b"OggS", b"", "ogg"),
        (b"fLaC", b"", "flac"),
        (b"ID3", b"", "mp3")
    ] {
        if data.startswith(prefix) and (not at8 or data[8:12] == at8) {
            return fmt;
        }
    }
    if len(data) > 1 and data[0] == 0xFF and (data[1] & 0xE0) == 0xE0 {
        return "mp3";
    }
    return "";
}


impl Audio.save(path: str) -> str {
    with open(path, "wb") as fh {
        fh.write(base64.b64decode(self._b64));
    }
    return path;
}

impl Audio.to_dict -> list[dict] {
    return [
        {
            "type": "input_audio",
            "input_audio": {
                "data": self._b64,
                "format": self.format or DEFAULT_AUDIO_FORMAT,

            },

        }
    ];
}

impl Video.postinit -> None {
    if self.data is not None {
        return;
    }
    if not os.path.exists(self.path) {
        raise ValueError(f"Video file does not exist: {self.path}");
    }
}

impl Video.from_bytes(data: bytes) -> Video {
    return Video(data=data);
}

impl Video.save(path: str) -> str {
    if self.data is None {
        raise ValueError("Video has no payload to save; it was built from a path.");
    }
    with open(path, "wb") as fh {
        fh.write(self.data);
    }
    return path;
}

impl Video.load_frames -> None {
    try {
        import cv2;
    } except ImportError {
        raise ImportError(
            "OpenCV is required to process video files. "
            "Install `jac install 'byllm[video]'` for video capabilities."
        );
    }
    self._base64frames = [];
    video = cv2.VideoCapture(self.path);
    total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT));
    target_fps = self.fps;
    source_fps = video.get(cv2.CAP_PROP_FPS);
    frames_to_skip = int(source_fps / target_fps) - 1 if target_fps < source_fps else 1;
    curr_frame = 0;
    while curr_frame < total_frames - 1 {
        video.set(cv2.CAP_PROP_POS_FRAMES, curr_frame);
        (success, frame) = video.read();
        if not success {
            raise ValueError("Failed to read video frame.");
        }
        (_, buffer) = cv2.imencode(".jpg", frame);
        self._base64frames.append(base64.b64encode(bytes(buffer)).decode("utf-8"));
        curr_frame += frames_to_skip;
    }
}

impl Video.to_dict -> list[dict] {
    if self._base64frames is None {
        self.load_frames();
    }
    assert (self._base64frames is not None) , "Frames must be loaded before conversion.";
    return [
        {"type": "image_url", "image_url": f"data:image/jpeg;base64,{frame}",}
        for frame in self._base64frames
    ];
}
