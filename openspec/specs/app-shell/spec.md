# app-shell Specification

## Purpose
TBD - created by archiving change bootstrap-mac-app. Update Purpose after archive.
## Requirements
### Requirement: Menu bar presence
The system SHALL show a menu bar extra for Inface when the app is running.

#### Scenario: Icon visible
- GIVEN Inface is launched
- WHEN the menu bar is inspected
- THEN an Inface menu bar item is available

### Requirement: Russian empty state
The system SHALL show Russian copy indicating calendars are not connected yet.

#### Scenario: Empty state text
- GIVEN no calendar permission granted
- WHEN the user opens the menu bar popover
- THEN the UI shows «Календари ещё не подключены»

### Requirement: Permission request entry point
The system SHALL provide a button to request Calendar access.

#### Scenario: Request button
- GIVEN empty state
- WHEN the user taps «Запросить доступ к Календарю»
- THEN the app invokes the calendar permission request API

