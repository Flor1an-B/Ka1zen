# Changelog

All notable changes to Ka1zen are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
