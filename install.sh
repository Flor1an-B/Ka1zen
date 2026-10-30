#!/usr/bin/env bash
#
# Ka1zen — installs the Python dependencies needed by the app.
# Usage: ./install.sh
#
# Requirements: macOS 15 Sequoia or newer, on Apple Silicon.
# This script installs mlx-lm, mlx-vlm, huggingface-hub, hf_transfer and
# mflux into the official python.org Python 3.14+. It does not touch the
# system Python or Homebrew.

set -euo pipefail

BOLD="$(tput bold 2>/dev/null || true)"
DIM="$(tput dim 2>/dev/null || true)"
RED="$(tput setaf 1 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
YELLOW="$(tput setaf 3 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

info()  { echo "${BOLD}${GREEN}==>${RESET} ${BOLD}$*${RESET}"; }
warn()  { echo "${BOLD}${YELLOW}==>${RESET} ${BOLD}$*${RESET}"; }
fail()  { echo "${BOLD}${RED}==>${RESET} ${BOLD}$*${RESET}" >&2; exit 1; }

# --- 1. Locate a Python 3.14+ interpreter under /Library/Frameworks ---
FRAMEWORK_ROOT="/Library/Frameworks/Python.framework/Versions"
CHOSEN_VERSION=""

if [ -d "$FRAMEWORK_ROOT" ]; then
    while IFS= read -r version; do
        [ -z "$version" ] && continue
        # Only consider entries shaped like "X.Y" (skip "Current" symlink etc.)
        if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
            continue
        fi
        major="${version%%.*}"
        minor="${version##*.}"
        if [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -ge 14 ]; }; then
            if [ -x "$FRAMEWORK_ROOT/$version/bin/python3" ]; then
                if [ -z "$CHOSEN_VERSION" ] || [ "$version" \> "$CHOSEN_VERSION" ]; then
                    CHOSEN_VERSION="$version"
                fi
            fi
        fi
    done < <(ls "$FRAMEWORK_ROOT" 2>/dev/null || true)
fi

if [ -z "$CHOSEN_VERSION" ]; then
    warn "Python 3.14+ not found in /Library/Frameworks/Python.framework/"
    echo
    echo "  Ka1zen requires the official Python installer from python.org."
    echo "  Homebrew and pyenv won't work (wrong location)."
    echo
    echo "  ${BOLD}Download Python 3.14 here:${RESET} https://www.python.org/downloads/macos/"
    echo "  Pick 'macOS 64-bit universal2 installer'."
    echo
    read -p "Press Enter to open the download page…"
    open "https://www.python.org/downloads/macos/"
    echo
    fail "Re-run this script after installing Python 3.14."
fi

PY_BIN="$FRAMEWORK_ROOT/$CHOSEN_VERSION/bin"
PY="$PY_BIN/python3"
PIP="$PY_BIN/pip3"

info "Detected Python: $CHOSEN_VERSION ($PY)"

# --- 2. Upgrade pip to avoid resolver quirks ---
info "Upgrading pip"
"$PIP" install --upgrade pip >/dev/null

# --- 3. Install packages (PINNED to validated versions) ---
# We pin exact versions instead of `--upgrade`. mlx-vlm bumped 0.7.2 → 0.7.8
# (validated 2026-10-14, real prod Python.framework — `import mlx_vlm` 5/5
# stable, mlx_vlm.server real chat completions + tool-calls clean on both
# Gemma 4 E4B dense+MTP (assistant drafter, mechanism intact, ~1.2x on this
# small model — the 31B/27B pair used for the historical 1.94x/2.6x numbers
# wasn't cached on the test machine this round, so the full MTP/DFlash
# speed battery wasn't re-run; spot-check Fast Mode once this ships) and
# Qwen 3.6 35B-A3B MoE (no drafter, per the standing MoE+MTP policy below).
# 0.7.8 requires mlx>=0.32.3 (was >=0.32.2) and mlx-audio>=0.5.2 (was
# >=0.4.8) — both bumped to their current latest (0.32.3 / 0.5.9) to match;
# mlx-audio isn't independently pinned here, it rides along as mlx-vlm's
# transitive dependency. 0.6.0, 0.6.4 and 0.6.16 stay denylisted.
# transformers/tokenizers/datasets bumped alongside (5.14.1→5.19.0,
# 0.22.2→0.23.3, 4.8.5→5.1.0 respectively) — see the huggingface-hub note
# right below for why. Ka1zen version-gates MoE Fast Mode on mlx-vlm ≥ 0.6.3
# (SpeculativeDecoding.moeMTPSupported).
#
# huggingface-hub: bumped 1.17.0 → 2.2.0 (2026-10-14). FIRST attempt at this
# got reverted on a surface-level `pip check` reading (transformers 5.14.1/
# tokenizers 0.22.2/datasets 4.8.5, all still on OLD versions at the time,
# declared `huggingface-hub<2.0` — that's what `pip check` was actually
# flagging). Re-investigated properly: on PyPI, transformers 5.19.0,
# tokenizers 0.23.3 and datasets 5.1.0 already declare
# `huggingface-hub<3.0,>=1.31.0` — fully compatible with 2.x. Bumping all
# three (above) makes those three conflicts disappear for real, verified
# on the real prod Python.framework: `import mlx_vlm` stable 5/5,
# mlx_vlm.server real chat completion + tool-call clean. Two conflict
# lines remain in `pip check` and are BOTH confirmed cosmetic, not
# functional:
#   - `mflux 0.17.5 requires huggingface-hub<2.0` — same already-accepted
#     class of noise as its `mlx<0.32.0` complaint below (dead pip fallback,
#     real image-gen uses the separate uv-tool mflux). Verified mflux's own
#     CODE still imports fine against huggingface-hub 2.2.0
#     (`from mflux.models.flux2 import Flux2Klein` succeeds) — the `<2.0`
#     bound is just a stale, over-conservative pin, not a real break.
#   - `diffusers 0.38.0 requires huggingface-hub<2.0` — diffusers itself
#     turned out to be ORPHANED in this environment: `pip show diffusers`
#     shows no `Required-by` at all (nothing in Ka1zen's stack — not
#     mlx-vlm, not mlx-audio, not either mflux — pulls it in), and its
#     dist-info has a `REQUESTED` marker, meaning it was installed directly
#     at some point, not as a dependency. Its stale pin is noise from a
#     package nothing actually uses. Runtime Health's `DependencyInspector.
#     pipCheck()` now excludes both of these lines by name (same treatment
#     as the existing mflux exclusion) so this doesn't surface as a
#     misleading "fix me" warning.
#
# `mflux` stays UNPINNED ON PURPOSE — tried pinning it to 0.20.0 on
# 2026-09-23 to silence its cosmetic `pip check` conflict with `mlx` (it
# declares `mlx<0.32.0`, which Ka1zen's `mlx==0.32.x` pin always trips —
# harmless, since `ImageGenerationTool` actually runs the separate
# `uv tool install`-managed mflux, not this pip one). That pin transitively
# bumped `torch` 2.12.0 → 2.14.0 (mflux 0.20.0 requires torch>=2.13), and
# WITH torch 2.14.0 installed alongside it, `import mlx_vlm` started
# crashing intermittently (SIGSEGV/SIGBUS, no Python traceback — 3/3 repro,
# ~112 GB free RAM at the time so not a memory-pressure fluke) — a real
# native-extension incompatibility between the two in the same process,
# root cause not isolated further. Reverted immediately (real prod install
# restored to mflux==0.17.5 + torch==2.12.0, re-verified stable 5/5). DO NOT
# re-attempt pinning `mflux` past 0.17.5 in this shared pip environment
# without first confirming `import mlx_vlm` stays crash-free with whatever
# torch version that mflux version pulls in. The in-app "Runtime Health"
# panel tracks the same validated set.
#
# **2026-10-30: mlx-vlm 0.7.8 → 0.7.11, mlx-lm 0.31.3 → 0.32.2 (first mlx-lm
# move in months), huggingface-hub 2.2.0 → 2.4.0.** Real prod Python.framework
# test: `import mlx_vlm` stable 5/5, `pip check` unchanged (still only the
# already-excluded mflux/diffusers lines — transformers/tokenizers stayed put,
# nothing forced a bump). mlx-vlm 0.7.11 requires mlx>=0.32.4 (was >=0.32.3)
# and mlx-audio>=0.6.2 (was >=0.5.2) — bumped to current latest (0.32.4 /
# 0.6.3). Gemma-4-12B-it-qat-4bit dense + MTP (assistant drafter) re-verified:
# ~1.37x speedup (40.4 → 55.2 t/s), non-regressed vs the 1.25x measured on
# 0.7.8 two weeks ago — if anything slightly better, well within normal
# bench-to-bench variance. Real chat completion + tool-call clean on both
# that pair and the mlx-lm 0.32.2 path (`mlx_lm.server` binary, used for
# non-vision/text-only models — confirmed via `ModelLauncher.swift`: VLM-
# tagged models always route through mlx_vlm.server regardless of this pin,
# so mlx-lm's own ~380-commit gap was almost entirely new-model support,
# nothing touching Ka1zen's actual usage). huggingface-hub 2.4.0: no new
# breaking changes for this stack (checked both 2.3.0 and 2.4.0 release
# notes — Buckets, CLI extensions, inference-client fixes, nothing affecting
# transformers/tokenizers/mlx-vlm compatibility).
PACKAGES=(
    "mlx-lm==0.32.2"
    "mlx-vlm==0.7.11"
    "transformers==5.19.0"
    "tokenizers==0.23.3"
    "datasets==5.1.0"
    "huggingface-hub==2.4.0"
    "hf-transfer==0.1.9"
    "mflux"
    "mlx==0.32.4"   # MUST stay last — guards against any mflux mlx-downgrade (see note above)
)

for pkg in "${PACKAGES[@]}"; do
    info "Installing $pkg"
    "$PIP" install "$pkg"
done

# --- 4. Install llama.cpp (GGUF backend, Metal) — PINNED build ---
# Ka1zen uses llama.cpp's `llama-server` to run GGUF models — the day-one bridge
# for architectures too new for MLX (e.g. Gemma 4 12B / gemma4_unified). We use
# the engine directly (not Ollama/LM Studio, which merely wrap it).
#
# We pin an EXACT release build into Application Support rather than relying on
# `brew install llama.cpp` (a moving bottle that lagged at 9430, before Gemma 4
# unified vision landed). Ka1zen's LlamaServerResolver prefers this managed
# binary over any Homebrew one, so the GGUF backend is reproducible and a later
# `brew upgrade` can't change the version Ka1zen runs. The release tarball is
# self-contained (dylibs via @loader_path). Falls back to Homebrew if the
# download fails.
LLAMA_BUILD="b12005"
LLAMA_DEST="$HOME/Library/Application Support/Ka1zen/llama"
LLAMA_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_BUILD}/llama-${LLAMA_BUILD}-bin-macos-arm64.tar.gz"
info "Installing llama.cpp ${LLAMA_BUILD} (GGUF backend, pinned)"
LLAMA_TMP="$(mktemp -d)"
if curl -fsSL -o "$LLAMA_TMP/llama.tar.gz" "$LLAMA_URL" \
   && tar xzf "$LLAMA_TMP/llama.tar.gz" -C "$LLAMA_TMP" 2>/dev/null \
   && LLAMA_BIN="$(find "$LLAMA_TMP" -name llama-server -type f | head -1)" \
   && [ -n "$LLAMA_BIN" ]; then
    mkdir -p "$LLAMA_DEST"
    cp "$(dirname "$LLAMA_BIN")/llama-server" "$LLAMA_DEST/"
    cp "$(dirname "$LLAMA_BIN")"/*.dylib "$LLAMA_DEST/" 2>/dev/null
    xattr -dr com.apple.quarantine "$LLAMA_DEST" 2>/dev/null || true
    codesign --force --sign - "$LLAMA_DEST"/*.dylib "$LLAMA_DEST/llama-server" 2>/dev/null || true
    echo "  ${GREEN}✓${RESET} llama-server pinned ${LLAMA_BUILD} → ${LLAMA_DEST}"
else
    warn "Could not fetch pinned llama.cpp ${LLAMA_BUILD}; falling back to Homebrew."
    if command -v brew >/dev/null 2>&1; then
        brew install llama.cpp || warn "llama.cpp install failed — GGUF models won't run until you run: brew install llama.cpp"
    else
        echo "  Install Homebrew (https://brew.sh), then run: ${BOLD}brew install llama.cpp${RESET}"
    fi
fi
rm -rf "$LLAMA_TMP"

# --- 5. Sanity check — imports + binaries ---
info "Checking imports"
for mod in mlx_lm mlx_vlm huggingface_hub mflux; do
    if "$PY" -c "import $mod" 2>/dev/null; then
        echo "  ${GREEN}✓${RESET} $mod"
    else
        echo "  ${RED}✗${RESET} $mod"
    fi
done
# Prefer the pinned managed binary (what Ka1zen actually runs); fall back to a
# PATH/Homebrew llama-server. llama.cpp switched to semantic versioning
# (upstream #26839, ~b10375+): `--version` now prints "version: X.Y.Z-dev
# (build N, commit H)" instead of the old "version: N (H)", so a naive
# `version: [0-9]*` grep matches the leading digit of X.Y.Z and always
# reports "0" — prefer the `(build N…)` group and fall back to the old shape,
# matching `LlamaServerResolver.readBuildNumber`'s hardened parser.
llama_build() {
    local out; out="$("$1" --version 2>&1)"
    local n; n="$(echo "$out" | grep -oE 'build [0-9]+' | grep -oE '[0-9]+' | head -1)"
    [ -z "$n" ] && n="$(echo "$out" | grep -oE 'version: [0-9]+' | grep -oE '[0-9]+' | head -1)"
    echo "build $n"
}
if [ -x "$LLAMA_DEST/llama-server" ]; then
    echo "  ${GREEN}✓${RESET} llama-server pinned ($(llama_build "$LLAMA_DEST/llama-server"))"
elif command -v llama-server >/dev/null 2>&1; then
    echo "  ${GREEN}✓${RESET} llama-server ($(llama_build llama-server)) — Homebrew fallback"
else
    echo "  ${YELLOW}–${RESET} llama-server (optional — needed only for GGUF models)"
fi

echo
info "Done."
echo "${DIM}Now launch Ka1zen from /Applications.${RESET}"
