#!/usr/bin/env bash
set -euo pipefail

# Model management for GhostDrive
# NOTE: "pull" requires an internet connection.
#       "list", "remove", and "info" work offline.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
if [ -t 1 ]; then
    GREEN='\033[0;32m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'
    YELLOW='\033[1;33m'; BOLD='\033[1m'; WHITE='\033[1;37m'
    DIM='\033[2m'; NC='\033[0m'; RED='\033[0;31m'
else
    GREEN=''; BLUE=''; CYAN=''; YELLOW=''; BOLD=''; WHITE=''; DIM=''; NC=''; RED=''
fi

# Detect OS and set binary path
OS="$(uname -s)"
case "${OS}" in
    Linux*)  OLLAMA_BIN="${SCRIPT_DIR}/engine/linux-amd64/bin/ollama" ;;
    Darwin*) OLLAMA_BIN="${SCRIPT_DIR}/engine/darwin/Ollama.app/Contents/Resources/ollama" ;;
    *)       echo "Unsupported system: ${OS}"; exit 1 ;;
esac

chmod +x "${OLLAMA_BIN}" 2>/dev/null || true

# Parse config safely (don't source — USB stick could have been tampered with)
OLLAMA_PORT=11435
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    while IFS='=' read -r key value; do
        [ -z "${value}" ] && continue
        value="${value%%#*}"
        value="${value%% }"
        value="${value%%	}"
        case "${key}" in
            OLLAMA_PORT) OLLAMA_PORT="${value}" ;;
        esac
    done < <(grep -v '^\s*#' "${SCRIPT_DIR}/config.env" 2>/dev/null || true)
fi

export OLLAMA_MODELS="${SCRIPT_DIR}/models"
export OLLAMA_HOST="127.0.0.1:${OLLAMA_PORT}"

case "${OS}" in
    Linux*) export OLLAMA_RUNNERS_DIR="${SCRIPT_DIR}/engine/linux-amd64/lib" ;;
esac

# Check if Ollama is already running
ollama_running() {
    "${OLLAMA_BIN}" list &>/dev/null
}

# Start a temporary Ollama instance if needed
TEMP_OLLAMA=false
TEMP_PID=""
ensure_ollama() {
    if ! ollama_running; then
        echo -e "  ${DIM}Starting AI engine...${NC}"
        mkdir -p "${SCRIPT_DIR}/logs" 2>/dev/null || true
        "${OLLAMA_BIN}" serve >> "${SCRIPT_DIR}/logs/ollama-models.log" 2>&1 &
        TEMP_PID=$!
        TEMP_OLLAMA=true
        # Poll up to 15 seconds for engine to start
        for (( _i=1; _i<=15; _i++ )); do
            if ollama_running; then
                break
            fi
            if ! kill -0 "${TEMP_PID}" 2>/dev/null; then
                echo -e "  ${RED}✗${NC} AI engine crashed during startup. Check logs/ollama-models.log"
                exit 1
            fi
            sleep 1
        done
        if ! ollama_running; then
            echo -e "  ${RED}✗${NC} AI engine took too long to start. Check logs/ollama-models.log"
            exit 1
        fi
    fi
}

stop_temp_ollama() {
    if [ "${TEMP_OLLAMA}" = true ] && [ -n "${TEMP_PID:-}" ]; then
        kill "${TEMP_PID}" 2>/dev/null || true
        wait "${TEMP_PID}" 2>/dev/null || true
    fi
}

trap stop_temp_ollama EXIT

# Model descriptions
describe_model() {
    local model="$1"
    case "${model}" in
        gemma3:4b*)      echo "Fast and conversational" ;;
        gemma3:12b*)     echo "Smarter, needs more memory" ;;
        qwen3:8b*)       echo "Strong reasoning and analysis" ;;
        llama3*:8b*)     echo "Great all-around assistant" ;;
        qwen2.5-coder*)  echo "Specialized for programming" ;;
        llava*)          echo "Can understand images and text" ;;
        phi4*)           echo "Deep reasoning (needs 32GB RAM)" ;;
        deepseek-r1*)    echo "Step-by-step problem solver" ;;
        nomic-embed*)    echo "Text embeddings (advanced)" ;;
        *)               echo "" ;;
    esac
}

case "${1:-help}" in
    list|ls)
        ensure_ollama
        echo ""
        echo -e "  ${WHITE}${BOLD}Models on Your GhostDrive${NC}"
        echo ""

        local_data=$("${OLLAMA_BIN}" list 2>/dev/null | tail -n +2)
        if [ -n "${local_data}" ]; then
            while IFS= read -r line; do
                model_name=$(echo "${line}" | awk '{print $1}')
                model_size=$(echo "${line}" | grep -oE '[0-9.]+ [KMGT]B' | head -1)
                [ -z "${model_size}" ] && model_size="unknown"
                desc=$(describe_model "${model_name}")

                echo -e "    ${BLUE}○${NC} ${BOLD}${model_name}${NC}  ${DIM}(${model_size})${NC}"
                if [ -n "${desc}" ]; then
                    echo -e "      ${DIM}${desc}${NC}"
                fi
            done <<< "${local_data}"
        else
            echo -e "    ${YELLOW}No models installed yet.${NC}"
        fi
        echo ""
        du -sh "${SCRIPT_DIR}/models" 2>/dev/null | awk -v b="${BOLD}" -v d="${DIM}" -v nc="${NC}" '{print "  " b "Total space used:" nc " " $1}'
        echo ""
        ;;

    pull|add)
        if [ -z "${2:-}" ]; then
            echo ""
            echo -e "  ${WHITE}${BOLD}Download a New Model${NC}"
            echo ""
            echo -e "  Usage: ${CYAN}bash models.sh pull <model_name>${NC}"
            echo ""
            echo -e "  ${BOLD}Popular models:${NC}"
            echo ""
            echo -e "    ${CYAN}gemma3:4b${NC}            Fast, great for chat       ${DIM}(needs 8GB RAM)${NC}"
            echo -e "    ${CYAN}gemma3:12b${NC}           Smarter, more capable      ${DIM}(needs 16GB RAM)${NC}"
            echo -e "    ${CYAN}qwen3:8b${NC}             Strong reasoning           ${DIM}(needs 16GB RAM)${NC}"
            echo -e "    ${CYAN}llama3.1:8b${NC}          Great all-rounder          ${DIM}(needs 16GB RAM)${NC}"
            echo -e "    ${CYAN}qwen2.5-coder:7b${NC}     Code generation            ${DIM}(needs 16GB RAM)${NC}"
            echo -e "    ${CYAN}llava:7b${NC}             Vision + text              ${DIM}(needs 16GB RAM)${NC}"
            echo -e "    ${CYAN}phi4:14b${NC}             Deep reasoning             ${DIM}(needs 32GB RAM)${NC}"
            echo -e "    ${CYAN}deepseek-r1:8b${NC}       Step-by-step thinking      ${DIM}(needs 16GB RAM)${NC}"
            echo ""
            exit 1
        fi
        echo ""
        echo -e "  ${YELLOW}⚠${NC}  Downloading a model requires an internet connection."
        echo -e "     The model will be saved to this USB drive."
        echo ""
        ensure_ollama
        "${OLLAMA_BIN}" pull "$2"
        echo ""
        # Verify model actually downloaded (ollama pull can exit 0 on some failures)
        if "${OLLAMA_BIN}" show "$2" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} ${BOLD}$2${NC} is now available on your GhostDrive — no internet needed to use it."
        else
            echo -e "  ${RED}✗${NC} Download may have failed. Run ${CYAN}bash models.sh list${NC} to check."
        fi
        echo ""
        ;;

    remove|rm|delete)
        if [ -z "${2:-}" ]; then
            echo ""
            echo -e "  Usage: ${CYAN}bash models.sh remove <model_name>${NC}"
            echo ""
            echo -e "  Your current models:"
            ensure_ollama
            "${OLLAMA_BIN}" list
            echo ""
            exit 1
        fi
        ensure_ollama
        "${OLLAMA_BIN}" rm "$2"
        echo -e "  ${GREEN}✓${NC} ${BOLD}$2${NC} has been removed from your GhostDrive."
        ;;

    info|show)
        if [ -z "${2:-}" ]; then
            echo -e "  Usage: ${CYAN}bash models.sh info <model_name>${NC}"
            exit 1
        fi
        ensure_ollama
        "${OLLAMA_BIN}" show "$2"
        ;;

    *)
        echo ""
        echo -e "  ${WHITE}${BOLD}GhostDrive Model Manager${NC}"
        echo ""
        echo -e "  Manage the AI models on your GhostDrive."
        echo ""
        echo -e "  ${BOLD}Commands:${NC}"
        echo ""
        echo -e "    ${CYAN}bash models.sh list${NC}              See your installed models"
        echo -e "    ${CYAN}bash models.sh pull <model>${NC}      Download a new model (needs internet)"
        echo -e "    ${CYAN}bash models.sh remove <model>${NC}    Remove a model from the drive"
        echo -e "    ${CYAN}bash models.sh info <model>${NC}      Show details about a model"
        echo ""
        ;;
esac
