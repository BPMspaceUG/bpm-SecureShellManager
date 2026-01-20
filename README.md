# SM - SSH Manager

Ein schneller SSH-Verbindungsmanager mit interaktiver Auswahl und zellij Session-Persistenz.

## Features

- **Interaktive Auswahl** mit Pfeiltasten
- **Schnellzugriff** auf Default-Verbindung via `smd`
- **Session-Liste** auf Default-Server via `sml`
- **Automatischer Verzeichniswechsel** nach SSH-Login
- **Zellij Session-Persistenz** - Verbindung bleibt bei SSH-Abbruch aktiv
- **Host-Aliase** für bessere Übersicht
- **Individuelle SSH-Keys** pro Verbindung

## Voraussetzungen

**Auf dem Server** muss [zellij](https://github.com/zellij-org/zellij) installiert sein:

```bash
# Schnelle Installation auf dem Server
curl -L https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz | tar xz
sudo mv zellij /usr/local/bin/
```

## Installation

### User Install (~/.local/bin)

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-SecureShellManager/main/install.sh | bash -s -- --user
```

### System-wide Install (/usr/local/bin)

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-SecureShellManager/main/install.sh | sudo bash -s -- --global
```

### Both Locations

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-SecureShellManager/main/install.sh | sudo bash -s -- --all
```

### Interactive Mode

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-SecureShellManager/main/install.sh | bash
```

### Specific Version

```bash
SM_VERSION=v1.0.0 curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-SecureShellManager/main/install.sh | bash -s -- --user
```

### Manual / Development

```bash
git clone https://github.com/BPMspaceUG/bpm-SecureShellManager.git
cd bpm-SecureShellManager
./install.sh          # Interactive
./install.sh --user   # User only
./install.sh --all    # Both locations
```

Stelle sicher, dass `~/.local/bin` in deinem `PATH` ist:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Verwendung

### Befehle

| Befehl | Beschreibung |
|--------|--------------|
| `sm` | Interaktive Auswahl (Pfeiltasten) |
| `sm <alias>` | Direkt zu Verbindung verbinden |
| `sm list` | Alle Verbindungen anzeigen |
| `sm set <alias>` | Default-Verbindung setzen |
| `smd` | Schnellzugriff auf Default |
| `sml` | Sessions auf Default-Server auflisten |

### Interaktiver Modus

```
=== SM - SSH Manager ===
ALIAS      HOSTALIAS    USER            DIRECTORY
--------------------------------------------------------------------------------
> sm231    contabo2     rob-ico         ico-n8n-prozesse2
  sm232    contabo2     rob-ico         ico-cert

↑↓ Navigate | Enter: Connect | L: List Sessions | R: Reset | D: Default | Esc/Q: Exit
```

**Tastenbelegung:**
- `↑↓` - Navigation
- `Enter` - Verbinden (zellij Session wiederherstellen/erstellen)
- `L` - Sessions auf Server auflisten und auswählen
- `R` - Session zurücksetzen (löschen und neu erstellen)
- `D` - Als Default setzen
- `Esc/Q` - Beenden

### Session-Liste (L)

```
=== Sessions on sm210 (N8N Prozesse) ===

> sm210 [Created 5m ago]
  sm220 [Created 1h ago]
  [NEW] Create session 'sm210'

↑↓ Navigate | Enter: Connect | Esc/Q: Back
```

## Session-Persistenz

SM nutzt **zellij** für Session-Persistenz:

```
┌─────────────────────────────────────┐
│ Dein PC          │ Server           │
├─────────────────────────────────────┤
│ sm → Enter ──────┼─► zellij Session │
│                  │   └── deine App  │
│ [SSH bricht ab]  │                  │
│                  │   Session läuft! │
│ sm → Enter ──────┼─► reattach       │
└─────────────────────────────────────┘
```

- Prozesse laufen weiter auch wenn SSH abbricht
- Bei Reconnect: automatisch zur laufenden Session

## Zellij Shortcuts

| Shortcut | Beschreibung |
|----------|--------------|
| `Ctrl+o d` | **Detach** - Session verlassen (läuft weiter) |
| `Ctrl+q` | **Quit** - Session beenden |
| `Ctrl+p x` | Pane schließen |
| `Alt+n` | Neues Pane |
| `Alt+←→↑↓` | Pane wechseln |
| Maus-Klick | Pane wechseln |

**Wichtig:**
- `Ctrl+o d` = Session bleibt aktiv, `Enter` verbindet wieder
- `Ctrl+q` = Session wird beendet, `Enter` erstellt neue

## Konfiguration

Die Konfigurationsdatei wird beim ersten Start erstellt:
```
~/.config/sm/connections.conf
```

### Format

```
# Format: alias|host|port|user|directory|description|[ssh_key]

# Beispiele:
sm231|contabo2.example.com|22|rob-ico|ico-n8n-prozesse2|N8N Server|
sm232|contabo2.example.com|22|rob-ico|ico-cert|Cert Service|~/.ssh/special_key

# Host-Alias (optional):
hostalias:contabo2.example.com=contabo2

# Default-Verbindung:
default=sm231
```

### Felder

| Feld | Pflicht | Beschreibung |
|------|---------|--------------|
| alias | Ja | Eindeutiger Name (z.B. `sm231`) |
| host | Ja | Hostname oder IP |
| port | Ja | SSH Port (meist `22`) |
| user | Ja | SSH Benutzername |
| directory | Nein | Verzeichnis nach Login |
| description | Nein | Beschreibung für Anzeige |
| ssh_key | Nein | Pfad zu SSH Key |

## Deinstallation

```bash
# Quick uninstall
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-SecureShellManager/main/uninstall.sh | bash

# Or manual:
rm ~/.local/bin/sm ~/.local/bin/smd ~/.local/bin/sml
rm -rf ~/.config/sm  # Optional: Konfiguration löschen
```

## Lizenz

MIT
