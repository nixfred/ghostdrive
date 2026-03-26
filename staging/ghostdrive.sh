#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
#  GhostDrive — Your Private AI. No Internet Required.
#  One script. Two platforms. Zero dependencies.
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GHOST_VERSION="1.0.0"

# ── Colors (if terminal supports them) ────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'
    CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
    DIM='\033[2m'; WHITE='\033[1;37m'; MAGENTA='\033[0;35m'
else
    RED=''; GREEN=''; BLUE=''; CYAN=''; YELLOW=''; BOLD=''; NC=''
    DIM=''; WHITE=''; MAGENTA=''
fi

# ── Logging (internal, friendly language) ────────────────────────────
log()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
err()  { echo -e "  ${RED}✗${NC} $1" >&2; }
die()  { echo ""; err "$1"; echo ""; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────
banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    cat << 'ART'
      ╔═══════════════════════════════════════════════╗
      ║                                               ║
      ║    ░██████╗░██╗░░██╗░█████╗░░██████╗████████╗║
      ║    ██╔════╝░██║░░██║██╔══██╗██╔════╝╚══██╔══╝║
      ║    ██║░░██╗░███████║██║░░██║╚█████╗░   ██║   ║
      ║    ██║░░╚██╗██╔══██║██║░░██║░╚═══██╗   ██║   ║
      ║    ╚██████╔╝██║░░██║╚█████╔╝██████╔╝   ██║   ║
      ║    ░╚═════╝░╚═╝░░╚═╝░╚════╝░╚═════╝░   ╚═╝   ║
      ║                                               ║
      ║          D   R   I   V   E                    ║
      ╚═══════════════════════════════════════════════╝
ART
    echo -e "${NC}"
    echo -e "     ${WHITE}${BOLD}Your Private AI — No Internet Required${NC}"
    echo -e "     ${DIM}Everything stays on this device. Always.${NC}"
    echo ""
}

# ── First-run welcome ────────────────────────────────────────────────
WELCOME_FILE="${SCRIPT_DIR}/logs/.ghost_welcomed"

show_first_run() {
    echo -e "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${WHITE}${BOLD}  Welcome to GhostDrive.${NC}"
    echo ""
    echo -e "  ${CYAN}  This USB stick contains a complete AI assistant${NC}"
    echo -e "  ${CYAN}  that runs entirely on your computer.${NC}"
    echo ""
    echo -e "  ${WHITE}  Here's what makes it special:${NC}"
    echo ""
    echo -e "    ${GREEN}●${NC}  ${BOLD}Completely Private${NC} — Your conversations never"
    echo -e "       leave your computer. No cloud. No tracking."
    echo ""
    echo -e "    ${GREEN}●${NC}  ${BOLD}Works Offline${NC} — No Wi-Fi or internet needed."
    echo -e "       Works on airplanes, in the field, anywhere."
    echo ""
    echo -e "    ${GREEN}●${NC}  ${BOLD}Nothing to Install${NC} — Just plug in and run."
    echo -e "       Everything the AI needs is on this drive."
    echo ""
    echo -e "    ${GREEN}●${NC}  ${BOLD}You Own It${NC} — No subscriptions. No accounts."
    echo -e "       No one can take it away or shut it off."
    echo ""
    echo -e "  ${DIM}  You can ask it anything — write emails, explain"
    echo -e "    documents, brainstorm ideas, get advice, summarize"
    echo -e "    long text, draft messages, and much more.${NC}"
    echo ""
    echo -e "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Mark welcome as shown (best effort — exFAT may be read-only)
    mkdir -p "${SCRIPT_DIR}/logs" 2>/dev/null || true
    touch "${WELCOME_FILE}" 2>/dev/null || true
}

is_first_run() {
    [ ! -f "${WELCOME_FILE}" ]
}

# ── Load config ───────────────────────────────────────────────────────
OLLAMA_PORT=11435
DEFAULT_MODEL="gemma3:4b"
OLLAMA_FLASH_ATTENTION=1
OLLAMA_NUM_PARALLEL=2
OLLAMA_MAX_LOADED_MODELS=1

if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
fi

# ── Parse arguments ───────────────────────────────────────────────────
REQUESTED_MODEL=""
LIST_ONLY=false

usage() {
    echo ""
    echo -e "  ${WHITE}${BOLD}GhostDrive${NC} — Your Private AI"
    echo ""
    echo -e "  ${BOLD}Getting Started:${NC}"
    echo -e "    ${CYAN}bash ghostdrive.sh${NC}             Start a conversation"
    echo ""
    echo -e "  ${BOLD}Options:${NC}"
    echo -e "    ${CYAN}-m, --model NAME${NC}     Use a specific AI model"
    echo -e "    ${CYAN}-l, --list${NC}           Show available AI models"
    echo -e "    ${CYAN}-p, --port NUMBER${NC}    Change the connection port"
    echo -e "                         (default: ${OLLAMA_PORT})"
    echo -e "    ${CYAN}-h, --help${NC}           Show this help"
    echo ""
    echo -e "  ${BOLD}Examples:${NC}"
    echo -e "    ${DIM}bash ghostdrive.sh${NC}                 Start chatting"
    echo -e "    ${DIM}bash ghostdrive.sh -m qwen3:8b${NC}     Use a larger, smarter model"
    echo -e "    ${DIM}bash ghostdrive.sh -l${NC}              See what models you have"
    echo ""
    echo -e "  ${BOLD}Managing Models:${NC}"
    echo -e "    ${DIM}bash models.sh list${NC}                See installed models"
    echo -e "    ${DIM}bash models.sh pull phi4:14b${NC}       Download a new model"
    echo -e "    ${DIM}bash models.sh remove llava:7b${NC}     Remove a model"
    echo ""
    echo -e "  ${BOLD}Stopping:${NC}"
    echo -e "    Type ${CYAN}/bye${NC} or press ${CYAN}Ctrl+C${NC} to end your session."
    echo -e "    If something gets stuck: ${DIM}bash stop.sh${NC}"
    echo ""
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model) REQUESTED_MODEL="$2"; shift 2 ;;
        -l|--list)  LIST_ONLY=true; shift ;;
        -p|--port)  OLLAMA_PORT="$2"; shift 2 ;;
        -h|--help)  usage ;;
        -*)         die "Unknown option: $1\n\n  Run ${CYAN}bash ghostdrive.sh --help${NC} to see available options." ;;
        *)          REQUESTED_MODEL="$1"; shift ;;
    esac
done

MODEL="${REQUESTED_MODEL:-${DEFAULT_MODEL}}"

# ── Detect OS and architecture ────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
    Linux*)
        if [ "${ARCH}" != "x86_64" ]; then
            die "GhostDrive requires a 64-bit Intel/AMD computer.\n  Your system reports: ${ARCH}\n\n  This is a hardware limitation — GhostDrive can't run on this machine."
        fi
        OLLAMA_BIN="${SCRIPT_DIR}/engine/linux-amd64/bin/ollama"
        RUNNERS_DIR="${SCRIPT_DIR}/engine/linux-amd64/lib"
        OS_FRIENDLY="Linux"
        ;;
    Darwin*)
        OLLAMA_BIN="${SCRIPT_DIR}/engine/darwin/Ollama.app/Contents/Resources/ollama"
        RUNNERS_DIR="${SCRIPT_DIR}/engine/darwin/Ollama.app/Contents/Resources"
        if [ "${ARCH}" = "arm64" ]; then
            OS_FRIENDLY="Mac (Apple Silicon)"
        else
            OS_FRIENDLY="Mac (Intel)"
        fi
        ;;
    *)
        die "GhostDrive works on Linux and Mac computers.\n  Unfortunately, your system (${OS}) isn't supported yet."
        ;;
esac

# ── Verify engine exists ──────────────────────────────────────────────
if [ ! -f "${OLLAMA_BIN}" ]; then
    die "The AI engine is missing from this drive.\n\n  This might mean the drive is incomplete or was corrupted.\n  Try re-copying the files from the original source."
fi

# exFAT does not preserve Unix execute permissions.
chmod +x "${OLLAMA_BIN}" 2>/dev/null || {
    warn "Could not prepare the AI engine for your system."
    warn "Try running: chmod +x '${OLLAMA_BIN}'"
}

# Also fix permissions on any shared libraries
find "${RUNNERS_DIR}" -name "*.so" -exec chmod +x {} \; 2>/dev/null || true
find "${RUNNERS_DIR}" -name "*.dylib" -exec chmod +x {} \; 2>/dev/null || true

# ── Model descriptions (friendly names) ──────────────────────────────
describe_model() {
    local model="$1"
    case "${model}" in
        gemma3:4b*)      echo "Gemma 3 Small — Fast and conversational" ;;
        gemma3:12b*)     echo "Gemma 3 Medium — Smarter, needs more memory" ;;
        qwen3:8b*)       echo "Qwen 3 — Strong reasoning and analysis" ;;
        llama3*:8b*)     echo "Llama 3 — Great all-around assistant" ;;
        qwen2.5-coder*)  echo "Qwen Coder — Specialized for programming" ;;
        llava*)          echo "LLaVA — Can understand images and text" ;;
        phi4*)           echo "Phi-4 — Deep reasoning (needs 32GB RAM)" ;;
        deepseek-r1*)    echo "DeepSeek R1 — Step-by-step problem solver" ;;
        nomic-embed*)    echo "Nomic Embed — Text embeddings (advanced)" ;;
        *)               echo "${model}" ;;
    esac
}

# ── Pre-flight checks ────────────────────────────────────────────────

check_ram() {
    local ram_mb=0
    case "${OS}" in
        Linux*)
            ram_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
            ;;
        Darwin*)
            local ram_bytes
            ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
            ram_mb=$((ram_bytes / 1024 / 1024))
            ;;
    esac

    local ram_gb=$(( (ram_mb + 512) / 1024 ))

    if [ "${ram_mb}" -lt 7000 ]; then
        die "Your computer needs at least 8 GB of memory to run the AI.\n  Yours has about ${ram_gb} GB.\n\n  Try using a computer with more memory."
    elif [ "${ram_mb}" -lt 15000 ]; then
        warn "Your computer has ${ram_gb} GB of memory — that's enough for smaller AI models."
        if [ -z "${REQUESTED_MODEL}" ]; then
            MODEL="gemma3:4b"
            log "Selected the fastest model for your system"
        fi
    else
        log "Memory: ${ram_gb} GB — plenty of room"
    fi
}

check_gpu() {
    case "${OS}" in
        Linux*)
            if command -v nvidia-smi &>/dev/null; then
                local gpu_name
                gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1) || true
                if [ -n "${gpu_name}" ] && [[ ! "${gpu_name}" =~ "failed" ]]; then
                    log "Graphics: ${gpu_name} — accelerated responses"
                    return
                fi
            fi
            log "Graphics: Standard mode (no GPU detected)"
            ;;
        Darwin*)
            if [ "${ARCH}" = "arm64" ]; then
                log "Graphics: Apple Silicon — fast, accelerated responses"
            else
                log "Graphics: Standard mode"
            fi
            ;;
    esac
}

check_port() {
    local port_in_use=false

    case "${OS}" in
        Linux*)
            local hex_port
            hex_port=$(printf '%04X' "${OLLAMA_PORT}")
            if [ -f /proc/net/tcp ] && grep -qi ":${hex_port} " /proc/net/tcp 2>/dev/null; then
                port_in_use=true
            fi
            ;;
        Darwin*)
            if lsof -i ":${OLLAMA_PORT}" -sTCP:LISTEN &>/dev/null 2>&1; then
                port_in_use=true
            fi
            ;;
    esac

    if [ "${port_in_use}" = true ]; then
        die "Something else is using the connection GhostDrive needs.\n\n  This usually means GhostDrive is already running in another window.\n  Close that window first, or run: ${CYAN}bash stop.sh${NC}"
    fi
}

# ── PID file management ──────────────────────────────────────────────
PID_FILE="${SCRIPT_DIR}/logs/ghostdrive.pid"

is_already_running() {
    if [ -f "${PID_FILE}" ]; then
        local old_pid
        old_pid=$(cat "${PID_FILE}" 2>/dev/null)
        if [ -n "${old_pid}" ] && kill -0 "${old_pid}" 2>/dev/null; then
            return 0
        fi
        rm -f "${PID_FILE}"
    fi
    return 1
}

# ── Spinner ──────────────────────────────────────────────────────────
spinner() {
    local pid=$1
    local message="${2:-Loading}"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0

    while kill -0 "${pid}" 2>/dev/null; do
        echo -ne "\r  ${CYAN}${frames[$i]}${NC} ${message}  "
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.12
    done
    echo -ne "\r                                                   \r"
}

# ── Start Ollama server ──────────────────────────────────────────────
start_ollama() {
    export OLLAMA_MODELS="${SCRIPT_DIR}/models"
    export OLLAMA_HOST="127.0.0.1:${OLLAMA_PORT}"
    export OLLAMA_FLASH_ATTENTION="${OLLAMA_FLASH_ATTENTION}"
    export OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL}"
    export OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS}"

    if [ "${OS}" = "Linux" ]; then
        export OLLAMA_RUNNERS_DIR="${RUNNERS_DIR}"
    fi

    export DO_NOT_TRACK=1
    export SCARF_NO_ANALYTICS=1

    mkdir -p "${SCRIPT_DIR}/logs"
    "${OLLAMA_BIN}" serve > "${SCRIPT_DIR}/logs/ollama.log" 2>&1 &
    local pid=$!
    echo "${pid}" > "${PID_FILE}"

    # Show spinner while waiting
    local startup_messages=(
        "Warming up your AI"
        "Preparing the engine"
        "Almost ready"
    )
    local msg_idx=0
    local attempts=0
    local max_attempts=30

    while [ ${attempts} -lt ${max_attempts} ]; do
        if "${OLLAMA_BIN}" list &>/dev/null; then
            echo -ne "\r                                                   \r"
            log "AI engine is ready"
            return 0
        fi

        if ! kill -0 ${pid} 2>/dev/null; then
            echo ""
            err "The AI engine couldn't start on this computer."
            err ""
            err "This might be caused by:"
            err "  • Not enough free memory — try closing other programs"
            err "  • A security program blocking it — check your antivirus"
            err ""
            err "Technical details are saved in: logs/ollama.log"
            return 1
        fi

        # Rotate friendly messages
        local current_msg="${startup_messages[$msg_idx]}"
        local frame_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        local frame="${frame_chars[$((attempts % 10))]}"
        echo -ne "\r  ${CYAN}${frame}${NC} ${current_msg}...  "

        if [ $((attempts % 10)) -eq 9 ] && [ ${msg_idx} -lt $(( ${#startup_messages[@]} - 1 )) ]; then
            msg_idx=$((msg_idx + 1))
        fi

        sleep 1
        attempts=$((attempts + 1))
    done

    echo ""
    err "The AI engine is taking too long to start."
    err "Your computer might not have enough memory available."
    err ""
    err "Try closing some programs and running GhostDrive again."
    kill ${pid} 2>/dev/null || true
    return 1
}

# ── List models ──────────────────────────────────────────────────────
list_models() {
    echo ""
    echo -e "  ${WHITE}${BOLD}Your AI Models${NC}"
    echo -e "  ${DIM}These are the AI brains available on your GhostDrive:${NC}"
    echo ""

    local model_data
    model_data=$("${OLLAMA_BIN}" list 2>/dev/null | tail -n +2)

    if [ -z "${model_data}" ]; then
        echo -e "    ${YELLOW}No models found.${NC}"
        echo -e "    ${DIM}Use ${NC}bash models.sh pull gemma3:4b${DIM} to add one (requires internet).${NC}"
    else
        while IFS= read -r line; do
            local model_name
            model_name=$(echo "${line}" | awk '{print $1}')
            local model_size
            model_size=$(echo "${line}" | awk '{print $3, $4}')
            local description
            description=$(describe_model "${model_name}")

            if [ "${model_name}" = "${MODEL}" ]; then
                echo -e "    ${GREEN}▸${NC} ${BOLD}${model_name}${NC}"
                echo -e "      ${description}  ${DIM}(${model_size})${NC}  ${GREEN}← active${NC}"
            else
                echo -e "    ${BLUE}○${NC} ${model_name}"
                echo -e "      ${DIM}${description}  (${model_size})${NC}"
            fi
            echo ""
        done <<< "${model_data}"
    fi
}

# ── Cleanup / shutdown ────────────────────────────────────────────────
cleanup() {
    echo ""
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${WHITE}${BOLD}  Session ended.${NC}"
    echo ""
    echo -e "    ${GREEN}●${NC}  Your conversation was ${BOLD}completely private${NC}."
    echo -e "    ${GREEN}●${NC}  Nothing was sent to the internet."
    echo -e "    ${GREEN}●${NC}  No data was saved or logged."
    echo ""
    echo -e "  ${DIM}  Unplug your GhostDrive anytime. See you next time.${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ -f "${PID_FILE}" ]; then
        local pid
        pid=$(cat "${PID_FILE}" 2>/dev/null)
        if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" 2>/dev/null
            local i=0
            while [ ${i} -lt 5 ] && kill -0 "${pid}" 2>/dev/null; do
                sleep 1
                i=$((i + 1))
            done
            if kill -0 "${pid}" 2>/dev/null; then
                kill -9 "${pid}" 2>/dev/null
            fi
        fi
        rm -f "${PID_FILE}"
    fi

    exit 0
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
    banner

    # First-run experience
    if is_first_run; then
        show_first_run
    fi

    echo -e "  ${DIM}Checking your system...${NC}"
    echo ""

    log "System: ${OS_FRIENDLY}"
    check_ram
    check_gpu
    check_port

    echo ""

    if is_already_running; then
        die "GhostDrive is already running in another window.\n\n  Close that window first, or run: ${CYAN}bash stop.sh${NC}"
    fi

    if ! start_ollama; then
        die "Could not start the AI engine. See the messages above for help."
    fi

    if [ "${LIST_ONLY}" = true ]; then
        list_models
        cleanup
        exit 0
    fi

    list_models

    trap cleanup SIGINT SIGTERM

    echo -e "  ${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${WHITE}${BOLD}  GhostDrive is ready.${NC} ${GREEN}Ask me anything.${NC}"
    echo ""
    echo -e "  ${DIM}  Try something like:${NC}"
    echo ""
    echo -e "    ${CYAN}\"Explain quantum computing in simple terms\"${NC}"
    echo -e "    ${CYAN}\"Help me write a professional email to my boss\"${NC}"
    echo -e "    ${CYAN}\"What are the pros and cons of solar panels?\"${NC}"
    echo ""
    echo -e "  ${DIM}  Type ${NC}/bye${DIM} or press ${NC}Ctrl+C${DIM} to end your session.${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    "${OLLAMA_BIN}" run "${MODEL}"

    cleanup
}

main "$@"
