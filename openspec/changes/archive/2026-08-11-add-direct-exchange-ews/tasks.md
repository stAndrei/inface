# Tasks: add-direct-exchange-ews

- [x] X1 Core EWS + Keychain + Router
  - Assignee: developer
  - Goal: EWSCalendarService, EWS SOAP client/parser, Keychain store, CalendarSourceRouter
  - Reviewers: spec, architecture, security, tests
  - Tests: unit ≥70% on new Core
  - Depends on: add-eventkit-sync (archived)

- [x] X2 Settings + AppModel wiring
  - Assignee: developer
  - Goal: source picker, @mail-bot instructions, login/logout, popover reload
  - Reviewers: spec, ui, security, tests
  - Tests: functional AppModel + Settings flows
  - Depends on: X1

## Review board

- Spec / Architecture / Security / UI / Tests: Approve

## Tester

- Pass: swift test (31 tests) + qa-checklist Exchange section
