---
name: ui-integration-testing
description: Use whenever a project needs UI tests or integration-test setup for Flutter, Patrol, Playwright, React, or another app framework.
---

# UI Integration Testing

Optimize for confidence per maintenance cost. Default to integration tests for user-visible behavior: exercise real components together, interact through the public UI, and assert outcomes a user can observe.

## Choose the test level

Choose the lowest level that crosses every boundary needed to prove the use case—not the smallest unit that happens to execute the changed line.

| Level | Use it for |
| --- | --- |
| Static checks | Type, lint, and compile-time guarantees |
| Unit | Pure logic, parsers, state transitions, and combinatorial edge cases |
| Component or widget | One meaningful UI behavior with its real local collaborators |
| Integration | The default for behavior spanning UI, routing, state, persistence, or data flow |
| End to end | A few critical journeys, real-device behavior, native UI, or system integration |

Do not chase a coverage percentage. Inventory use cases, rank them by the cost of breakage, cover the most important happy path, then add material failure and edge cases at the cheapest level that still provides confidence.

## Build a behavior-first test

1. Read the feature, adjacent tests, test configuration, and existing helpers before choosing a pattern.
2. State the use case in user language and identify its observable success or failure outcome.
3. Start from production composition: use the real router, state wiring, widgets or components, serialization, and internal collaborators involved in that outcome.
4. Replace only boundaries that are slow, destructive, uncontrollable, or outside the process. Prefer deterministic fakes, seeded stores, and local test servers over mocks of internal calls.
5. Interact as a user would. Prefer accessible names, visible labels, and semantic roles. Treat test IDs or keys as an explicit UI testing API when user-facing selectors are unavailable or the platform harness requires them.
6. Assert the visible or public result, not internal state, callback counts, network completion, provider emissions, component instances, or exact widget trees.
7. Run the exact test through the real harness. Debug failures from screenshots, traces, logs, and rendered state; do not add arbitrary sleeps.

## Keep tests trustworthy

- A refactor that preserves behavior should usually leave the test unchanged.
- Breaking the named behavior should make the test fail for the expected reason.
- Wait for observable conditions. Use bounded framework waits; never use fixed delays to hide races.
- Give each test isolated data and reset mutable external state. Control clocks, randomness, identity, and network responses when they affect the scenario.
- Keep helpers in domain language such as `signInAs` or `completeCheckout`. Do not hide the outcome assertion or turn every click into a helper.
- Avoid one test per implementation branch. One user journey may validly exercise several internal branches.
- Keep E2E coverage deliberately small. Put alternate inputs and error permutations in faster integration or unit tests.

## Platform guidance

Read [references/frameworks.md](references/frameworks.md) for Flutter widget and integration tests, Patrol native flows, and Playwright web tests. Follow the project's existing harness and conventions before introducing another one.

When Patrol is selected, use `patrol-setup` for first-time configuration and `patrol-write-test` for current APIs, native interactions, and key conventions. This skill decides what behavior to cover and where; the Patrol skills decide how to express it.

## Completion gate

Before reporting success:

- Run the narrow test, then the relevant surrounding suite.
- Re-run timing-sensitive or previously flaky flows enough to expose instability.
- Confirm failure artifacts are usable in CI for costly flows.
- Report the use case covered, the boundaries kept real, the boundaries replaced, and the exact commands that passed.
