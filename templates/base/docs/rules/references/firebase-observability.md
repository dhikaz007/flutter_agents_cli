# Firebase observability

## Crashlytics

- Record a fatal and a non-fatal error differently: an unhandled framework exception is a crash, and an expected failure is a non-fatal record.
- Forward `FlutterError.onError` and `PlatformDispatcher.instance.onError` to Crashlytics, or fatal reporting silently misses real crashes.
- Catch isolate errors with `runZonedGuarded` or `Isolate.current.addErrorListener`. An error in a background isolate does not reach the zone that owns `onError`.
- Never let a Crashlytics call throw. Wrap reporting in its own guard so telemetry cannot become the crash.
- Record breadcrumbs and custom keys for the state a failure depends on: screen route, user id, request id, feature flag. Do not record tokens, email, or document contents.
- Attach a user identifier after sign-in and clear it on sign-out, so one user's crash data is not attributed to the next user.
- Release builds need obfuscated symbol upload. Generate the symbol file with the release build and upload the matching `app` symbol, or every release stack trace is unsymbolicated.
- Keep the mapping file per release version. Re-uploading the same version overwrites the previous symbols.

## Analytics

- Log an event only for a meaningful product action. Do not log a screen name on every frame or a raw widget interaction.
- Set user properties once after sign-in and reset on sign-out.
- Use the project's default event parameters rather than repeating the app name and version on every event.
- Do not send an email, a user id, a document path, or any other direct identifier as an event name or parameter.
- Do not log an event in debug builds if the project gates analytics, so test traffic never reaches production reporting.

## Remote Config

- Give every parameter a default in code and fetch/activate before the first screen reads it. A missing remote value must not be `null` at a call site.
- Activate once per launch or on the project's documented trigger, not on every entry to a screen.
- Read the value once into state and let the widget rebuild from that. Do not call `getString` inside `build` on every frame.
- Gate a flag behind an `await getBool` only where the flag changes behavior; a gate that flashes the wrong variant is worse than no gate.
- A flag must be safe in both states. Treat "off" as the working baseline and make "on" additive, because a kill switch can be triggered at any time.

## Verification

- Confirm a release-mode crash reaches Crashlytics with the expected symbol before shipping. A dev-mode-only check does not prove the release path.
- Verify the rules in the Emulator, and verify that the release build has App Check enforcement active.

<!-- Derived from the official Crashlytics, Analytics, and Remote Config Flutter
     documentation. Restated as project rules; no upstream text is copied. -->