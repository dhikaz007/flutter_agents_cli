# Fastlane Scaffold Design

Date: 2026-10-04
Status: approved in chat, pending written review

## Goal

Add `agents release init` to Flutter Agents CLI. The command writes a working
`fastlane/Fastfile` that builds an APK, uploads it to Firebase App Distribution,
prompts for release notes, auto-increments the build number from App
Distribution, and cleans up artifacts afterwards. The generated Fastfile adapts
at runtime to whether the project declares Android product flavors.

## Non-goals

- Not a profile slot. `StackConfig.kindFields`, `manifest.dart` serialization,
  `dependency_manager.dart`, and `detector.dart` are untouched.
- Not a dependency installer. Fastlane is a Ruby gem; `DependencyManager.run()`
  only shells out to `flutter pub`, so it cannot be reused.
- Not a replacement for an existing Fastfile. Real Fastfiles in the wild are
  241 to 613 lines. The generated file is a starting point.
- Not TestFlight, Play Store, or `match` device-registration lanes.
- No write-back of the chosen build number into `pubspec.yaml`.

## Grounding

Every rule below comes from three inspected projects, not from assumption.

| | dms_mobile | lms_mobile_revamp | BTN-SMART-Mobile |
| --- | --- | --- | --- |
| Gradle file | `build.gradle.kts` | `build.gradle.kts` | `build.gradle` |
| flavor dimension | absent | `flavorDimensions.add("env")` | `flavorDimensions += "env"` |
| flavor entries | absent | 3, `dimension = "env"` | 3, `dimension "env"` |
| iOS shared schemes | `Runner` | `beta`, `dev`, `prod` | `ImageNotification`, `Runner`, `dev`, `prod`, `zegen` |
| Fastfile | 241 lines | 613 lines | none |

Three assumptions that inspection disproved:

1. `scheme: "Runner"` is not universal. `lms_mobile_revamp` has no `Runner`
   scheme; hardcoding it produces an iOS lane that cannot run.
2. Flavor-to-scheme mapping is not one to one. `BTN-SMART-Mobile` has five
   schemes for three flavors; `Runner` and `ImageNotification` are not flavors.
3. Both Gradle DSLs are in use, with different syntax for the same concepts.

## Command surface

```
agents release init [--dry-run] [--force]
```

`--dry-run` prints the files that would be written and their paths without
touching disk, matching the existing `agents migrate` convention.

`--force` overwrites an existing `fastlane/Fastfile` after copying it to
`fastlane/Fastfile.bak`.

## Files

| Path | Action |
| --- | --- |
| `lib/src/release_scaffold.dart` | New. Project detection and template rendering. |
| `lib/src/cli_release.dart` | New. Argument parsing and orchestration. |
| `lib/src/cli.dart` | Register the `release` command and dispatch `runRelease`. |
| `templates/release/Fastfile` | New. Ruby template. |
| `templates/release/.env.fastlane.example` | New. |
| `test/release_scaffold_test.dart` | New. |

The template lives in `templates/release/`, not `templates/base/`.
`generator.dart:128-135` copies every file under `templates/base/` into every
project on `agents init`, so a Fastfile placed there would be installed
unconditionally. `templates/release/` is read only by `release_scaffold.dart`.

`templates/release/Appfile` is not generated. App Store Connect identifiers are
per-developer-account state that the user must own; a generated Appfile would be
wrong more often than right.

## Detection at generate time (Dart)

`release_scaffold.dart` reads exactly three things:

1. Application name from the `name:` field of `pubspec.yaml`, used as the
   artifact `output_name`.
2. Whether the Gradle file is `android/app/build.gradle` or
   `android/app/build.gradle.kts`, used to build `gradle_path`.
3. Whether `ios/Runner.xcworkspace` exists. When absent, the iOS lane is
   omitted and a warning is printed.

The Dart side does not parse `productFlavors` and does not resolve schemes.
Those are runtime concerns, handled in Ruby.

## Template placeholders

One placeholder: `{{APP_NAME}}`. Everything else is either fixed text or
resolved at runtime.

## Runtime behavior (Ruby)

### Flavor detection

Read `android/app/build.gradle` or `android/app/build.gradle.kts` and extract
`productFlavors` entry names. Both syntaxes must be recognized:

- Groovy: `flavorDimensions += "env"`, entries as `dimension "env"`
- Kotlin: `flavorDimensions.add("env")`, entries as `dimension = "env"`

Zero flavors found means the single-variant path: `gradle` with no `flavor:`
key, matching `dms_mobile`. One or more flavors means `gradle(flavor: <name>)`.

### iOS scheme resolution

Schemes are read from `ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme`.

1. If flavors exist, compute the intersection of flavor names and scheme names.
2. Intersection of exactly one scheme: use it.
3. Intersection of more than one: print every candidate with
   `UI.important`, use the first, and state which was chosen so the user can
   correct it.
4. Empty intersection: `UI.user_error!` listing the available schemes.

The CLI never guesses silently in any branch.

### Lanes

`android_firebase`:

1. `require_fastlane_env!`
2. `next_build_number(ENV['FIREBASE_APP_ID_ANDROID'])`
3. `version_name_prompt` — offers the `pubspec.yaml` version name as the default
4. `release_notes_prompt`
5. `gradle(task: "assemble", build_type: "Release", flavor:, gradle_path:,
   project_dir:, properties: {versionCode, versionName})`
6. Glob `build/app/outputs/apk/release/**/*.apk`, which covers both the
   single-variant layout and the flavored `release/<flavor>/` subdirectory
7. `distribute`
8. `cleanup_artifacts`

`ios_firebase`:

1. `require_fastlane_env!`
2. `next_build_number(ENV['FIREBASE_APP_ID_IOS'])`
3. `version_name_prompt`
4. `release_notes_prompt`
5. `match(type: "adhoc", ...)`
6. Resolve scheme by the rule above
7. `build_app(workspace:, scheme:, output_name:, xcargs: FLUTTER_BUILD_NUMBER=...)`
8. Glob `build/ios/ipa/*.ipa`
9. `distribute`
10. `cleanup_artifacts`

### Distribution

Upload through the `firebase` CLI rather than the fastlane
`firebase_app_distribution` action, matching the reference project. This keeps
the `firebase_app_distribution` plugin out of `Pluginfile` and removes a
dependency. `GOOGLE_APPLICATION_CREDENTIALS` is set inside `begin` and deleted
in `ensure`. Release notes are written to a temporary file because
`appdistribution:distribute` takes `--release-notes-file`, and that temporary
file is deleted in the same `ensure`.

### Build number

```
pubspec_build = <build number parsed from pubspec.yaml version: x.y.z+N>
latest        = firebase_app_distribution_get_latest_release(...).buildVersion
chosen        = latest >= pubspec_build ? latest + 1 : pubspec_build
```

The `>=` guard means the chosen number can never equal a number already on App
Distribution.

Known limitation, carried over from the reference implementation on purpose:
`pubspec.yaml` is never updated. The build number therefore only ratchets
upward and `pubspec` stops tracking what has shipped. Every run prints the
chosen number so the drift stays visible.

### Release notes

`prompt(text: "Release notes (akhiri dengan baris '.'): ",
multi_line_end_keyword: ".")`

### Version name

`prompt` with `default_value` set to the version name parsed from the
`pubspec.yaml` `version:` field. Both lanes prompt for it, so a hotfix release
does not require editing `pubspec.yaml` first. The build number is never
prompted; it is always derived.

### Artifact cleanup

`cleanup_artifacts(*globs)` deletes matched files and reports how many were
removed. Runs after a successful upload only, so a failed upload leaves the
artifact in place for inspection.

## Failure handling

| Condition | Behavior |
| --- | --- |
| `pubspec.yaml` missing | Refuse. Name the file. Not a Flutter project. |
| Neither Gradle file present | Refuse. Name both paths tried. |
| `fastlane/Fastfile` exists without `--force` | Refuse. Name `--force`. |
| Environment variable missing | `ensure_env_vars!` with the exact per-platform list. |
| Service account file missing | `UI.user_error!` with the resolved path. |
| `flavor:` passed but Gradle declares none | `UI.user_error!` listing detected flavors. |
| iOS scheme not among shared schemes | `UI.user_error!` listing available schemes. |
| No artifact after build | `UI.user_error!` naming the glob searched. |
| App absent from App Distribution | Rescue, fall back to the `pubspec` build number. |

## Testing

`test/release_scaffold_test.dart` covers:

- `{{APP_NAME}}` substitution from `pubspec.yaml`
- `gradle_path` correctness for both `.gradle` and `.gradle.kts`
- refusal when neither Gradle file exists
- refusal when `pubspec.yaml` is missing
- refusal when `fastlane/Fastfile` exists without `--force`
- `Fastfile.bak` written when `--force` is used
- `.gitignore` block appended once, not duplicated on a second run
- iOS lane omitted with a warning when `ios/Runner.xcworkspace` is missing

### Coverage gap, stated plainly

The Dart suite cannot execute Ruby. Flavor detection in the Fastfile, build
number auto-increment, distribution, and cleanup have no automated coverage and
are verified manually by running `fastlane android_firebase` in a scratch
project without performing an upload. This is a real gap and must not be
reported as tested.

### Generated `.gitignore`

The CLI appends a Fastlane block. It must be stricter than the blocks found in
the reference projects, which omit JSON and backup files:

```
.env.fastlane
fastlane/service-account.json
fastlane/*.json
fastlane/*.p8
fastlane/*.bak
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots
fastlane/test_output
```

`lms_mobile_revamp/.gitignore:55-62` covers neither `fastlane/*.json` nor
`fastlane/*.bak`, and its `fastlane/Fastfile1.bak` is tracked in git. The
generated block closes that gap for new projects.

## Documentation obligations

`AGENTS.md` requires README and CHANGELOG updates for every user-facing change.

- `README.md` gains the `agents release init` command, its flags, the generated
  file layout, and the manual fill-in steps for iOS placeholders.
- `CHANGELOG.md` gains an `## Unreleased` entry.
- Version bump, tag, and release follow the existing release flow after merge.

## Open items for the reviewer

1. Build numbers never return to `pubspec.yaml`. Accepted to match proven
   behavior; flag if the drift becomes a problem.
2. The iOS lane ships with placeholders and cannot run until a human fills in
   the bundle identifier and `match` repository. Accepted per decision.
3. Ruby has no automated coverage. Accepted as a known gap.