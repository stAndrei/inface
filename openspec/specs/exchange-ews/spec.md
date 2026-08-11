# exchange-ews Specification

## Purpose
Direct Exchange (EWS) calendar source for Ozon corporate mail/calendar with EventKit fallback.

## Requirements

### Requirement: Calendar source switch
The system SHALL let the user choose EventKit or Exchange as the calendar source in Settings.

#### Scenario: Switch to Exchange
- GIVEN Settings is open
- WHEN the user selects Exchange
- THEN Exchange login fields and @mail-bot instructions are shown

#### Scenario: Switch to EventKit
- GIVEN Exchange was selected
- WHEN the user selects EventKit
- THEN the app uses system Calendar permission flow as before

### Requirement: Exchange EWS login
The system SHALL connect to `https://mailsec.o3t.ru/EWS/Exchange.asmx` using HTTP Basic auth with username `{login}@ozon.ru` and password entered as `CODE:PASSWORD` from @mail-bot.

#### Scenario: Successful login
- GIVEN valid credentials
- WHEN the user taps «Войти»
- THEN credentials are stored in Keychain and events are fetched

#### Scenario: Auth failure
- GIVEN invalid credentials
- WHEN login fails
- THEN a Russian error is shown and password is not logged

### Requirement: Exchange event list
The system SHALL list the user's calendar events with title, start/end, location, notes, and meeting URL in the same UI as EventKit events.

#### Scenario: Events listed
- GIVEN Exchange is authorized
- WHEN the menu bar popover is shown
- THEN upcoming events for the selected day appear

### Requirement: Exchange refresh triggers
The system SHALL refresh Exchange events on timer (~60s), system wake, day change, after login, and when opening the menu bar popover.

#### Scenario: Popover open reload
- GIVEN Exchange source and valid credentials
- WHEN the user opens the menu bar popover
- THEN events are reloaded from EWS

### Requirement: Exchange logout
The system SHALL remove Exchange credentials from Keychain on «Выйти».

#### Scenario: Logout
- GIVEN stored Exchange credentials
- WHEN the user taps «Выйти»
- THEN Keychain entry is deleted and auth status becomes notDetermined
