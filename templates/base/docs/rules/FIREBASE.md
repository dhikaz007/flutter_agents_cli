# Firebase Rule

Load only when the project uses Firebase: initialization, auth, Firestore, Realtime Database, Storage, Crashlytics, Cloud Messaging, or Remote Config.

- Enable App Check before exposing any Firebase surface in a release build. Without it, an attacker can call your project directly from outside the app.
- Firestore and Realtime Database security rules are the only authorization boundary. Hiding a button or guarding a route in the client protects nothing.
- Write rules that deny by default and grant per-path access. Never ship a rule that allows read or write on a whole collection because one screen needs it.
- Rules must validate the field, not only the path. Checking `request.auth.uid` is not enough when the client can also write another user's document.
- Use a server timestamp or a trusted backend for any value used for ordering, expiry, or audit. A client clock is attacker-controlled.
- Decide offline persistence explicitly per feature. Silent caching hides staleness; always-on persistence keeps a signed-out user's data on disk.
- Never put a service-account key, admin SDK, or server secret in a Flutter app. Anything shipped in the binary is public.
- A composite query with more than one equality or range filter needs a Firestore index. Ship the `firestore.indexes.json` the console asks for instead of rewriting the query to dodge it.
- Map Firebase exceptions to the project's error model in the repository layer. `FirebaseAuthException` and `FirebaseException` must not reach widgets.
- Use the Auth Emulator and the Firestore Emulator before testing rules locally. Never point a test build at the production project.
- Strip debug logging, verbose Crashlytics keys, and test users before a release build.
- Read the matching reference before changing Firebase code. Read more than one when a task spans services.

| Task | Read |
| --- | --- |
| Firestore schema, CRUD, listeners, pagination, indexes, offline, rules | [references/firebase-firestore.md](references/firebase-firestore.md) |
| Auth state, social sign-in, MFA, session persistence, auth errors | [references/firebase-auth.md](references/firebase-auth.md) |
| Crashlytics, logging, Analytics, Remote Config | [references/firebase-observability.md](references/firebase-observability.md) |

The per-service detail lives in those three files so this rule stays small enough to always load.