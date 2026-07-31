#!/usr/bin/env bash
# M4 on-device gate: build → install → launch → interact → DexClassLoader hot-swap → verify.
#
# Requires: jac on PATH, ANDROID_HOME / ANDROID_SDK_ROOT, a booted emulator or device
# (jac start will auto-start the AVD from jac.toml when none is connected).
#
# Usage (from repo root):
#   bash scripts/android_compose_device_e2e.sh
#
# Environment:
#   COMPOSE_ANDROID_DIR   — project dir (default: jac/examples/compose_android)
#   JAC_ANDROID_DEV_PORT  — dev-server port (default: ephemeral free port)
#   TIMEOUT_HMR_READY     — seconds to wait for initial HMR (default: 600)
#   TIMEOUT_HOT_SWAP      — seconds to wait for hot dex rebuild (default: 300)
#   JAC_DEV_LOG           — jac stdout log path (default: /tmp/jac-android-e2e.log)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_DIR="${COMPOSE_ANDROID_DIR:-$ROOT/jac/examples/compose_android}"
MAIN_JAC="$EXAMPLE_DIR/main.jac"
LOG_FILE="${JAC_DEV_LOG:-/tmp/jac-android-e2e.log}"
TIMEOUT_HMR_READY="${TIMEOUT_HMR_READY:-600}"
TIMEOUT_HOT_SWAP="${TIMEOUT_HOT_SWAP:-300}"
ORIG_TITLE='Jac → Jetpack Compose'
E2E_MARKER='__JAC_E2E_HMR_MARKER__'

if [[ -n "${JAC_ANDROID_DEV_PORT:-}" ]]; then
  DEV_PORT="$JAC_ANDROID_DEV_PORT"
else
  DEV_PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')"
fi

if [[ -n "${ANDROID_HOME:-}" ]]; then
  ADB="$ANDROID_HOME/platform-tools/adb"
elif [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
  ADB="$ANDROID_SDK_ROOT/platform-tools/adb"
else
  ADB="$(command -v adb || true)"
fi
if [[ ! -x "$ADB" ]]; then
  echo "adb not found (set ANDROID_HOME or ANDROID_SDK_ROOT)" >&2
  exit 1
fi

JAC_PID=""

restore_main_jac() {
  if [[ -f "${MAIN_JAC}.e2e.bak" ]]; then
    mv -f "${MAIN_JAC}.e2e.bak" "$MAIN_JAC"
  fi
}

cleanup() {
  if [[ -n "$JAC_PID" ]] && kill -0 "$JAC_PID" 2>/dev/null; then
    kill "$JAC_PID" 2>/dev/null || true
    wait "$JAC_PID" 2>/dev/null || true
  fi
  restore_main_jac
}
trap cleanup EXIT

ui_texts() {
  "$ADB" shell uiautomator dump /sdcard/jac_e2e_ui.xml >/dev/null 2>&1
  "$ADB" shell cat /sdcard/jac_e2e_ui.xml 2>/dev/null | python3 -c '
import re, sys
for m in re.findall(r"text=\"([^\"]*)\"", sys.stdin.read()):
    if m:
        print(m)
' || true
}

wait_for_text() {
  local needle="$1" timeout="${2:-120}" elapsed=0
  while (( elapsed < timeout )); do
    if ui_texts | grep -Fxq "$needle"; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "TIMEOUT waiting for UI text: $needle" >&2
  echo "Visible texts:" >&2
  ui_texts | head -20 >&2 || true
  return 1
}

wait_for_log() {
  local pattern="$1" timeout="${2:-600}" elapsed=0
  while (( elapsed < timeout )); do
    if grep -q "$pattern" "$LOG_FILE" 2>/dev/null; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "TIMEOUT waiting for log pattern: $pattern" >&2
  tail -40 "$LOG_FILE" >&2 || true
  return 1
}

manifest_version() {
  curl -sf "http://localhost:${DEV_PORT}/_jac/dev/modules/manifest.json" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])"
}

echo "==> Waiting for adb device..."
"$ADB" wait-for-device
booted=0
for _ in $(seq 1 90); do
  boot="$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  if [[ "$boot" == "1" ]]; then
    booted=1
    break
  fi
  sleep 2
done
if [[ "$booted" != "1" ]]; then
  echo "Emulator/device did not finish booting" >&2
  exit 1
fi
echo "==> Device ready: $("$ADB" devices -l | awk '/device product:/{print $1; exit}')"

rm -f "$LOG_FILE"
cd "$EXAMPLE_DIR"

echo "==> Starting jac android dev (port $DEV_PORT, log $LOG_FILE)..."
jac start --client android --dev -p "$DEV_PORT" >"$LOG_FILE" 2>&1 &
JAC_PID=$!

wait_for_log "HMR ready" "$TIMEOUT_HMR_READY"
INITIAL_VER="$(manifest_version)"
echo "==> HMR ready — initial hot module v${INITIAL_VER}"

wait_for_text "$ORIG_TITLE" 120
echo "==> Initial Compose UI rendered"

# Increment button center (Small_Phone 720×1280 layout).
"$ADB" shell input tap 193 284
sleep 2
wait_for_text "1" 60
echo "==> Counter increment works"

cp "$MAIN_JAC" "${MAIN_JAC}.e2e.bak"
python3 - "$MAIN_JAC" "$ORIG_TITLE" "$E2E_MARKER" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
needle = sys.argv[2]
marker = sys.argv[3]
text = path.read_text(encoding="utf-8")
if needle not in text:
    raise SystemExit(f"expected {needle!r} in {path}")
path.write_text(text.replace(needle, marker), encoding="utf-8")
PY

wait_for_log "Hot module swapped" "$TIMEOUT_HOT_SWAP"
NEW_VER="$(manifest_version)"
if [[ "$NEW_VER" == "$INITIAL_VER" ]]; then
  echo "Manifest version unchanged after hot rebuild ($NEW_VER)" >&2
  exit 1
fi
echo "==> Hot dex swapped v${INITIAL_VER} → v${NEW_VER}"

wait_for_text "$E2E_MARKER" 120
echo "==> Hot-swapped UI visible"

if ui_texts | grep -Fxq "0"; then
  echo "==> Counter reset after hot swap"
else
  echo "WARNING: counter 0 not seen after hot swap (timing/layout)" >&2
fi

echo "android_compose_device_e2e: PASSED"
