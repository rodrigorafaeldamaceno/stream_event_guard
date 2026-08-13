## Why

Asynchronous event sources can emit the same logical event repeatedly while an earlier occurrence is still being processed or shortly after it completes. Applications currently need to rebuild keyed duplicate suppression themselves, which makes concurrency behavior and failure handling inconsistent.

## What Changes

- Introduce `EventGuard<K>` to coordinate event handling independently for each key.
- Drop a repeated key while its action is already running.
- Apply a configurable cooldown after a successful action and drop the same key during that window.
- Return an explicit `GuardResult<R>` that distinguishes executed actions from dropped events without overloading `null`.
- Propagate action failures while reliably releasing the running key and allowing an immediate retry.
- Remove expired per-key state so high-cardinality event sources do not retain keys indefinitely.
- Make the package Dart-only and add public documentation, examples, and concurrency-focused tests.
- Keep queueing, joining, latest-wins behavior, retries, cancellation, and distributed idempotency out of the initial release.

## Capabilities

### New Capabilities

- `keyed-event-guard`: Key-scoped asynchronous execution, duplicate suppression, cooldown enforcement, result reporting, error behavior, and state cleanup.

### Modified Capabilities

None.

## Impact

- Replaces the generated calculator API in `lib/stream_event_guard.dart` with the public guard API and supporting source files.
- Replaces the generated Flutter test with Dart tests covering timing, concurrency, errors, and cleanup.
- Removes the Flutter runtime dependency so the package can be consumed by Dart and Flutter applications.
- Establishes the initial public API; no existing production API is being migrated.
