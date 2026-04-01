# docker-pyinstaller-win-x86

[![Build and Publish Docker Image](https://github.com/KilianSen/docker-pyinstaller-win-x86/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/KilianSen/docker-pyinstaller-win-x86/actions/workflows/docker-publish.yml)

A Docker container that uses **Wine**, **QEMU**, and **PyInstaller** to build
**Windows x86 (32-bit) executables** from Python source code on Linux hosts –
including ARM64 hosts such as Apple-silicon or AWS Graviton CI runners.

---

## Quick start

```bash
# Build a single-file Windows .exe from myscript.py
docker run --rm \
  -v "$(pwd):/src" \
  ghcr.io/kilianSen/docker-pyinstaller-win-x86 \
  --onefile myscript.py
```

The finished executable is written to `/src/dist/` (the mounted directory).

### With a requirements file

If your project root contains a `requirements.txt`, the container installs it
automatically before running PyInstaller:

```bash
docker run --rm \
  -v "$(pwd):/src" \
  ghcr.io/kilianSen/docker-pyinstaller-win-x86 \
  --onefile --name myapp myscript.py
```

All arguments after the image name are forwarded verbatim to
`wine python -m PyInstaller`.

---

## Using in CI/CD

### GitHub Actions example

```yaml
jobs:
  build-windows-exe:
    runs-on: ubuntu-latest   # or: runs-on: [self-hosted, arm64]
    steps:
      - uses: actions/checkout@v4

      # Required on ARM64 runners to enable i386 emulation for Wine
      - uses: docker/setup-qemu-action@v3

      - name: Build Windows x86 executable
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/src" \
            ghcr.io/kilianSen/docker-pyinstaller-win-x86 \
            --onefile --name myapp src/main.py
```

### ARM64 bare-metal hosts

On ARM64 Linux machines that are **not** using `docker/setup-qemu-action`,
register the QEMU binfmt interpreters once before running the container:

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

---

## Build arguments

| Argument             | Default   | Description                           |
|----------------------|-----------|---------------------------------------|
| `PYTHON_VERSION`     | `3.11.9`  | 32-bit Windows Python version to use  |
| `PYINSTALLER_VERSION`| `6.5.0`   | PyInstaller version to install        |

Build a custom image:

```bash
docker build \
  --build-arg PYTHON_VERSION=3.12.3 \
  --build-arg PYINSTALLER_VERSION=6.6.0 \
  -t my-pyinstaller .
```

---

## Supported platforms

| Platform       | Wine mode | Notes                                         |
|----------------|-----------|-----------------------------------------------|
| `linux/amd64`  | wine32    | Runs x86 code natively; no QEMU needed        |
| `linux/arm64`  | wine32 via QEMU | i386 binfmt must be registered on the host |

---

## How it works

1. **Wine** provides the Windows API layer so Windows executables can run on Linux.
2. **Python for Windows (32-bit)** is installed *inside* Wine, giving PyInstaller
   a genuine Windows Python environment.
3. **PyInstaller** is invoked via `wine python -m PyInstaller`, which produces a
   self-contained Windows x86 `.exe` in the `dist/` folder.
4. On **ARM64** hosts, **QEMU** (via `binfmt_misc`) transparently emulates the
   i386 instructions that Wine's 32-bit layer requires.

---

## Pre-built image

Pre-built multi-arch images are published automatically to the
[GitHub Container Registry](https://github.com/KilianSen/docker-pyinstaller-win-x86/pkgs/container/docker-pyinstaller-win-x86):

```
ghcr.io/kilianSen/docker-pyinstaller-win-x86:latest   # latest main-branch build
ghcr.io/kilianSen/docker-pyinstaller-win-x86:v1.0.0   # specific release tag
```

---

## License

[MIT](LICENSE)
