# hstx

hstx is **history extended:** smarter terminal history for macOS. fuzzy search everything, and save the commands that matter as recipes.

_what problem does hstx solve?_
zsh's built-in `ctrl+r` only searches the current session and has no way to label or organize commands. hstx captures everything into a local SQLite database and gives you a fuzzy search TUI across all sessions, plus a recipe system for commands you run repeatedly.

## install

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/hstx/main/install.sh | bash
```

then reload your shell:

```bash
source ~/.zshrc
```

**requirements:** macOS, zsh (the default since macOS Catalina), [Homebrew](https://brew.sh).
`fzf` and `sqlite3` are handled automatically by the installer.

---

## usage

### search history

```bash
hstx
hstx db
hstx reset user
```

opens a fuzzy search TUI over everything you've ever run. the selected command loads into your prompt buffer so you can edit it before hitting enter so nothing runs blind.

### tag a command

```bash
# run something first, then label it
psql $DATABASE_URL -c "DELETE FROM sessions WHERE user_id = 42;"
hstx tag db
```

tags show up in search so you can filter by topic later.
_in this example, `db` is the tag name_

### save a recipe

```bash
# run a command, then name it
rails db:seed
hstx save seed-db
```

promotes the last command into a named recipe. you'll be asked for an optional note to describe what it does.
_in this example, `seed-db` is the recipe name_

### browse recipes

```bash
hstx list
```

opens a TUI showing all saved recipes. enter loads the selected one into your prompt.

### run a recipe by name

```bash
hstx run seed-db
```

loads the recipe into your prompt buffer. same deal: you can edit before running.
_in this example, `seed-db` is the recipe name_

### help

```bash
hstx help
```

---

## how it works

hstx uses zsh's `preexec` hook to silently capture every command you run into a local SQLite database at `~/.hstx/history.db`. nothing is sent anywhere — it's entirely local.

two tables:
- `history` — every command, with timestamp, working directory, and optional tags
- `recipes` — named commands you've explicitly saved

the fuzzy search TUI is powered by [fzf](https://github.com/junegunn/fzf).

---

## uninstall :(

```bash
# remove hstx files
rm -rf ~/.hstx

# remove the source line from ~/.zshrc
# open ~/.zshrc and delete the line that ends with  # hstx
```

---

## license

mit
