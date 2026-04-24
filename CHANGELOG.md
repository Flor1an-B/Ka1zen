# Changelog

All notable changes to Ka1zen are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.20] — 2026-04-24

### Added
- **FLUX cache purge in Settings → General → Image Generation.** Ka1zen's image-generation backends (FLUX via `mflux`, Z-Image) write every PNG to `~/var/folders/<user>/T/ka1zen_images/` without ever cleaning up — a heavy user can rack up several GB of generated images over time. The *Image Generation* section now surfaces the current folder size and file count, with an **Open folder** button that drops you inside the directory in Finder and a **Clear cache** button that wipes every file after a confirmation ("Clear N files — this removes XX.X MB"). Clearing keeps the folder itself so the next generation can write straight in; already-generated images referenced from past conversations stop rendering after purge (expected — the files are gone).
- **Orphan MLX server detection.** When the user force-quits Ka1zen while a model is running, the Python `mlx_lm.server` / `mlx_vlm.server` child is re-parented to launchd and keeps its port bound. The next launch then fails with a cryptic "address already in use" error. Ka1zen now scans `ps -ax` for MLX server processes it doesn't own *before* trying to start a new one; when one is found, an alert surfaces the orphan's model ID, port, and PID along with *Kill & launch* / *Cancel* buttons. *Kill & launch* sends `SIGTERM`, waits 500 ms for the OS to release the port, then proceeds with the launch on a freshly-allocated port.

### Fixed
- **Generated images now render at their actual position in the message flow.** Every `[IMAGE:path]` marker was previously extracted by a SwiftUI `ForEach` placed above the text body, so every generated image ended up docked to the top of the bubble regardless of where it sat in the content. This looked fine for the plain "draw a dragon" path (a one-line prompt followed by the image), but broke the attach-and-reproduce pipeline: the image was up above a 200-line analysis, so users scrolled down to the `**FLUX reproduction**` header, saw no image, and concluded the generation had failed. A new `.image(path)` `RenderBlock` is emitted by `splitIntoBlocks` whenever a `[IMAGE:path]` marker appears on its own line, rendered inline via `inlineImageView` — the picture lands right under the heading that introduces it. Placeholder ("Loading image…") appears briefly if the file isn't yet readable, then re-renders to the actual PNG once FLUX finishes the write.

## [0.3.18] — 2026-04-24

### Added
- **Attach + reproduce pipeline** — a third grounded image-generation path alongside the existing "plain FLUX" and "web search + FLUX" branches. When the user attaches one or more images AND asks for a reproduction (keywords: *reproduis / reproduire / recrée / replicate / recreate / réplique / copie* — or a combined *analyse + génère une image* pattern), Ka1zen now runs: (1) the vision-capable chat model streams a detailed analysis of the attached image into the assistant turn as normal; (2) once the chat completes, that analysis is condensed by a small LLM pass (`synthesizeReproductionPrompt`) into a dense ~120-word FLUX prompt; (3) FLUX generates a reproduction, which is appended to the same assistant message alongside the original analysis. Tests the full vision → description → generation loop end-to-end in one turn.

### Fixed
- **Image attachments are no longer silently discarded by the FLUX-only paths.** The `isImageGenerationRequest` detector's flexible "verb + image-noun" matcher was triggering on phrases like *"pour générer une image"* buried inside analysis briefs, sending the prompt through the text-only FLUX path — the attached image was dropped, and the optimizer LLM (called without the image) replied *"I'm sorry, no image was attached"*. Both the `isImageGenerationRequest` and `isSearchAndGenerateRequest` branches are now gated on `imagesToSend.isEmpty` so the attachment is preserved whenever present; the dedicated reproduce pipeline handles the legitimate "attach + regenerate" intent, and everything else flows through the regular chat VLM path.

## [0.3.17] — 2026-04-23

### Fixed
- **In-app DMG download (Help → Check for Updates → Download Update) now runs at full bandwidth.** The previous implementation iterated `URLSession.shared.bytes(from:)` — an `AsyncSequence<UInt8>` — byte-by-byte, forcing a Swift-level async checkpoint *per byte*. A 15 MB DMG ended up taking 3–7 s regardless of the user's actual connection; on a gigabit link the effective throughput capped at ~2–5 MB/s, nothing to do with GitHub or the network. `UpdateDownloader` now uses a proper `URLSessionDownloadTask`, which lets the URL loading system stream the response straight to disk from its own thread and publish progress through KVO on `task.progress`. Cancellation, destination path, and the "Open DMG / Reveal in Finder" flow are unchanged. Expected: DMG download now saturates the user's connection (sub-second on fast links, bound by bandwidth everywhere else).

## [0.3.16] — 2026-04-23

### Changed
- **Model downloads now match the `hf download` CLI speed.** The previous implementation looped over `siblings` calling `hf_hub_download` file-by-file, which was strictly sequential — a 13-shard MoE like `Qwen3-Next-80B-A3B-6bit` ended up taking ~8× longer than the official CLI. Ka1zen now calls `snapshot_download` (the same entry point the CLI uses) with `max_workers=8`, dispatching concurrent downloads through a `ThreadPoolExecutor`. A custom `AggregateByteProgress` tqdm subclass aggregates per-file `update(n)` calls across threads under a lock so the progress bar stays smooth and monotonic instead of reflecting only the current file's slice. Cache layout, SHA verification, LFS handling, and revision pinning are unchanged — the same underlying `hf_hub_download` is still called per file, just in parallel. End result is byte-identical to a CLI download. Expected speedup: ~5–8× on multi-shard models, limited only by network bandwidth or the HuggingFace CDN.
- **`hf_transfer` acceleration enabled when installed, and added to the bundled prerequisites.** The Rust-based downloader used by `hf download` can give a further 2–5× speedup when the `hf_transfer` Python package is present. Ka1zen now sets `HF_HUB_ENABLE_HF_TRANSFER=1` in the download subprocess environment, but only after verifying the package can be imported — otherwise `huggingface_hub` would fail loudly. `hf_transfer` is now part of `install.sh` and the *Update Prerequisites* runner (Settings → System Models), so fresh installs and updates pick it up automatically. Existing users can click *Update Prerequisites* to add it.

## [0.3.15] — 2026-04-23

### Added
- **Redesigned Model Manager → Installed tab.** Each card used to show only name, disk size, and three generic capability badges — not enough to decide which model to launch. The card now packs a proper specs line, a metrics line, and capability badges into the same vertical space, plus a favourites marker, a free-form note, and a right-click menu of common actions. Fields added to each card:
  - **Architecture line** — `MoE · 3B / 35B · 8-bit · 262K ctx · mlx_lm · 35.2 GB`. Architecture (MoE vs Dense), active / total parameters (parsed from community naming convention, e.g. `-35B-A3B-`), quantization bits (from `config.json` or the `-Nbit` / `mxfpN` suffix), context window, chosen MLX server, and disk size.
  - **Metrics line** — fit verdict for the current Mac (🟢 Fits · 🟠 Tight · 🔴 Won't fit, computed from model size vs detected RAM), rough generation throughput estimate (`~65 t/s`, computed from active-parameter count × bit width vs the host chip's unified-memory bandwidth), last benchmark result with relative timestamp, and last time the server was actually launched for this model.
  - **Capabilities badges** — Vision / Tools / Thinking / Audio pulled from the live `config.json`, unchanged in spirit but now on their own row.
- **Installed tab filter bar.** Search by name / repo ID, sort by Family (grouped, default) · Last used · Name · Size · Throughput, and toggle chip filters: ⭐ Favourites · Running · MoE · Vision · Thinking · Fits my Mac. A *Clear* button appears whenever any filter is active. Useful when the list has grown past a dozen models and the family grouping alone isn't enough.
- **Favourites, notes, and last-used tracking.** ⭐ star any model to pin it at the top regardless of sort mode; add a short note visible on the card (e.g. *"my go-to for Swift"*). Last-used is recorded when a server actually reaches `running` (not on launch click, so failed starts don't pollute the sort).
- **Card context menu** — right-click any model to Add/Remove favourite, Add/Edit note, Run benchmark (when running), Copy model ID, Reveal in Finder, Open on HuggingFace, or Delete from disk.
- **Throughput estimator.** A lightweight `ThroughputEstimator` maps the detected chip (M5 Max / M4 Max / M3 Ultra / M1 Max …) to a rough unified-memory bandwidth and produces a `~NN t/s` generation estimate from the model's active-parameter count and quant bits. Approximations only — a real benchmark still wins — so the number is shown next to (not instead of) the `Bench NN.N t/s` value when both are available.

## [0.3.14] — 2026-04-23

### Fixed
- **Generation stats bar (tokens · t/s · peak memory · model) now survives conversation switches.** The bar was driven by a `@Published var generationStats` held in memory on `ChatViewModel`, not persisted anywhere — so leaving the conversation and coming back wiped it even though the messages themselves were intact. Stats are now attached to the assistant `Message` when the turn completes (`GenerationStats` is now `Codable`, and `Message.generationStats` is an optional field that decodes gracefully on older conversations), and the bar reads from the last assistant message's stats when the live value is absent. The model name shown in the bar also comes from the stats struct now, so switching your active model no longer relabels past turns with the wrong model.

### Changed
- **System Prompt toolbar button now shows an orange dot when the current conversation has a per-conversation prompt set.** Ka1zen's final system prompt is built from three stacked layers: Settings → General's Response Style preset, Settings → General's global custom prompt, and the per-conversation prompt from this toolbar button — all three are concatenated and sent to the model. The overlap wasn't obvious from the UI: two separate places to edit "the system prompt" and no indication that both applied. The new dot signals that a conversation-specific layer is active on top of the global defaults, and the tooltip (plus a one-line subtitle inside the popover) spells out the layering rule so the behaviour is discoverable from the UI itself.

## [0.3.13] — 2026-04-22

### Added
- **Publisher-recommended generation defaults applied at install time.** Ka1zen used to create every new model config with `temperature: 0.2`, which produced noticeably flatter output for families whose publishers recommend very different values (Qwen3 official: 0.6, Gemma 3/4: 1.0, DeepSeek-R1: 0.6). When a model is downloaded through Model Manager, Ka1zen now resolves its generation defaults in this order: (1) the repo's own `generation_config.json` if it ships one — fetched locally from the HF cache, or remotely from `huggingface.co/<repo>/raw/main/generation_config.json` with a 5 s timeout; (2) the model family's published recommendation if the repo doesn't ship one (common for community fine-tunes that strip the file) — Qwen → temp 0.6 / top_p 0.95 / top_k 20, Gemma → 1.0 / 0.95 / 64, DeepSeek → 0.6 / 0.95, Mistral → 0.7, Llama 3 → 0.8 / 0.9, Nemotron → 0.6 / 0.95; (3) a neutral 0.7 as last resort. Fields covered: `temperature`, `top_p`, `top_k`, `repetition_penalty`. The remote fetch is bounded to 5 s so a flaky network can't block a model install.
- **"Reset to publisher defaults" button in the model editor.** Existing configs created before 0.3.13 keep their old values (the auto-resolution only runs at install time, not retroactively). A new button at the top of the *Generation* section in Settings → Models → Edit pulls the same publisher → family → neutral cascade and applies it to the four sliders (temperature, top_p, top_k, repetition penalty) in one click. A short confirmation line under the button shows what was applied and from which source (*"Applied from generation_config.json: temp 0.60, top_p 0.95, top_k 20."* or *"Applied from Qwen family default: …"*). Lets users who downloaded a model under an older version of Ka1zen — or who edited their config into a bad state — get back to the publisher's recommended behaviour without deleting and re-downloading.

## [0.3.12] — 2026-04-22

### Fixed
- **Grounded image generation now triggers reliably on English prompts.** 0.3.11 detected phrasings like *"Generate an image of…"* where the image noun follows the verb immediately, but missed *"Search for X and create a **photorealistic** image of Y"* — the adjective between `create` and `image` broke the exact-substring match, and the implicit check only fired when the message started with the verb. French phrasings (`crée une image photoréaliste`) kept working because the adjective sits *after* the noun. A third detection layer now matches `<verb> … <image-noun>` within a 60-character window, tolerating any adjective between the two. Verbs covered: `generate / create / make / draw` and their French equivalents; nouns covered: `image / picture / photo / illustration / drawing / dessin`. Plain image requests (no search keyword) continue to bypass the pipeline.

## [0.3.11] — 2026-04-22

### Added
- **Grounded image generation (web-search + FLUX).** Ka1zen now detects prompts that ask for *both* a search and an image — e.g. *"Search for what a squircle is in UI design and generate an image of a photorealistic infographic on paper"* or *"Look up the Ford Mustang 1967 and draw the car at sunset in front of an American diner"* — and runs a 3-stage pipeline: `web_search` → LLM prompt synthesis (the search results are converted into concrete visual language) → FLUX generation. The resulting image is grounded in real facts retrieved live instead of whatever the model happened to remember. Sources from the web search are attached to the assistant message as clickable `[N]` citations, and both `web_search` and `generate_image` show up as Agent Steps. Detection requires BOTH an image verb (*generate / create / draw / make* and their French equivalents *génère / crée / dessine / fais*) AND a search keyword (*search / look up / on the web / find info* and their French equivalents *cherche / recherche / sur internet / trouve des infos*) in the same message — plain image requests like *"draw a dragon in an enchanted forest"* continue through the existing direct-to-FLUX path with no added latency. Best suited for technical diagrams, historical scenes, and infographic-style illustrations where factual precision improves composition; less useful for faithful product replicas (FLUX has no image-to-image reference in `mflux`, and text rendered on images remains unreliable — a FLUX-wide limitation).

## [0.3.10] — 2026-04-21

### Fixed
- **Prompt optimizer now works with reasoning models.** On Nemotron, Qwen3-Thinking, DeepSeek-R1 and similar families, clicking ✨ *Improve / Concise / Detailed…* silently did nothing: a 400-token cap inside `runQuickLLM` was being consumed entirely by the model's `<think>…</think>` reasoning block before any content tokens reached the stream, so the optimizer received an empty body and the input field was never updated. The cap is now 1500 tokens, leaving room for thinking + the rewritten prompt, and the sanitizer strips any `<think>…</think>` blocks (plus the orphan `</think>` case for templates like Nemotron Cascade / Qwopus-GLM-Healed that pre-inject `<think>\n` into the prompt). Failures and empty content are now logged (`subsystem: com.ka1zen, category: ChatViewModel`) instead of silently returning `nil`.
- **Thinking no longer flashes in the chat bubble before jumping to the Thinking section.** On Qwen3-Thinking fine-tunes, Nemotron Cascade, Qwopus and any other model whose chat template pre-injects `<think>\n` into the assistant prompt, the stream begins already inside the reasoning block — no `<think>` tag is ever emitted. The parser only detected this retroactively (once `</think>` finally arrived) so the first seconds of reasoning rendered in the visible bubble and then abruptly disappeared into the collapsible Thinking panel. A proactive synth now fires at stream start when *thinking mode is on* and no thinking marker of any format is present in the buffer, routing content into the Thinking panel from the first token. Gemma 4 26B/31B (`<|channel>thought…<channel|>`) and Gemma 4 E2B/E4B (`<|think|>…<turn|>`) are explicitly excluded from the proactive branch so their native markers are still handled by the standard parser.

## [0.3.9] — 2026-04-21

### Added
- **GPT and Nemotron families in the chat model picker.** `gpt-oss-*` (OpenAI's open-weights release), `gpt2`, `gpt-neo`, `gpt-j`, and NVIDIA's `Nemotron` models were lumped into the catch-all *Other* section, which was misleading — these are well-known families with their own behaviour profiles. They now get dedicated sections, icons, and sort alongside Qwen/Gemma/GLM. Nemotron detection runs before Llama detection so that `Llama-3.1-Nemotron-70B` and similar Llama-based Nemotron fine-tunes land in *Nemotron* instead of *Llama*.

### Changed
- **MLX toggle enabled by default in Model Manager → Browse.** The *MLX-only* filter used to start unchecked, which meant the first time a user opened Browse they saw a flood of GGUF / bnb / AWQ / GPTQ / EXL2 repos that `mlx_lm.server` cannot load. Filtering on MLX is now the default — the browse list only shows models the app can actually run. Uncheck the toggle to see the broader catalogue (e.g. when you want to download a repo for another tool).

## [0.3.8] — 2026-04-20

### Fixed
- **Chat responses no longer truncate mid-answer.** Long answers that contained the strings `\nUser:`, `\nHuman:` or `\nSystem:` anywhere in their body (for example, a French reply containing *"Système:"*, a config sample listing `User:` fields, or any enumeration that started a bullet with *System:* / *Assistant:*) were being cut off by a client-side "runaway" guard that treated those markers as a sign the model had started role-playing the next turn. The guard is removed: we now rely on the server's `finish_reason` and the model's own EOS token to end a stream, and the full response is shown regardless of what it contains. Reproduced with long technical prompts on Qwen3.6-35B-A3B-8bit and Gemma 3 27B where the answer would stop after 500-900 tokens; those same prompts now complete cleanly past 1800 tokens.

### Added
- **Download the update from inside Ka1zen.** *Help → Check for Updates…* now offers a **Download Update** button alongside *Open Release Page*. Ka1zen streams the release DMG to your `~/Downloads` folder with a live progress sheet (including a Cancel button), then lets you open the DMG or reveal it in Finder. No more round-trip to the browser for the download. The button only appears when the GitHub release has a `.dmg` asset attached; releases that ship only source or dSYM bundles still send you to the release page.

## [0.3.7] — 2026-04-20

### Added
- **Direct-URL auto-fetch.** When your message contains one or more `http(s)://` URLs, Ka1zen now skips web-search (which sees the URL as keywords and returns noise) and fetches each URL directly with `fetch_page`, up to 3 per message. The page content is injected into the model's context as `### <url>` sections, and clickable sources appear on the assistant reply. Paste a GitHub repo, an article URL or a documentation page and ask "summarise this" — the model sees the actual page.
- **GitHub native handler in `fetch_page`.** `github.com` is a React SPA whose raw HTML contains almost no text. Ka1zen now routes `github.com/<owner>/<repo>` to the REST API (README + metadata) and `github.com/<owner>/<repo>/blob/<ref>/<path>` to `raw.githubusercontent.com`, so repo URLs return real content instead of empty shells.
- **Headless WKWebView fallback for JS-rendered pages.** If the raw HTML extracts fewer than 200 characters of readable text, Ka1zen spins up a hidden `WKWebView`, lets the page's JavaScript hydrate, then reads `document.body.innerText`. Fixes Reddit, Medium, Notion, Twitter/X and other single-page apps that used to return empty results. Runs in an isolated, cookie-free session (no auth leakage).

### Changed
- **Consistent Safari 17 User-Agent** across `web_search`, `fetch_page` and the JS renderer. Minimal `Mozilla/5.0` strings were tripping bot filters on legitimate sites.
- **DDG provider fallback chain.** `web_search` now tries `html.duckduckgo.com` first and falls back to `lite.duckduckgo.com` on empty or error responses instead of giving up after one provider.
- **Smart year injection.** The automatic current-year suffix added to `web_search` queries is now skipped when the query already contains a year, looks like a URL, or isn't time-sensitive (news / prices / weather / scores). Appending `2026` to `https://github.com/...` actively hurt DDG ranking.
- **Dedicated `URLCache` (10 MB memory / 50 MB disk)** and **persistent cookie jar** (`HTTPCookieStorage.shared`) for the search session. Follow-up questions on the same topic hit the cache instead of re-crawling, and DDG's session cookie survives so repeated requests aren't flagged as fresh bot traffic.
- **Secret storage moved off the macOS Keychain.** API keys and the API Relay bearer token are now kept in an encrypted on-disk file (`~/Library/Application Support/Ka1zen/secrets.enc`, AES-GCM, key derived per-machine via HKDF-SHA256 from `IOPlatformUUID`, `0600` perms). Ad-hoc-signed builds on macOS Sequoia could not persist Keychain ACL updates — the system showed the password prompt, the right password was accepted, and the write silently failed (only ESC dismissed the dialog). Each new release re-triggered that broken prompt because the code hash changed. The new store never touches `SecItem*`, so no prompt is ever shown on launch or upgrade.

### Migration notes for users upgrading from 0.3.6
- **Model/LLM configurations, conversations, settings**: preserved (stored as JSON, not in the Keychain).
- **API keys on remote `ModelConfig`s**: not migrated. Re-enter once in Settings → Models → Edit. (Local `mlx_lm.server` setups have no API key to re-enter.)
- **API Relay bearer token**: regenerated automatically on first launch. External clients (Continue / Cursor / Zed / LM Studio) need the new value from Server → Settings → Bearer Token.
- **Orphan Keychain entries** (`com.lefbe.Ka1zen` / `modelConfig.apiKey.*`, `com.lefbe.Ka1zen` / `server.bearerToken`) remain in Keychain Access.app but are never read or written again. You can delete them manually; it's not required.

## [0.3.6] — 2026-04-19

### Added
- **Exact model sizes from HuggingFace.** Ka1zen now queries the HF Tree API for each model shown in Model Manager → Browse and Model Selection Help, sums the `.safetensors` shard sizes, and displays the real figure (e.g. `~4.8 GB`) instead of a name-parsed estimate. The name-based parse is still used as an instant fallback while the request is in flight.
- **Fit badges in Model Manager → Browse.** Every browse card now carries the same *Fits well / Tight / Won't fit / Size unclear* indicator that already existed in Model Selection Help, colour-coded and with a tooltip explaining the verdict. Decide whether a model will run on your Mac before starting the download.
- **Harmony-format support for gpt-oss.** Responses that use OpenAI's harmony schema (`<|channel|>analysis<|message|>…<|end|>`, `<|channel|>final<|message|>…<|return|>`) are parsed cleanly: the analysis block flows into the collapsible Thinking section, the final block becomes the chat bubble, structural tokens never leak into the UI.

### Changed
- **Incompatibility detection is name-only.** Earlier 0.3.5 also scanned HuggingFace tags, which produced false positives on legitimate MLX repos that inherited `bitsandbytes` / `gguf` tags from an upstream model (e.g. `JANGQ-AI/Mistral-Small-4-119B-A6B-JANG_2L`). Detection now relies exclusively on the strict community suffix convention (`-GGUF`, `-bnb-`, `-AWQ`, `-GPTQ`, `-EXL2`).
- **About, Settings and Check for Updates windows** are now anchored to the main Ka1zen window — About and Check for Updates open as sheets, and the Settings window re-centres over the main window on first display.

### Fixed
- 404 errors from `mlx_lm.server` now surface the server's response body so failures on new quantization formats can be diagnosed instead of showing a generic "Endpoint not found".

## [0.3.5] — 2026-04-19

### Added
- **Download from Model Selection Help.** Each recommendation and search result now has an inline Download button wired to the shared installer, so a download started from the Help sheet shows up immediately in Model Manager → Browse (and vice-versa).
- **Multi-source search.** The Help sheet's live search now queries every HuggingFace org configured in Model Manager → Browse (not just `mlx-community`). Results from non-default orgs carry an author chip so cross-source matches stay legible.
- **Incompatible-format detection.** Repos shipping weights the MLX server can't load — **GGUF** (llama.cpp), **bitsandbytes** (`-bnb-4bit`, NF4), **AWQ**, **GPTQ**, **EXL2** — are now detected from the repo name / HF tags and shown with an *"Incompatible with MLX server"* badge. Download is blocked at the UI *and* the installer level; installed incompatibles swap the Launch button for Delete with a tooltip explaining why and where to find an MLX build.

### Changed
- Refactored download bookkeeping into a shared `ModelInstaller` singleton so the Help sheet and Model Manager observe a single source of truth for installed / downloading / failed state.

## [0.3.4] — 2026-04-19

### Added
- **Help → Check for Updates…** queries the GitHub Releases API and tells you whether a newer Ka1zen is available. If so, a button opens the release page; otherwise it confirms you're on the latest version. Manual only — no background polling.

## [0.3.3] — 2026-04-18

### Added
- **Model Selection Help** window (Help menu → *Model Selection Help…*, ⌘⇧M). Detects the host Mac (chip, RAM, free disk), shows three curated `mlx-community` models for its RAM tier, and offers a live search of `mlx-community` with a fit indicator (Fits well / Tight / Won't fit / Size unclear) computed from the model's naming convention — no HuggingFace API round-trip required per keystroke. Links out to [MODEL_GUIDE.md](https://github.com/Flor1an-B/Ka1zen/blob/main/MODEL_GUIDE.md) on GitHub for deeper explanations.

## [0.3.2] — 2026-04-18

### Added
- **Update prerequisites** button (in Settings → System Models and in the Preflight footer) that runs `pip install -U` for `mlx-lm`, `mlx-vlm`, `huggingface-hub`, and upgrades `mflux` via the install path it was set up with (pip or `uv tool`). Live streaming log with per-package status.
- **Extra launch args** advanced field on every model (Settings → Edit model). Appended to `mlx_lm.server` / `mlx_vlm.server` when the endpoint is local — lets power users pass flags like `--trust-remote-code`, `--draft-model`, `--adapter-path`. `--host`, `--port`, and `--model` are reserved by Ka1zen and filtered out.
- README credits for [Apple MLX](https://github.com/ml-explore/mlx), [mlx-community](https://huggingface.co/mlx-community) and [Hugging Face](https://huggingface.co/).

## [0.3.1] — 2026-04-18

### Added
- FLUX.2 image generation integration via `mflux` with automatic prompt optimization.
- Token Inspector panel with per-token logprob colouring (green / yellow / orange / red).
- API Relay: optional Bearer token and "Allow LAN" toggle.
- Onboarding: automatic RAM detection and first-model suggestion.

### Changed
- Web search: DuckDuckGo provider, auto-enrichment of short follow-up questions.
- RAG: Apple `NLEmbedding` (300-dim) replaces previous embedding backend; local SQLite storage via GRDB.
- Prerequisites screen now rechecks `mflux` detection via both `pip` and `uv tool install`.

### Fixed
- Serialized FLUX generation requests through a dedicated actor to avoid concurrent GPU calls.
- Clickable `[N]` citations no longer reference out-of-range sources.

## [0.3.0] — 2026-04-14

### Added
- Thinking-mode UI: collapsible reasoning block for Qwen3 / DeepSeek-R1 / Gemma 3-4 / Mistral Small 4+.
- Multi-model runtime: simultaneous `mlx_lm.server` (8080) and `mlx_vlm.server` (8081).
- Conversation export: Markdown, PDF, JSON, plain text.
- Text-to-Speech with premium-voice preference and language auto-detect.

### Changed
- Native macOS chat font-size slider (11–24 pt).

## Earlier versions

Earlier versions were internal / pre-release and are not documented here.
