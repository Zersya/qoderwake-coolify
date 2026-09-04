#!/bin/bash
set -euo pipefail

# download-binaries.sh — runs during Docker build to fetch QoderWake + QoderCLI

MANIFEST_URL="https://download.qoder.com/qoderwake/channels/manifest.json"
INSTALL_DIR="$HOME/.qoderwake"

mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/qodercli" "$INSTALL_DIR/.tmp"

echo "==> Fetching QoderWake manifest..."
MANIFEST="$(curl -fsSL "$MANIFEST_URL")"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) TARGET_ARCH="amd64" ;;
  aarch64|arm64) TARGET_ARCH="arm64" ;;
  *) echo "Unsupported arch: $ARCH" && exit 1 ;;
esac

echo "==> Target platform: linux/$TARGET_ARCH"

# Parse manifest with python3
QW_URL="$(echo "$MANIFEST" | python3 -c "import json,sys;m=json.load(sys.stdin);[print(f['url']) for f in m['files'] if f['os']=='linux' and f['arch']=='$TARGET_ARCH']")"
QW_SHA="$(echo "$MANIFEST" | python3 -c "import json,sys;m=json.load(sys.stdin);[print(f['sha256']) for f in m['files'] if f['os']=='linux' and f['arch']=='$TARGET_ARCH']")"
CLI_URL="$(echo "$MANIFEST" | python3 -c "import json,sys;m=json.load(sys.stdin);[print(f['url']) for f in m['qodercli']['files'] if f['os']=='linux' and f['arch']=='$TARGET_ARCH']")"
CLI_SHA="$(echo "$MANIFEST" | python3 -c "import json,sys;m=json.load(sys.stdin);[print(f['sha256']) for f in m['qodercli']['files'] if f['os']=='linux' and f['arch']=='$TARGET_ARCH']")"

echo "==> Downloading QoderWake: $QW_URL"
curl -fsSL "$QW_URL" -o /tmp/qoderwake.tar.gz
echo "$QW_SHA  /tmp/qoderwake.tar.gz" | sha256sum -c -
tar -xzf /tmp/qoderwake.tar.gz -C "$INSTALL_DIR/"
rm /tmp/qoderwake.tar.gz

echo "==> Downloading QoderCLI: $CLI_URL"
curl -fsSL "$CLI_URL" -o /tmp/qodercli.tar.gz
echo "$CLI_SHA  /tmp/qodercli.tar.gz" | sha256sum -c -
tar -xzf /tmp/qodercli.tar.gz -C "$INSTALL_DIR/qodercli/"
rm /tmp/qodercli.tar.gz

# Make binaries executable
chmod +x "$INSTALL_DIR/qoderwake"
find "$INSTALL_DIR/qodercli/" -type f -name 'qodercli*' -exec chmod +x {} +

# Create symlinks in bin/
ln -sf "$INSTALL_DIR/qoderwake" "$INSTALL_DIR/bin/qoderwake"
CLI_BIN="$(find "$INSTALL_DIR/qodercli/" -type f -name 'qodercli*' | head -1)"
if [ -n "$CLI_BIN" ]; then
  ln -sf "$CLI_BIN" "$INSTALL_DIR/bin/qodercli-wake"
fi

echo "==> Verifying installation..."
"$INSTALL_DIR/qoderwake" --version

echo "==> QoderWake installed successfully!"
