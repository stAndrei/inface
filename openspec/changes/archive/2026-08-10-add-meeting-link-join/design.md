# Design: add-meeting-link-join

## Approach

Scan `url`, then `notes`, then `location` for known hosts/patterns.
`LinkOpening` protocol wraps `NSWorkspace`.
Bundled provider list in code (extensible array).

## Test plan

- Unit: fixture URLs for 30+ patterns
- Functional: Join calls LinkOpening mock
