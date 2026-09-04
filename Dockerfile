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

# Install fake systemctl shim (containers have no systemd, but QoderWake
# calls systemctl to register a user service unit during daemon startup)
COPY fake-systemctl.sh /usr/local/bin/systemctl
RUN chmod +x /usr/local/bin/systemctl

# Create a non-root user
RUN useradd -m -s /bin/bash qoderwake

USER qoderwake
WORKDIR /home/qoderwake

# Copy and run the binary download script
COPY --chown=qoderwake:qoderwake download-binaries.sh /tmp/download-binaries.sh
RUN chmod +x /tmp/download-binaries.sh && bash /tmp/download-binaries.sh && rm /tmp/download-binaries.sh

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
