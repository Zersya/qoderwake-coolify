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

# Install Google Chrome Stable for Chrome DevTools MCP support
# (direct .deb download — no apt repo management needed)
RUN curl -fsSL -o /tmp/google-chrome.deb \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update \
    && apt-get install -y /tmp/google-chrome.deb fonts-liberation fonts-dejavu-core \
    && rm /tmp/google-chrome.deb \
    && rm -rf /var/lib/apt/lists/*

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

# Add to PATH
ENV PATH="/home/qoderwake/.qoderwake/bin:/home/qoderwake/.qoderwake:${PATH}"

# Expose the default web console port
EXPOSE 19820

# Copy entrypoint script
COPY --chown=qoderwake:qoderwake entrypoint.sh /home/qoderwake/entrypoint.sh
RUN chmod +x /home/qoderwake/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -s -o /dev/null -w "%{http_code}" http://localhost:19820/ | grep -qE '^[0-9]{3}$' || exit 1

ENTRYPOINT ["/home/qoderwake/entrypoint.sh"]
