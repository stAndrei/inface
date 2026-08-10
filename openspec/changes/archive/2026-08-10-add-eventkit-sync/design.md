# Design: add-eventkit-sync

## Approach

`CalendarAccessing` protocol; `EventKitCalendarService` wraps `EKEventStore`.
Fetch window: now → +48h. Map to `MeetingEvent`.
Observe `.EKEventStoreChanged`.
Permission denied: open `x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars` (or Settings URL on modern macOS).

## Test plan

- Unit: mapping EKEvent→MeetingEvent with fixtures/mocks
- Functional: inject mock store into app state, assert list titles
