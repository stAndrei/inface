# Inface

Личный macOS menu-bar meeting reminder (вдохновлён In Your Face).

## Tech stack

- Swift 5.9+ / SwiftUI + AppKit
- EventKit (календари, в т.ч. Exchange через Calendar.app)
- Swift Package Manager (`Package.swift`)
- Unit: XCTest; Functional: XCTest с debug-хуками (+ XCUITest когда есть полный Xcode)
- macOS 14+

## Product

- Имя: **Inface**
- UI: **русский**
- Default alert lead time: **1 минута**
- MVP: menu bar, EventKit sync, fullscreen alerts, meeting link join
- Out of MVP: filters UI, themes, reminders/widgets, polish/login item, StoreKit, remote git

## Conventions

- OpenSpec в `openspec/`; closed-loop агенты в `.cursor/agents/`
- Domain models в `InfaceCore`; UI в `InfaceApp`
- EventKit за протоколами для тестов
- Coverage ≥70% на новый код Core
- Локальные git commits после каждого change; без push

## Agent team

См. `AGENTS.md`.
