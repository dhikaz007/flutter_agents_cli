# Storage Profile — cloud_firestore

Cloud Firestore as the project's persistence layer. Replaces local storage when the project also needs realtime updates, shared multi-device data, or server-side rules. It does not replace local caching for offline-first data.

- Keep all Firestore access behind the repository boundary. Presentation must not call `FirebaseFirestore.instance` directly.
- Reuse the project's existing collection path, converter, mapper, and error-mapping wrapper. Never invent a second path for a document that already has one.
- Model a document as a plain Dart model with explicit field names, and keep the document id separate from the payload unless the schema says otherwise.
- Use `FieldValue.serverTimestamp()` for created/updated fields and `FieldValue.delete()` to clear a field. Never send `null` to mean "remove".
- `set` replaces the whole document and drops omitted fields. Use `update` for a partial change.
- Paginate with `startAfter(lastDocument)`; never `offset` a large collection.
- A query with a `where` plus an `orderBy` on another field requires a composite index. Ship `firestore.indexes.json`.
- Decide cache persistence deliberately, and clear user-scoped data on sign-out.
- Security rules are authoritative. A hidden UI element or a client-side guard is not access control.
- Never treat an empty snapshot as an empty state when the read actually failed; handle the error branch separately.
- When the schema is undocumented, inspect the existing model, collection constant, or endpoint mapping. Do not invent field names.

Read `docs/rules/FIREBASE.md` for the cross-cutting invariants, the Firestore reference for schema, listener, and rules detail, and the setup reference when the Firebase config or a flavor is involved.