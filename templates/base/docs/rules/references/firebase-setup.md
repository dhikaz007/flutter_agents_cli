# Firebase setup

Project-level wiring: the CLI run, the config files it produces, the emulator, and
per-flavor projects. Read this before changing setup code or adding a flavor.

## One initialize, before anything else

- `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` runs once in `main()` after `WidgetsFlutterBinding.ensureInitialized()` and is awaited before `runApp`.
- Keep the call in one bootstrap function. A second `initializeApp` with different options throws at runtime, so a duplicate bootstrap surfaces only on the flavor that runs it.
- Pass the options explicitly. Without them, initialization falls back to the platform config file and a missing file becomes a silent misconfiguration.
- Give `Firebase.initializeApp` a `demoProjectId` starting with `demo-` when the app runs against the Emulator, and never ship that path in a release build.

## Configure with the FlutterFire CLI

- Run `flutterfire configure` from the project root. It selects the platforms, registers each app in the Firebase project, writes `lib/firebase_options.dart`, and adds the Crashlytics Gradle plugin on Android.
- Re-run it after the package id or bundle id changes, after a new platform is added, and after the project is linked to a different Firebase project. It matches existing apps by the project identifiers, so an unchanged id keeps the same Firebase app.
- Use `flutterfire configure --out=<path>` when the generated file must not sit at `lib/firebase_options.dart`, and update the import with it.
- Commit the generated options file. It holds non-secret identifiers, and a fresh checkout that lacks it cannot build or run.
- Never hand-edit a generated options file. `flutterfire configure` overwrites it, and a manual value drifts from the console without warning.

## Platform minimums

- Each Firebase plugin declares its own minimum Android API level and iOS deployment target. Set the project minimum to the highest requirement across the plugins actually in `pubspec.yaml`, not to the Flutter default.
- A minimum set too low fails at build or at first plugin call, not at `pubspec.yaml` resolution. Raise it in `android/app/build.gradle` and in the iOS target before adding a plugin that needs more.

## Platform config files

- Android reads `android/app/google-services.json`, and iOS reads the `GoogleService-Info.plist` added to the target.
- Both are non-secret and identify the app, not the account. They are still project-scoped: commit them, and never copy one flavor's file over another.
- Add the plist through the Xcode target's membership, not by leaving it loose in the project folder.

## Emulator

- Run `firebase init emulators` once per project and start the suite with `firebase emulators:start`. Port overrides belong in `firebase.json` so every machine and CI agrees.
- Call `useAuthEmulator('localhost', <port>)` and the equivalent `useFirestoreEmulator` right after initialization, before the first authenticated call.
- Gate emulator wiring behind a compile-time flag so a release build cannot reach it. Emulator traffic must never touch a production project.
- Point the Auth Emulator at the Firestore Emulator when a rule reads the auth token, or the rule sees an anonymous user and passes for the wrong reason.

## Flavors and environments

- Give each release-status variant its own Firebase project. A debug build that shares the release project writes test data into production and defeats App Check enforcement.
- Keep the platform apps of one variant in one project. iOS and Android of the same build belong together; they share data and rules.
- Android resolves the config per variant from `android/app/src/<flavor>/google-services.json`, falling back to `android/app/google-services.json`. Place one file per flavor so no variant silently inherits the default project's config.
- iOS needs a per-configuration plist. With separate targets, add each plist to its own target through target membership. Within one target, give each a distinct name such as `GoogleService-Info-<flavor>.plist` and load it by name at runtime.
- Select the options per flavor from one place, a small lookup from the flavor name to the matching `FirebaseOptions`. Do not branch on the flavor inside a repository or a widget.
- Keep the flavor name available in Dart through the project's existing flavor mechanism. A `--dart-define` or an existing flavor helper is enough; do not add a second mechanism to read it.
- Per-flavor wiring means per-flavor App Check registration, per-flavor Crashlytics apps, and per-flavor App Distribution targets. Adding a flavor without them leaves that build reporting into the wrong project.

<!-- Derived from the official Flutter setup, Emulator Suite, and multi-project
     documentation. Restated as project rules; no upstream text is copied. -->
