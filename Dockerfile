FROM ubuntu:22.04

LABEL maintainer="QoderWake Coolify Deployment"
LABEL description="QoderWake - AI Digital Employee Platform"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    sudo \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for QoderWake
RUN useradd -m -s /bin/bash qoderwake && \
    echo "qoderwake ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to the qoderwake user
USER qoderwake
WORKDIR /home/qoderwake

# Install QoderWake via the official install script
RUN curl -fsSL https://qoder-ide.oss-ap-southeast-1.aliyuncs.com/qoderwake/install.sh | bash

# Add QoderWake to PATH
ENV PATH="/home/qoderwake/.qoderwake/bin:${PATH}"

# Expose the default QoderWake web console port
EXPOSE 19820

# Copy entrypoint script
COPY --chown=qoderwake:qoderwake entrypoint.sh /home/qoderwake/entrypoint.sh
RUN chmod +x /home/qoderwake/entrypoint.sh

# Health check to verify the service is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:19820/ || exit 1

ENTRYPOINT ["/home/qoderwake/entrypoint.sh"]
