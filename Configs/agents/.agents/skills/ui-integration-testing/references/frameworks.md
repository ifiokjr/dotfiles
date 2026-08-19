# Framework guidance

Use this reference only for the framework involved in the current task. The shared rule is to test a user-observable use case through the largest useful slice of real application code.

## Flutter

### Widget tests

- Use widget tests for most screen and component behavior. Pump the real screen with its router, theme, localization, providers, and local state wiring when those participate in the use case.
- Replace remote services, platform channels, and persistent stores at their boundary. Prefer a small fake implementation over interaction-heavy mocks.
- Find controls by visible text or semantics when that represents how the user discovers them. Use shared `Key` values when content is dynamic, localized, visually duplicated, or a higher-level harness requires a stable contract.
- Pump the frames required by the behavior. Use `pumpAndSettle` only when the animation schedule is finite; an always-running animation makes it the wrong wait primitive.
- Assert rendered content, navigation destinations, enabled states, accessibility semantics, or another public result. Do not assert provider internals or the exact widget hierarchy.

### Flutter integration tests

- Use `integration_test` when confidence depends on the assembled app, plugins, navigation across several screens, or behavior on a target device.
- Start through an app entry point that retains production composition while accepting deterministic boundary dependencies.
- Seed state explicitly and make each test independent. Avoid ordering tests around a shared signed-in session or mutable database.
- Keep a small happy-path journey at this level; move input permutations and business-rule matrices down to widget or unit tests.

Flutter reference: [Testing Flutter apps](https://docs.flutter.dev/testing/overview) and [Integration testing](https://docs.flutter.dev/testing/integration-tests).

## Patrol

- Choose Patrol when the use case crosses Flutter and native UI: permissions, notifications, system settings, switching apps, or platform dialogs.
- For setup or API mechanics, defer to the installed `patrol-setup` and `patrol-write-test` skills and the [Patrol documentation](https://patrol.leancode.co/documentation).
- Patrol's shared keys are a public testing contract. Add only keys used by tests, keep them unique, and assert the user-visible result after the interaction.
- Run a single scenario while developing, then the relevant Patrol suite. Capture the native tree and screenshot when a platform interaction fails.

## Playwright

- Use `@playwright/test` for persistent browser tests. Use interactive Playwright exploration to learn the real flow, then encode it as a test.
- Prefer role plus accessible name, label, visible text, and then test ID. Avoid CSS structure and XPath selectors.
- Use web-first assertions such as visibility, accessible state, URL, and displayed content. Avoid asserting that a request merely completed when the user-facing outcome is what matters.
- Let Playwright auto-wait and wait for specific outcomes. Never use `waitForTimeout` as synchronization.
- Keep authentication and test data deterministic. Reuse stored authentication only when the scenario is not testing authentication itself.
- Retain traces and screenshots on failure in CI. Run a suspect test repeatedly before accepting that it is stable.

Playwright reference: [Best practices](https://playwright.dev/docs/best-practices) and [Auto-waiting](https://playwright.dev/docs/actionability).

## Principles and sources

The cross-framework guidance adapts these sources rather than importing React-specific APIs:

- Kent C. Dodds, [Write tests. Not too many. Mostly integration.](https://kentcdodds.com/blog/write-tests): integration tests balance confidence with execution and maintenance cost; excessive mocking removes integration confidence.
- Kent C. Dodds, [Testing Implementation Details](https://kentcdodds.com/blog/testing-implementation-details): assertions on internals create false failures during refactors and can miss broken user behavior.
- Kent C. Dodds, [How to know what to test](https://kentcdodds.com/blog/how-to-know-what-to-test): prioritize use-case coverage and begin with the workflows whose failure would hurt most.
- Testing Library, [Guiding Principles](https://testing-library.com/docs/guiding-principles) and [query priority](https://testing-library.com/docs/queries/about#priority): tests gain confidence by resembling real use and preferring accessible queries.
