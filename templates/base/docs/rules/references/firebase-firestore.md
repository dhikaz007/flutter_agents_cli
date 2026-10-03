# Firestore

## Schema

- Model a Firestore document as a plain Dart model with explicit field names. Do not persist a widget state object or a class with private fields.
- Keep the document id separate from the model unless the id is genuinely absent from the payload. `id` as a stored field duplicates the key.
- Use `FieldValue.serverTimestamp()` for created/updated fields and `FieldValue.delete()` for a removed field. Never send `null` for a field you mean to clear.
- Store money as an integer of minor units, never a double. Firestore stores a double as IEEE 754.
- Decide up front which documents are owned by one user (`users/{uid}/...`) and which are shared. Ownership shapes the security rules and the query index.
- Do not use an auto-increment or client-generated id when two devices can write concurrently. Let Firestore assign the document id.

## Read and write

- Go through the repository boundary. A widget must never call `FirebaseFirestore.instance` directly.
- Use a typed converter or a mapper so a schema change fails at one place, not in every screen.
- `set` overwrites the whole document and drops fields you omit. Use `update` for a partial change and `set(..., merge: true)` only when a full replace is not intended.
- Batch or write in a single transaction when two documents must change together. Never leave a multi-step mutation without a defined failure path.
- Treat a write as unconfirmed until the returned future completes. Do not update the UI optimistically without a documented rollback.
- `increment` on the server keeps a counter correct under concurrent writes. Read-modify-write from the client does not.

## Listeners and pagination

- `snapshots()` streams and `get()` reads once. Choose deliberately; a stream left open keeps a listener and its cost alive for the widget's lifetime.
- Cancel the subscription in `dispose` or scope it to the state object that owns it.
- Paginate with `startAfter(lastDocument)` and keep the cursor in state. Never `offset` a large collection.
- A `where` plus `orderBy` on a different field needs a composite index. Add the index the console prints and commit `firestore.indexes.json` rather than dropping the filter.
- Distinguish the empty collection from a failed read. An empty `QuerySnapshot` after an error is a bug, not an empty state.
- For a long-lived list, keep the query on the parent document instead of one listener per row. Per-row listeners multiply cost by row count.

## Offline and cache

- Enable persistence deliberately. The default memory cache hides the network; `settings(persistenceEnabled: true)` survives a restart and keeps a signed-out user's data on disk.
- Set a cache size limit only when the document count is known. An unbounded cache on a large collection will evict unpredictably.
- Treat server-timestamp fields as `null` locally until the server acknowledges the write. Render a pending state instead of formatting `null`.
- Do not assume a listener fires while offline. Reconcile with a one-time `get()` when the app returns to the foreground.

## Security rules

- Deny by default. Grant the narrowest path that works, for the narrowest operation.
- Validate the shape as well as the path: `request.resource.data.keys().hasOnly([...])` and a per-field type check.
- Verify `request.auth.uid` against the document owner on every read and write, not only on create.
- Never trust a field the client supplied for authorization, such as `role` or `isAdmin`. Compare against a server-held value.
- Enforce that a user cannot overwrite `createdAt` on an update.
- Test rules against the Emulator before shipping. A rule that compiles is not a rule that is correct.

<!-- Derived from the official Cloud Firestore Flutter documentation. Restated as
     project rules; no upstream text is copied. -->