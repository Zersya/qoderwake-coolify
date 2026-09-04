#!/bin/bash
# fake-systemctl.sh — stub systemctl for containers without systemd.
# QoderWake calls systemctl to register/manage a user service unit.
# In Docker there is no systemd; the daemon runs as a direct process,
# so we only need systemctl to exit 0 and report "active".

# Strip --user and other global flags to find the subcommand
cmd=""
for arg in "$@"; do
    case "$arg" in
        --*) continue ;;   # skip flags like --user
        -*) continue ;;    # skip short flags
        *) cmd="$arg"; break ;;
    esac
done

case "$cmd" in
    daemon-reload|enable|disable|start|stop|restart|reset-failed)
        exit 0
        ;;
    is-active)
        echo "active"
        exit 0
        ;;
    is-enabled)
        echo "enabled"
        exit 0
        ;;
    status)
        echo "Active: active (running)"
        exit 0
        ;;
    "")
        exit 0
        ;;
    *)
        # Unknown subcommand — succeed to avoid breaking startup
        exit 0
        ;;
esac
