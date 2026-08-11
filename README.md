<p align="center">
  <img src="docs/assets/icon-readme.png" alt="Inface icon" width="160" height="160" />
</p>

# Inface

**Fullscreen meeting reminders for macOS** — so you actually notice the call before it starts.

Inface lives in the menu bar and can read calendars either via **Apple EventKit** (including Exchange already set up in Calendar.app) or via **direct corporate Exchange (EWS)** (`mailsec.o3t.ru`). About **one minute before** each meeting it shows a fullscreen alert. One click joins Zoom, Google Meet, Teams, ChatZone, and other common links.

UI language: **Russian**.

---

## What it does

| Feature | Details |
|--------|---------|
| Menu bar timeline | Day view of your meetings, side‑by‑side columns for overlaps, click a meeting for details |
| Fullscreen alerts | Unmissable overlay ~1 minute before start (snooze 5/10 min, pause, dismiss) |
| Calendar sync | EventKit **or** direct Exchange EWS (switch in Settings) |
| Local cache | Exchange events show instantly from cache; refresh runs in the background |
| Join meeting | Detects conference links; **ChatZone / Meetzone** opens in the ChatZone desktop app |
| Launch at login | Registered as a login item by default (toggle in Settings) |
| Privacy‑first | Calendar data stays on your Mac — passwords in Keychain, no cloud sync of events |

---

## Requirements

- macOS **14+**
- **Xcode** (recommended) or Command Line Tools with Swift 5.9+
- For EventKit: calendars in the system **Calendar** app
- For Exchange EWS: corporate login + `код:пароль` from **@mail-bot** in Chatzone

---

## Install (DMG)

1. Download the latest `Inface-*.dmg` from [Releases](https://github.com/stAndrei/inface/releases) (or build one locally — see below).
2. Open the DMG and drag **Inface** into **Applications**.
3. Launch Inface.
4. If Gatekeeper blocks it (ad‑hoc signature): right‑click → **Open**, or allow it in **System Settings → Privacy & Security**.
5. Connect a calendar (EventKit permission **or** Exchange login — see below).
6. Click the calendar icon in the menu bar.

Optional: keep **Launch at login** enabled (default) so Inface starts when you sign in.

---

## Connect Exchange (EWS)

1. Open Inface → **⚙️ / Настройки** (or **⌘,**).
2. **Календарь → Источник → Exchange (EWS)**.
3. **Логин:** `имя@ozon.ru` (example: `petrovan@ozon.ru`).
4. **Пароль:** string `КОД:ПАРОЛЬ` from **@mail-bot** in Chatzone (not your account password alone).
5. Tap **Войти**. Default server: `https://mailsec.o3t.ru/EWS/Exchange.asmx`.

After password rotation (~every 3 months), get a new code from @mail-bot and update the password field.

---

## How to use

1. **Menu bar icon** — open the popover to see today’s (or another day’s) timeline.
2. **Day switcher** — previous / next day, or jump to Today.
3. **Meeting card** — click a block for title, time, location, notes, and join link.
4. **Join** — **Подключиться** opens the meeting link (ChatZone Meetzone UUID links open in ChatZone.app).
5. **Alert** — when a meeting is about to start, a fullscreen sheet appears:
   - join / dismiss / snooze / pause alerts
6. **Settings**:
   - calendar source (EventKit / Exchange)
   - lead time (minutes)
   - pause alerts
   - launch at login

---

## Build from source

```bash
git clone https://github.com/stAndrei/inface.git
cd inface

# Prefer full Xcode toolchain
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# or: ./Scripts/use-xcode.sh

swift test
./Scripts/package-app.sh
open dist/Inface.app
```

### Shareable DMG

```bash
./Scripts/package-dmg.sh
# → dist/Inface-<version>.dmg
```

Reload a running local build:

```bash
./Scripts/reload-app.sh
```

---

## Project layout

- `Sources/InfaceCore` — calendar (EventKit + EWS), alerts, link detection, cache
- `Sources/InfaceApp` — SwiftUI menu bar UI + fullscreen presenter
- `Scripts/package-app.sh` / `package-dmg.sh` / `reload-app.sh` — packaging & local reload
- `openspec/` — product specs and change history
- `AGENTS.md` — local multi‑agent workflow notes

---

## Privacy

Inface requests **Calendar** access only when using EventKit. Exchange credentials are stored in the macOS **Keychain**. Events are not uploaded. Meeting links are opened locally via `NSWorkspace` / ChatZone deep links.

---

## License

MIT — see [LICENSE](LICENSE).
