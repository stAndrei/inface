# QA Checklist — Inface MVP

## Automated

- [x] `swift build --product InfaceTests && .build/debug/InfaceTests` — unit + functional green
- [x] Coverage focus: MeetingLinkDetector, AlertScheduler, MockCalendarService / AppModel hooks (CLT harness; XCTest when Xcode installed)

## Manual (на машине пользователя)

- [ ] Exchange/рабочие встречи видны в Calendar.app
- [ ] Inface: «Запросить доступ к Календарю» → события появляются
- [ ] Fullscreen алерт за ~1 мин до тестовой встречи
- [ ] «Подключиться» открывает Teams/Zoom из события
- [ ] «Пауза» глушит алерты
- [ ] Snooze 5/10 мин
- [ ] Multi-display: алерт на всех экранах (если есть)
- [ ] Sleep/wake: алерт не теряется безвозвратно

## Notes

Живой Exchange в CI недоступен — покрыт mock + этот checklist.
