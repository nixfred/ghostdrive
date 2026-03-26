# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

GhostDrive is an open-source portable offline AI USB stick — the free version of the "AI sticks" being sold on Instagram for $129. Those products are just Ollama + an open-weight model on a USB drive. This repo provides the same thing (with better UX) and step-by-step build instructions so anyone can make their own.

The `staging/` directory IS the USB drive contents. Everything inside it gets copied to an exFAT-formatted USB stick.

## Repo Structure

```
README.md               ← GitHub landing page (public-facing, explains the scam)
CLAUDE.md               ← This file (developer guidance)
.gitignore              ← Excludes binaries and models from git
staging/                ← USB drive contents (this whole dir gets copied to the stick)
  ghostdrive.sh         ← Single entry point. Detects OS, starts Ollama, drops into chat
  models.sh             ← Model management (list/pull/remove)
  stop.sh               ← Emergency kill via PID file
  config.env            ← User-editable runtime config (port, default model)
  README.md             ← On-stick user guide (consumer-friendly, no dev jargon)
  knowledge/            ← User's offline reference documents
  engine/
    linux-amd64/bin/ollama    ← Linux binary (downloaded during build, not in git)
    linux-amd64/lib/          ← CUDA/CPU runner libs
    darwin/Ollama.app/        ← macOS .app bundle (needed for Metal)
      Contents/Resources/ollama  ← macOS CLI binary (NOT MacOS/Ollama which is GUI)
  models/                     ← Model blobs (downloaded during build, not in git)
```

**Critical path detail:** The macOS CLI binary is at `Contents/Resources/ollama`, not `Contents/MacOS/Ollama` (that's the GUI app). Scripts must reference the Resources path.

## Two READMEs

- **Root `README.md`** — GitHub-facing. Explains the Instagram scam, provides build instructions, positions the project as the free alternative.
- **`staging/README.md`** — Goes ON the USB stick. Written for non-technical end users. Premium consumer product tone. No mention of the scam or GitHub.

These serve different audiences and should stay distinct.

## Architecture

- `ghostdrive.sh` detects OS via `uname -s`, picks the correct Ollama binary, `chmod +x` at runtime (exFAT kills permissions), starts server on port 11435, drops user into `ollama run`
- First-run detection via `logs/.ghost_welcomed` — shows welcome message on first launch
- RAM-aware model selection — auto-downgrades to gemma3:4b on <16GB systems
- GPU detection — NVIDIA on Linux, Apple Silicon on Mac
- All user-facing output uses friendly, jargon-free language
- Model descriptions mapped via `describe_model()` function

## Constraints

- **Target machine dependencies: bash only.** No curl, no python, no pip, no docker.
- **No GUI/web UI.** CLI-only via `ollama run`.
- **exFAT filesystem.** Required for Linux+macOS cross-compatibility. Does not preserve Unix execute permissions — scripts must `chmod +x` binaries at runtime.
- **Port 11435** to avoid conflicting with any system Ollama on 11434.
- **Linux x86_64 and macOS (Intel + Apple Silicon) only.** No Windows, no ARM Linux.
- **Consumer UX.** All user-facing text must be understandable by someone who has never used a terminal before.

## Testing

No automated tests. Smoke test manually:

```bash
cd staging
bash ghostdrive.sh --help        # Verify arg parsing
bash ghostdrive.sh --list        # Starts Ollama, lists models, stops
bash models.sh help              # Verify model manager
bash stop.sh                     # Verify PID cleanup
```

For a full integration test, run `bash ghostdrive.sh`, send a message, verify response, `/bye` to exit.
