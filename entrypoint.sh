#!/bin/bash
# entrypoint.sh – runs inside the container to build a Windows x86 executable
# with PyInstaller via Wine.
#
# Usage:
#   docker run --rm -v /path/to/project:/src ghcr.io/kilianSen/docker-pyinstaller-win-x86 \
#       [pyinstaller options] <script.py>
#
# The container expects the Python project to be mounted at /src.
# If /src/requirements.txt exists it will be installed before PyInstaller runs.

set -e

# ── Start a virtual framebuffer so that Wine has a display ────────────────────
Xvfb :99 -screen 0 1024x768x24 &
XVFB_PID=$!
export DISPLAY=:99

cleanup() {
    kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

# ── Wait for Xvfb to be ready ─────────────────────────────────────────────────
sleep 1

# ── Install project dependencies if a requirements file is present ────────────
if [ -f /src/requirements.txt ]; then
    echo "[entrypoint] Installing Python requirements..."
    wine python -m pip install --no-warn-script-location -r /src/requirements.txt
fi

# ── Run PyInstaller via Wine ──────────────────────────────────────────────────
echo "[entrypoint] Running: wine python -m PyInstaller $*"
wine python -m PyInstaller "$@"
