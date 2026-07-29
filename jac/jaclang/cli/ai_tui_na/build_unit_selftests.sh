#!/usr/bin/env bash
# build_unit_selftests.sh — build native unit-test harness binaries.
#
# Compiles selftest_{width,keys,editor,markdown,overlay,autocomplete}.na.jac
# into bin/ without booting embedded CPython. Used by jac/tests/cli/test_tui_*.jac.
#
# Usage: bash build_unit_selftests.sh [selftest_name ...]
#   With no args, builds every unit selftest.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REPO_JAC="$REPO_ROOT/jac/zig-out/bin/jac"
REPO_VENV="$REPO_ROOT/.venv"

if [ -n "${JAC_BIN:-}" ]; then
    JAC=("$JAC_BIN")
    echo "==> Using \$JAC_BIN: $JAC_BIN"
elif [ -n "${JAC_PY:-}" ]; then
    JAC=("$JAC_PY" -m jaclang)
    echo "==> Using \$JAC_PY: $JAC_PY -m jaclang"
elif [ -x "$REPO_JAC" ]; then
    JAC=("$REPO_JAC")
    echo "==> Using repo-built jac binary: $REPO_JAC"
elif [ -x "$REPO_VENV/bin/python" ]; then
    JAC=("$REPO_VENV/bin/python" -m jaclang)
    echo "==> Using repo editable jaclang: $REPO_VENV/bin/python -m jaclang"
else
    echo "==> No jac build toolchain found (set JAC_BIN, build zig-out, or .venv)." >&2
    exit 1
fi

HOST="$(uname -s 2>/dev/null || echo "unknown")"
case "${JAC_AI_TUI_TARGET:-}" in
    linux)  TTY=linux  ;;
    darwin) TTY=darwin ;;
    *)
        case "$HOST" in
            Linux*)  TTY=linux  ;;
            Darwin*) TTY=darwin ;;
            *) echo "==> Unsupported host '$HOST'; set JAC_AI_TUI_TARGET" >&2; exit 1 ;;
        esac
        ;;
esac
case "$TTY" in
    linux)  PLAT=tty/tty_plat.linux.na.jac;  SHIM=libjacpyembed.so    ;;
    darwin) PLAT=tty/tty_plat.darwin.na.jac; SHIM=libjacpyembed.dylib ;;
esac

XFLAGS=""
case "$TTY" in
    darwin) [[ "$HOST" != Darwin* ]] && XFLAGS="--target darwin" ;;
esac

echo "==> TTY backend: $TTY   shim: $SHIM"

SHIM_SRC="${JAC_PYEMBED_SHIM:-$REPO_ROOT/jac/jaclang/runtimelib/client/targets/desktop/native/$SHIM}"
if [ ! -f "$SHIM_SRC" ]; then
    echo "==> libjacpyembed shim not found at $SHIM_SRC" >&2
    exit 1
fi

cp "$PLAT" tty_plat.na.jac
cp tty/libc_tty_base.na.jac libc_tty.na.jac
cp "$SHIM_SRC" "$SHIM"

source "$SCRIPT_DIR/_stage_modules.sh"
stage_tui_modules

mkdir -p bin
trap "rm -f tty_plat.na.jac libc_tty.na.jac '$SCRIPT_DIR/$SHIM'; cleanup_staged_modules" EXIT

ALL_ENTRIES=(
    selftest_width.na.jac
    selftest_keys.na.jac
    selftest_editor.na.jac
    selftest_markdown.na.jac
    selftest_overlay.na.jac
    selftest_autocomplete.na.jac
    selftest_wake.na.jac
)

build_one() {
    local entry="$1"
    local base="${entry%.na.jac}"
    local out="bin/${base#selftest_}"
    out="bin/${base}"
    # selftest_width.na.jac -> bin/selftest_width
    out="bin/${entry%.na.jac}"
    local tmp="bin/.${entry%.na.jac}.partial.$$"
    echo "==> Compiling $entry -> $out ..."
    "${JAC[@]}" nacompile "$entry" ${XFLAGS:+$XFLAGS} -o "$tmp"
    cp "$SHIM_SRC" "bin/$SHIM"
    mv -f "$tmp" "$out"
    echo "    built $out"
}

if [ "$#" -gt 0 ]; then
    for name in "$@"; do
        case "$name" in
            *.na.jac) build_one "$name" ;;
            selftest_*) build_one "${name}.na.jac" ;;
            *) build_one "selftest_${name}.na.jac" ;;
        esac
    done
else
    for entry in "${ALL_ENTRIES[@]}"; do
        build_one "$entry"
    done
fi

echo "==> Done. Unit selftests in $SCRIPT_DIR/bin/ (+ bin/$SHIM)"
