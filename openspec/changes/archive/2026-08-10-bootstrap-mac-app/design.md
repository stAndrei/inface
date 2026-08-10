# Design: bootstrap-mac-app

## Approach

Swift Package: library `InfaceCore`, executable `InfaceApp` (SwiftUI `@main`).
`LSUIElement`-style menu bar via `MenuBarExtra`.
Settings: `Settings` scene.

## Visual

- Menu bar icon: SF Symbol `calendar.badge.exclamationmark`
- Popover: тёмный угольный фон `#1A1F24`, акцент янтарь `#E8A838`, шрифт заголовка `.system(.title3, design: .rounded)`
- Статус: «Календари ещё не подключены»
- Кнопка: «Запросить доступ к Календарю»
- Лёгкий fade при появлении popover (opacity 0→1, 0.2s)

## Test plan

- Smoke: target compiles
- Unit N/A for shell; functional placeholder app launch hook later
