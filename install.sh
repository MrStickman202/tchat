#!/usr/bin/env bash

# ─────────────────────────────────────────
#  tchat installer
#  Usage: curl -fsSL https://raw.githubusercontent.com/MrStickman202/tchat/main/install.sh | bash
# ─────────────────────────────────────────

set -e

REPO="MrStickman202/tchat"
BRANCH="main"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/tchat.sh"

R="\033[0m"
BOLD="\033[1m"
GREEN="\033[32m"
RED="\033[31m"
DIM="\033[2m"
YELLOW="\033[33m"

echo ""
printf "  ${BOLD}tchat installer${R}\n"
printf "  ${DIM}────────────────────────────────────${R}\n\n"

# ── DETECT ENV ───────────────────────────
if [[ -d "/data/data/com.termux" ]] || [[ "$PREFIX" == *termux* ]]; then
  ENV="termux"
  INSTALL_DIR="$PREFIX/bin"
elif [[ "$(uname)" == "Darwin" ]]; then
  ENV="macos"
  if [[ -d "/opt/homebrew/bin" ]]; then
    INSTALL_DIR="/opt/homebrew/bin"
  else
    INSTALL_DIR="/usr/local/bin"
  fi
else
  ENV="linux"
  INSTALL_DIR="/usr/local/bin"
fi

printf "  ${DIM}Environment: ${YELLOW}%s${R}\n" "$ENV"
printf "  ${DIM}Install to:  ${YELLOW}%s/tchat${R}\n\n" "$INSTALL_DIR"

# ── CHECK DEPS ───────────────────────────
missing=()
for cmd in curl jq bash; do
  if ! command -v "$cmd" &>/dev/null; then
    missing+=("$cmd")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  printf "  ${RED}✗ Missing dependencies: %s${R}\n\n" "${missing[*]}"
  if [ "$ENV" = "termux" ]; then
    printf "  Install with: ${BOLD}pkg install %s${R}\n\n" "${missing[*]}"
  elif [ "$ENV" = "macos" ]; then
    printf "  Install with: ${BOLD}brew install %s${R}\n\n" "${missing[*]}"
  else
    printf "  Install with: ${BOLD}sudo apt install %s${R}\n\n" "${missing[*]}"
  fi
  exit 1
fi

printf "  ${GREEN}✓ Dependencies OK${R}\n"

# ── DOWNLOAD ─────────────────────────────
printf "  ${DIM}Downloading tchat...${R}\n"
TMP=$(mktemp /tmp/tchat.XXXXXX)
if ! curl -fsSL "$SCRIPT_URL" -o "$TMP"; then
  printf "  ${RED}✗ Download failed. Check your connection.${R}\n\n"
  rm -f "$TMP"
  exit 1
fi

# verify it looks like a tchat script
if ! grep -q "tchat" "$TMP" 2>/dev/null; then
  printf "  ${RED}✗ Downloaded file doesn't look right.${R}\n\n"
  rm -f "$TMP"
  exit 1
fi

printf "  ${GREEN}✓ Downloaded${R}\n"

# ── INSTALL ──────────────────────────────
TARGET="$INSTALL_DIR/tchat"

# backup existing install
if [ -f "$TARGET" ]; then
  cp "$TARGET" "${TARGET}.backup" 2>/dev/null && \
    printf "  ${DIM}Backed up existing install to tchat.backup${R}\n"
fi

# on macos/linux we may need sudo
if [ "$ENV" != "termux" ] && [ ! -w "$INSTALL_DIR" ]; then
  printf "  ${DIM}Need sudo to write to %s...${R}\n" "$INSTALL_DIR"
  sudo mv "$TMP" "$TARGET"
  sudo chmod +x "$TARGET"
else
  mv "$TMP" "$TARGET"
  chmod +x "$TARGET"
fi

rm -f "$TMP" 2>/dev/null || true

printf "  ${GREEN}✓ Installed to %s${R}\n\n" "$TARGET"
printf "  ${BOLD}Done! Run with: ${GREEN}tchat${R}\n\n"
