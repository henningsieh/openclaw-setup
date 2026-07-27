# CalDAV Calendar — Reparatur & Dokumentation

## Problem

Das Entrypoint-Script `scripts/openclaw-init.sh` konnte qcard und CalDAV-Configs nicht provisionieren, weil es nach einem nicht-existierenden Vaultwarden-Item `openclaw/qcard/henning@sieh.org` suchte. Zusätzlich war `khal new` nicht in der Lage, zeitlich begrenzte Events (Timed Events) korrekt zu erstellen.

## Fix-Branch

Branch: `fix/caldav-vaultwarden-lookup`  
Repo: `https://github.com/henningsieh/openclaw-setup`  
Base: `main` (noch kein Merge)

Drei Commits:

### Commit 1: Vaultwarden-Lookup + SOGO_EMAIL
**Hash:** `e0a1678`  
**Was:** 
- Entfernt den Resolver `openclaw/qcard/henning@sieh.org` (existiert nicht)
- Neuer Lookup: `bw list items --search "MailCow"` + jq-Filter auf `.login.username == "$SOGO_EMAIL"`
- `SOGO_EMAIL` als `.env`-Variable statt hardcoded `henning@sieh.org`
- qcard + caldav in einem Block (shared password lookup)

**Dateien:**
- `.env.example`: `SOGO_EMAIL=henning@sieh.org`
- `scripts/openclaw-init.sh`: qcard/caldav provisioning

### Commit 2: khal dateformat Fix
**Hash:** `edb7c0e`  
**Was:**
- `dateformat = %d.%m.%Y` → `%Y-%m-%d`
- `datetimeformat = %Y-%m-%d %H:%M` hinzugefügt
- `longdatetimeformat = %Y-%m-%d %H:%M` hinzugefügt

**Warum:** Ohne datetimeformat verwendet khal den Default `%a %b %d %H:%M:%S %Y` (z.B. "Wed Jul 29 10:00:00 2026") und kann daher `2026-07-29 10:00` nicht als Datetime parsen. Stattdessen erstellt es einen All-Day-Event und ignoriert die Uhrzeit.

### Commit 3: khal-event Wrapper
**Hash:** `daea9b5`  
**Was:**
- `scripts/khal-event` — atomarer Wrapper: `khal new "$@" && vdirsyncer sync`
- Entrypoint installiert ihn nach `/usr/local/bin/khal-event`
- Bei Sync-Fehler wird die lokale `.ics` gelöscht

**Dateien:**
- `scripts/khal-event`: das Wrapper-Script

## Notwendige Aufgaben (müssen VOR dem Testen erledigt werden)

### 1. Merge den Branch in main
```bash
cd /home/node/.openclaw/workspace/openclaw-setup
git checkout main
git merge fix/caldav-vaultwarden-lookup
git push origin main
```

### 2. TOOLS.md aktualisieren

**Datei:** `/home/node/.openclaw/workspace/TOOLS.md`

**Aktion:** Die bestehende CalDAV-Sektion (nach "### 📅 Calendar (CalDAV)") durch folgenden Text ersetzen:

```
### 📅 Calendar (CalDAV)

**❗ CRITICAL: Immer `khal-event` benutzen, niemals `khal new` direkt!**
`khal-event` ist ein atomarer Wrapper, der `khal new` + `vdirsyncer sync` kombiniert.
Nur `khal-event` stellt sicher, dass der Termin auf dem MailCow-Server landet.
`khal new` direkt erzeugt NUR ein lokales ICS — landet nie auf dem Server.

---

**Wrapper-Befehl:**
```bash
khal-event "<yyyy-mm-dd hh:mm>" <hh:mm> "<Titel>" -a personal -m <minuten>
# Beispiel:
# khal-event "2026-07-29 10:00" 14:00 "🛒 Einkaufen bei Aldi / Globus" -a personal -m 60
```

**View:**
```bash
khal list <yyyy-mm-dd> [<yyyy-mm-dd>]
# khal list 2026-07-29
```

**Search:**
```bash
khal search "<query>"
```

**Sync (nur für manuelle Änderungen oder nach khal edit):**
```bash
vdirsyncer sync
```

**Configs:**
- `~/.config/vdirsyncer/config`
- `~/.config/vdirsyncer/caldav_password`
- `~/.config/khal/config`

**Infrastruktur:**
- Server: `https://mail.sieh.org/SOGo/dav/henning@sieh.org/Calendar/personal/`
- User: `henning@sieh.org`
- Passwort aus Vaultwarden-Item mit Name "MailCow" und `login.username == "henning@sieh.org"`
```

### 3. SKILL.md aktualisieren

**Datei:** `/home/node/.openclaw/skills/caldav-calendar/SKILL.md`

**Aktionen:**
1. Im Abschnitt "## Create Events" ALLE `khal new`-Zeilen durch `khal-event` ersetzen
2. Nach dem Create-Abschnitt diesen Block einfÃ¼gen:

```
### ⚠️ CRITICAL: khal-event statt khal new

Nutze NUR `khal-event` fÃ¼r neue Termine. `khal-event` ist ein Wrapper, der
`khal new` und `vdirsyncer sync` atomar ausfÃ¼hrt. Ein Termin, der nur lokal
per `khal new` erstellt wurde, landet NIE auf dem MailCow-Server!

`khal-event` erwartet Datetime-Format: `"YYYY-MM-DD HH:MM"` als ersten Parameter.
```

### 4. MEMORY.md aktualisieren

**Datei:** `/home/node/.openclaw/workspace/MEMORY.md`

**Aktion:** Vorhandenen MEMORY.md-Inhalt am Ende ergÃ¤nzen um:

```
## 📅 CalDAV khal-event Rule (CRITICAL)

`khal-event` ist der einzig erlaubte Weg, Calendar-Events zu erstellen.
`khal new` direkt NIEMALS verwenden — erzeugt nur lokale .ics ohne Server-Sync!

- `khal-event` = `khal new` + `vdirsyncer sync` (atomar, fehlschlagsicher)
- Bei Sync-Fehler wird die lokale .ics gelÃ¶scht (keine verwaisten Events)
- Diese Regel wurde 2026-07-27 eingefÃ¼hrt, nachdem mehrfach Events lokal erstellt
  wurden, ohne jemals auf dem MailCow-Server anzukommen.
```

### 5. prompt.md lÃ¶schen

Nachdem alle Tasks abgearbeitet sind: `rm /home/node/.openclaw/workspace/openclaw-setup/prompt.md`

---

## Test nach Rebuild

### 5.1 Container neustarten
```bash
cd /home/node/.openclaw/workspace/openclaw-setup
docker compose down
docker compose up -d
```

### 5.2 Event anlegen (ein Versuch, muss klappen)
```bash
khal-event "2026-08-01 10:00" 12:00 "Test nach Rebuild" -a personal -m 30
```

### 5.3 PrÃ¼fen
```bash
khal list 2026-08-01
```
Muss zeigen: `10:00-12:00 Test nach Rebuild â°`

ZusÃ¤tzlich im Browser prÃ¼fen: `https://mail.sieh.org/SOGo/` â Kalender â 01.08.2026 â Termin muss sichtbar sein.

---

## Bekannte Fehler / Grenzen

- `khal-event` funktioniert nicht interaktiv (kein TTY) — fÃ¼r exec-Aufrufe ausgelegt
- `khal import` ist interaktiv, ohne `echo y |` nicht nutzbar
- vdirsyncer benÃ¶tigt Netzwerkzugriff auf mail.sieh.org — bei Ausfall schlÃ¤gt
  `khal-event` fehl (gewollt, kein lokales Waisen-Event)
- `khal list` verwendet ISO-Datumsformat (`2026-07-29`), nicht deutsches Format
