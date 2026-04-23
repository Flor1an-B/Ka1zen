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

# --- 3. Install packages ---
PACKAGES=(mlx-lm mlx-vlm huggingface-hub hf_transfer mflux)

for pkg in "${PACKAGES[@]}"; do
    info "Installing $pkg"
    "$PIP" install --upgrade "$pkg"
done

# --- 4. Sanity check — can Python import each package? ---
info "Checking imports"
for mod in mlx_lm mlx_vlm huggingface_hub mflux; do
    if "$PY" -c "import $mod" 2>/dev/null; then
        echo "  ${GREEN}✓${RESET} $mod"
    else
        echo "  ${RED}✗${RESET} $mod"
    fi
done

echo
info "Done."
echo "${DIM}Now launch Ka1zen from /Applications.${RESET}"
