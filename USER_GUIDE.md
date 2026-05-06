<p align="center">
  <img src="assets/icon.png" width="120" height="120" alt="Ka1zen icon">
</p>

<h1 align="center">Ka1zen — User Guide</h1>

<p align="center">
  <strong>Local AI for Apple Silicon</strong> · Version 0.3.32 · by Florian Bertaux
</p>

---

## Table of Contents

1. [Hardware & software requirements](#1-hardware--software-requirements)
2. [First launch](#2-first-launch)
3. [Interface overview](#3-interface-overview)
4. [Conversations & chat](#4-conversations--chat)
5. [Attachments & files](#5-attachments--files)
6. [Web search, web images & tools](#6-web-search--tools)
7. [Thinking mode (reasoning)](#7-thinking-mode-reasoning)
8. [Image generation (FLUX.2)](#8-image-generation-flux2)
9. [Document library (RAG)](#9-document-library-rag)
10. [Model Manager](#10-model-manager)
11. [Settings](#11-settings)
12. [API Relay server](#12-api-relay-server)
13. [Token Inspector](#13-token-inspector)
14. [Text-to-Speech (TTS)](#14-text-to-speech-tts)
15. [Exporting conversations](#15-exporting-conversations)
16. [Keyboard shortcuts](#16-keyboard-shortcuts)
17. [File locations & privacy](#17-file-locations--privacy)
18. [FAQ & troubleshooting](#18-faq--troubleshooting)

---

## 1. Hardware & software requirements

### Hardware

| Component | Requirement |
|---|---|
| **Processor** | Apple Silicon required (M1, M2, M3, M4 or later). Intel Macs are not supported. |
| **Unified memory** | 16 GB minimum · 32 GB recommended · 64 GB+ for the largest models |
| **Storage** | 20 GB free minimum (each model weighs 2–80 GB) |

**RAM ↔ comfortable model size** (4-bit quantization):

| RAM | Comfortable models |
|---|---|
| 16 GB | Up to 7–8 B |
| 32 GB | Up to 30 B |
| 64 GB | Up to 70 B |
| 128 GB+ | 122 B and beyond |

### Software

| Software | Role | Required? |
|---|---|---|
| **Ka1zen.app** | The app itself | Yes |
| **Python 3.14** (python.org installer) | Host for MLX servers | Yes |
| **mlx-lm** | Text-LLM server | Yes |
| **mlx-vlm** | Vision / audio server | Recommended |
| **huggingface-hub** | Model downloads | Yes |
| **mflux** | Image generation (FLUX.2) | Optional |

> **Python path — important.** Ka1zen expects Python at `/Library/Frameworks/Python.framework/Versions/3.14/`. Only the official **python.org** installer places Python there — Homebrew, pyenv and conda **will not work**.

See the [README](README.md) for step-by-step installation.

---

## 2. First launch

Ka1zen walks you through two setup screens:

1. **Prerequisites check** — Python and every required pip package are listed. If anything is missing, copy the suggested command, paste it into Terminal, and click **Recheck**.
2. **First model** — Ka1zen detects your RAM and proposes a model sized for your Mac. You can also install FLUX for image generation.

Once setup is done, you land straight in the chat, ready to go.

---

## 3. Interface overview

The window is split into a **sidebar** on the left (navigation) and a **main panel** on the right (content).

| Section | Purpose |
|---|---|
| **Conversations** | Chat with your models |
| **Documents** | RAG library (indexed files) |
| **Model Manager** | Download, launch, delete local models |
| **API Relay** | Expose an OpenAI-compatible proxy |
| **Settings** | Endpoints, generation, appearance, TTS |

---

## 4. Conversations & chat

### Create a new conversation

- Click **+** in the sidebar, or press **⌘N**.

### Send a message

1. Type into the input field at the bottom.
2. Press **Enter** or click the send button.

> Insert a line break without sending: **Shift + Enter** or **Option + Enter**.

### Stop generation

Click the **Stop** button (red square) that replaces the send arrow while the model is generating. Partial text is kept.

### Pick a model per conversation

The toolbar shows a **model picker** on the left. Each conversation remembers its own model and its own temperature / max-tokens values — switching models in one conversation doesn't affect the others.

### System prompt

The **text + badge** icon in the toolbar opens the system prompt editor. Use it to assign a role ("You are an expert in…"), set constraints ("Always answer in French") or impose a format ("Use bullet lists"). A checkmark badge indicates an active system prompt.

### Generation statistics

After each reply a bar briefly appears below the last message showing **tokens/s**, **GPU memory (GiB)** and **generated tokens**.

### Rename / delete

Double-click a conversation's title in the sidebar to rename it (the title is also auto-generated after the first exchange). Right-click → **Delete** to remove it.

---

## 5. Attachments & files

### Images (VLM models only)

- **Drag and drop** into the chat, or
- Click the **paperclip/image** icon in the input bar.

Supported formats: PNG, JPEG, HEIC, WebP, GIF. Compatible models: Gemma 3/4, LLaVA, Pixtral, Mistral Small VLM, Qwen2-VL…

> The image button only appears when the active model supports vision.

### Text / PDF documents (one-shot)

Click the **document** icon to open the file picker. Supported: PDF, TXT, Markdown, JSON, Swift, Python. Content is extracted and injected directly into the message context (up to 60,000 characters per file).

> Different from RAG: the content is sent once with the message, no permanent indexing.

### RAG context bar

When library documents are attached to a conversation, a bar appears at the top of the chat listing the active documents. Click **📎** to pick which documents to use.

---

## 6. Web search, web images & tools

### Enable tools

The **tools** button in the chat toolbar toggles tool mode. When it is on, Ka1zen runs a **DuckDuckGo search before every send**:

1. Ka1zen launches a search with your question.
2. Results (titles, URLs, excerpts) are injected into the context.
3. The model synthesizes an answer using the fresh data.

A *"Searching…"* indicator is shown during the search. Short follow-ups (e.g. "And Artemis 2?") are automatically enriched with the previous question's context.

### Clickable citations

Responses cite sources as `[1]`, `[2]`… Each marker is clickable and opens the URL. A collapsible source list appears below the reply with title, domain and link.

### `fetch_page` tool

The model can call `fetch_page` to retrieve the full content of a specific URL — complements automatic search.

### Inline web images (`web_image_search`)

Ka1zen can fetch real photos from DuckDuckGo Images and display them inline in the chat. **No FLUX, no generation** — it's pure web download of the actual images, cached locally and rendered exactly like a generated image bubble.

**How to trigger** — phrase your message with a count followed by an image noun. Six languages are recognised:

- **EN** — `image / images / photo / photos / picture / pictures / pic / pics`, verbs *show / display / find / fetch*
- **FR** — `image(s) / photo(s)`, verbs *affiche / montre / trouve / cherche*
- **PT** — `imagem / imagens / foto / fotos / retrato(s)`, verbs *mostre / mostra / exiba / busque*
- **ES** — `imagen / imágenes / foto / fotos / retrato(s)`, verbs *muestra / muéstrame / enséñame / busca*
- **DE** — `Bild / Bilder / Foto / Fotos / Aufnahme(n)`, verbs *zeig / zeige / suche / finde*
- **IT** — `immagine / immagini / foto / fotografia / fotografie`, verbs *mostra / mostrami / fammi vedere / cerca*

A leading verb is helpful but not required — a bare *N image-noun* pattern is enough on its own. Determiners in the captured subject (*the / le / la / les / del / di / der / die / das / do / da*…) are stripped automatically.

**Examples that work:**

| Prompt | Result |
|---|---|
| `Show me 5 photos of Japan` | 5 images of Japan, inline |
| `Display 10 pictures of Mario` | 10 images, inline |
| `2 images of Zendaya at the Met Gala` | 2 images, inline (no verb needed) |
| `3 photos of Cristiano Ronaldo` | 3 images, inline |
| `Find me 4 images of the Eiffel Tower at night` | 4 images, inline |
| `Show 6 pictures of golden retriever puppies` | 6 images, inline |
| `Display 5 photos of the Tesla Cybertruck` | 5 images, inline |
| `Show me 8 images of the Northern Lights in Iceland` | 8 images, inline |
| `5 photos of Tokyo street food` | 5 images, no verb needed |
| `Show me 7 paintings by Van Gogh` | 7 images of paintings, inline |
| `4 images of MacBook Pro 16-inch` | 4 product photos, inline |
| `Display 5 photos of the Lamborghini Revuelto` | 5 images, inline |
| `Show me 3 pictures of Mount Fuji at sunrise` | 3 images, inline |
| `Find 6 photos of vintage Porsche 911s` | 6 images, inline |
| `2 images of Zendaya at the Met Gala, 3 of Mario, 3 of Ronaldo` | **8 images total** — three parallel sub-calls, one per subject |
| `2 of Tokyo, 2 of Osaka, 2 of Kyoto` | 6 images via three parallel calls (subject inferred from each segment) |

**Limits:**

- **10 images max per call.** Higher numbers are silently capped.
- **No global cap on parallel sub-calls** but in practice keep counts modest. *"2 of A, 2 of B, 2 of C"* (6 images) reads cleanly; pushing past ~10 total images per turn makes the chat scroll awkwardly and piles up bandwidth (each image up to 5 MB).
- **5 MB max per image, 10 s timeout per fetch.** Larger or slower images are skipped silently — you'll see *N* images instead of *N+1*.
- **Disabled when *Web Search* is off.** The toggle in the chat toolbar gates both `web_search` and `web_image_search`.

**On-disk cache:** images live in `~/var/folders/<user>/T/ka1zen_images/web_*.{jpg,png,webp,gif}`. Wipe via *Settings → General → Image Generation → Clear cache* — same dropbox as the FLUX cache.

**Privacy:** every image is fetched directly from a third-party host (your IP is exposed to that host), although thumbnails go through DuckDuckGo's `external-content.duckduckgo.com` proxy and are typically used as the first choice.

### When to disable tools

- Creative conversations (writing, brainstorming) that don't need fresh data
- To avoid search latency (~3–15 s per message)
- Slow models where every token matters

---

## 7. Thinking mode (reasoning)

Some models expose their internal chain-of-thought before giving a final answer. This improves quality on math, logic, code and analysis.

**Compatible models:** Qwen3 · DeepSeek-R1 · Gemma 3/4 · Mistral Small 4+.

Click the **brain / lightbulb** icon in the toolbar to toggle thinking. The reasoning is shown in a **collapsible block** above the final answer. Thinking time can range from ~10 s to several minutes.

---

## 8. Image generation & editing

### Prerequisites

`mflux` must be installed. Ka1zen ships with three supported families: **FLUX.2-klein-9B** (default, downloaded automatically on first generation), **Qwen-Image** (e.g. `Qwen-Image-2512-8bit`), and **Z-Image**. No HuggingFace key required for any of them.

Pick which family to use as the active image-gen model in **Settings → System Models → Image Generation**.

### Trigger (text-to-image)

Generation is automatic when tools are on. Natural phrases trigger it:
- "Generate an image of…"
- "Draw me a…"
- "Create a photo of…"
- "Génère une image de…"

Ka1zen optimizes your prompt before generating, then shows the image in the chat.

### Image editing (image-to-image)

Since 0.3.31, Ka1zen can **edit** an existing image instead of generating a fresh one. Three ways to enter edit mode:

**A. Pin an image rendered in the chat.** Right-click any image in the conversation (FLUX-generated, web-search result, or one you uploaded) → **Use as edit source**. Or simply hover the image and click the small ✏️ pencil overlay top-right.

The pinned image gets a 2 px purple border + a small **Source** badge so you always know which one will be edited. A brand-coloured banner appears above the composer with the thumbnail and a × to clear the pin.

Type your edit instruction and send: *"make the dress blue"*, *"transforme en pixel art"*, *"add a pair of sunglasses"*. The next image-gen call routes to FLUX.2-Klein-Edit (or `mflux-generate-qwen` if Qwen-Image is your active model) with the pinned file as the source.

**B. Attach + edit verb (one shot).** Click the paperclip, attach a photo, type an instruction with an edit verb (`edite`, `modifie`, `change`, `transforme`, `make it`, `add`, `remove`, `replace`…) and send. Ka1zen detects this combination and routes the attachment straight to the edit binary — bypasses the chat model entirely. Works in FR / EN / ES / DE / IT / PT.

**C. Edit your own upload.** Same as A, but right-click the thumbnail in your message bubble.

The pin clears automatically after each edit so the result becomes your next candidate — pin it (one click, the result has the same hover overlay) to iterate.

**Source dimensions are preserved.** Editing a portrait keeps it portrait — `mflux-generate-flux2-edit` and `mflux-generate-qwen` default `--width`/`--height` to the source image's own dimensions when those flags are omitted. No more 1024×1024 forced crops.

### Settings (Settings → General → Image Generation)

| Parameter | Default | Description |
|---|---|---|
| Steps | 4 | Denoising passes. More = better, slower |
| Width | 1024 px | Must be a multiple of 16 |
| Height | 1024 px | Must be a multiple of 16 |
| Seed | -1 (random) | Fixed value to reproduce an image |

Image generation requests are **serialized** through an actor — no concurrent GPU calls.

### Grounded generation (web-search + FLUX)

Since 0.3.11, Ka1zen can ground an image in live web-search results. When your message contains **both** an image verb (*generate / create / draw / make*, or their French equivalents *génère / crée / dessine / fais*) **and** a search keyword (*search / look up / on the web / find info*, or their French equivalents *cherche / recherche / sur internet / trouve des infos*), Ka1zen runs:

1. **Web search** on the subject — results appear in the Agent Steps.
2. **Prompt synthesis** — the active LLM turns the search snippets into a FLUX-optimized English prompt that incorporates the factual details (colors, shapes, era, context).
3. **FLUX generation** — the image is produced from the enriched prompt. Sources from the web search are attached to the assistant message as clickable `[N]` citations.

Examples (English):

```
Search for what a squircle is in UI design and generate an image
of a photorealistic hand-drawn infographic on white paper lying
on a blue cutting mat.
```

```
Search for a 1967 Ford Mustang and create a photorealistic image
of this car parked in front of an American diner at sunset.
```

```
Look up the Renaissance fresco technique and make a detailed
illustration of an artist at work on a church ceiling.
```

```
Find info about Japanese ramen shops in Tokyo and generate a
cinematic photo of a steaming bowl of tonkotsu ramen on a
wooden counter with neon reflections.
```

```
Search the web for James Webb Space Telescope imagery and draw
a stylized poster celebrating its deep-field observations.
```

```
Find information about Belle Époque Parisian fashion around 1905
and create an illustration of a couple walking on the Champs-Élysées.
```

**When it helps:** technical diagrams, historical scenes, infographic-style illustrations, concepts where your own description would be vague.

**When it doesn't:** faithful reproduction of a specific real product. FLUX generates from text; the search returns text; the gap between "white earbuds with an oval case" and "actual AirPods Pro 3 design" is real. For surgical edits of a known image, use the **image editing** flow above — pin a reference and instruct the change. Text rendered inside the image also remains unreliable — avoid asking the model to write long labels or paragraphs.

**Plain image requests** (no search keyword — *"draw a dragon in an enchanted forest"*) skip the search and go straight to FLUX with no added latency.

Requirements: **Tools** and **Web search** both enabled (top of the chat), a local LLM loaded, and `mflux` installed.

---

## 9. Document library (RAG)

RAG (Retrieval-Augmented Generation) lets you index documents locally and inject relevant passages into your prompts without attaching the whole file every time.

### Add a document

- **Drag and drop** into the Documents view, or
- click **+ Add Document**.

Supported formats: PDF, TXT, Markdown, JSON, Swift, Python.

### Indexing pipeline

1. Raw-text extraction (PDFKit for PDFs).
2. Chunking (~512 tokens with overlap).
3. Embedding of each chunk (300-dim vectors via Apple's `NLEmbedding`).
4. Storage in a local SQLite database (GRDB).

Everything is **local and offline** — no external API, no embedding ever leaves your Mac.

### Use in a conversation

1. In the chat, click the **document / paperclip** icon.
2. Select documents to activate.
3. The RAG bar appears at the top of the chat.

On every message Ka1zen extracts the most relevant passages and injects them into the context.

### Advanced RAG settings

| Parameter | Default | Description |
|---|---|---|
| Top-K | 5 | Passages retrieved per query |
| Similarity threshold | 0.2 | Minimum score (0–1) |
| Chunk size | 512 tokens | Chunk size at indexing time |
| Overlap | 64 tokens | Tokens shared between consecutive chunks |
| Max context chars | 3,000 | Total RAG text injected per message |

### Delete a document

Hover a document → **Trash** button. The file and every embedding are permanently removed from the local database.

---

## 10. Model Manager

### Installed tab

Shows every model present in `~/.cache/huggingface/hub/`, sorted by size. Each card displays the HuggingFace ID, disk size, detected capabilities (Vision / Thinking / Audio) and server state. Models whose download was interrupted (network drop, app quit mid-fetch) are filtered out automatically — Ka1zen verifies that `blobs/` is non-empty, contains no `*.incomplete` files, that a snapshot ref was resolved, and that every symlink in the snapshot tree points to an existing non-empty blob. Re-clicking **Download** on a partial model resumes from where it stopped.

- **Launch** — starts `mlx_lm.server` (or `mlx_vlm.server` for VLMs) on the configured port. Startup: 30 s to 5 min depending on size.
- **Stop** — terminates every child process immediately.
- **Delete** — removes the model folder from the HuggingFace cache permanently.
- **Benchmark** (stopwatch icon) — measures tokens/s and time-to-first-token.
- **Verify integrity** (right-click → context menu) — hashes every LFS blob (multi-GB safetensors) and compares the SHA-256 to the blob filename, which **is** the expected hash at HuggingFace. Fully offline, streamed in 1 MB chunks, cancellable. Useful after a suspected disk corruption, or just before launching a model you haven't used in a while. Result appears as a green ✓ *Integrity verified* / red ⚠ *Integrity failed — \<short hash\>* badge in the card. Status is in-memory only — re-verify next session if needed.

### Browse HuggingFace tab

Search and download MLX models directly.

- **Search** — by name (e.g. `qwen3`, `gemma`, `llama`), results sorted by download count.
- **Filters** — `mlx-community` by default; optional toggle to include other orgs.
- **Download** — file-by-file progress bar. Cancellable.

### Recommended starter models

For a full breakdown — how to read MLX model names, dense vs MoE, quantization trade-offs, and curated recommendations for every RAM tier from 8 GB to 192 GB — see the dedicated **[Model Guide](MODEL_GUIDE.md)**.

Quick defaults:

| Model | Size | Min RAM | Capabilities |
|---|---|---|---|
| `mlx-community/Qwen3-8B-4bit` | ~4.5 GB | 16 GB | Text · Tools · Thinking |
| `mlx-community/gemma-4-31b-it-4bit` | ~17 GB | 32 GB | Vision · Audio · Thinking |
| `mlx-community/Llama-3.3-70B-Instruct-4bit` | ~39 GB | 64 GB | Text · Tools |
| `mlx-community/Qwen3.5-122B-A10B-4bit` | ~65 GB | 96 GB | MoE · Vision · Tools · Thinking |

### Gated models

A few models (e.g. Meta's Llama) require accepting the terms on HuggingFace. Log in once:

```bash
/Library/Frameworks/Python.framework/Versions/3.14/bin/python3 -m huggingface_cli login
```

Paste your token from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens).

### Automatic server startup

If you send a message to a conversation whose model isn't running, Ka1zen tries to launch the server automatically and asks you to retry in a few seconds.

---

## 11. Settings

Open via **⌘,** or **Ka1zen → Settings**.

### Models tab — endpoints

Ka1zen supports multiple models running simultaneously on different ports.

**Fields:**

| Field | Example | Description |
|---|---|---|
| Name | Qwen3 8B | Shown in the UI |
| Base URL | `http://127.0.0.1:8080/v1` | OpenAI-compatible URL |
| API Key | `mlx` or empty | Bearer token (optional locally) |
| Model ID | `mlx-community/Qwen3-8B-4bit` | Exact model identifier |

**Generation parameters:**

| Parameter | Range | Description |
|---|---|---|
| Temperature | 0 – 2 | Creativity (0 = deterministic) |
| Max Tokens | 256 – 131 072 | Max response length |
| Context Length | 1024 – 524 288 | Context window size |
| Top-P | 0 – 1 | Nucleus sampling (1 = off) |
| Top-K | 0 – 200 | Keeps K best tokens (0 = off) |
| Min-P | 0 – 1 | Relative min-probability threshold |
| Repetition Penalty | 0 – 2 | 1.1 = mild |
| Frequency Penalty | -2 – 2 | Penalizes frequent tokens |
| Presence Penalty | -2 – 2 | Penalizes already-seen tokens |
| Seed | optional | Fixed value for reproducibility |

**Capabilities** — toggles for Vision / Tool use / Thinking / Audio input / "Set as active". The **Auto-detect** button reads the local `config.json` automatically.

#### Publisher-recommended defaults

Since 0.3.13, every newly downloaded model is created with the generation parameters its publisher recommends. Ka1zen looks at three sources in order:

1. **The repo's own `generation_config.json`** — fetched from the local HF cache, or directly from HuggingFace. Qwen3, Gemma, DeepSeek and most first-party repos ship this file.
2. **Family-level fallback** — applied when the repo strips the file (common for community fine-tunes). Based on each publisher's documented recommendation: Qwen → temp 0.6 / top_p 0.95 / top_k 20, Gemma → 1.0 / 0.95 / 64, DeepSeek → 0.6 / 0.95, Mistral → 0.7, Llama 3 → 0.8 / 0.9, Nemotron → 0.6 / 0.95.
3. **Neutral 0.7** if the family is unknown.

For models downloaded under an older Ka1zen version, a **✨ Reset to publisher defaults** button at the top of the *Generation* section in Edit Model applies the same cascade in one click. A small caption below the button shows what was applied and from which source.

### General tab

- **Response Style** — presets (Concise, Detailed, Professional, Casual, Technical, Beginner-friendly) and a global custom system prompt.
- **Prompt Optimizer** — the ✨ button in the chat rewrites your draft using a chosen style. A small local model is recommended here.
- **Web Search** — Number of sources (1–20, default 5).
- **Image Generation** — Steps, Width, Height, Seed.
- **Voice & TTS** — Speed slider (0–1), voice picker across all installed system voices ("Auto" = auto-detect language).
- **Appearance** — Chat font size (11–24 pt).

---

## 12. API Relay server

Ka1zen exposes an **OpenAI-compatible HTTP proxy** (SwiftNIO) that forwards requests to the active local model. Useful to plug in IDEs (Continue, Cursor, Zed), third-party clients (LM Studio), or share access over the local network.

### Start

Sidebar → **API Relay** → **Start**.

### Configuration

| Option | Default | Description |
|---|---|---|
| Port | 1234 | Listening port |
| Bearer Token | empty | Simple auth (recommended on LAN) |
| Allow LAN | off | Bind on `0.0.0.0` instead of `127.0.0.1` |

### Example

```bash
curl http://127.0.0.1:1234/v1/chat/completions \
  -H "Authorization: Bearer MY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-8b",
    "messages": [{"role":"user","content":"Hello"}],
    "stream": true
  }'
```

### Continue / Cursor / Zed

Configure the OpenAI provider with:

```
Base URL : http://<mac-ip>:1234/v1
API Key  : <optional-bearer-token>
Model    : <name shown by Ka1zen>
```

> **Security.** Only turn **Allow LAN** on a trusted network, and always set a bearer token so other devices can't use your GPU without permission.

### Request log

The server panel shows a real-time log of incoming requests: method, path, response code, duration in ms.

---

## 13. Token Inspector

The Token Inspector visualizes the **model's confidence** per generated token (via logprobs).

Click the **magnifier / token** icon in the chat toolbar. The panel appears below the chat after the next generation.

| Color | Meaning | Probability |
|---|---|---|
| Green | Certain | > 90 % |
| Yellow | Likely | 60–90 % |
| Orange | Uncertain | 30–60 % |
| Red | Unlikely | < 30 % |

Click a token to see its exact logprob.

> Useful for spotting hallucinations: red / orange stretches often map to made-up facts.
> Note: logprobs are disabled when tools are active — turn tools off to see the inspector.

---

## 14. Text-to-Speech (TTS)

Ka1zen reads model responses aloud via the macOS speech-synthesis engine.

Click the **speaker** icon in the chat toolbar to start reading the last assistant message; click again to stop.

- Markdown is cleaned before speaking (headings, bold, links, code blocks stripped).
- Language is **auto-detected** if no voice is selected.
- Premium (enhanced / neural) voices are preferred over compact voices.

Settings → General → Voice & TTS: pick a voice, adjust speed. To install better voices, go to **System Settings → Accessibility → Spoken Content → System Voice**.

---

## 15. Exporting conversations

Click the **share** icon in the chat toolbar (or **File → Export Conversation**, `⌘E`).

| Format | Content |
|---|---|
| Markdown (`.md`) | Messages with Markdown preserved |
| Plain Text (`.txt`) | Raw text, no formatting |
| PDF (`.pdf`) | Rendered from Markdown |
| JSON (`.json`) | Full structure (roles, timestamps, metadata) |

---

## 16. Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` | New conversation |
| `⌘,` | Open Settings |
| `⌘E` | Export conversation |
| `⌘⇧M` | Open Model Manager |
| `⌘K` | Clear the input field |
| **Enter** | Send |
| **Shift + Enter** | New line |
| `⌘.` | Stop current generation |

---

## 17. File locations & privacy

### File locations

| Data | Path |
|---|---|
| Downloaded models | `~/.cache/huggingface/hub/` |
| Ka1zen database (conversations, RAG) | `~/Library/Application Support/Ka1zen/` |
| Encrypted secrets (API keys, relay bearer) | `~/Library/Application Support/Ka1zen/secrets.enc` |
| User preferences | `~/Library/Preferences/com.lefbe.Ka1zen.plist` |
| HuggingFace token | `~/.cache/huggingface/token` |

### Privacy

By default **no data leaves your Mac.** Inference, RAG embeddings and TTS are fully local.

Explicit exceptions you control:
- **Web search** — the query is sent to the selected engine (DuckDuckGo by default).
- **Cloud endpoints** — if you configure one (OpenAI, Anthropic…), messages go to that service.
- **Model downloads** — HTTPS traffic to `huggingface.co`.

### Further reading

- MLX models — [huggingface.co/mlx-community](https://huggingface.co/mlx-community)
- MLX documentation — [ml-explore.github.io/mlx](https://ml-explore.github.io/mlx/)
- mflux — [github.com/filipstrand/mflux](https://github.com/filipstrand/mflux)

---

## 18. FAQ & troubleshooting

**The model answers in English when I ask in French (or vice versa).**
→ Add a system prompt: *"You are a French-speaking assistant. Always answer in French."*

**Web search slows every conversation.**
→ Turn off tools when you don't need fresh info. Reduce **Settings → General → Number of sources** to 2 or 3.

**Text generates very slowly.**
→ Check Activity Monitor → Memory Pressure. If it's red, your system is swapping — pick a smaller model or close other apps. Lower **Max Tokens**.

**Responses have repetitions.**
→ Raise **Repetition Penalty** to 1.1–1.2 in the model parameters.

**Token Inspector is empty.**
→ It needs logprobs, which are disabled when tool use is on. Turn tools off.

**My PDF wasn't extracted well.**
→ Some scanned PDFs contain text as images. Ka1zen uses PDFKit (no OCR). Convert the PDF to text first.

**API relay doesn't answer from another device.**
→ Enable **Allow LAN** in the Server panel, and allow incoming connections for Ka1zen in **System Settings → Network → Firewall**.

**How do I use a cloud model (OpenAI, Anthropic, …)?**
→ Settings → Models → **Add Model** → enter the cloud URL, your API key and the model ID. Any OpenAI Chat Completions endpoint works.
Example (OpenAI): URL `https://api.openai.com/v1`, model `gpt-4o`.

**Capability auto-detect doesn't work.**
→ Auto-detect reads the local `config.json`. If the model isn't downloaded yet it can't work — set the toggles manually.

**Server stuck on `Starting…`.**
→ Model too big for RAM, or slow first load. Check Memory Pressure. Large models (70B+) can take 3–5 minutes.

**`mlx_lm.server not found` / `No module named mlx_vlm`.**
→ The MLX packages aren't installed in Python 3.14. Re-run `./install.sh` from the repo.

**Image generation fails.**
→ `mflux` probably isn't installed. Check:
```bash
/Library/Frameworks/Python.framework/Versions/3.14/bin/python3 -c "import mflux"
```
If that errors, re-run `./install.sh`. (If you installed mflux via `uv tool install mflux`, Ka1zen picks it up too.)

**Still stuck?**
→ Open an issue on GitHub with the output of the **Prerequisites** screen (Settings → System Models → Recheck) and the Model Manager log if a model failed.
