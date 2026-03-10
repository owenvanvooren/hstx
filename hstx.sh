#!/bin/zsh

# ─────────────────────────────────────────────
#  hstx — smarter terminal history for macOS
#  github.com/owenvanvooren/hstx
# ─────────────────────────────────────────────

HSTX_DIR="$HOME/.hstx"
HSTX_DB="$HSTX_DIR/history.db"

# create the hstx database if it doesn't exist yet
_hstx_init() {
  mkdir -p "$HSTX_DIR"
  sqlite3 "$HSTX_DB" "
    CREATE TABLE IF NOT EXISTS history (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      cmd       TEXT NOT NULL,
      tags      TEXT,
      cwd       TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS recipes (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      name      TEXT UNIQUE NOT NULL,
      cmd       TEXT NOT NULL,
      note      TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  "
}

# hook (auto-captures commands and puts them in history)
# this is called by zsh's preexec hook (fires before each command runs)
_hstx_capture() {
  local cmd="$1"
  local cwd="$(pwd)"
  # skip capturing hstx commands themselves, and blank lines
  [[ -z "$cmd" || "$cmd" == hstx* ]] && return
  # escape single quotes so they don't break the SQL
  cmd="${cmd//'/'}"
  cwd="${cwd//'/'}"
  sqlite3 "$HSTX_DB" "INSERT INTO history (cmd, cwd) VALUES ('$cmd', '$cwd');" 2>/dev/null
}

# main entry point
hstx() {
  _hstx_init

  local subcommand="${1:-search}"

  case "$subcommand" in
    search)  _hstx_search "${@:2}" ;;
    tag)     _hstx_tag "${@:2}" ;;
    save)    _hstx_save "${@:2}" ;;
    list)    _hstx_list ;;
    run)     _hstx_run "${@:2}" ;;
    help|--help|-h) _hstx_help ;;
    *)
      # if no subcommand, treat the whole thing as a search query
      # e.g. `hstx reset tokens` searches for "reset tokens"
      _hstx_search "$@"
      ;;
  esac
}

# hstx / hstx search <query>
# fuzzy search all captured history. the selected command goes into your prompt
# buffers so you can edit it before hitting enter.
_hstx_search() {
  local query="${*:-}"
  local result

  result=$(sqlite3 -separator $'\x01' "$HSTX_DB" \
    "SELECT id, cmd, COALESCE(tags,''), cwd, timestamp
     FROM history
     ORDER BY timestamp DESC" \
    | fzf \
        --query="$query" \
        --delimiter=$'\x01' \
        --with-nth=2 \
        --prompt="hstx > " \
        --header="search history  |  ctrl+t: tag  |  enter: copy to prompt" \
        --preview='printf "CMD:  {2}\nTAGS: {3}\nDIR:  {4}\nTIME: {5}"' \
        --preview-window=down:5:wrap \
        --height=60% \
        --bind "ctrl-t:execute(hstx tag $(echo {3}) 2>/dev/null)+reload(sqlite3 -separator $'\x01' $HSTX_DB 'SELECT id,cmd,COALESCE(tags,\"\"),cwd,timestamp FROM history ORDER BY timestamp DESC')" \
        2>/dev/null)

  [[ -n "$result" ]] && print -z "$(echo "$result" | cut -d$'\x01' -f2)"
}

# hstx / hstx tag <label>
# tags the last command you ran with a label.
# usage: hstx tag db
# hstx tag "db, migrations"
_hstx_tag() {
  if [[ -z "$1" ]]; then
    echo "usage: hstx tag <label>"
    echo "example: hstx tag db"
    return 1
  fi

  local tag="$1"
  local last_cmd

  last_cmd=$(sqlite3 "$HSTX_DB" "SELECT cmd FROM history ORDER BY id DESC LIMIT 1;")

  if [[ -z "$last_cmd" ]]; then
    echo "hstx: no commands in history yet"
    return 1
  fi

  sqlite3 "$HSTX_DB" \
    "UPDATE history SET tags='$tag' WHERE id=(SELECT MAX(id) FROM history);"

  echo "✓ Tagged: [$tag]  →  $last_cmd"
}

# hstx / hstx save <name>
# promotes the last command you ran into a named recipe.
# usage: hstx save reset-tokens
_hstx_save() {
  if [[ -z "$1" ]]; then
    echo "usage: hstx save <name>"
    echo "example: hstx save reset-tokens"
    return 1
  fi

  local name="$1"
  local last_cmd

  last_cmd=$(sqlite3 "$HSTX_DB" "SELECT cmd FROM history ORDER BY id DESC LIMIT 1;")

  if [[ -z "$last_cmd" ]]; then
    echo "hstx: no commands in history yet"
    return 1
  fi

  # ask for an optional note
  echo "command: $last_cmd"
  echo -n "note (optional, press enter to skip): "
  read note
  note="${note//'/'}"

  sqlite3 "$HSTX_DB" \
    "INSERT INTO recipes (name, cmd, note)
     VALUES ('$name', '$last_cmd', '$note')
     ON CONFLICT(name) DO UPDATE SET cmd='$last_cmd', note='$note', timestamp=CURRENT_TIMESTAMP;"

  echo "✓ Saved recipe: [$name]  →  $last_cmd"
}

# hstx / hstx list
# browse all saved recipes in a fuzzy TUI. enter copies to prompt buffer.
_hstx_list() {
  local result

  local count=$(sqlite3 "$HSTX_DB" "SELECT COUNT(*) FROM recipes;")
  if [[ "$count" -eq 0 ]]; then
    echo "no recipes saved yet."
    echo "run a command, then use: hstx save <name>"
    return
  fi

  result=$(sqlite3 -separator $'\x01' "$HSTX_DB" \
    "SELECT name, cmd, COALESCE(note,''), timestamp FROM recipes ORDER BY name" \
    | fzf \
        --delimiter=$'\x01' \
        --with-nth=1,3 \
        --prompt="recipes > " \
        --header="saved recipes  |  enter: copy to prompt  |  ctrl+d: delete" \
        --preview='printf "NAME: {1}\ncmd:  {2}\nnote: {3}\nsaved:{4}"' \
        --preview-window=down:5:wrap \
        --height=60% \
        2>/dev/null)

  [[ -n "$result" ]] && print -z "$(echo "$result" | cut -d$'\x01' -f2)"
}

# hstx / hstx run <name>
# looks up a recipe by name and puts it in your prompt buffer.
# usage: hstx run reset-tokens
_hstx_run() {
  if [[ -z "$1" ]]; then
    echo "usage: hstx run <name>"
    echo "tip:   hstx list  to browse all recipes"
    return 1
  fi

  local name="$1"
  local cmd

  cmd=$(sqlite3 "$HSTX_DB" "SELECT cmd FROM recipes WHERE name='$name' LIMIT 1;")

  if [[ -z "$cmd" ]]; then
    echo "hstx: no recipe named '$name'"
    echo ""
    echo "saved recipes:"
    sqlite3 "$HSTX_DB" "SELECT '  ' || name || ' — ' || cmd FROM recipes ORDER BY name;"
    return 1
  fi

  # put command in prompt buffer (you can edit before hitting enter)
  print -z "$cmd"
}

# hstx / hstx help
_hstx_help() {
  cat <<EOF

hstx: smarter terminal history

USAGE
  hstx                   fuzzy search all history
  hstx search <query>    search with a pre-filled query
  hstx tag <label>       tag the last command you ran
  hstx save <name>       save last command as a named recipe
  hstx list              browse all saved recipes
  hstx run <name>        run a recipe by name

EXAMPLES
  hstx db                search history for anything with "db"
  hstx tag migrations    tag the last command as "migrations"
  hstx save seed-db      name the last command "seed-db"
  hstx run seed-db       load "seed-db" into your prompt

TIPS
  - Commands are captured automatically in the background
  - hstx run and hstx list load commands into your prompt buffer
    so you can review/edit before hitting enter — nothing runs blind
  - Use hstx tag to label commands for easier searching later

EOF
}

# ── register the preexec hook ──────────────────────────────────────────────────
# preexec is a zsh hook that fires right before each command executes.
# hstx uses it to silently capture every command into the database.
autoload -Uz add-zsh-hook
add-zsh-hook preexec _hstx_capture

# ── make sure database exists on shell start ────────────────────────────────────────
_hstx_init
