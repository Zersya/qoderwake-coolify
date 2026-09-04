FROM ubuntu:22.04

LABEL maintainer="QoderWake Coolify Deployment"
LABEL description="QoderWake - AI Digital Employee Platform"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies (python3 is required by QoderWake internals)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    sudo \
    procps \
    python3 \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for QoderWake
RUN useradd -m -s /bin/bash qoderwake && \
    echo "qoderwake ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to the qoderwake user
USER qoderwake
WORKDIR /home/qoderwake

# Create the .local/bin directory so it's in PATH for symlinks
RUN mkdir -p /home/qoderwake/.local/bin /home/qoderwake/.qoderwake/bin

# Download and install QoderWake binaries WITHOUT running login or starting the daemon.
# The install script requires python3 and tries to login+start at the end,
# so we run it with --login-method PAT and provide a dummy token to skip browser auth,
# but capture the binary installation part only.
#
# Strategy: download the install script, patch out the login/start/browser-open at the end,
# then run it to get the binaries installed.
RUN curl -fsSL https://qoder-ide.oss-ap-southeast-1.aliyuncs.com/qoderwake/install.sh -o /tmp/install.sh && \
    # Patch the main() function: replace login + start + open browser with just "log done" 
    sed -i 's/case "$login_method" in/log "Skipping login and daemon start during Docker build"; if false; then case "$login_method" in/' /tmp/install.sh && \
    sed -i 's/^  main "$@"$/  main "--login-method" "PAT"/' /tmp/install.sh && \
    # Provide a dummy PAT so resolve_pat() doesn't die — we won't actually use it since login is patched out
    QODER_PERSONAL_ACCESS_TOKEN="docker-build-placeholder" bash /tmp/install.sh || true && \
    rm -f /tmp/install.sh

# Verify the binary exists (fail the build if installation actually failed)
RUN test -f /home/qoderwake/.qoderwake/qoderwake && \
    /home/qoderwake/.qoderwake/qoderwake --version

# Add QoderWake to PATH
ENV PATH="/home/qoderwake/.qoderwake/bin:/home/qoderwake/.local/bin:/home/qoderwake/.qoderwake:${PATH}"

# Expose the default QoderWake web console port
EXPOSE 19820

# Copy entrypoint script
COPY --chown=qoderwake:qoderwake entrypoint.sh /home/qoderwake/entrypoint.sh
RUN chmod +x /home/qoderwake/entrypoint.sh

# Health check to verify the service is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:19820/ || exit 1

ENTRYPOINT ["/home/qoderwake/entrypoint.sh"]
