# Choosing a model for your Mac

This guide helps you pick the right local model for your hardware — what the weird names mean, why MoE matters, and which [`mlx-community`](https://huggingface.co/mlx-community) releases are safe bets at each RAM tier.

> **TL;DR** — match the **4-bit disk size** of the model to **about half your RAM**. The other half is for the KV cache (context), macOS, and whatever else you run. When in doubt, start smaller: a model that actually fits and streams at 30 tok/s beats a bigger one that crashes or crawls at 2 tok/s.

## Table of contents

- [Quick pick by RAM](#quick-pick-by-ram)
- [How to read an MLX model name](#how-to-read-an-mlx-model-name)
- [Dense vs MoE — and why it matters](#dense-vs-moe--and-why-it-matters)
- [Quantization — 4-bit vs 6-bit vs 8-bit](#quantization--4-bit-vs-6-bit-vs-8-bit)
- [Capabilities — Vision, Audio, Thinking, Tools](#capabilities--vision-audio-thinking-tools)
- [Recommendations by RAM tier](#recommendations-by-ram-tier)
- [Practical tips](#practical-tips)
- [Why mlx-community?](#why-mlx-community)

---

## Quick pick by RAM

| Your Mac | Recommended size | Good starting model |
|---|---|---|
| **8 GB** (M1/M2/M3 base) | 3–4 B at 4-bit | [`Phi-4-mini-instruct-4bit`](https://huggingface.co/mlx-community/Phi-4-mini-instruct-4bit) · [`Qwen3-4B-4bit`](https://huggingface.co/mlx-community/Qwen3-4B-4bit) |
| **16 GB** | 7–14 B at 4-bit | [`Qwen3-8B-4bit`](https://huggingface.co/mlx-community/Qwen3-8B-4bit) · [`Mistral-Small-4-4bit`](https://huggingface.co/mlx-community/Mistral-Small-4-4bit) |
| **24 GB** | 14–24 B at 4-bit | [`Qwen3-14B-4bit`](https://huggingface.co/mlx-community/Qwen3-14B-4bit) · [`Mistral-Small-3-24B-Instruct-4bit`](https://huggingface.co/mlx-community/Mistral-Small-3-24B-Instruct-4bit) |
| **32 GB** | up to 31 B at 4-bit | [`gemma-4-31b-it-4bit`](https://huggingface.co/mlx-community/gemma-4-31b-it-4bit) · [`Qwen3-32B-4bit`](https://huggingface.co/mlx-community/Qwen3-32B-4bit) |
| **48 GB** | up to 32 B at 6-bit, MoE ~70 B | [`Qwen3-32B-6bit`](https://huggingface.co/mlx-community/Qwen3-32B-6bit) |
| **64 GB** | up to 70 B at 4-bit | [`Llama-3.3-70B-Instruct-4bit`](https://huggingface.co/mlx-community/Llama-3.3-70B-Instruct-4bit) |
| **96 GB** | 70 B at 6–8 bit, first MoEs | [`Llama-3.3-70B-Instruct-6bit`](https://huggingface.co/mlx-community/Llama-3.3-70B-Instruct-6bit) |
| **128 GB** | very large MoEs at 4-bit | [`Qwen3.5-122B-A10B-4bit`](https://huggingface.co/mlx-community/Qwen3.5-122B-A10B-4bit) |
| **192 GB+** (M-Ultra) | frontier MoEs at 4-bit | DeepSeek-V3-style 600 B-A37B MoEs |

Sizes assume **4-bit MLX quantization**. Rule of thumb for disk/memory footprint:

- `N B` dense at 4-bit ≈ **0.55 × N GB** on disk, plus **~10–30 %** for the KV cache at your chosen context length.
- MoE `N B-AK B` → same disk as an `N B` dense, but **only `K B` worth** is active per token. That's the whole point (see below).

---

## How to read an MLX model name

Example: `mlx-community/Qwen3.5-122B-A10B-4bit`

```
mlx-community/Qwen3.5-122B-A10B-4bit
└─────┬─────┘ └──┬─┘ └┬─┘ └─┬─┘ └─┬─┘
      │         │    │    │    └── quantization (see below)
      │         │    │    └─────── active parameters per token (MoE only)
      │         │    └──────────── total parameters (122 billion)
      │         └───────────────── model family / version
      └─────────────────────────── HuggingFace org
```

Common suffixes you'll see:

| Suffix | Meaning |
|---|---|
| `-it`, `-Instruct` | Instruction-tuned (chat-ready). Always prefer this over base models. |
| `-Base` | Raw pre-trained, no chat behaviour. Avoid unless you know what you're doing. |
| `-R1`, `-Thinking`, `-reasoning` | Fine-tuned to emit a `<think>` block before the answer. Show it up via **Thinking mode** in Ka1zen. |
| `-vision`, `-vl`, `-VL` | Vision-capable (image input). Runs under `mlx_vlm.server`. |
| `-audio`, `-omni` | Audio input (and sometimes output). Also VLM. |
| `-MoE`, `-Ax B` | Mixture of Experts. `A10B` means 10 B parameters are active per token. |
| `-4bit`, `-6bit`, `-8bit`, `-bf16` | Quantization precision (see below). Smaller = less RAM, slightly worse quality. |

Not all models use every suffix. `gemma-4-31b-it-4bit` is an instruction-tuned 31 B Gemma 4, quantized to 4-bit. No MoE, no vision explicitly in the name — but Gemma 4 happens to be multimodal, so it *is* a VLM. The only reliable source of truth is the model card on HuggingFace.

---

## Dense vs MoE — and why it matters

**Dense models** use every parameter for every token. A 70 B dense model does ~70 B operations per token. Simple, predictable — but every token pays the full memory-bandwidth bill.

**MoE (Mixture of Experts)** models keep a pool of specialist "experts" and a small router that picks a few per token. The weights *sit* in memory, but the *compute* only touches a subset.

```
Dense 70 B:          Every token uses all 70 B params → heavy
MoE 122B-A10B:       Every token uses only 10 B params → fast
                     (but 122 B still has to fit in RAM)
```

**When MoE wins:**
- **Chat UX** — first-token latency is tied to active params, so 122B-A10B feels like a 10 B at the keyboard but reasons like a 122 B in the answer.
- **Long contexts** — the compute savings stack up on 32k+ prompts.
- **You have RAM to spare** — MoE needs the full weight budget even if only part runs per token.

**When dense wins:**
- **Small models** (< 15 B) — MoE overhead isn't worth it.
- **Reasoning tasks with heavy tool use** — some dense reasoning models (DeepSeek-R1-Distill, QwQ) still beat mid-tier MoEs on math/code benchmarks.
- **Tight RAM** — a 32 B dense at 4-bit (~17 GB) fits a 32 GB Mac; a 70B-A10B MoE at 4-bit (~38 GB) does not.

**Rule of thumb:** if your Mac has ≥ 64 GB and you want both speed *and* quality, look at MoE. Below that, stick to dense.

---

## Quantization — 4-bit vs 6-bit vs 8-bit

Quantization compresses the model weights. MLX supports several precisions; the trade-off is **file size / RAM vs output quality**.

| Precision | Size (vs bf16) | Quality loss | When to use |
|---|---|---|---|
| **bf16 / fp16** | 100 % | none (reference) | Benchmarks only. 16 GB for an 8 B model. |
| **8-bit** | 50 % | negligible | When you have RAM to spare and want maximum fidelity. |
| **6-bit** | ~37 % | very small | Sweet spot for 30–70 B models on 48–96 GB Macs. |
| **4-bit** | ~25 % | small but noticeable on some reasoning tasks | **Default choice.** What the MLX community ships by default. |
| **3-bit**, **2-bit** | ~19 % / 12.5 % | significant, especially on small models | Experimental. Only for very large models (70 B+) on very small Macs. |

For most users: **start at 4-bit**. If you notice the model making silly mistakes it shouldn't, try 6-bit or 8-bit of the same model — it's usually one search away on `mlx-community`.

---

## Capabilities — Vision, Audio, Thinking, Tools

Ka1zen detects capabilities automatically from the model card, but here's what each flag means:

- **Vision** — the model can see images. Uses `mlx_vlm.server` (port 8081 by default). Attach images in chat with the paperclip.
- **Audio** — the model accepts audio input (currently Gemma 4 Vision). Use the mic icon.
- **Thinking** — the model emits a `<think>…</think>` reasoning block. Ka1zen shows it in a collapsible panel.
- **Tools** — the model can call functions. Required for web search, file reading, etc. Enable in **Settings → General → Tools**.

Most 2024+ instruction-tuned models support Tools. Vision and Thinking are model-specific (check the HF card). Audio is rare — mostly Gemma 4 and the "omni" releases.

---

## Recommendations by RAM tier

All models below are from [`mlx-community`](https://huggingface.co/mlx-community) — click through to read the full card before downloading.

### 8–16 GB — entry Macs (M1/M2/M3 base)

For fast interactive chat. Don't expect frontier reasoning.

| Model | Size | Why |
|---|---|---|
| [`Phi-4-mini-instruct-4bit`](https://huggingface.co/mlx-community/Phi-4-mini-instruct-4bit) | ~2.5 GB | Microsoft's compact reasoner. Fast, surprisingly capable. |
| [`Qwen3-4B-4bit`](https://huggingface.co/mlx-community/Qwen3-4B-4bit) | ~2.5 GB | Strong multilingual, tools-ready. |
| [`Qwen3-8B-4bit`](https://huggingface.co/mlx-community/Qwen3-8B-4bit) | ~4.5 GB | Great all-rounder at 16 GB. |
| [`DeepSeek-R1-Distill-Qwen-7B-4bit`](https://huggingface.co/mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit) | ~4 GB | Reasoning-focused. Turn on **Thinking mode**. |
| [`gemma-4-4b-it-4bit`](https://huggingface.co/mlx-community/gemma-4-4b-it-4bit) | ~2.5 GB | Vision-capable in a small footprint. |

### 24–32 GB — the sweet spot

Runs any "flagship lite" model comfortably with room for tools and context.

| Model | Size | Why |
|---|---|---|
| [`Qwen3-14B-4bit`](https://huggingface.co/mlx-community/Qwen3-14B-4bit) | ~8 GB | Smart, fast, tools. |
| [`Mistral-Small-3-24B-Instruct-4bit`](https://huggingface.co/mlx-community/Mistral-Small-3-24B-Instruct-4bit) | ~13 GB | Mistral's best mid-size. |
| [`Qwen3-32B-4bit`](https://huggingface.co/mlx-community/Qwen3-32B-4bit) | ~17 GB | 32 GB only — tight but works. |
| [`gemma-4-31b-it-4bit`](https://huggingface.co/mlx-community/gemma-4-31b-it-4bit) | ~17 GB | Multimodal (vision + audio). |
| [`Mistral-Small-4-4bit`](https://huggingface.co/mlx-community/Mistral-Small-4-4bit) | ~14 GB | Latest Small with vision. |

### 48–64 GB — serious local setups

70 B dense becomes available. Context windows can go wide.

| Model | Size | Why |
|---|---|---|
| [`Qwen3-32B-6bit`](https://huggingface.co/mlx-community/Qwen3-32B-6bit) | ~25 GB | Same 32 B, better quality. |
| [`Llama-3.3-70B-Instruct-4bit`](https://huggingface.co/mlx-community/Llama-3.3-70B-Instruct-4bit) | ~39 GB | Meta's flagship dense. |
| [`QwQ-32B-4bit`](https://huggingface.co/mlx-community/QwQ-32B-4bit) | ~17 GB | Dedicated reasoning model. |
| [`Qwen3-72B-4bit`](https://huggingface.co/mlx-community/Qwen3-72B-4bit) | ~40 GB | Alternative 70-class. |

### 96–128 GB — MoE territory

The reason to spend on a higher RAM tier.

| Model | Size | Why |
|---|---|---|
| [`Llama-3.3-70B-Instruct-6bit`](https://huggingface.co/mlx-community/Llama-3.3-70B-Instruct-6bit) | ~55 GB | Near-reference quality 70 B. |
| [`Qwen3.5-122B-A10B-4bit`](https://huggingface.co/mlx-community/Qwen3.5-122B-A10B-4bit) | ~65 GB | Fast chat (10 B active) with 122 B knowledge. |
| [`Mistral-Large-Instruct-2411-4bit`](https://huggingface.co/mlx-community/Mistral-Large-Instruct-2411-4bit) | ~65 GB | Mistral's top dense. |

### 192 GB+ — M-Ultra / M-Max Studio

Frontier models at home.

| Model | Size | Why |
|---|---|---|
| [`DeepSeek-V3-4bit`](https://huggingface.co/mlx-community/DeepSeek-V3-4bit) | ~340 GB | 671 B-A37B MoE. Flagship OSS reasoning. |
| [`Qwen3.5-235B-A22B-4bit`](https://huggingface.co/mlx-community/Qwen3.5-235B-A22B-4bit) | ~120 GB | Larger Qwen MoE. |

New releases drop on `mlx-community` weekly — the **Browse HuggingFace** tab in Ka1zen is the fastest way to check what's new.

---

## Practical tips

- **Start smaller than you think.** A 14 B that streams at 40 tok/s feels better than a 70 B at 8 tok/s for 95 % of chats.
- **Leave room for context.** A 32 B at 4-bit is ~17 GB, but with a 32k context window, the KV cache can add another 6–10 GB. If your Mac is 32 GB total, you'll swap.
- **Unload before switching.** Ka1zen's **Unload** button (or the red "Stop" on a running server) frees the RAM immediately. Two 32 B models at once on 32 GB won't work.
- **Out-of-memory crashes** usually mean: context too long, `max_tokens` too high, or the model is too big for 4-bit on your Mac. Drop `max_tokens` to 4096 and re-try.
- **Slow first response, fast after** is normal — MLX compiles the graph on the first inference. Subsequent turns are dramatically faster.
- **Prefer `-it` / `-Instruct` models** for chat. Base models will ramble.
- **MoEs need RAM, not cores.** If you have 96 GB+, MoE becomes the best speed / quality trade. Below that, stick to dense.
- **Check the HF card for a prompt template.** MLX usually handles this automatically, but some exotic fine-tunes need a specific system prompt to behave.

---

## Why mlx-community?

[`mlx-community`](https://huggingface.co/mlx-community) is the Hugging Face org maintained by the MLX community — it hosts **MLX-native quantizations** of essentially every major open model within days of release. Using their builds instead of raw HF models means:

- Correct MLX quantization (not a GGUF or safetensors you'd have to convert yourself).
- The `mlx_lm.server` / `mlx_vlm.server` config files are already in place.
- Files are split into shards that download incrementally — if one fails, Ka1zen resumes without restarting.

**Huge thanks** to the maintainers — they're the reason on-device AI on the Mac is even approachable. If you use their models, star the org on HuggingFace. It takes two seconds.

Underlying credits also to [Apple MLX](https://github.com/ml-explore/mlx) ([`@ml_explore`](https://x.com/ml_explore), [`@awnihannun`](https://x.com/awnihannun)) — without the framework, none of this would run on Apple Silicon.

---

## See also

- [USER_GUIDE.md](USER_GUIDE.md) — full Ka1zen feature walkthrough.
- [CHANGELOG.md](CHANGELOG.md) — version history.
- [huggingface.co/mlx-community](https://huggingface.co/mlx-community) — the actual model hub.
- [github.com/ml-explore/mlx](https://github.com/ml-explore/mlx) — MLX framework.
