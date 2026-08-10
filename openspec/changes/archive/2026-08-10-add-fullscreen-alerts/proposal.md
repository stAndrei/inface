# Proposal: add-fullscreen-alerts

## Why

Непропускаемый fullscreen alert за 1 минуту до встречи — ядро продукта.

## What Changes

- AlertScheduler with injectable clock
- AppKit borderless windows on all screens
- Dismiss, Snooze 5/10 min
- Pause flag
- Reschedule on wake

## Non-goals

- Themes, custom sounds packs, per-event overrides UI

## Impact

- InfaceCore scheduler + InfaceApp AlertWindowController
