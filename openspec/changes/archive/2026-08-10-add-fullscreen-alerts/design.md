# Design: add-fullscreen-alerts

## Approach

`AlertScheduler` computes next fire from events + lead time (default 60s).
`AlertWindowController`: NSPanel level `.screenSaver`, one per NSScreen.
Debug: `InfaceDebug.forceAlert(event)` for functional tests.
Pause via `AppSettings.alertsPaused`.

## Visual

- Fullscreen: градиент уголь→глубокий сине-зелёный, крупный title, countdown
- Primary CTA: «Закрыть», secondary «Отложить 5 мин» / «10 мин»
- Appear: scale 0.98→1 + fade 0.25s

## Test plan

- Unit: scheduler timing table (lead time, snooze, pause)
- Functional: forceAlert shows overlay via test hook
