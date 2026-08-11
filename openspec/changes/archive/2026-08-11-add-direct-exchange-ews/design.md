# Design: add-direct-exchange-ews

## Approach

`CalendarSourceRouter` implements `CalendarAccessing` and delegates to `EventKitCalendarService` or `EWSCalendarService`.

EWS: SOAP `FindItem` + `CalendarView` on distinguished calendar folder. HTTP Basic auth header. Credentials in Keychain (`ru.inface.exchange`).

Exchange refresh: Timer polling 60s; no EKEventStoreChanged.

## Visual (Settings — Exchange)

- Секция «Календарь»: Picker «Системный (EventKit)» / «Exchange (EWS)»
- При Exchange — info-блок (`.callout`, secondary):
  - Логин: `имя@ozon.ru` (пример `petrovan@ozon.ru`)
  - Пароль: строка `код:пароль` из @mail-bot в Chatzone
  - При смене пароля учётки обновите код и пароль здесь
- Поля: логин (TextField), пароль (SecureField), endpoint (advanced, default mailsec)
- Кнопки «Войти» / «Выйти»; статус ошибки красным callout
- Tokens: `InfaceTheme.accent`, grouped Form как в существующих Settings

## Test plan

- Unit: SOAP XML parse, event mapping, router switch, Keychain mock, Basic auth header
- Functional: AppModel с mock EWS, popover reload hook
- Manual: mailsec + реальный @mail-bot код (qa-checklist)
