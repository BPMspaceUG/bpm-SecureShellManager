# SM - SSH Manager

Ein schneller SSH-Verbindungsmanager mit interaktiver Auswahl und zellij Session-Persistenz.

## Features

- **Interaktive Auswahl** mit Pfeiltasten
- **Schnellzugriff** auf Default-Verbindung via `smd`
- **Automatischer Verzeichniswechsel** nach SSH-Login
- **Zellij Session-Persistenz** - Verbindung bleibt bei SSH-Abbruch aktiv
- **Claude-Integration** - `c` startet Claude, `r` startet Claude mit Resume
- **2-Pane Layout** - Claude oben, Bash unten (mit Maus-Unterstützung)
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

```bash
git clone git@github.com:BPMspaceUG/bpm-SecureShellManager.git
cd bpm-SecureShellManager
./install.sh
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
| `sml` | Alle Verbindungen auflisten |

### Interaktiver Modus

```
=== SM - SSH Manager ===
ALIAS      HOSTALIAS    USER            DIRECTORY
--------------------------------------------------------------------------------
> sm231    contabo2     rob-ico         ico-n8n-prozesse2
  sm232    contabo2     rob-ico         ico-cert

↑↓ Navigate | Enter: Connect | c: Claude | r: Claude -r | D: Default | Esc/Q: Exit
```

**Tastenbelegung:**
- `↑↓` - Navigation
- `Enter` - Verbinden (zellij Session wiederherstellen/erstellen)
- `c` - Verbinden + Claude starten (2-Pane: Claude oben, Bash unten)
- `r` - Verbinden + Claude -r starten (Resume-Modus)
- `D` - Als Default setzen
- `Esc/Q` - Beenden

## Session-Persistenz

SM nutzt **zellij** für Session-Persistenz:

```
┌─────────────────────────────────────┐
│ Dein PC          │ Server           │
├─────────────────────────────────────┤
│ sm → Enter ──────┼─► zellij Session │
│                  │   └── claude     │
│ [SSH bricht ab]  │                  │
│                  │   Session läuft! │
│ sm → Enter ──────┼─► reattach       │
└─────────────────────────────────────┘
```

- Claude läuft weiter auch wenn SSH abbricht
- Bei Reconnect: automatisch zur laufenden Session

**Zellij-Vorteile gegenüber tmux:**
- Maus-Klick zum Pane-Wechsel
- Shortcuts werden unten angezeigt
- Intuitivere Bedienung

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

### Host-Aliase

Für kürzere Hostnamen in der Übersicht:
```
hostalias:very-long-hostname.example.com=short
```

## Beispiele

```bash
# Interaktive Auswahl starten
sm

# Direkt zu "prod" verbinden
sm prod

# Alle Verbindungen auflisten
sm list
sml

# "staging" als Default setzen
sm set staging

# Schnell zum Default verbinden
smd
```

## Zellij Shortcuts

Falls du dich in zellij befindest:

| Shortcut | Beschreibung |
|----------|--------------|
| Maus-Klick | Pane wechseln |
| `Ctrl+p` `d` | Detach (Session verlassen, läuft weiter) |
| `Alt+n` | Neues Pane |
| `Alt+←→↑↓` | Pane wechseln |

## Deinstallation

```bash
rm ~/.local/bin/sm ~/.local/bin/smd ~/.local/bin/sml
rm -rf ~/.config/sm  # Optional: Konfiguration löschen
```

## Lizenz

MIT
