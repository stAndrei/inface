# QA Checklist — Inface MVP

## Automated

- [x] `DEVELOPER_DIR=... swift test` — XCTest unit + functional green
- [x] `InfaceTests` harness green
- [x] `./Scripts/package-app.sh` + ad-hoc codesign

## Manual (на машине пользователя)

- [x] Exchange/рабочие встречи видны в Calendar.app
- [x] Inface: «Запросить доступ к Календарю» → события появляются
- [ ] Exchange (EWS): Settings → Exchange → логин `имя@ozon.ru`, пароль `код:пароль` из @mail-bot
- [ ] Exchange: события видны в popover без Calendar.app
- [ ] Exchange: popover reload при открытии иконки
- [ ] Exchange: в карточке встречи есть заметки и «Подключиться» на ChatZone Meetzone UUID
- [ ] «Подключиться» по `chatzone.o3t.ru/meetzone/{uuid}` открывает звонок `/meet/{uuid}`, не town-square
- [x] Fullscreen алерт за ~1 мин до тестовой встречи
- [ ] «Подключиться» открывает Teams/Zoom из события
- [ ] «Пауза» глушит алерты
- [ ] Snooze 5/10 мин
- [x] Multi-display: алерт на всех экранах (если есть)
- [ ] Sleep/wake: алерт не теряется безвозвратно



## Notes

Xcode установлен. Один раз выполни `./Scripts/use-xcode.sh` (sudo), чтобы `xcodebuild`/`swift test` работали без `DEVELOPER_DIR`.
Живой Exchange в CI недоступен — покрыт mock + этот checklist.