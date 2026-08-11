# Proposal: add-direct-exchange-ews

## Why

Пользователям нужен прямой доступ к корпоративному Exchange (Ozon) без зависимости от синхронизации Calendar.app — с тем же списком встреч и алертами.

## What Changes

- Переключатель источника: EventKit ↔ Exchange (EWS)
- `EWSCalendarService`: Basic auth к `https://mailsec.o3t.ru/EWS/Exchange.asmx`
- Пароль клиента `КОД:ПАРОЛЬ` (из @mail-bot в Chatzone) → Keychain
- Username `{login}@ozon.ru`, fallback `o3\{login}` при 401
- Polling ~60с + reload на wake / смену дня / логин / открытие popover
- Settings UI: инструкция @mail-bot, логин, пароль, Войти/Выйти

## Non-goals

- Microsoft Graph OAuth
- Запись/редактирование событий
- Shared/чужие календари
- Встроенный mail-bot / Enigma

## Impact

- InfaceCore: EWS client, Keychain, CalendarSourceRouter
- InfaceApp: Settings, MenuBar popover reload
- Spec delta: `exchange-ews`
