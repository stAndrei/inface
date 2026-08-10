# Proposal: add-eventkit-sync

## Why

Показывать upcoming/ongoing события из системных календарей (включая Exchange).

## What Changes

- EventStore protocol + EKEventStore implementation
- Domain `MeetingEvent`
- Menu list of upcoming events
- Live refresh on EKEventStoreChanged
- Denied permission → CTA в Системные настройки

## Non-goals

- Direct Microsoft Graph OAuth
- Filters / reminders

## Impact

- InfaceCore + MenuBar UI
