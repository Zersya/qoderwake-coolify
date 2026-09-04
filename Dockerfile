FROM ubuntu:22.04

LABEL maintainer="QoderWake Coolify Deployment"
LABEL description="QoderWake - AI Digital Employee Platform"

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    procps \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -s /bin/bash qoderwake

USER qoderwake
WORKDIR /home/qoderwake

# Set up directory structure matching the official installer layout
RUN mkdir -p \
    /home/qoderwake/.qoderwake/bin \
    /home/qoderwake/.qoderwake/qodercli \
    /home/qoderwake/.qoderwake/.tmp \
    /home/qoderwake/.local/bin

# ── Download & install QoderWake binary ──────────────────────────────
# Fetches the manifest at build time, picks the right linux archive,
# verifies the sha256, and extracts the binary.
RUN set -eux; \
    MANIFEST_URL="https://download.qoder.com/qoderwake/channels/manifest.json"; \
    MANIFEST="$(curl -fsSL "$MANIFEST_URL")"; \
    \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
      x86_64|amd64) TARGET_ARCH="amd64" ;; \
      aarch64|arm64) TARGET_ARCH="arm64" ;; \
      *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac; \
    \
    # Extract QoderWake download URL and sha256 for linux/$TARGET_ARCH
    QW_URL="$(echo "$MANIFEST" | python3 -c "
import json, sys
m = json.load(sys.stdin)
arch = '$TARGET_ARCH'
for f in m['files']:
    if f['os'] == 'linux' and f['arch'] == arch:
        print(f['url']); break
else:
    sys.exit(1)
")"; \
    QW_SHA="$(echo "$MANIFEST" | python3 -c "
import json, sys
m = json.load(sys.stdin)
arch = '$TARGET_ARCH'
for f in m['files']:
    if f['os'] == 'linux' and f['arch'] == arch:
        print(f['sha256']); break
else:
    sys.exit(1)
")"; \
    \
    # Extract QoderCLI download URL and sha256 for linux/$TARGET_ARCH
    CLI_URL="$(echo "$MANIFEST" | python3 -c "
import json, sys
m = json.load(sys.stdin)
arch = '$TARGET_ARCH'
for f in m['qodercli']['files']:
    if f['os'] == 'linux' and f['arch'] == arch:
        print(f['url']); break
else:
    sys.exit(1)
")"; \
    CLI_SHA="$(echo "$MANIFEST" | python3 -c "
import json, sys
m = json.load(sys.stdin)
arch = '$TARGET_ARCH'
for f in m['qodercli']['files']:
    if f['os'] == 'linux' and f['arch'] == arch:
        print(f['sha256']); break
else:
    sys.exit(1)
")"; \
    \
    echo "==> Downloading QoderWake ($TARGET_ARCH): $QW_URL"; \
    curl -fsSL "$QW_URL" -o /tmp/qoderwake.tar.gz; \
    echo "$QW_SHA  /tmp/qoderwake.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/qoderwake.tar.gz -C /home/qoderwake/.qoderwake/; \
    rm /tmp/qoderwake.tar.gz; \
    \
    echo "==> Downloading QoderCLI ($TARGET_ARCH): $CLI_URL"; \
    curl -fsSL "$CLI_URL" -o /tmp/qodercli.tar.gz; \
    echo "$CLI_SHA  /tmp/qodercli.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/qodercli.tar.gz -C /home/qoderwake/.qoderwake/qodercli/; \
    rm /tmp/qodercli.tar.gz; \
    \
    # Make binaries executable
    chmod +x /home/qoderwake/.qoderwake/qoderwake; \
    find /home/qoderwake/.qoderwake/qodercli/ -type f -name 'qodercli*' -exec chmod +x {} +; \
    \
    # Create symlinks in bin/ (matching what the official installer does)
    ln -sf /home/qoderwake/.qoderwake/qoderwake /home/qoderwake/.qoderwake/bin/qoderwake; \
    CLI_BIN="$(find /home/qoderwake/.qoderwake/qodercli/ -type f -name 'qodercli*' | head -1)"; \
    if [ -n "$CLI_BIN" ]; then \
      ln -sf "$CLI_BIN" /home/qoderwake/.qoderwake/bin/qodercli-wake; \
    fi; \
    \
    echo "==> QoderWake installed successfully"

# Verify the binaries work
RUN /home/qoderwake/.qoderwake/qoderwake --version

# Add to PATH
ENV PATH="/home/qoderwake/.qoderwake/bin:/home/qoderwake/.qoderwake:${PATH}"

# Expose the default web console port
EXPOSE 19820

# Copy entrypoint script
COPY --chown=qoderwake:qoderwake entrypoint.sh /home/qoderwake/entrypoint.sh
RUN chmod +x /home/qoderwake/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:19820/ || exit 1

ENTRYPOINT ["/home/qoderwake/entrypoint.sh"]
