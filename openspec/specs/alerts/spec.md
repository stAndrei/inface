# alerts Specification

## Purpose
TBD - created by archiving change add-fullscreen-alerts. Update Purpose after archive.
## Requirements
### Requirement: Fullscreen alert before event
The system SHALL present a fullscreen alert on all displays at the configured lead time before an event (default 1 minute).

#### Scenario: Default lead time
- GIVEN an event starting in 60 seconds and default settings
- WHEN the scheduler fires
- THEN a fullscreen alert for that event is shown

### Requirement: Snooze
The system SHALL allow snoozing an alert by 5 or 10 minutes.

#### Scenario: Snooze 5
- GIVEN a visible alert
- WHEN the user chooses «Отложить 5 мин»
- THEN the alert dismisses and is scheduled to reappear in 5 minutes

### Requirement: Pause
The system SHALL NOT present alerts while Pause is enabled.

#### Scenario: Paused
- GIVEN alerts are paused
- WHEN a fire time is reached
- THEN no alert window is shown

### Requirement: Wake reschedule
The system SHALL reschedule alerts after system wake.

#### Scenario: After sleep
- GIVEN the Mac sleeps past a fire time or near it
- WHEN the system wakes
- THEN the scheduler recomputes upcoming fires

