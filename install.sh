#!/bin/bash

# ─────────────────────────────────────────────
#  hstx installer
#  usage: curl -fsSL https://raw.githubusercontent.com/owenvanvooren/hstx/main/install.sh | bash
# ─────────────────────────────────────────────

set -e

HSTX_DIR="$HOME/.hstx"
HSTX_SCRIPT="$HSTX_DIR/hstx.sh"
ZSHRC="$HOME/.zshrc"

echo ""
echo "  installing hstx..."
echo ""

# install / 1. check we're on macOS with zsh
if [[ "$(uname)" != "Darwin" ]]; then
  echo "  oops! hstx requires macOS"
  exit 1
fi

if [[ -z "$ZSH_VERSION" && "$SHELL" != */zsh ]]; then
  echo "  oops! hstx requires zsh (the default macOS shell)"
  echo "    run: chsh -s /bin/zsh"
  exit 1
fi

# install / 2. check for Homebrew
if ! command -v brew &>/dev/null; then
  echo "  oops! Homebrew not found"
  echo "    install it first: https://brew.sh"
  exit 1
fi

# install / 3. install fzf if needed
if ! command -v fzf &>/dev/null; then
  echo "  -> installing fzf..."
  brew install fzf
  echo "  fzf installed :)"
else
  echo "  fzf already installed :)"
fi

# install / 4. sqlite3 ships with macOS, just verify
if ! command -v sqlite3 &>/dev/null; then
  echo "  oops! sqlite3 not found (it comes with macOS - something may be misconfigured)"
  exit 1
fi
echo "  sqlite3 available :)"

# install / 5. download hstx.sh
mkdir -p "$HSTX_DIR"
curl -fsSL "https://raw.githubusercontent.com/owenvanvooren/hstx/main/hstx.sh" -o "$HSTX_SCRIPT"
chmod +x "$HSTX_SCRIPT"
echo "  hstx installed to $HSTX_SCRIPT :)"

# install / 6. add source line to .zshrc (only once)
SOURCE_LINE="source \"$HSTX_SCRIPT\"  # hstx"

if grep -q "# hstx" "$ZSHRC" 2>/dev/null; then
  echo "  .zshrc already configured :)"
else
  echo "" >> "$ZSHRC"
  echo "$SOURCE_LINE" >> "$ZSHRC"
  echo "  added to ~/.zshrc :)"
fi

# install / 7. done!!
echo ""
echo "  hstx is ready!"
echo ""
echo "  before use, please reload your shell via:  source ~/.zshrc"
echo ""
echo "  commands:"
echo "    hstx               search history"
echo "    hstx tag <label>   tag last command"
echo "    hstx save <name>   save as recipe"
echo "    hstx list          browse recipes"
echo "    hstx run <name>    run a recipe"
echo "    hstx help          show all commands"
echo ""
