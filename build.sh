#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
#  GhostDrive Builder
#  Detects your USB stick, downloads everything, builds a complete GhostDrive.
#  Run this on any Linux or Mac with internet access.
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING_DIR="${SCRIPT_DIR}/staging"

# ── Colors ───────────────────────────────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'
    CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'
    WHITE='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; BLUE=''; CYAN=''; YELLOW=''; BOLD=''
    WHITE=''; DIM=''; NC=''
fi

log()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
err()  { echo -e "  ${RED}✗${NC} $1" >&2; }
die()  { echo ""; err "$1"; echo ""; exit 1; }

# ── Banner ───────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'ART'
   ╔═══════════════════════════════════════════════╗
   ║          GhostDrive Builder                   ║
   ║          Build your own AI USB stick          ║
   ╚═══════════════════════════════════════════════╝
ART
echo -e "${NC}"

# ── Detect OS ────────────────────────────────────────────────────────
OS="$(uname -s)"
case "${OS}" in
    Linux*)  BUILD_OS="linux" ;;
    Darwin*) BUILD_OS="darwin" ;;
    *)       die "This builder runs on Linux or macOS. Detected: ${OS}" ;;
esac

# ── Check dependencies ──────────────────────────────────────────────
check_dep() {
    if ! command -v "$1" &>/dev/null; then
        die "Required tool '$1' not found.\n  Install it with: $2"
    fi
}

check_dep wget "apt install wget (Linux) / brew install wget (Mac)"
check_dep rsync "apt install rsync (Linux) / brew install rsync (Mac)"

if [ "${BUILD_OS}" = "linux" ]; then
    if ! command -v mkfs.exfat &>/dev/null; then
        die "exFAT tools not found.\n  Install with: sudo apt install exfatprogs"
    fi
    if ! command -v unzstd &>/dev/null && ! command -v zstd &>/dev/null; then
        die "zstd not found.\n  Install with: sudo apt install zstd"
    fi
fi

if ! command -v unzip &>/dev/null; then
    die "unzip not found.\n  Install with: sudo apt install unzip (Linux) / brew install unzip (Mac)"
fi

log "Build system: ${OS}"

# ── Model catalog ────────────────────────────────────────────────────
declare -A MODEL_SIZES MODEL_DESCS MODEL_RAM
MODEL_SIZES=(
    ["gemma3:4b"]="3.3"
    ["gemma3:12b"]="8.1"
    ["qwen3:8b"]="5.2"
    ["llama3.1:8b"]="4.9"
    ["qwen2.5-coder:7b"]="4.7"
    ["llava:7b"]="4.7"
    ["phi4:14b"]="9.1"
    ["deepseek-r1:8b"]="4.9"
)
MODEL_DESCS=(
    ["gemma3:4b"]="Fast, great for conversation"
    ["gemma3:12b"]="Smarter, more capable"
    ["qwen3:8b"]="Strong reasoning and analysis"
    ["llama3.1:8b"]="Great all-around assistant"
    ["qwen2.5-coder:7b"]="Code generation specialist"
    ["llava:7b"]="Vision + text understanding"
    ["phi4:14b"]="Deep reasoning (needs 32GB RAM)"
    ["deepseek-r1:8b"]="Step-by-step problem solver"
)
MODEL_RAM=(
    ["gemma3:4b"]="8"
    ["gemma3:12b"]="16"
    ["qwen3:8b"]="16"
    ["llama3.1:8b"]="16"
    ["qwen2.5-coder:7b"]="16"
    ["llava:7b"]="16"
    ["phi4:14b"]="32"
    ["deepseek-r1:8b"]="16"
)

# Ordered list for display
MODEL_ORDER=(
    "gemma3:4b"
    "qwen3:8b"
    "llama3.1:8b"
    "gemma3:12b"
    "qwen2.5-coder:7b"
    "llava:7b"
    "deepseek-r1:8b"
    "phi4:14b"
)

# Engine overhead (approximate GB for both Linux + macOS engines)
ENGINE_OVERHEAD_GB=2.5

# ── Step 1: Detect USB drives ───────────────────────────────────────
echo -e "  ${WHITE}${BOLD}Step 1: Select your USB drive${NC}"
echo ""

detect_usb_drives() {
    case "${BUILD_OS}" in
        linux)
            # Find removable block devices
            lsblk -dno NAME,SIZE,MODEL,TRAN 2>/dev/null | grep -i usb | while read -r name size model tran; do
                echo "/dev/${name}|${size}|${model}"
            done
            ;;
        darwin)
            # Find external physical disks
            diskutil list external physical 2>/dev/null | grep "^/dev/" | while read -r disk rest; do
                local size
                size=$(diskutil info "${disk}" 2>/dev/null | grep "Disk Size" | awk -F: '{print $2}' | xargs | awk '{print $1, $2}')
                local name
                name=$(diskutil info "${disk}" 2>/dev/null | grep "Media Name" | awk -F: '{print $2}' | xargs)
                echo "${disk}|${size}|${name}"
            done
            ;;
    esac
}

USB_DRIVES=()
while IFS= read -r line; do
    [ -n "${line}" ] && USB_DRIVES+=("${line}")
done < <(detect_usb_drives)

if [ ${#USB_DRIVES[@]} -eq 0 ]; then
    die "No USB drives detected.\n\n  Make sure your USB stick is plugged in.\n  On Linux, it should show up when you run: lsblk"
fi

echo -e "  ${BOLD}Detected USB drives:${NC}"
echo ""

for i in "${!USB_DRIVES[@]}"; do
    IFS='|' read -r dev size model <<< "${USB_DRIVES[$i]}"
    echo -e "    ${CYAN}$((i+1)))${NC} ${BOLD}${dev}${NC} — ${size} ${DIM}(${model})${NC}"
done
echo ""

if [ ${#USB_DRIVES[@]} -eq 1 ]; then
    echo -ne "  Use this drive? ${DIM}[Y/n]${NC} "
    read -r confirm
    if [[ "${confirm}" =~ ^[Nn] ]]; then
        die "Cancelled."
    fi
    SELECTED_IDX=0
else
    echo -ne "  Select a drive ${DIM}[1-${#USB_DRIVES[@]}]${NC}: "
    read -r choice
    SELECTED_IDX=$((choice - 1))
    if [ ${SELECTED_IDX} -lt 0 ] || [ ${SELECTED_IDX} -ge ${#USB_DRIVES[@]} ]; then
        die "Invalid selection."
    fi
fi

IFS='|' read -r TARGET_DEV TARGET_SIZE TARGET_MODEL <<< "${USB_DRIVES[$SELECTED_IDX]}"

# Parse size to GB for model recommendations
parse_size_gb() {
    local size_str="$1"
    # Handle formats: "28.9G", "29G", "32.0 GB", etc.
    local num
    num=$(echo "${size_str}" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    if echo "${size_str}" | grep -qi "T"; then
        echo "$(echo "${num} * 1000" | bc 2>/dev/null || echo 1000)"
    else
        echo "${num}"
    fi
}

USB_SIZE_GB=$(parse_size_gb "${TARGET_SIZE}")
AVAILABLE_GB=$(echo "${USB_SIZE_GB} - ${ENGINE_OVERHEAD_GB}" | bc 2>/dev/null || echo "$(( ${USB_SIZE_GB%.*} - 3 ))")

echo ""
log "Selected: ${TARGET_DEV} (${TARGET_SIZE} — ${TARGET_MODEL})"
echo -e "  ${DIM}  Available for models after engines: ~${AVAILABLE_GB} GB${NC}"
echo ""

# ── Step 2: Select models ───────────────────────────────────────────
echo -e "  ${WHITE}${BOLD}Step 2: Choose your AI models${NC}"
echo ""
echo -e "  ${DIM}  Select models that fit on your drive. Space available: ~${AVAILABLE_GB} GB${NC}"
echo ""

for i in "${!MODEL_ORDER[@]}"; do
    local_model="${MODEL_ORDER[$i]}"
    local_size="${MODEL_SIZES[$local_model]}"
    local_desc="${MODEL_DESCS[$local_model]}"
    local_ram="${MODEL_RAM[$local_model]}"

    # Check if it fits
    fits=""
    if (( $(echo "${local_size} <= ${AVAILABLE_GB}" | bc 2>/dev/null || echo 0) )); then
        fits="${GREEN}fits${NC}"
    else
        fits="${RED}too large${NC}"
    fi

    echo -e "    ${CYAN}$((i+1)))${NC} ${BOLD}${local_model}${NC}  ${DIM}${local_size} GB | ${local_ram}GB RAM | ${local_desc}${NC}  [${fits}]"
done

echo ""
echo -e "  ${DIM}  Recommended starter combo: gemma3:4b + qwen3:8b (8.5 GB total)${NC}"
echo ""
echo -ne "  Enter model numbers separated by spaces ${DIM}(e.g., 1 2)${NC}: "
read -r model_choices

SELECTED_MODELS=()
TOTAL_MODEL_GB=0
for choice in ${model_choices}; do
    idx=$((choice - 1))
    if [ ${idx} -ge 0 ] && [ ${idx} -lt ${#MODEL_ORDER[@]} ]; then
        model="${MODEL_ORDER[$idx]}"
        SELECTED_MODELS+=("${model}")
        model_gb="${MODEL_SIZES[$model]}"
        TOTAL_MODEL_GB=$(echo "${TOTAL_MODEL_GB} + ${model_gb}" | bc 2>/dev/null || echo "${TOTAL_MODEL_GB}")
    fi
done

if [ ${#SELECTED_MODELS[@]} -eq 0 ]; then
    die "No models selected. You need at least one model."
fi

echo ""
log "Selected ${#SELECTED_MODELS[@]} model(s): ${SELECTED_MODELS[*]}"
echo -e "  ${DIM}  Total model size: ~${TOTAL_MODEL_GB} GB${NC}"

# Check if it fits
TOTAL_NEEDED=$(echo "${TOTAL_MODEL_GB} + ${ENGINE_OVERHEAD_GB}" | bc 2>/dev/null || echo 99)
if (( $(echo "${TOTAL_NEEDED} > ${USB_SIZE_GB}" | bc 2>/dev/null || echo 0) )); then
    warn "Selected models (~${TOTAL_MODEL_GB} GB) + engines (~${ENGINE_OVERHEAD_GB} GB) may not fit on ${TARGET_SIZE} drive."
    echo -ne "  Continue anyway? ${DIM}[y/N]${NC} "
    read -r confirm
    if [[ ! "${confirm}" =~ ^[Yy] ]]; then
        die "Cancelled. Try selecting fewer or smaller models."
    fi
fi

# ── Step 3: Confirm and format ──────────────────────────────────────
echo ""
echo -e "  ${WHITE}${BOLD}Step 3: Format USB drive${NC}"
echo ""
echo -e "  ${RED}${BOLD}  WARNING: This will ERASE ALL DATA on ${TARGET_DEV}${NC}"
echo -e "  ${RED}  Device: ${TARGET_DEV} — ${TARGET_SIZE} (${TARGET_MODEL})${NC}"
echo ""
echo -ne "  Type ${BOLD}YES${NC} to format: "
read -r confirm

if [ "${confirm}" != "YES" ]; then
    die "Format cancelled. You must type YES (all caps) to proceed."
fi

echo ""

# Unmount any existing partitions
case "${BUILD_OS}" in
    linux)
        # Kill any processes using the drive, then force unmount
        sudo fuser -k "${TARGET_DEV}" 2>/dev/null || true
        sleep 1
        for part in ${TARGET_DEV}*; do
            sudo umount -l "${part}" 2>/dev/null || true
        done
        # Also catch auto-mounter mount points
        mount | grep "${TARGET_DEV}" | awk '{print $3}' | while read -r mp; do
            sudo umount -l "${mp}" 2>/dev/null || true
        done
        sleep 1
        log "Formatting ${TARGET_DEV} as exFAT (label: GHOSTAI)..."
        sudo mkfs.exfat -n GHOSTAI "${TARGET_DEV}"
        log "Format complete"

        # Mount it
        MOUNT_POINT="/media/$(whoami)/GHOSTAI"
        sudo mkdir -p "${MOUNT_POINT}"
        sudo mount -o rw,uid=$(id -u),gid=$(id -g) "${TARGET_DEV}" "${MOUNT_POINT}"
        log "Mounted at ${MOUNT_POINT}"
        ;;
    darwin)
        diskutil unmountDisk "${TARGET_DEV}" 2>/dev/null || true
        log "Formatting ${TARGET_DEV} as exFAT (label: GHOSTAI)..."
        diskutil eraseDisk ExFAT GHOSTAI "${TARGET_DEV}"
        log "Format complete"

        MOUNT_POINT="/Volumes/GHOSTAI"
        # macOS auto-mounts after format
        sleep 2
        if [ ! -d "${MOUNT_POINT}" ]; then
            die "Drive did not auto-mount at ${MOUNT_POINT}"
        fi
        log "Mounted at ${MOUNT_POINT}"
        ;;
esac

# ── Step 4: Download engines ────────────────────────────────────────
echo ""
echo -e "  ${WHITE}${BOLD}Step 4: Download AI engines${NC}"
echo ""

LINUX_ENGINE_DIR="${STAGING_DIR}/engine/linux-amd64"
MACOS_ENGINE_DIR="${STAGING_DIR}/engine/darwin"

# Download Linux engine
if [ -f "${LINUX_ENGINE_DIR}/bin/ollama" ]; then
    log "Linux engine already downloaded"
else
    log "Downloading Linux engine..."
    mkdir -p "${LINUX_ENGINE_DIR}/bin" "${LINUX_ENGINE_DIR}/lib"
    wget -q --show-progress -O /tmp/ghostdrive-ollama-linux.tar.zst \
        https://ollama.com/download/ollama-linux-amd64.tar.zst 2>&1

    log "Extracting Linux engine..."
    rm -rf /tmp/ghostdrive-linux-extract
    mkdir -p /tmp/ghostdrive-linux-extract
    tar --use-compress-program=unzstd -xf /tmp/ghostdrive-ollama-linux.tar.zst \
        -C /tmp/ghostdrive-linux-extract

    cp /tmp/ghostdrive-linux-extract/bin/ollama "${LINUX_ENGINE_DIR}/bin/"
    cp -r /tmp/ghostdrive-linux-extract/lib/ollama/* "${LINUX_ENGINE_DIR}/lib/"
    chmod +x "${LINUX_ENGINE_DIR}/bin/ollama"
    rm -rf /tmp/ghostdrive-linux-extract /tmp/ghostdrive-ollama-linux.tar.zst
    log "Linux engine ready"
fi

# Download macOS engine
if [ -d "${MACOS_ENGINE_DIR}/Ollama.app" ]; then
    log "macOS engine already downloaded"
else
    log "Downloading macOS engine..."
    mkdir -p "${MACOS_ENGINE_DIR}"
    wget -q --show-progress -O /tmp/ghostdrive-ollama-darwin.zip \
        https://github.com/ollama/ollama/releases/latest/download/Ollama-darwin.zip 2>&1

    log "Extracting macOS engine..."
    rm -rf /tmp/ghostdrive-darwin-extract
    mkdir -p /tmp/ghostdrive-darwin-extract
    unzip -q /tmp/ghostdrive-ollama-darwin.zip -d /tmp/ghostdrive-darwin-extract

    cp -r /tmp/ghostdrive-darwin-extract/Ollama.app "${MACOS_ENGINE_DIR}/"
    rm -rf /tmp/ghostdrive-darwin-extract /tmp/ghostdrive-ollama-darwin.zip
    log "macOS engine ready"
fi

# ── Step 5: Pull models ─────────────────────────────────────────────
echo ""
echo -e "  ${WHITE}${BOLD}Step 5: Download AI models${NC}"
echo ""

# Determine which binary to use for pulling
if [ "${BUILD_OS}" = "linux" ]; then
    PULL_BIN="${LINUX_ENGINE_DIR}/bin/ollama"
    PULL_RUNNERS="${LINUX_ENGINE_DIR}/lib"
else
    PULL_BIN="${MACOS_ENGINE_DIR}/Ollama.app/Contents/Resources/ollama"
    PULL_RUNNERS="${MACOS_ENGINE_DIR}/Ollama.app/Contents/Resources"
fi

chmod +x "${PULL_BIN}" 2>/dev/null || true

MODELS_DIR="${STAGING_DIR}/models"
mkdir -p "${MODELS_DIR}"

# Start temp Ollama for model pulling
PULL_PORT=11436
export OLLAMA_MODELS="${MODELS_DIR}"
export OLLAMA_HOST="127.0.0.1:${PULL_PORT}"
if [ "${BUILD_OS}" = "linux" ]; then
    export OLLAMA_RUNNERS_DIR="${PULL_RUNNERS}"
fi
export DO_NOT_TRACK=1

log "Starting temporary engine for model downloads..."
"${PULL_BIN}" serve > /tmp/ghostdrive-pull.log 2>&1 &
PULL_PID=$!

# Wait for it to be ready
for i in $(seq 1 30); do
    if "${PULL_BIN}" list &>/dev/null; then
        break
    fi
    if ! kill -0 ${PULL_PID} 2>/dev/null; then
        die "Engine failed to start for model downloads.\n  Check /tmp/ghostdrive-pull.log"
    fi
    sleep 1
done

# Pull each selected model
for model in "${SELECTED_MODELS[@]}"; do
    echo ""
    log "Downloading ${model}..."
    "${PULL_BIN}" pull "${model}" 2>&1
    log "${model} downloaded"
done

# Verify models are present
echo ""
log "Verifying models..."
"${PULL_BIN}" list

# Kill temp server
kill ${PULL_PID} 2>/dev/null || true
wait ${PULL_PID} 2>/dev/null || true

# Set default model to the first (smallest) selected
DEFAULT_MODEL="${SELECTED_MODELS[0]}"
sed -i.bak "s/^DEFAULT_MODEL=.*/DEFAULT_MODEL=${DEFAULT_MODEL}/" "${STAGING_DIR}/config.env" 2>/dev/null || \
    sed -i '' "s/^DEFAULT_MODEL=.*/DEFAULT_MODEL=${DEFAULT_MODEL}/" "${STAGING_DIR}/config.env"
rm -f "${STAGING_DIR}/config.env.bak"

# ── Step 6: Copy to USB ─────────────────────────────────────────────
echo ""
echo -e "  ${WHITE}${BOLD}Step 6: Building your GhostDrive${NC}"
echo ""

log "Copying files to USB..."

# Use rsync with -L to dereference symlinks (exFAT can't handle symlinks)
rsync -rL --info=progress2 "${STAGING_DIR}/" "${MOUNT_POINT}/" 2>&1

# Verify critical files exist
echo ""
log "Verifying USB contents..."

VERIFY_PASS=true
for f in ghostdrive.sh models.sh stop.sh config.env README.md; do
    if [ -f "${MOUNT_POINT}/${f}" ]; then
        log "${f}"
    else
        err "Missing: ${f}"
        VERIFY_PASS=false
    fi
done

# Verify engine binaries
if [ -f "${MOUNT_POINT}/engine/linux-amd64/bin/ollama" ]; then
    log "Linux engine binary"
else
    err "Missing: Linux engine"
    VERIFY_PASS=false
fi

if [ -f "${MOUNT_POINT}/engine/darwin/Ollama.app/Contents/Resources/ollama" ]; then
    log "macOS engine binary"
else
    err "Missing: macOS engine"
    VERIFY_PASS=false
fi

# Verify model manifests (the tricky part on exFAT)
MANIFEST_DIR="${MOUNT_POINT}/models/manifests/registry.ollama.ai/library"
for model in "${SELECTED_MODELS[@]}"; do
    model_name="${model%%:*}"
    model_tag="${model##*:}"
    manifest_file="${MANIFEST_DIR}/${model_name}/${model_tag}"

    if [ -f "${manifest_file}" ]; then
        log "Model manifest: ${model}"
    else
        warn "Model manifest missing for ${model} — fixing..."
        # Copy manifest explicitly (exFAT sometimes drops extensionless files)
        src_manifest="${MODELS_DIR}/manifests/registry.ollama.ai/library/${model_name}/${model_tag}"
        if [ -f "${src_manifest}" ]; then
            mkdir -p "$(dirname "${manifest_file}")" 2>/dev/null || \
                sudo mkdir -p "$(dirname "${manifest_file}")"
            cp "${src_manifest}" "${manifest_file}" 2>/dev/null || \
                sudo cp "${src_manifest}" "${manifest_file}"
            log "Model manifest: ${model} (fixed)"
        else
            err "Source manifest not found for ${model}"
            VERIFY_PASS=false
        fi
    fi
done

if [ "${VERIFY_PASS}" = false ]; then
    warn "Some files may be missing. The drive might still work — try testing it."
fi

# ── Step 7: Sync and finish ─────────────────────────────────────────
echo ""
log "Syncing data to USB..."
sync

# Calculate final size
USB_USED=$(du -sh "${MOUNT_POINT}" 2>/dev/null | awk '{print $1}' || echo "unknown")

echo ""
echo -e "  ${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${WHITE}${BOLD}  GhostDrive build complete!${NC}"
echo ""
echo -e "    ${GREEN}●${NC} Drive: ${TARGET_DEV} (${TARGET_SIZE})"
echo -e "    ${GREEN}●${NC} Models: ${SELECTED_MODELS[*]}"
echo -e "    ${GREEN}●${NC} Space used: ${USB_USED}"
echo -e "    ${GREEN}●${NC} Default model: ${DEFAULT_MODEL}"
echo ""
echo -e "  ${BOLD}  To test it:${NC}"
echo ""
echo -e "    ${CYAN}cd ${MOUNT_POINT}${NC}"
echo -e "    ${CYAN}bash ghostdrive.sh${NC}"
echo ""
echo -e "  ${BOLD}  To use on another computer:${NC}"
echo ""
echo -e "    1. Safely eject the drive"
echo -e "    2. Plug into any Linux or Mac"
echo -e "    3. Open terminal, cd to the drive"
echo -e "    4. Run: bash ghostdrive.sh"
echo ""
echo -e "  ${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
