#!/bin/bash

# ─────────────────────────────────────────────
#  hstx installer
#  Usage: curl -fsSL https://raw.githubusercontent.com/owenvanvooren/hstx/master/install.sh | bash
# ─────────────────────────────────────────────

HSTX_DIR="$HOME/.hstx"
HSTX_SCRIPT="$HSTX_DIR/hstx.sh"
ZSHRC="$HOME/.zshrc"
BREW_LOG=$(mktemp)

# clean up temp log on exit no matter what
trap 'rm -f "$BREW_LOG"' EXIT

echo ""
echo "  installing hstx..."
echo ""

# install / 1. check we're on macOS with zsh
if [[ "$(uname)" != "Darwin" ]]; then
  echo "  oops! hstx requires macOS"
  exit 1
fi

if [[ "$SHELL" != */zsh ]]; then
  echo "  oops! hstx requires zsh (the default macOS shell since Catalina)"
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
# brew's stdout+stderr go to a temp log so they don't bleed into our output.
# if brew fails we print the log so the user can see what went wrong.
if ! command -v fzf &>/dev/null; then
  echo "  -> installing fzf (this may take a moment)..."
  if brew install fzf >"$BREW_LOG" 2>&1; then
    echo "  fzf installed :)"
  else
    echo "  oops! fzf install failed. brew output:"
    echo ""
    cat "$BREW_LOG"
    exit 1
  fi
else
  echo "  fzf already installed :)"
fi

# install / 4. sqlite3 ships with macOS, just verify
if ! command -v sqlite3 &>/dev/null; then
  echo "  oops! sqlite3 not found (it ships with macOS — something may be misconfigured)"
  exit 1
fi
echo "  sqlite3 available :)"

# install / 5. download hstx.sh
mkdir -p "$HSTX_DIR"
if curl -fsSL "https://raw.githubusercontent.com/owenvanvooren/hstx/master/hstx.sh" -o "$HSTX_SCRIPT" 2>"$BREW_LOG"; then
  chmod +x "$HSTX_SCRIPT"
  echo "  hstx installed :)"
else
  echo "  oops! download failed — are you connected to the internet?"
  exit 1
fi

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
echo "    hstx save <n>   save as recipe"
echo "    hstx list          browse recipes"
echo "    hstx run <n>    run a recipe"
echo "    hstx help          show all commands"
echo ""
