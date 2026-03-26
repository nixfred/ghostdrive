# GhostDrive — The "$129 AI USB Stick" You Saw on Instagram

You've probably seen the ads. A mysterious USB stick that gives you "your own private AI" for $129. No subscription, no internet, plug and play.

**Here's what's actually on that stick:** [Ollama](https://ollama.com) (free, open-source software) and a small language model. Total cost of materials: about $8 for the USB drive.

**This repo is the whole thing. For free.**

---

## What This Actually Is

GhostDrive is a portable, offline AI assistant on a USB stick. It works on Linux and Mac, requires no internet, and runs entirely on the host computer's hardware. It uses Ollama as the inference engine and ships with open-weight models like Gemma 3 and Qwen 3.

**There is nothing proprietary here.** The sellers are packaging free software on a cheap USB drive and charging a 15x markup. The scripts in this repo are arguably better than what they ship — we added OS detection, GPU detection, RAM-aware model selection, a first-run experience, friendly error messages, and a model manager.

---

## Build Your Own in 5 Minutes

### What you need

- A USB stick (8GB minimum, 32GB recommended) — **~$8**
- A computer with internet (just for the one-time build)
- About 5 minutes

### Automated Build (Recommended)

The builder handles everything — detects your USB, lets you pick models, downloads engines, formats, copies, and verifies:

```bash
git clone https://github.com/nixfred/ghostdrive.git
cd ghostdrive
bash build.sh
```

It will walk you through:
1. Selecting your USB drive
2. Choosing AI models that fit your stick
3. Formatting the drive
4. Downloading engines and models
5. Copying everything and verifying

That's it. You just saved $121.

### Manual Build

<details>
<summary>Click to expand manual steps (if you prefer doing it yourself)</summary>

#### Step 1: Format the USB as exFAT

exFAT works on both Linux and Mac. Label it `GHOSTAI`.

**Linux:**
```bash
lsblk                                    # find your USB device
sudo mkfs.exfat -n GHOSTAI /dev/sdX      # replace sdX with your device
```

**Mac:**
```bash
diskutil list                             # find your USB
diskutil eraseDisk ExFAT GHOSTAI /dev/diskN
```

#### Step 2: Clone this repo

```bash
git clone https://github.com/nixfred/ghostdrive.git
cd ghostdrive
```

#### Step 3: Download the AI engines

```bash
# Linux engine
wget -O /tmp/ollama-linux-amd64.tar.zst https://ollama.com/download/ollama-linux-amd64.tar.zst
mkdir -p staging/engine/linux-amd64
tar --use-compress-program=unzstd -xf /tmp/ollama-linux-amd64.tar.zst -C /tmp/ollama-linux-extract
cp /tmp/ollama-linux-extract/bin/ollama staging/engine/linux-amd64/bin/
cp -r /tmp/ollama-linux-extract/lib/ollama/* staging/engine/linux-amd64/lib/

# macOS engine
wget -O /tmp/ollama-darwin.zip https://github.com/ollama/ollama/releases/latest/download/Ollama-darwin.zip
mkdir -p staging/engine/darwin
unzip /tmp/ollama-darwin.zip -d /tmp/ollama-darwin-extract
cp -r /tmp/ollama-darwin-extract/Ollama.app staging/engine/darwin/
```

#### Step 4: Pull a model

```bash
OLLAMA_MODELS="$(pwd)/staging/models" OLLAMA_HOST="127.0.0.1:11435" \
  staging/engine/linux-amd64/bin/ollama serve &

OLLAMA_HOST="127.0.0.1:11435" staging/engine/linux-amd64/bin/ollama pull gemma3:4b
OLLAMA_HOST="127.0.0.1:11435" staging/engine/linux-amd64/bin/ollama pull qwen3:8b
kill %1
```

#### Step 5: Copy to USB

```bash
rsync -rL staging/ /media/$(whoami)/GHOSTAI/    # Linux
rsync -rL staging/ /Volumes/GHOSTAI/             # Mac
```

#### Step 6: Test it

```bash
cd /media/$(whoami)/GHOSTAI   # or /Volumes/GHOSTAI on Mac
bash ghostdrive.sh
```

</details>

---

## What's Included

| File | Purpose |
|------|---------|
| `ghostdrive.sh` | Main launcher — detects OS, starts engine, drops you into chat |
| `models.sh` | Model manager — list, download, remove AI models |
| `stop.sh` | Emergency stop if something gets stuck |
| `config.env` | Settings (port, default model, performance tuning) |
| `knowledge/` | Folder for your own offline reference documents |

## Features

- **Cross-platform** — Works on Linux x86_64 and macOS (Intel + Apple Silicon)
- **Zero dependencies** — Only needs `bash` on the target machine
- **RAM-aware** — Automatically selects the right model for your hardware
- **GPU-accelerated** — Detects NVIDIA (Linux) and Apple Silicon (Mac) automatically
- **First-run welcome** — Explains what GhostDrive is to non-technical users
- **Friendly errors** — No scary stack traces, just clear instructions
- **Privacy-first** — Telemetry disabled, no analytics, no cloud calls, no logging

## System Requirements

| | Minimum | Recommended |
|-|---------|-------------|
| **OS** | Linux x86_64 or macOS 14+ | Same |
| **RAM** | 8 GB | 16 GB+ |
| **Internet** | Not needed to run | Only needed to download new models |
| **Dependencies** | `bash` | That's it |

---

## Why This Exists

Offline AI is genuinely useful — for privacy, for travel, for air-gapped environments, for people who don't want their conversations sent to the cloud. That's a real and legitimate need.

What's **not** legitimate is taking free, open-source software that anyone can download in 10 minutes, putting it on an $8 USB drive, and selling it for $129 to people who don't know any better.

The AI models are open-weight and free. Ollama is open-source and free. The only value-add in those Instagram sticks is the convenience of not having to set it up yourself. This repo eliminates that last justification.

**If you find this useful, star the repo.** That's all the payment needed.

---

## License

MIT — Do whatever you want with it. Make your own sticks and give them to friends. Just don't charge $129 for it.

---

*Built with [Ollama](https://ollama.com) and open-weight models. No proprietary software. No secrets. No gotcha.*
