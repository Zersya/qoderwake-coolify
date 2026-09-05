#!/bin/bash
set -euo pipefail
# setup-browser-extension.sh — prepare the QoderWake Chrome extension for
# download and print instructions for loading it in the user's local browser.
#
# The extension lives inside the Docker image (bundled at build time).
# This script packages it into a zip and copies it to a well-known path
# so the user can retrieve it with `docker cp` or download it directly.

EXTENSION_SRC="$HOME/.qoderwake/data/browser-connector/chrome-extension"
OUTPUT_DIR="$HOME/.qoderwake/browser-extension-download"
OUTPUT_ZIP="$OUTPUT_DIR/qoderwork-chrome-extension.zip"

if [ ! -d "$EXTENSION_SRC" ]; then
    echo "[ERROR] Extension source directory not found: $EXTENSION_SRC"
    echo "[ERROR] The Chrome extension was not bundled during image build."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Package the extension directory into a zip for easy download
if command -v zip >/dev/null 2>&1; then
    rm -f "$OUTPUT_ZIP"
    (cd "$EXTENSION_SRC" && zip -r "$OUTPUT_ZIP" .) >/dev/null
    echo "[OK] Extension packaged: $OUTPUT_ZIP"
else
    # Fall back to a tar.gz if zip is not available
    OUTPUT_TGZ="$OUTPUT_DIR/qoderwork-chrome-extension.tar.gz"
    tar -czf "$OUTPUT_TGZ" -C "$EXTENSION_SRC" .
    echo "[OK] Extension packaged: $OUTPUT_TGZ"
fi

# Also copy the raw extension directory for "load unpacked" use
cp -r "$EXTENSION_SRC" "$OUTPUT_DIR/chrome-extension"
echo "[OK] Extension directory: $OUTPUT_DIR/chrome-extension"

# Detect the WebSocket URL the extension needs
RELAY_PORT="${BROWSER_RELAY_PORT:-16789}"
QODERWAKE_HOST="${QODERWAKE_HOST:-localhost}"
if [ "$QODERWAKE_HOST" = "0.0.0.0" ]; then
    QODERWAKE_HOST="localhost"
fi
WS_URL="ws://${QODERWAKE_HOST}:${RELAY_PORT}/extension/v2"

echo ""
echo "========================================"
echo "  QoderWake Browser Extension Setup"
echo "========================================"
echo ""
echo "Step 1: Copy the extension to your local machine"
echo ""
echo "  docker cp <container-name>:$OUTPUT_DIR/chrome-extension ./chrome-extension"
echo ""
echo "  — or — download the zip:"
echo ""
echo "  docker cp <container-name>:$OUTPUT_ZIP ./qoderwork-chrome-extension.zip"
echo "  unzip qoderwork-chrome-extension.zip -d chrome-extension"
echo ""
echo "Step 2: Load the extension in Chrome"
echo ""
echo "  1. Open chrome://extensions/ in your Chrome browser"
echo "  2. Enable 'Developer mode' (toggle in the top-right corner)"
echo "  3. Click 'Load unpacked'"
echo "  4. Select the 'chrome-extension' directory you copied"
echo ""
echo "Step 3: Connect the extension to QoderWake"
echo ""
echo "  WebSocket URL: $WS_URL"
echo ""
echo "  Open the extension popup (click the extension icon in Chrome)"
echo "  and enter the WebSocket URL above, or configure it in the"
echo "  extension options page."
echo ""
echo "Step 4: Enable the browser connector in QoderWake Console"
echo ""
echo "  Go to Settings → Connectors → 'Connect to Browser' → toggle ON"
echo ""
echo "========================================"
