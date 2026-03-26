#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${SCRIPT_DIR}/logs/ghostdrive.pid"

if [ -f "${PID_FILE}" ]; then
    pid=$(cat "${PID_FILE}" 2>/dev/null)
    if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
        # Kill process group (catches child runners and grandchildren)
        kill -- -"${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
        # Wait for graceful shutdown
        i=0
        while [ ${i} -lt 10 ] && kill -0 "${pid}" 2>/dev/null; do
            sleep 1
            i=$((i + 1))
        done
        # Force kill if still alive
        if kill -0 "${pid}" 2>/dev/null; then
            kill -9 "${pid}" 2>/dev/null || true
        fi
        # Catch any orphaned runners reparented to init
        pkill -f "ollama.*runner" 2>/dev/null || true
        echo "GhostDrive stopped (PID: ${pid})."
    else
        echo "GhostDrive was not running (stale PID file)."
    fi
    rm -f "${PID_FILE}"
else
    echo "No GhostDrive instance found."
fi
