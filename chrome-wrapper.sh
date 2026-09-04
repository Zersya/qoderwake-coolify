#!/bin/bash
# chrome-wrapper.sh — wraps google-chrome with container-safe flags.
# MCP servers (Puppeteer-based, CDP-based) call this instead of the raw
# binary. The flags below are required because Docker containers lack:
#   - User namespaces → --no-sandbox --disable-setuid-sandbox
#   - GPU              → --disable-gpu
#   - Large /dev/shm   → --disable-dev-shm-usage (writes to /tmp instead)
exec /usr/bin/google-chrome \
    --no-sandbox \
    --disable-setuid-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    "$@"
