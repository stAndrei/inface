# Inface

Menu-bar напоминания о встречах для macOS (русский UI). Полноэкранный алерт за 1 минуту до события, Join для видеоссылок, календари через EventKit (включая корпоративный Exchange из Calendar.app).

## Требования

- macOS 14+
- Полный **Xcode** (рекомендуется) или Command Line Tools со Swift 5.9+
- Календарь настроен в системном Calendar.app

## Сборка и запуск

Один раз переключи CLI на полный Xcode (нужен пароль):

```bash
./Scripts/use-xcode.sh
# или:
# sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Пока `xcode-select` не переключён, в каждой сессии можно так:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

```bash
cd /Users/petrovan/work/inface
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
swift build --product InfaceTests && .build/debug/InfaceTests
./Scripts/package-app.sh
open dist/Inface.app
```

В menu bar появится иконка календаря. Нажми «Запросить доступ к Календарю» — должны подтянуться события Exchange из Calendar.app.

Для `.app` бандла после установки Xcode:

```bash
./Scripts/package-app.sh
open dist/Inface.app
```

При первом запуске выдайте доступ к Календарю. По умолчанию Inface регистрируется в **объектах входа** (запуск при логине); отключить можно в настройках приложения.

## Раздача коллегам (DMG)

```bash
./Scripts/package-dmg.sh
# → dist/Inface-0.1.0.dmg
```

Отправьте `dist/Inface-0.1.0.dmg`. Получатель: открыть DMG → перетащить **Inface** в **Applications**.

Пока подпись ad-hoc (без Apple Developer ID), при первом запуске macOS может показать предупреждение Gatekeeper: ПКМ по приложению → **Открыть**, либо «Системные настройки → Конфиденциальность и безопасность → Всё равно открыть». Затем выдать доступ к Календарю.

## OpenSpec / агенты

См. `openspec/project.md` и `AGENTS.md`.

## MVP

- Menu bar + настройки
- EventKit sync
- Fullscreen alerts (закрыть / отложить 5/10 мин / пауза)
- Детект meeting links + «Подключиться»
