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
    unzip \
    zip \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome Stable for Chrome DevTools MCP support
# (direct .deb download — no apt repo management needed)
RUN curl -fsSL -o /tmp/google-chrome.deb \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update \
    && apt-get install -y /tmp/google-chrome.deb fonts-liberation fonts-dejavu-core \
    && rm /tmp/google-chrome.deb \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS (for npx-based MCP servers like chrome-devtools-mcp).
# Uses official binary tarball — no third-party apt repos needed.
ARG NODE_VERSION=20.18.3
RUN ARCH="$(dpkg --print-architecture | sed 's/amd64/x64/;s/arm64/arm64/')" \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" \
         -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && node --version && npm --version && npx --version

# Install chrome-wrapper that injects container-safe flags (--no-sandbox etc.)
COPY chrome-wrapper.sh /usr/local/bin/chrome-wrapper
RUN chmod +x /usr/local/bin/chrome-wrapper

# Tell MCP servers where to find Chrome and don't download a bundled one
ENV CHROME_BIN=/usr/local/bin/chrome-wrapper
ENV CHROME_PATH=/usr/local/bin/chrome-wrapper
ENV PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/chrome-wrapper
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Install fake systemctl shim (containers have no systemd, but QoderWake
# calls systemctl to register a user service unit during daemon startup)
COPY fake-systemctl.sh /usr/local/bin/systemctl

# Create a non-root user
RUN useradd -m -s /bin/bash qoderwake

# Install uv/uvx (Python package runner) for EverMeMOS MCP server
# Copy from official astral-sh image, then symlink to /home/qoderwake/.local/bin/
# which is the path the MCP config expects (visible in daemon PATH)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
RUN mkdir -p /home/qoderwake/.local/bin \
    && ln -sf /usr/local/bin/uv /home/qoderwake/.local/bin/uv \
    && ln -sf /usr/local/bin/uvx /home/qoderwake/.local/bin/uvx \
    && chown -R qoderwake:qoderwake /home/qoderwake/.local

USER qoderwake
WORKDIR /home/qoderwake

# Copy and run the binary download script
COPY --chown=qoderwake:qoderwake download-binaries.sh /tmp/download-binaries.sh
RUN chmod +x /tmp/download-binaries.sh && bash /tmp/download-binaries.sh && rm /tmp/download-binaries.sh

# EverMeMOS stdio launcher: seeds fresh qoderwake_data volumes (which overlay
# ~/.qoderwake). entrypoint.sh writes the credentials file this script reads.
COPY --chown=qoderwake:qoderwake evermemos-launch.sh /home/qoderwake/.qoderwake/bin/evermemos-launch.sh
RUN chmod +x /home/qoderwake/.qoderwake/bin/evermemos-launch.sh

# Download the Chrome browser extension for the "Connect to Browser" feature.
# The extension lets QoderWake control the user's local Chrome via CDP.
# It is bundled in the image so setup-browser-extension.sh can prepare a
# downloadable zip without needing internet at runtime.
RUN EXTENSION_DIR="/home/qoderwake/.qoderwake/data/browser-connector/chrome-extension" \
    && mkdir -p "$EXTENSION_DIR" \
    && curl -fsSL -o /tmp/chrome-extension.zip \
         "https://download.qoder.com/qoder-work/bin/browser-connector/chrome-extension/1.5.0/qoderwork-chrome-extension-v1.5.0.zip" \
    && unzip -o /tmp/chrome-extension.zip -d "$EXTENSION_DIR" \
    && rm /tmp/chrome-extension.zip

# Browser extension setup helper — copies the extension to a downloadable
# location and prints instructions for loading it in the user's local Chrome.
COPY --chown=qoderwake:qoderwake setup-browser-extension.sh /home/qoderwake/.qoderwake/bin/setup-browser-extension.sh
RUN chmod +x /home/qoderwake/.qoderwake/bin/setup-browser-extension.sh

# Add to PATH
ENV PATH="/home/qoderwake/.qoderwake/bin:/home/qoderwake/.qoderwake:${PATH}"

# Expose the default web console port and browser connector relay port
EXPOSE 19820
EXPOSE 16789

# Copy entrypoint script
COPY --chown=qoderwake:qoderwake entrypoint.sh /home/qoderwake/entrypoint.sh
RUN chmod +x /home/qoderwake/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -s -o /dev/null -w "%{http_code}" http://localhost:19820/ | grep -qE '^[0-9]{3}$' || exit 1

ENTRYPOINT ["/home/qoderwake/entrypoint.sh"]
