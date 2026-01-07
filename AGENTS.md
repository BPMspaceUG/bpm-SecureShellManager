# Repository Guidelines

## Project Structure & Module Organization
This repo is intentionally lean: `sm` is the entire SSH manager implementation, `install.sh` installs it into `~/.local/bin`, and `README.md` plus `CLAUDE.md` hold user-facing docs. Treat `sm` as the single source of truth for logic; keep helper functions near their callers, and favor small, composable Bash functions. Configuration is created by the script in `~/.config/sm/connections.conf`, so never commit personal connection data or keys.

## Build, Test, and Development Commands
- `./install.sh` copies `sm` into `~/.local/bin` and symlinks `smd`; re-run after any change that should be exercised via PATH.
- `~/.local/bin/sm list` renders the non-interactive table view and is the fastest smoke test when iterating on parsing logic.
- `sm <alias>` and `smd` should be exercised in a zellij-capable shell to confirm session persistence; use `sm set <alias>` to verify default handling.
- `sml` is the list-only entry point; invoke after edits to session enumeration or key handling.

## Coding Style & Naming Conventions
Stick to POSIX-compatible Bash with `set -euo pipefail` and four-space indentation as in `sm`. Name functions and variables with lowercase snake_case (`reset_terminal`, `get_default`) and keep constants uppercase. When printing UI, prefer printf over echo for alignment. Run `shellcheck sm` prior to submitting to catch quoting or array pitfalls, and add concise comments before non-obvious logic (e.g., terminal reset sequences).

## Testing Guidelines
Unit-style frameworks are absent, so rely on targeted manual exercises: `shellcheck sm`, `sm list` with a stub config, and dry-run SSH commands by setting `SM_DEBUG=1` when adding new flows. Validate that interactive mode recovers cleanly after Esc/Q and that default selection survives malformed config rows. Aim to keep interactive regressions out by testing both minimal and large connection lists.

## Commit & Pull Request Guidelines
Recent history (`git log --oneline`) shows short, imperative subjects such as “Fix terminal corruption…”. Mirror that format: ≤60 characters, capitalized, no trailing period, body if rationale is non-obvious. PRs should describe the behavior change, include reproduction steps or demo commands, mention updated docs/config migrations, and link any related issues.

## Security & Configuration Tips
Never embed live hostnames, users, or key paths in commits. If you must demonstrate config changes, anonymize aliases (`sm001`) and hosts. Remind reviewers to run `chmod 600` on keys and keep `~/.config/sm` permissions restrictive. When touching session management, double-check that commands appended to `ZELLIJ_MOUSE_FIX` remain idempotent and safe on shared hosts.
