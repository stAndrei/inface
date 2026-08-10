# Tasks: bootstrap-mac-app

- [x] B1 Package + App shell
  - Assignee: developer
  - Goal: SPM Package.swift, InfaceApp MenuBarExtra, Settings, Info.plist strings
  - Acceptance: app-shell scenarios
  - Reviewers: spec, architecture, ui, security
  - Tests: smoke compile; unit N/A
  - Depends on: —

- [x] B2 Design tokens in UI
  - Assignee: designer → developer
  - Goal: применить Visual brief
  - Acceptance: RU copy + visual tokens
  - Reviewers: ui
  - Tests: N/A
  - Depends on: B1

## Review board (closed-loop)

- Spec: Approve
- Architecture: Approve
- Security: Approve (usage strings present)
- UI: Approve (RU empty state)
- Tests: Approve (smoke build)

## Tester

- Pass: `swift build --product Inface`
- Functional suite later covers permission flows via mock
