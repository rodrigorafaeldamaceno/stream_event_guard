## Context

The repository is still the generated Flutter package scaffold: its public library exposes only a sample `Calculator`, and its test and documentation are placeholders. The capability contract is defined in `specs/keyed-event-guard/spec.md`. The implementation must remain useful to both Dart and Flutter consumers, preserve values including `null`, and keep per-key state bounded after work finishes.

## Goals / Non-Goals

**Goals:**

- Provide a small, type-safe public API for keyed execution and explicit drop outcomes.
- Make state transitions deterministic for synchronous actions, asynchronous actions, errors, reentrancy, and cooldown expiration.
- Avoid runtime dependencies and make timing tests deterministic.
- Keep the implementation organized so additional strategies can be added later without exposing them prematurely.

**Non-Goals:**

- Coordinating across isolates, processes, devices, or multiple guard instances.
- Persisting idempotency records or providing exactly-once delivery.
- Adding configurable join, queue, latest-wins, retry, cancellation, or eviction strategies in v0.1.
- Guaranteeing useful behavior for mutable keys whose equality or hash code changes while tracked.

## Decisions

### Public API separates key type from action result type

The guard will be generic only over its key, while `run` will infer a result type per invocation:

```dart
final class EventGuard<K> {
  EventGuard({Duration cooldown = Duration.zero});

  Future<GuardResult<R>> run<R>({
    required K key,
    required FutureOr<R> Function() action,
  });
}
```

`GuardResult<R>` will be sealed with final `Executed<R>` and `Dropped<R>` variants. `Dropped` will carry a `DropReason` enum with `alreadyRunning` and `cooldown` values. This preserves nullable action values and enables exhaustive pattern matching. `FutureOr<R>` supports synchronous and asynchronous callers through the same API.

Alternative considered: return `R?` or a boolean. This was rejected because `null` may be a successful value and neither option can communicate why an action was dropped.

### The v0.1 running policy is always drop

A second submission for the same key will always be dropped while the original action is running. There will be no `dropWhileRunning` flag because disabling it would introduce an implicit second concurrency strategy without defining its semantics. Explicit strategies can be designed in a future change.

Alternative considered: expose a boolean now. This was rejected because `false` could mean allow concurrent work, join existing work, or queue new work, making the contract ambiguous.

### Each key follows a three-state lifecycle

Each guard instance will maintain a private map whose entries represent one of these transitions:

```text
absent --run--> running --success with cooldown--> coolingDown --timer--> absent
                    |--success with zero cooldown-----------------------> absent
                    |--error--------------------------------------------> absent
```

The running entry will be installed synchronously before the action is invoked. Because Dart code in one isolate cannot be interleaved until control is yielded, the check-and-register segment prevents two same-key calls from both starting. Distinct keys use distinct entries and can progress concurrently.

Alternative considered: store only the last execution timestamp. This was rejected because it cannot directly represent in-flight work and encourages lazy cleanup that retains one-time keys indefinitely.

### Cooldown begins only after successful completion

The configured duration defaults to `Duration.zero`; negative values fail construction with `ArgumentError`. A positive cooldown begins after the action returns successfully. Failures release the key without entering cooldown so callers can retry immediately.

Alternative considered: begin cooldown when work starts or apply it after failures. Starting at invocation would let long-running work consume the entire cooldown, while applying it after failures would delay recovery from work that never completed successfully.

### Expiration cleanup uses identity-checked timers

A successful positive-cooldown action will replace its running entry with a cooldown entry and schedule a `Timer` to remove it. The timer callback will remove the map entry only when it is identical to the cooldown entry that scheduled the callback. This prevents stale cleanup from deleting newer state for the same key.

Alternative considered: compare wall-clock timestamps only when `run` is called. This avoids timers but leaves high-cardinality, one-time keys retained indefinitely unless an additional sweeping policy is introduced.

### Action failures preserve normal Dart error behavior

The action invocation will be normalized with `Future.sync`, so synchronous throws and asynchronous failures follow the same cleanup path. Cleanup will occur before the failure reaches the caller, and the original error will be rethrown rather than wrapped in a result variant.

Alternative considered: add a failed `GuardResult` variant. This was rejected because the guard is responsible for admission control, not for changing the action's established error contract.

### Package structure remains Dart-only

The public barrel `lib/stream_event_guard.dart` will export focused implementation files from `lib/src/`. Flutter will be removed from runtime and test dependencies; `package:test` will provide the test runner, and `fake_async` will be a development-only dependency for deterministic timer tests. No runtime package is required.

## Risks / Trade-offs

- **A timer per cooling key can become expensive during very high cardinality bursts** → Keep cooldown timers short-lived, remove entries on expiration, and document that the guard is an in-process utility rather than a durable deduplication store.
- **Mutable keys can become unreachable in the map after their hash code changes** → Document that keys must have stable equality and hash codes while tracked, matching normal Dart map requirements.
- **Immediate retries after repeated failures can create a hot loop** → Leave retry and failure backoff to callers in v0.1; consider a future explicit failure-cooldown policy instead of silently imposing one.
- **Real-time tests can be flaky** → Drive timers with `fake_async` and use completers for in-flight concurrency tests.
- **Future strategies may need a richer internal state model** → Keep states private and expose only the minimal drop result contract, allowing internals to evolve without breaking consumers.

## Migration Plan

1. Replace the generated Flutter package dependencies with Dart-only development dependencies.
2. Replace the sample calculator library and test with the public guard API, private state implementation, and behavioral tests.
3. Add an example and rewrite package documentation and changelog for the initial release.
4. Run formatting, static analysis, tests, and OpenSpec validation before publication.

Rollback consists of reverting these scaffold-level changes; there is no existing production API or stored data to migrate.
