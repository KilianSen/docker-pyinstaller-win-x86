# syntax=docker/dockerfile:1
FROM ubuntu:22.04

# ── Build arguments ────────────────────────────────────────────────────────────
ARG PYTHON_VERSION=3.11.9
# Optional SHA-256 checksum for the Python Windows installer.
# Supply it with --build-arg PYTHON_SHA256=<hash> when building a custom image
# to verify the download.  Leave empty to skip verification (default).
# Example (python-3.11.9.exe):
#   --build-arg PYTHON_SHA256=\
#     $(curl -s https://www.python.org/ftp/python/3.11.9/python-3.11.9.exe | sha256sum | cut -d' ' -f1)
ARG PYTHON_SHA256=""
ARG PYINSTALLER_VERSION=6.5.0

# ── Image labels ───────────────────────────────────────────────────────────────
LABEL org.opencontainers.image.source="https://github.com/KilianSen/docker-pyinstaller-win-x86"
LABEL org.opencontainers.image.description="Build Windows x86 executables with PyInstaller and Wine on Linux (amd64 & arm64)"
LABEL org.opencontainers.image.licenses="MIT"

# ── Wine / environment settings ────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    WINEARCH=win32 \
    WINEPREFIX=/wine \
    WINEDEBUG=-all \
    DISPLAY=:99

# ── Install Wine and system packages ──────────────────────────────────────────
# wine32 provides the 32-bit Windows (x86) emulation layer needed to run the
# Windows x86 Python interpreter and PyInstaller's bootloader.
#
# On amd64:  wine32 runs x86 code natively – no additional emulation needed.
# On arm64:  wine32 relies on QEMU binfmt_misc for i386 emulation.
#            docker/setup-qemu-action registers those binfmt handlers
#            automatically in GitHub Actions CI runners.
#            On bare-metal arm64 hosts, run once before using this image:
#              docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
#
# We use the official WineHQ repository instead of Ubuntu's default repos
# because the Ubuntu 22.04 wine packages (wine32/wine64/libwine:i386) have
# known conflicts that cause apt-get to exit with code 100.
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
    && rm -rf /var/lib/apt/lists/*

RUN set -ex \
    && dpkg --add-architecture i386 \
    && mkdir -pm755 /etc/apt/keyrings \
    && wget -q -O /etc/apt/keyrings/winehq-archive.key \
         https://dl.winehq.org/wine-builds/winehq.key \
    && wget -q -NP /etc/apt/sources.list.d/ \
         https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        xvfb \
        winehq-stable \
    && rm -rf /var/lib/apt/lists/*

# ── Bootstrap the Wine prefix ──────────────────────────────────────────────────
RUN xvfb-run sh -c 'wineboot --init 2>/dev/null; while pgrep wineserver > /dev/null; do sleep 1; done'

# ── Install Python for Windows (32-bit) inside Wine ───────────────────────────
# The installer runs silently (/quiet) and prepends the Python directory to the
# Wine PATH so subsequent `wine python` calls resolve automatically.
RUN set -ex \
    && wget -q "https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}.exe" \
         -O /tmp/python-installer.exe \
    && if [ -n "${PYTHON_SHA256}" ]; then \
         echo "${PYTHON_SHA256}  /tmp/python-installer.exe" | sha256sum -c -; \
       fi \
    && xvfb-run sh -c \
        "wine /tmp/python-installer.exe /quiet InstallAllUsers=0 PrependPath=1 Include_test=0 2>/dev/null; \
         while pgrep wineserver > /dev/null; do sleep 1; done" \
    && rm /tmp/python-installer.exe

# ── Upgrade pip and install PyInstaller inside Wine Python ────────────────────
RUN xvfb-run sh -c \
    "wine python -m pip install --upgrade pip 2>/dev/null; \
     while pgrep wineserver > /dev/null; do sleep 1; done" \
 && xvfb-run sh -c \
    "wine python -m pip install pyinstaller==${PYINSTALLER_VERSION} 2>/dev/null; \
     while pgrep wineserver > /dev/null; do sleep 1; done" \
 && find /wine -path "*/pip/cache" -type d -exec rm -rf {} + 2>/dev/null \
 ; true  # pip cache may not exist if nothing was cached; non-zero exit is expected

# ── Copy entrypoint ────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Runtime defaults ───────────────────────────────────────────────────────────
VOLUME /src
WORKDIR /src

ENTRYPOINT ["/entrypoint.sh"]
