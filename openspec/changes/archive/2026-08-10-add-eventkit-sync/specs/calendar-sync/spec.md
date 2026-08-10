# Delta for calendar-sync

## ADDED Requirements

### Requirement: Request calendar access
The system SHALL request Calendar access and on denial show a CTA to open System Settings.

#### Scenario: Denied shows CTA
- GIVEN permission is denied
- WHEN the popover is shown
- THEN the UI offers «Открыть настройки» to open System Settings

### Requirement: List upcoming events
The system SHALL show upcoming and ongoing events from EventKit sources including Exchange calendars present in EKEventStore.

#### Scenario: Events listed
- GIVEN permission granted and events in the next 48 hours
- WHEN the popover is shown
- THEN event titles and start times are listed in Russian-friendly formatting

### Requirement: Live updates
The system SHALL refresh the event list when the event store changes without relaunch.

#### Scenario: Store changed
- GIVEN the app is running with access
- WHEN EKEventStoreChanged is posted
- THEN the upcoming list is reloaded

### Requirement: No separate Microsoft OAuth
The system SHALL NOT require separate Microsoft OAuth while events are available via system Calendar/EventKit.

#### Scenario: Exchange via EventKit
- GIVEN an Exchange calendar synced in Calendar.app
- WHEN events are fetched
- THEN they appear without a Microsoft login screen in Inface
