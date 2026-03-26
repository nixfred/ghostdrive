# GhostDrive — Your Private AI

> Plug in. Type a question. Get answers. No internet needed.

---

## What Is This?

GhostDrive is a **complete AI assistant** that lives on this USB drive. It runs entirely on your computer — nothing is sent to the cloud, no account is needed, and no one can see your conversations.

Think of it like having ChatGPT in your pocket, except it's **completely private** and works **without internet**.

---

## Getting Started

### Step 1: Plug in the drive

Insert this USB into any **Linux** or **Mac** computer.

### Step 2: Open a terminal

- **Mac:** Press `Cmd + Space`, type "Terminal", press Enter
- **Linux:** Press `Ctrl + Alt + T` or find "Terminal" in your apps

### Step 3: Go to the drive

**Mac:**
```
cd /Volumes/GHOSTAI
```

**Linux:**
```
cd /media/$(whoami)/GHOSTAI
```

### Step 4: Start your AI

```
bash ghostdrive.sh
```

### Step 5: Ask anything

Just type your question and press Enter. The AI will respond right in your terminal.

### Step 6: When you're done

Type `/bye` or press `Ctrl+C`. Then you can safely unplug the drive.

---

## What Can I Ask It?

GhostDrive can help with almost anything you'd ask a smart assistant:

- **Write & edit** — emails, letters, resumes, cover letters, social media posts
- **Explain things** — break down complex topics in plain English
- **Brainstorm** — generate ideas for projects, gifts, business names, plans
- **Summarize** — paste in long text and get the key points
- **Analyze** — compare options, weigh pros and cons, think through decisions
- **Learn** — ask about history, science, cooking, coding, or anything else
- **Draft** — contracts, proposals, outlines, talking points

Just type naturally, like you're talking to a very knowledgeable friend.

---

## Switching AI Models

Your GhostDrive may have multiple AI "brains" installed. Smaller models are faster; larger models are smarter.

```
bash ghostdrive.sh -m qwen3:8b
```

To see what's available:
```
bash ghostdrive.sh -l
```

---

## Adding More Models

If you have internet access, you can download additional models:

```
bash models.sh pull phi4:14b
```

To see popular options: `bash models.sh pull` (with no model name).

To remove a model you don't need: `bash models.sh remove llava:7b`

---

## Requirements

| | Minimum | Recommended |
|-|---------|-------------|
| **Computer** | 64-bit Mac or Linux | Any modern Mac or Linux PC |
| **Memory** | 8 GB RAM | 16 GB+ RAM |
| **Internet** | Not needed | Only for downloading new models |
| **Software** | Nothing — just a terminal | — |

---

## Troubleshooting

**"Permission denied" when running the script:**
This is normal for USB drives. Always start with `bash ghostdrive.sh` (not `./ghostdrive.sh`).

**Responses are slow:**
This is normal on computers without a dedicated graphics card. Try a smaller model:
`bash ghostdrive.sh -m gemma3:4b`

**"Something else is using the connection":**
GhostDrive might already be running in another window. Close it first, or run: `bash stop.sh`

**Nothing happens / screen is blank:**
Make sure you're in the right folder. Run `ls` — you should see `ghostdrive.sh` in the list.

---

## Your Privacy

GhostDrive was built with one principle: **your data is yours.**

- Your conversations are **never sent anywhere**
- **No telemetry, analytics, or tracking** of any kind
- **No account or login** required
- **No internet connection** needed to use it
- When you unplug the drive, there is **no trace left** on the computer

---

*GhostDrive v1.0 — Own Your Intelligence*
