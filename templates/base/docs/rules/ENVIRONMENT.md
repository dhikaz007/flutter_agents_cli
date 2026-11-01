# Environment

Load when changing env vars, flavors, app config, base URLs, build-time defines, or startup initialization.

## Selection

Choose one mechanism per platform and document it; never mix two silently for the same value.

```text
Local or CI secret material    → .env file, gitignored, read at startup
Non-secret build values        → --dart-define / --dart-define-from-file
Platform-owned values          → Xcode build settings / Gradle properties
Variant identity               → flavor, never an env var
```

## AppConfig

One immutable `AppConfig` is constructed once at startup and is the only reader of env values.

```dart
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.environment});

  factory AppConfig.fromEnv() {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (apiBaseUrl.isEmpty) {
      throw StateError('API_BASE_URL is required for every build');
    }
    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      environment: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      ),
    );
  }

  final String apiBaseUrl;
  final String environment;
}
```

- Only `AppConfig` calls `String.fromEnvironment` or reads an env map. Features, screens, datasources, and repositories never do.
- A missing required value must throw at startup. Never give it a `defaultValue`; a silent default turns a typo or a missing CI secret into a production-only defect.
- `defaultValue` is allowed only where absence is genuinely harmless, such as a feature flag or log level.
- A misspelled variable name must fail loudly, not resolve to a default.
- The `environment` label must match the flavor the build was produced from. A mismatch means a misconfigured pipeline; treat it as a release blocker.

## `.env.example`

The committed template is documentation: it declares every required key with a placeholder and no real value.

```text
API_BASE_URL=
APP_ENV=
API_KEY=
```

- `.env.example` is committed. `.env` and every per-environment variant of it stay gitignored.
- Prefer an empty value. Use a descriptive placeholder only when empty is ambiguous, and never a plausible-looking one.
- Never put a real host, internal URL, account name, or key prefix in the template. `https://api.example.com` is acceptable; an internal hostname is not.
- Every required key read by `AppConfig` appears in `.env.example`. A key missing there is an undocumented requirement that fails only at runtime.
- Local setup starts by copying the template to `.env` and filling it in. A filled `.env` is never committed, never copied into another environment, and never attached to a bug report.

Committing a real value here is a secret exposure. Handling and rotation of real credentials belongs to `SECURITY.md`.

## Public by default

Anything shipped inside a client bundle is public. A value reachable from the binary can be read by anyone holding the app.

- Provider keys that the vendor documents as publishable may live in env config; secret credentials may not.
- A secret that must not reach the client belongs behind a server endpoint. Do not move it into env config to get it out of source control.
- Obfuscation and minification do not protect env values.

Credential storage and rotation belong to `SECURITY.md`; base URL consumption belongs to `NETWORK.md`; startup ordering belongs to `CODEGEN.md`.

## Release tooling parameters

Build and release tooling reads its parameters from the environment through its own file, for example `env.fastlane`, with its own committed template.

- TEMPLATE-PROJECT: the tooling file name, its template name, and how it is loaded — `source env.fastlane`, a `dotenv` load in the `Fastfile`, or a lane `env:` declaration.
- The tooling template is committed with placeholder-only values, exactly like `.env.example`, and the real tooling file is gitignored.
- Keep one naming convention for env files and their committed templates across the project; do not mix a `.env.staging` and an `env.staging` style.
- A tooling value is never bundled into the app. That difference is what separates the two classes:

```text
Bundled client value     → treated as public, see "Public by default"
Release tooling value    → may hold real credentials, must stay out of git
```

- Real release credentials — signing keys, keystore or certificate passwords, Apple IDs, store service keys — live only in the CI secret store or a local gitignored file. Never in a template, never in a commit, never in a bug report.
- Never move a release credential into client configuration to keep it out of one file. A signing key belongs in the platform keystore and the store account, not in a build-time define.

## Project environment contract

Fill from product/API requirements; do not invent:

- required variables and their per-environment values
- variable naming convention and any prefix
- precedence when a flavor value and an env value define the same key
- per-environment file layout, for example `.env.development` / `.env.staging`
- how CI injects values per environment
- which variables CI alone may read