# Inface

Menu-bar напоминания о встречах для macOS (русский UI). Полноэкранный алерт за 1 минуту до события, Join для видеоссылок, календари через EventKit (включая корпоративный Exchange из Calendar.app).

## Требования

- macOS 14+
- Полный **Xcode** (рекомендуется) или Command Line Tools со Swift 5.9+
- Календарь настроен в системном Calendar.app

## Сборка и запуск

```bash
cd /Users/petrovan/work/inface
swift build
swift build --product InfaceTests && .build/debug/InfaceTests
swift run Inface
```

> На машине без полного Xcode нет XCTest — используется `InfaceTests` (unit + functional harness). После установки Xcode можно добавить XCTest/XCUITest targets.

Для `.app` бандла после установки Xcode:

```bash
./Scripts/package-app.sh
open dist/Inface.app
```

При первом запуске выдайте доступ к Календарю.

## OpenSpec / агенты

См. `openspec/project.md` и `AGENTS.md`.

## MVP

- Menu bar + настройки
- EventKit sync
- Fullscreen alerts (закрыть / отложить 5/10 мин / пауза)
- Детект meeting links + «Подключиться»
