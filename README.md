# grimoire

<div align="center">
  <img src="./grimoire.svg" alt="grimoire" width="100%"/>
</div>

<br/>

<div align="center">

*A practitioner does not merely use tools.*
*A practitioner binds them.*

</div>

---

A unified spellbook for coding assistants — **Claude Code**, **Codex**, **OpenCode**, **Qoder**, and any that follow.

One repo holds your skills, subagents, slash commands, and base instructions. One command installs them everywhere. Per-machine customisation lives outside git.

---

## Tome Structure

```
grimoire/
├── AGENTS.md            # canonical base oath
├── CLAUDE.md            # Claude-specific base oath
├── skills/              # source may be nested; each leaf SKILL.md is one skill
├── agents/   commands/  # flat: each .md file is one item
│
├── registry.toml        # assistant → install paths
├── vendor.toml          # external skill sources (git subtree)
├── examples/local/      # copy-once templates for local/
│
├── local/               # per-machine overrides (gitignored)
│   ├── config.toml      #   targets selection, disabled list
│   ├── AGENTS.md        #   appended to AGENTS.md targets (codex/opencode/qoder)
│   ├── CLAUDE.md        #   appended to CLAUDE.md target (claude)
│   └── skills/ …        #   private items
│
├── grimoire.sh          # entry point: dispatches `install`, `doctor`, …
└── scripts/
    ├── grimoire-install # install logic
    ├── grimoire-doctor  # diagnose conflicts and orphans
    ├── grimoire-sync    # vendor.toml → git subtree sync
    └── _grimoire-lib.sh # shared TOML/discovery helpers
```

Requires `bash` 3.2+, `awk`, and GNU Stow — no Python or other runtime needed.

---

## Quick Start

```bash
# 1. Tell grimoire which machine this is.
mkdir -p local
cp examples/local/config.toml local/config.toml
$EDITOR local/config.toml          # set targets = ["claude", ...]

# 2. Install.
./grimoire.sh install              # or: ./grimoire.sh install --dry-run
```

`install` with no target names installs every target listed in `local/config.toml`.
`install --all` does the same thing; it does not install every target in `registry.toml`.

```bash
./grimoire.sh uninstall qoder      # remove one target
./grimoire.sh uninstall --dry-run qoder
```

---

## Per-Machine Customisation

`local/` is gitignored. Put per-machine bits there:

```toml
# local/config.toml
targets  = ["claude", "codex"]      # this machine installs to these
disabled = [
  "agents/eval-executor",           # turn off one item, by kind/name
]
```

```markdown
<!-- local/AGENTS.md -->
## Local Context
This machine is the work laptop. Default repo root is ~/code/...
```

`AGENTS.md` and `CLAUDE.md` are separate base instruction files. They start from the same house style, but can diverge where Claude Code and AGENTS.md-reading tools need different guidance.

On install, the file written to each assistant is `<repo>/<target.agents_md>` + `local/<target.agents_md>` — the local overlay mirrors the target's filename. Per assistant docs, the destination filename differs:

- `claude` reads `~/.claude/CLAUDE.md`, with local overrides from `local/CLAUDE.md`
- `codex`, `opencode`, `qoder` read `AGENTS.md`, with local overrides from `local/AGENTS.md`

Skill source directories may be nested to keep this repo organized, but the installer materializes each skill by its leaf directory name into `.grimoire-stow/` before stowing it because Claude, Codex, and Qoder expect `skills/<skill-name>/SKILL.md`.

You can also drop machine-private items into `local/skills/`, `local/agents/`, etc. Same name as a shared item → `local` wins.

---

## Adding a New Assistant

Add a stanza to `registry.toml`:

```toml
[new-assistant]
root      = "~/.new-assistant"
agents_md = "AGENTS.md"
skills    = "skills"      # or omit kinds the assistant doesn't support
commands  = "commands"
```

Kind paths are relative to `root` by default. Use `~` or `/` when one assistant stores a kind elsewhere. No script changes are needed; `./grimoire.sh install new-assistant` works.

Hooks are intentionally not supported yet. Each assistant registers hooks differently, usually through a config file rather than by scanning a synced directory.

---

## Doctor

```bash
./grimoire.sh doctor
```

Reports: missing local config, name collisions between self and local, broken symlinks left over in installed targets.

---

## Vendoring Skills

External skill sources live in `vendor.toml`. Each `[<name>]` block is one
source — an upstream repo, the `subdir` to pull, and the `dest` it lands in
(kept under `skills/` so it installs like any other skill):

```toml
# vendor.toml
[mattpocock]
url     = "https://github.com/mattpocock/skills.git"
branch  = "main"
subdir  = "skills"
dest    = "skills/mattpocock"
exclude = ["scaffold-exercises"]   # drop skills by leaf name (or a path)
rename  = ["review:matt-review"]   # rename a leaf skill (and its SKILL.md name:)
```

Use `subdir = "."` for a skill repo whose `SKILL.md` lives at the repo root.
Use `include = ["skill-name"]` when you want only specific top-level paths from
the upstream subdir.

Sync every source, or one by name:

```bash
./grimoire.sh sync                 # all sources
./grimoire.sh sync mattpocock      # one source
./grimoire.sh sync --dry-run       # changed paths, no writes
./grimoire.sh sync --stat          # diff stat
./grimoire.sh sync --diff          # full patch
```

Sync uses `git subtree` with a squash merge, so clones of this repo need no
submodule setup. Commit or stash local changes first; subtree merges require a
clean worktree. `rename` is the fork-by-rename escape for when an upstream skill
name would collide with one of yours — grimoire never silently overrides on a
name clash, so renaming (or `exclude`) is how you resolve it.

---

## Philosophy

Most people configure tools. This grimoire *shapes* tools — nudging them toward a particular aesthetic, a particular way of reasoning, a particular voice.

The goal is not to make AI assistants more capable. They are already capable.
The goal is to make them *mine*.

---

*Here begins the work.*
