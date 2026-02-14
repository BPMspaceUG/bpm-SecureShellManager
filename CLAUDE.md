# SM - SSH Manager

## Lokale Entwicklung

- **Arbeitskopie:** `/home/rob/bpm-SecureShellManager/`
- **Remote:** `git@github.com:BPMspaceUG/bpm-SecureShellManager.git`
- **Installiert:** `/home/rob/.local/bin/sm`

## Workflow

1. Änderungen im Repo machen (`/home/rob/bpm-SecureShellManager/sm`)
2. Installieren: `./install.sh --user` (brennt Version ein)
   - Alternativ: `cp sm ~/.local/bin/sm` (zeigt dann "dev")
3. Commit & Push

## Versioning

Format: **YYMMDD-HHMM** (Zeitstempel des HEAD-Commits)

| Zustand | Anzeige | Bedeutung |
|---------|---------|-----------|
| committed + pushed | `260214-1154` | Release — produktionsbereit |
| committed + nicht gepusht | `260214-1154-draft` | Push steht noch aus |
| uncommitted changes | `260214-1154-dirty` | Noch nicht committed |
| Kein Git-Repo (plain copy) | `dev` | Nicht über install.sh installiert |

- `sm --version` zeigt den Zustand live (wenn aus Git-Repo ausgeführt)
- `install.sh` brennt den aktuellen Zustand als fixen String ein
- Rollback: `cp ~/.local/bin/sm.bak ~/.local/bin/sm`
- **Immer `install.sh --user` statt `cp` verwenden** — sonst fehlt die Version

## Git Identity

```
user.email = 5494647+BPMspaceUG@users.noreply.github.com
user.name = BPMspaceUG
```

## SSH Push

Benötigt Passphrase für `/home/rob/.ssh/id_ed25519_github_win11`

## Refactoring Roadmap (Feb 2026)

30 issues created on GitHub (#5-#34), organized by priority:

### P0 - Critical (Security/Safety) - Issues #5-#9
- #5: Unquoted SSH command word splitting (use bash arrays)
- #6: Unquoted $directory in cd_cmd (spaces break connections)
- #7: Regex injection in alias grep patterns
- #8: Port number validation missing
- #9: Uninstall.sh has no confirmation prompt

### P1 - Code Quality (DRY/Structure) - Issues #10-#15
- #10: Extract build_ssh_cmd() helper (duplicated 5x)
- #11: Extract parse_connection() helper (duplicated 4x)
- #12: Extract exit_or_return() helper (duplicated 14x)
- #13: Extract cd_cmd construction (duplicated 4x)
- #14: Break down monster functions (list_and_connect 237 lines, interactive_select 171 lines)
- #15: Extract calculate_column_widths() (duplicated)

### P2 - UX/Features - Issues #16-#24
- #16: --help and --version flags
- #17: sm test <alias> connection testing
- #18: CLI equivalents for interactive keys (auth, parallel, reset, sessions)
- #19: Search/filter in interactive menu
- #20: Show description column
- #21: sm edit command
- #22: Config validation (sm validate / sm doctor)
- #23: Hard reset confirmation prompt
- #24: --no-color flag

### P3 - Nice to Have - Issues #25-#34
- #25: Connection groups
- #26: Import from ~/.ssh/config
- #27: Shell completions (bash/zsh)
- #28: Connection history
- #29: Change config delimiter (pipe breaks in descriptions)
- #30: sm add wizard
- #31: sm remove command
- #32: Check timeout availability
- #33: Sanitize terminal title inputs
- #34: Complete keybinding docs in README

### Rules
- Require test AND documentation approval before closing any issue
- Stay single-file (preserves deployment simplicity)
- Estimated reduction after P0+P1: ~200 lines (1047 -> ~850)
