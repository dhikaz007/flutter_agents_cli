# Testing Rule

Load when creating/updating/debugging tests or validating changed logic.

Prefer focused behavioral tests for non-trivial business transitions, parsers/mappers, repository coordination, mutation guards, pagination, important UI interactions, and regressions.

When running Flutter tests under this template, run one test file per invocation rather than an entire folder/suite unless the user explicitly requests a broader run.

Avoid low-value tests that only mirror implementation details.

## Before writing the test

- Ask: "Can this test fail if the real code is broken?" If it only passes because the mock is doing what the mock was told to do, it proves nothing.
- Do not assert behavior that the language, the standard library, or the analyzer already guarantees. Test this project's decisions, not Dart's.
- Test the contract the caller depends on: the state emitted, the value returned, the argument handed to the repository boundary.

## Structure and naming

- Always wrap cases in `group()`, even when the file holds a single test, and name the group after the class under test.
- Name each case with "should" followed by the expected behavior: `test('value should start at 0', ...)`.
- Build a fresh subject per test. Shared state across cases makes failures order-dependent.
- Inject the clock and any id or random source instead of reading `DateTime.now()` inside the logic under test.
- Assert on the observable effect; avoid asserting on private field values that an implementation detail could change without breaking the contract.

## Choosing the level

- Business and state logic: unit test it in isolation from the widget tree, with no `WidgetTester`.
- Layout, interaction, and semantics: widget test the widget, not the layer below it.
- Mock only what you do not own. Prefer a real value object or a hand-written fake over a generated mock for pure data.
- Reach for a mock at a true boundary: network client, clock, filesystem, platform channel. Give it a fallback value before stubbing when the package requires one.
- Use a golden test only for a surface that is genuinely visual and expected to be stable, and pin fonts, surface size, and image loading first.

## Mocking

- Follow the project's established mocking library. Do not add a second one, and do not swap an existing one for another.
- Mock only at a boundary the project does not own: network client, clock, filesystem, platform channel, secure storage.
- Prefer a real value object, a factory, or a hand-written fake over a mock for pure data. A fake with real behavior catches more bugs than a mock that records calls.
- With `mocktail`, call `registerFallbackValue` before stubbing any method that takes a custom type, otherwise the stub returns null and the test fails far from its cause.
- With `mocktail`, stub only the method under test. Unstubbed methods throw instead of returning null, which surfaces an unexpected dependency rather than hiding it.
- Verify behavior through the public surface. Assert on the value returned or the state emitted, not on every interaction.
- Do not assert that a mock was called unless the call itself is the contract, such as a repository receiving a specific endpoint argument.

## End-to-end

- Reach for an end-to-end test only when the behavior cannot be verified at a lower level: native permission dialogs, platform channels, deep links, or a real navigation stack.
- Use the project's existing E2E harness. Do not introduce one for a single test.
- Give each test an explicit arrangement step and at least one assertion on user-visible outcome, and make it independent of test execution order.
- Select the device or platform explicitly for a native-permission test instead of relying on the default target.
- Keep E2E count low. Push logic assertions down to unit and widget tests so a failure points at one file.

## Finishing

- Keep `flutter analyze` clean after adding or changing tests.
- Do not add a test that asserts the current buggy behavior to make the suite pass. Fix the code or record the gap.

<!-- Derived from the official Dart and Flutter testing documentation. Restated as
     project rules; no upstream text is copied. -->