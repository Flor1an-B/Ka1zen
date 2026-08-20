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
# We pin exact versions instead of `--upgrade`. mlx-vlm is pinned to 0.6.15
# (validated 2026-08-20, non-regression vs 0.6.13 against real installed
# weights, tested in the EXACT combo that ships — mlx-vlm 0.6.15 + mlx 0.32.0
# (0.6.15 only needs mlx>=0.32.0; the trailing `mlx==0.32.0` pin below always
# wins anyway, so mlx 0.32.1's release the same week changes nothing here):
# the #1317 MoE+MTP repro clean (114.2 t/s, 0 CJK), a 2-turn conversation
# clean, Gemma 4 E4B dense + MTP clean (109.3 t/s), DiffusionGemma mxfp4 still
# clean. 0.6.14/0.6.15 are serving-path polish (prefix-cache fix for short
# first prompts #1901, batched-row independence fix #1946) — no regression
# class; `thinking_budget` (#1912) doesn't apply, Ka1zen never sets it. It
# still carries the 0.6.5 fix for the 0.6.4 regression that broke qwen3_5
# inference (#1521), plus 0.6.9's #1748/#1754 and 0.6.13's #1864 tool-call
# fix. 0.6.0 and 0.6.4 are denylisted. transformers unchanged (needs >= 5.14.0;
# prod keeps 5.14.1, fresh install resolves ~5.15.x, both verified clean
# historically). IMPORTANT: mflux caps mlx<0.32.0 (all versions, incl. 0.18.0),
# so installing mflux AFTER mlx-vlm makes pip DOWNGRADE mlx to 0.31.2 to
# satisfy mflux — which breaks mlx-vlm (needs >= 0.32.0). So `mlx==0.32.0` is
# pinned LAST to force it back up after mflux; the end state is mlx 0.32.0
# with a harmless pip conflict warning about mflux (image generation is
# runtime-verified working on 0.32.0 — the cap is conservative, not a real
# break). Ka1zen version-gates MoE Fast Mode on mlx-vlm ≥ 0.6.3
# (SpeculativeDecoding.moeMTPSupported). The in-app "Runtime Health" panel
# tracks the same validated set. 0.6.0 and 0.6.4 are denylisted.
PACKAGES=(
    "mlx-lm==0.31.3"
    "mlx-vlm==0.6.15"
    "huggingface-hub==1.17.0"
    "hf-transfer==0.1.9"
    "mflux"
    "mlx==0.32.0"   # MUST stay last — undoes mflux's mlx downgrade (see note above)
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
LLAMA_BUILD="b10509"
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
# PATH/Homebrew llama-server.
if [ -x "$LLAMA_DEST/llama-server" ]; then
    echo "  ${GREEN}✓${RESET} llama-server pinned ($("$LLAMA_DEST/llama-server" --version 2>&1 | grep -o 'version: [0-9]*' | head -1))"
elif command -v llama-server >/dev/null 2>&1; then
    echo "  ${GREEN}✓${RESET} llama-server ($(llama-server --version 2>&1 | grep -o 'version: [0-9]*' | head -1)) — Homebrew fallback"
else
    echo "  ${YELLOW}–${RESET} llama-server (optional — needed only for GGUF models)"
fi

echo
info "Done."
echo "${DIM}Now launch Ka1zen from /Applications.${RESET}"
