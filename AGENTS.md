# AGENTS.md

## Project Overview

This repository is a portable "grimoire" for AI assistant configuration. It
stores shared base instructions, skills, agents, and slash commands, then
installs them into assistant-specific config directories through GNU Stow.

Important paths:

- `AGENTS.md`: base instructions for AGENTS.md-reading tools such as Codex,
  OpenCode, and Qoder.
- `CLAUDE.md`: Claude-specific base instructions. Keep it separate unless the
  user explicitly asks for parity.
- `skills/`: shared skills. Skill source directories may be nested, but each
  installed skill is keyed by the leaf directory containing `SKILL.md`.
- `agents/` and `commands/`: flat shared item directories; each non-hidden file
  or directory is one installable item.
- `registry.toml`: assistant target definitions and destination paths.
- `vendor.toml`: external skill sources synced with `git subtree`.
- `local/`: per-machine overrides and private items. Treat this as local state;
  do not edit it unless the user asks.
- `.grimoire-stow/`: generated install artifacts. Do not edit directly.
- `scripts/`: Bash implementation for `install`, `uninstall`, `doctor`, and
  `sync`, dispatched by `./grimoire.sh`.

## Working Rules

State assumptions before changing behavior. If the request has multiple
reasonable interpretations, name them and ask or choose the smallest reversible
change.

Keep changes surgical. Touch only files needed for the request, match existing
style, and avoid speculative abstractions or unrelated cleanup. If you notice
unrelated dead code or drift, mention it instead of fixing it.

Prefer simple shell and TOML changes over new dependencies. The project is
designed around Bash 3.2+, `awk`, `git`, `tar`, and GNU Stow; do not introduce
Python, Node, or another runtime for normal operation unless explicitly asked.

When editing scripts, preserve the current defensive style: `set -euo pipefail`,
small helpers, explicit refusal before overwriting non-owned files, and dry-run
support where the command already has it.

Write new code, comments, identifiers, commit messages, and developer-facing
documentation in English. Preserve existing non-English user-facing text,
fixtures, and translations unless the task asks to change them.

## Install Model

The installer resolves items by kind from two layers:

1. `self`: repository directories such as `skills/`, `agents/`, and `commands/`.
2. `local`: matching directories under `local/`.

`local` wins on same-name items. `local/config.toml` can disable any item by
fully-qualified name such as `skills/tdd` or `agents/eval-executor`.

For `AGENTS.md` and `CLAUDE.md`, install renders the root file plus the matching
local overlay (`local/AGENTS.md` or `local/CLAUDE.md`) into `.grimoire-stow/`
before stowing it into the target root.

When adding a target, update `registry.toml`; avoid script changes unless the
new assistant needs a genuinely new install model.

When adding or moving a skill, ensure the skill directory contains `SKILL.md`.
Avoid duplicate skill leaf names, even in different category folders, because
installed skill names are flattened to their leaf directory names.

## Common Commands

- `./grimoire.sh doctor`: check local config, skill markers, name conflicts, and
  broken symlinks.
- `./grimoire.sh install --dry-run`: preview install for targets in
  `local/config.toml`.
- `./grimoire.sh install <target> --dry-run`: preview one target.
- `./grimoire.sh uninstall <target> --dry-run`: preview removal for one target.
- `./grimoire.sh sync --dry-run`: preview vendored skill updates.
- `./grimoire.sh sync --stat` or `./grimoire.sh sync --diff`: inspect vendored
  changes before applying them.

Use dry-run commands before real install, uninstall, or sync changes when the
request touches deployment behavior.

## Verification

For documentation-only changes, inspect the diff and run no heavier checks
unless the edited documentation describes generated behavior.

For changes to discovery, resolution, install, uninstall, or target metadata,
run:

```bash
./grimoire.sh doctor
./grimoire.sh install --dry-run
```

For vendoring changes, prefer previewing first:

```bash
./grimoire.sh sync --dry-run
```

Real `sync` uses network access and requires a clean worktree because it performs
`git subtree` operations. Do not run it casually.

## Git Workflow

The worktree may contain user changes. Never revert changes you did not make.
If unrelated files are dirty, leave them alone.

When creating commits, use Conventional Commits:
`<type>(<scope>): <description>`.

Allowed types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, and
`ci`.

Add a commit body only when it materially explains rationale, impact, migration
notes, or test coverage. Do not include assistant or vendor metadata in commit
messages.
