#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${SCRIPT_DIR}/logs/ghostdrive.pid"

if [ -f "${PID_FILE}" ]; then
    pid=$(cat "${PID_FILE}" 2>/dev/null)
    if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}" 2>/dev/null
        echo "GhostDrive stopped (PID: ${pid})."
    else
        echo "GhostDrive was not running (stale PID file)."
    fi
    rm -f "${PID_FILE}"
else
    echo "No GhostDrive instance found."
fi
