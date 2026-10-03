# Firebase Auth

## Initialization and state

- Initialize Firebase once, before `runApp`, and await it. Do not touch `FirebaseAuth.instance` before initialization completes.
- Expose auth state as one stream the app observes. A widget must not subscribe to `authStateChanges()` on its own.
- Distinguish signed out, signed in, and initializing. A screen that renders before the first auth event fires will flash the wrong state.
- Treat the initial auth event as asynchronous. Do not read a cached user synchronously to decide the first route.

## Sign-in and sign-out

- Use the project's existing sign-in surface. Do not add a second provider or a parallel credential path.
- Persist the session with the project's chosen mechanism and honor it. `FirebaseAuth.instance.signOut()` alone leaves no server-side session to revoke when the project also uses a custom backend.
- On sign-out, clear every cache that holds user data: local database, secure storage, and any in-memory repository. Otherwise the next user on the device sees the previous user's data.
- Treat a token refresh failure as a session expiry, not as a transient network error. Re-authenticate or sign out; do not retry silently.
- Never store a token in `SharedPreferences` or a plain file. Use the platform secure storage the project already uses.

## Errors

- Map `FirebaseAuthException` codes to the project's error model in the repository layer: `user-not-found`, `wrong-password`, `invalid-email`, `user-disabled`, `too-many-requests`, `network-request-failed`. Widgets must not switch on Firebase codes.
- `network-request-failed` means the request never reached the server. It is retryable; `wrong-password` is not. Do not lump them into one "login failed" path.
- Treat `recent-login-required` as a re-authentication prompt rather than a generic failure.
- Do not reveal whether an account exists in a user-facing message unless the product requires it.

## Social and multi-factor

- Complete social sign-in only inside the app. Never accept a sign-in link with the user's email in a redirect query parameter; that enables session injection.
- Use HTTPS link domains in production so a sign-in link cannot be intercepted.
- Fetch and store the user's profile claims once after first sign-in. Do not call a profile endpoint on every build.
- Require multi-factor enrollment to be an explicit user action with a recovery path. Do not force a factor on an account that has none.

## Security rules coupling

- Auth alone is not authorization. Every read and write must also be validated by the database rules for that document.
- Guard privileged actions in the backend as well. A verified token proves who the caller is, not what they may do.

<!-- Derived from the official Firebase Authentication Flutter documentation.
     Restated as project rules; no upstream text is copied. -->