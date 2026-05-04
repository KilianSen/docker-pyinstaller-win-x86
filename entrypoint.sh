#!/bin/bash
# entrypoint.sh – runs inside the container to build a Windows x86 executable
# with PyInstaller via Wine.
#
# Usage:
#   docker run --rm -v /path/to/project:/src ghcr.io/kiliansen/docker-pyinstaller-win-x86 \
#       [pyinstaller options] <script.py>
#
# The container expects the Python project to be mounted at /src.
# If /src/requirements.txt exists it will be installed before PyInstaller runs.

set -e

if [ $# -eq 0 ]; then
    echo "[entrypoint] Error: no arguments provided. Pass PyInstaller arguments (e.g. --onefile myscript.py)" >&2
    exit 1
fi

# ── Start a virtual framebuffer so that Wine has a display ────────────────────
Xvfb :99 -screen 0 1024x768x24 &
XVFB_PID=$!
export DISPLAY=:99

cleanup() {
    kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

# ── Wait for Xvfb to be ready ─────────────────────────────────────────────────
for i in $(seq 1 20); do
    xdpyinfo -display :99 >/dev/null 2>&1 && break
    sleep 0.5
done

# ── Install project dependencies if a requirements file is present ────────────
if [ -f /src/requirements.txt ]; then
    echo "[entrypoint] Installing Python requirements..."
    wine python -m pip install --no-warn-script-location --no-cache-dir -r /src/requirements.txt
fi

# ── Run PyInstaller via Wine ──────────────────────────────────────────────────
echo "[entrypoint] Running: wine python -m PyInstaller $*"
wine python -m PyInstaller "$@"
