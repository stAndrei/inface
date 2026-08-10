# Delta for meeting-links

## ADDED Requirements

### Requirement: Extract conference URL
The system SHALL extract the first valid conference URL from event url, notes, or location.

#### Scenario: Teams link in notes
- GIVEN an event with a Teams URL in notes
- WHEN detection runs
- THEN that URL is returned as the meeting link

### Requirement: Join action
The system SHALL show «Подключиться» when a meeting URL exists and open it with the default handler.

#### Scenario: Join from alert
- GIVEN an alert with a detected meeting URL
- WHEN the user taps «Подключиться»
- THEN the URL is opened via the link opener
