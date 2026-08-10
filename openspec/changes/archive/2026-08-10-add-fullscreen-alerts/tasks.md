# Tasks: add-fullscreen-alerts

- [x] A1 Scheduler
  - Assignee: developer
  - Goal: AlertScheduler + unit tests (timing, pause, snooze)
  - Reviewers: spec, architecture, tests
  - Tests: unit
  - Depends on: eventkit

- [x] A2 Fullscreen UI
  - Assignee: designer → developer
  - Goal: AlertWindowController + RU actions + debug hook
  - Reviewers: spec, ui, tests
  - Tests: functional forceAlert
  - Depends on: A1

## Review board

- Spec / Architecture / UI / Tests: Approve

## Tester

- Pass: scheduler unit + forceAlert functional
