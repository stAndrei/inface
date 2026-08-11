# Inface — команда агентов

Замкнутый цикл: **Тимлид** → **BA** (задачи) → **Дизайнер?** → **Разработчик** ↔ **Board ревьюеров** → **Тестер**.

## Роли

| Роль | Файл |
|------|------|
| Тимлид | `.cursor/agents/team-lead.md` |
| Бизнес-аналитик | `.cursor/agents/business-analyst.md` |
| Дизайнер | `.cursor/agents/designer.md` |
| Разработчик | `.cursor/agents/developer.md` |
| Ревьюер Spec | `.cursor/agents/reviewer-spec.md` |
| Ревьюер Architecture | `.cursor/agents/reviewer-architecture.md` |
| Ревьюер Security | `.cursor/agents/reviewer-security.md` |
| Ревьюер UI | `.cursor/agents/reviewer-ui.md` |
| Ревьюер Tests | `.cursor/agents/reviewer-tests.md` |
| Тестер | `.cursor/agents/tester.md` |

## MVP scope

Changes: `bootstrap-mac-app` → `add-eventkit-sync` → `add-fullscreen-alerts` → `add-meeting-link-join`.

Продукт: **Inface**, UI **русский**, календари через EventKit (Exchange из Calendar.app), lead time **1 мин**.

## DoD change

- `tasks.md` все `[x]`
- ревьюеры Approve (0 blockers)
- unit + functional green, coverage ≥70% на новый код
- QA checklist Pass или N/A
- openspec archive + локальный git commit
- после изменений Swift/UI: `./Scripts/reload-app.sh` (пересборка `dist/Inface.app` + перезапуск)
- **релиз** (когда просят): обновить README → bump version в Info.plist → `swift test` → `./Scripts/package-dmg.sh` → push → merge в `main` → GitHub Release + DMG

## Эскалация человеку

Только: нет Xcode / permission denied / MDM / 4-й failed review loop.
