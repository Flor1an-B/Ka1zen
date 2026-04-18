# Changelog

All notable changes to Ka1zen are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
