import from "@jac/wasm_host" { set_na_env }

import from .arena { init }

obj Shim {
    has canvas: HTMLCanvasElement,
        gl: any = None,
        exports: any = None,
        game: int | None = None,
        mem: any = None,
        heap: int = 0,
        proj: list[float] = [],
        mv: list[float] = [],
        pstack: list[list[float]] = [],
        mvstack: list[list[float]] = [],
        mode: int = 0x1700,
        verts: list[float] = [],
        color: list[float] = [1.0, 1.0, 1.0, 1.0],
        bmode: int = 4,
        vbo: any = None,
        aPos: int = 0,
        aCol: int = 0,
        uMVP: any = None,
        keys: dict[int, int] = {},
        pressed: dict[int, int] = {},
        mpressed: dict[int, int] = {},
        mouseX: float = 0.0,
        mouseY: float = 0.0,
        locked: bool = False,
        dt: float = 0.016,
        time: float = 0.0,
        t0: float = 0.0,
        draws: int = 0,
        on_tick: Callable[[int, float, int, int], None] | None = None,
        stopped: bool = True,
        session: int = 0,
        raf: float = 0.0,
        program: any = None,
        on_key_down: Callable[[KeyboardEvent], None] | None = None,
        on_key_up: Callable[[KeyboardEvent], None] | None = None,
        on_mouse_down: Callable[[MouseEvent], None] | None = None,
        on_mouse_move: Callable[[MouseEvent], None] | None = None,
        on_lock_change: Callable[[Event], None] | None = None,
        on_blur: Callable[[Event], None] | None = None;
}

# One shim for the page's lifetime: the wasm host instantiates arena.wasm
# once per module stem with the env built here, so a relaunch has to reuse
# the object those env closures captured rather than mint a new one.
glob _shim: Shim | None = None;

def _m_ident -> list[float] {
    return [
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0
    ];
}

def _m_mul(a: list[float], b: list[float]) -> list[float] {
    c = [
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0
    ];
    col = 0;
    while col < 4 {
        row = 0;
        while row < 4 {
            s = 0.0;
            k = 0;
            while k < 4 {
                s = s + a[row + 4 * k] * b[k + 4 * col];
                k = k + 1;
            }
            c[row + 4 * col] = s;
            row = row + 1;
        }
        col = col + 1;
    }
    return c;
}

def _m_translate(x: float, y: float, z: float) -> list[float] {
    m = _m_ident();
    m[12] = x;
    m[13] = y;
    m[14] = z;
    return m;
}

def _m_rotate(ang: float, x: float, y: float, z: float) -> list[float] {
    a = ang * 3.141592653589793 / 180.0;
    c = Math.cos(a);
    s = Math.sin(a);
    ln = Math.hypot(x, y, z);
    if ln == 0.0 {
        ln = 1.0;
    }
    x = x / ln;
    y = y / ln;
    z = z / ln;
    t = 1.0 - c;
    return [
        x * x * t + c,
        y * x * t + z * s,
        x * z * t - y * s,
        0.0,
        x * y * t - z * s,
        y * y * t + c,
        y * z * t + x * s,
        0.0,
        x * z * t + y * s,
        y * z * t - x * s,
        z * z * t + c,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0
    ];
}

def _m_frustum(
    l: float, r: float, b: float, t: float, n: float, f: float
) -> list[float] {
    return [
        2.0 * n / (r - l),
        0.0,
        0.0,
        0.0,
        0.0,
        2.0 * n / (t - b),
        0.0,
        0.0,
        (r + l) / (r - l),
        (t + b) / (t - b),
        -(f + n) / (f - n),
        -1.0,
        0.0,
        0.0,
        -2.0 * f * n / (f - n),
        0.0
    ];
}

def _m_ortho(
    l: float, r: float, b: float, t: float, n: float, f: float
) -> list[float] {
    return [
        2.0 / (r - l),
        0.0,
        0.0,
        0.0,
        0.0,
        2.0 / (t - b),
        0.0,
        0.0,
        0.0,
        0.0,
        -2.0 / (f - n),
        0.0,
        -(r + l) / (r - l),
        -(t + b) / (t - b),
        -(f + n) / (f - n),
        1.0
    ];
}

def _cur(sh: Shim) -> list[float] {
    return sh.proj if sh.mode == 0x1701 else sh.mv;
}

def _setcur(sh: Shim, m: list[float]) {
    if sh.mode == 0x1701 {
        sh.proj = m;
    } else {
        sh.mv = m;
    }
}


def _flush(sh: Shim) -> None {
    if len(sh.verts) == 0 {
        return;
    }
    gl = sh.gl;
    mvp = _m_mul(sh.proj, sh.mv);
    gl.bindBuffer(gl.ARRAY_BUFFER, sh.vbo);
    gl.bufferData(gl.ARRAY_BUFFER, new(Float32Array, sh.verts), gl.STREAM_DRAW);
    gl.enableVertexAttribArray(sh.aPos);
    gl.vertexAttribPointer(sh.aPos, 3, gl.FLOAT, False, 28, 0);
    gl.enableVertexAttribArray(sh.aCol);
    gl.vertexAttribPointer(sh.aCol, 4, gl.FLOAT, False, 28, 12);
    gl.uniformMatrix4fv(sh.uMVP, False, new(Float32Array, mvp));
    prim = gl.LINES if sh.bmode == 1 else gl.TRIANGLES;
    gl.drawArrays(prim, 0, len(sh.verts) // 7);
    sh.draws = sh.draws + 1;
    sh.verts = [];
}

def _build_env(sh: Shim) -> dict[str, any] {
    return {
        "InitWindow": lambda (w: int, h: int, t: int) {},
        "WindowShouldClose": lambda { return 0; },
        "CloseWindow": lambda {},
        "SetTargetFPS": lambda (f: int) {},
        "BeginDrawing": lambda { sh.gl.viewport(0, 0, 960, 600); },
        "EndDrawing": lambda {},
        "EndMode3D": lambda { _flush(sh); },
        "GetFrameTime": lambda { return sh.dt; },
        "GetTime": lambda { return sh.time; },
        "DrawFPS": lambda (x: int, y: int) {},
        "IsKeyDown": lambda (k: int) { return sh.keys.get(k, 0); },
        "IsKeyPressed": lambda (k: int) { return sh.pressed.get(k, 0); },
        "GetMouseX": lambda { return sh.mouseX; },
        "GetMouseY": lambda { return sh.mouseY; },
        "IsMouseButtonPressed": lambda (b: int) { return sh.mpressed.get(b, 0); },
        "DisableCursor": lambda { sh.canvas.requestPointerLock(); },
        "EnableCursor": lambda { document.exitPointerLock(); },
        "rlClearColor": lambda (r: int, g: int, b: int, a: int) { sh.gl.clearColor(
            float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0
        ); },
        "rlClearScreenBuffers": lambda { sh.gl.clear(16384 | 256); },
        "rlEnableDepthTest": lambda { sh.gl.enable(sh.gl.DEPTH_TEST); },
        "rlDisableDepthTest": lambda { sh.gl.disable(sh.gl.DEPTH_TEST); },
        "rlMatrixMode": lambda (m: int) { sh.mode = m; },
        "rlLoadIdentity": lambda { _setcur(sh, _m_ident()); },
        "rlPushMatrix": lambda { if sh.mode == 0x1701 {
            sh.pstack.append(sh.proj);
        } else {
            sh.mvstack.append(sh.mv);
        } },
        "rlPopMatrix": lambda { if sh.mode == 0x1701 {
            sh.proj = sh.pstack.pop();
        } else {
            sh.mv = sh.mvstack.pop();
        } },
        "rlTranslatef": lambda (x: float, y: float, z: float) { _setcur(
            sh, _m_mul(_cur(sh), _m_translate(x, y, z))
        ); },
        "rlRotatef": lambda (a: float, x: float, y: float, z: float) { _setcur(
            sh, _m_mul(_cur(sh), _m_rotate(a, x, y, z))
        ); },
        "rlFrustum": lambda (
            l: float, r: float, b: float, t: float, n: float, f: float
        ) { _setcur(sh, _m_mul(_cur(sh), _m_frustum(l, r, b, t, n, f))); },
        "rlOrtho": lambda (
            l: float, r: float, b: float, t: float, n: float, f: float
        ) { _setcur(sh, _m_mul(_cur(sh), _m_ortho(l, r, b, t, n, f))); },
        "rlBegin": lambda (m: int) {
            sh.bmode = m;
            sh.verts = [];
        },
        "rlEnd": lambda { _flush(sh); },
        "rlVertex3f": lambda (x: float, y: float, z: float) {
            sh.verts.append(x);
            sh.verts.append(y);
            sh.verts.append(z);
            sh.verts.append(sh.color[0]);
            sh.verts.append(sh.color[1]);
            sh.verts.append(sh.color[2]);
            sh.verts.append(sh.color[3]);
        },
        "rlColor4ub": lambda (r: int, g: int, b: int, a: int) { sh.color = [
            float(r) / 255.0,
            float(g) / 255.0,
            float(b) / 255.0,
            1.0
        ]; },
        "rlSetLineWidth": lambda (w: float) { sh.gl.lineWidth(w); }
    };
}

def _compile_shader(gl: any, kind: int, source: str) -> any {
    shader = gl.createShader(kind);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if not gl.getShaderParameter(shader, gl.COMPILE_STATUS) {
        message = str(gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        raise Error("Arena shader compilation failed: " + message);
    }
    return shader;
}

def _init_gl(sh: Shim) {
    gl = sh.gl;
    vs = "attribute vec3 aPos; attribute vec4 aCol; uniform mat4 uMVP; varying vec4 vCol; void main(){ gl_Position = uMVP * vec4(aPos,1.0); vCol = aCol; }";
    fs = "precision mediump float; varying vec4 vCol; void main(){ gl_FragColor = vCol; }";
    vsh = _compile_shader(gl, gl.VERTEX_SHADER, vs);
    fsh: any = None;
    try {
        fsh = _compile_shader(gl, gl.FRAGMENT_SHADER, fs);
        prog = gl.createProgram();
        sh.program = prog;
        gl.attachShader(prog, vsh);
        gl.attachShader(prog, fsh);
        gl.linkProgram(prog);
        if not gl.getProgramParameter(prog, gl.LINK_STATUS) {
            raise Error("Arena shader link failed: " + str(gl.getProgramInfoLog(prog)));
        }
    } finally {
        gl.deleteShader(vsh);
        if fsh is not None {
            gl.deleteShader(fsh);
        }
    }
    gl.useProgram(prog);
    sh.aPos = gl.getAttribLocation(prog, "aPos");
    sh.aCol = gl.getAttribLocation(prog, "aCol");
    sh.uMVP = gl.getUniformLocation(prog, "uMVP");
    sh.vbo = gl.createBuffer();
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.disable(gl.CULL_FACE);
}

def _keymap(code: str) -> int {
    m = {
        "KeyW": 87,
        "KeyA": 65,
        "KeyS": 83,
        "KeyD": 68,
        "Space": 32,
        "Tab": 258,
        "ArrowRight": 262,
        "ArrowLeft": 263,
        "ArrowDown": 264,
        "ArrowUp": 265
    };
    return m.get(code, 0);
}

# The game owns the keyboard only while it is engaged: the pointer is locked
# to its canvas, or the canvas is the focused element. Anywhere else on the
# page (a login form, the docs search) WASD, Space, Tab and the arrows keep
# their normal meaning.
def _engaged(sh: Shim) -> bool {
    return sh.locked or document.activeElement == sh.canvas;
}

def _install_input(sh: Shim) {
    sh.on_key_down = lambda (e: KeyboardEvent) {
        if not _engaged(sh) {
            return;
        }
        kc = _keymap(e.code);
        if kc != 0 {
            e.preventDefault();
            if not sh.keys.get(kc, 0) {
                sh.pressed[kc] = 1;
            }
            sh.keys[kc] = 1;
        }
    };
    sh.on_key_up = lambda (e: KeyboardEvent) {
        kc = _keymap(e.code);
        if kc != 0 {
            sh.keys[kc] = 0;
        }
    };
    sh.on_mouse_down = lambda (e: MouseEvent) { if e.button == 0 {
        sh.mpressed[0] = 1;
    }};
    sh.on_mouse_move = lambda (e: MouseEvent) { if sh.locked {
        sh.mouseX = sh.mouseX + e.movementX;
        sh.mouseY = sh.mouseY + e.movementY;
    } else {
        sh.mouseX = e.offsetX;
        sh.mouseY = e.offsetY;
    } };
    sh.on_lock_change = lambda (e: Event) {
        was = sh.locked;
        sh.locked = document.pointerLockElement == sh.canvas;
        if was and not sh.locked {
            sh.keys = {};
            sh.pressed = {};
            sh.pressed[258] = 1;
        }
    };
    sh.on_blur = lambda (e: Event) {
        sh.keys = {};
        sh.pressed = {};
        sh.mpressed = {};
    };
    window.addEventListener("blur", sh.on_blur);
    window.addEventListener("keydown", sh.on_key_down);
    window.addEventListener("keyup", sh.on_key_up);
    sh.canvas.addEventListener("mousedown", sh.on_mouse_down);
    document.addEventListener("mousemove", sh.on_mouse_move);
    document.addEventListener("pointerlockchange", sh.on_lock_change);
}

def _remove_input(sh: Shim) {
    window.removeEventListener("blur", sh.on_blur);
    window.removeEventListener("keydown", sh.on_key_down);
    window.removeEventListener("keyup", sh.on_key_up);
    sh.canvas.removeEventListener("mousedown", sh.on_mouse_down);
    document.removeEventListener("mousemove", sh.on_mouse_move);
    document.removeEventListener("pointerlockchange", sh.on_lock_change);
}

# Halts the frame loop, drops every page-level listener and releases the
# pointer, so an unmounted game leaves nothing behind.
def _stop(sh: Shim, session: int) {
    if sh.stopped or session != sh.session {
        return;
    }
    sh.stopped = True;
    if sh.raf {
        cancelAnimationFrame(sh.raf);
        sh.raf = 0;
    }
    try {
        game = take(sh.game);
        if game is not None {
            sh.exports.shutdown(game);
        }
    } finally {
        _remove_input(sh);
        if document.pointerLockElement == sh.canvas {
            document.exitPointerLock();
        }
        if sh.vbo is not None {
            sh.gl.deleteBuffer(sh.vbo);
            sh.vbo = None;
        }
        if sh.program is not None {
            sh.gl.deleteProgram(sh.program);
            sh.program = None;
        }
        sh.keys = {};
        sh.pressed = {};
        sh.mpressed = {};
        sh.on_tick = None;
    }
}

def _frame_tick(sh: Shim, session: int, ts: float) {
    if sh.stopped or session != sh.session {
        return;
    }
    sh.raf = 0;
    try {
        if sh.t0 == 0.0 {
            sh.t0 = ts;
        }
        now = (ts - sh.t0) / 1000.0;
        sh.dt = (now - sh.time) if sh.time > 0.0 else 0.016;
        if sh.dt > 0.05 {
            sh.dt = 0.05;
        }
        sh.time = now;
        game = sh.game;
        if game is None {
            _stop(sh, session);
            return;
        }
        closed = sh.exports.frame(game);
        if sh.on_tick is not None {
            fps = int(Math.round(1.0 / sh.dt)) if sh.dt > 0.0 else 0;
            sh.on_tick(
                int(str(sh.exports.get_score(game))),
                sh.exports.get_hp(game),
                int(str(sh.exports.get_deaths(game))),
                fps
            );
        }
        sh.pressed = {};
        sh.mpressed = {};
        if closed {
            _stop(sh, session);
        } elif not sh.stopped and session == sh.session {
            sh.raf = requestAnimationFrame(
                lambda (t: float) { _frame_tick(sh, session, t); }
            );
        }
    } except Exception as err {
        _stop(sh, session);
        console.error("arena frame failed", err);
    }
}

async def _boot(sh: Shim, session: int) {
    try {
        game = (await init()) as int;
        if sh.stopped or session != sh.session {
            sh.exports.shutdown(game);
            return;
        }
        sh.game = game;
        sh.raf = requestAnimationFrame(
            lambda (ts: float) { _frame_tick(sh, session, ts); }
        );
    } except Exception as err {
        _stop(sh, session);
        console.error("arena.wasm failed to start", err);
    }
}

def:pub run_game(
    canvas: HTMLCanvasElement,
    on_tick: Callable[[int, float, int, int], None] | None = None
) -> Callable[[], None] {
    if _shim is None {
        _shim = Shim(canvas=canvas);
        set_na_env("arena", _shim, {"env": _build_env(_shim)});
    }
    sh = _shim;
    _stop(sh, sh.session);
    sh.session += 1;
    session = sh.session;
    sh.stopped = False;
    sh.on_tick = on_tick;
    sh.canvas = canvas;
    sh.gl = canvas.getContext("webgl");
    try {
        if sh.gl is None {
            raise Error("WebGL is unavailable");
        }
        sh.proj = _m_ident();
        sh.mv = _m_ident();
        sh.pstack = [];
        sh.mvstack = [];
        sh.verts = [];
        sh.locked = False;
        sh.mouseX = 0.0;
        sh.mouseY = 0.0;
        sh.t0 = 0.0;
        sh.time = 0.0;
        _init_gl(sh);
        _install_input(sh);
        canvas.focus();
        _ = _boot(sh, session);
    } except Exception as err {
        _stop(sh, session);
        raise err;
    }
    return lambda { _stop(sh, session); };
}
