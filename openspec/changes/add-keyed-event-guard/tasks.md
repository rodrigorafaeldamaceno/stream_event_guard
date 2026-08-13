## 1. Dart Package Foundation

- [x] 1.1 Convert `pubspec.yaml` and analysis configuration from the Flutter scaffold to a Dart-only package at version 0.1.0 with test, lint, and deterministic-timer development dependencies.
- [x] 1.2 Replace the calculator barrel with documented exports and create the focused `lib/src/` files for the guard and result model.

## 2. Public API and State Machine

- [x] 2.1 Implement the sealed `GuardResult<R>` model, `Executed<R>`, `Dropped<R>`, and the `DropReason` values `alreadyRunning` and `cooldown`.
- [x] 2.2 Implement `EventGuard<K>` construction with a zero default cooldown and `ArgumentError` validation for negative durations.
- [x] 2.3 Implement generic synchronous/asynchronous action execution with atomic per-key registration, independent keys, explicit in-flight drops, exact value preservation, and error propagation with immediate key release.
- [x] 2.4 Implement success-based cooldown state and identity-checked timer cleanup so expired state cannot remove a newer entry.

## 3. Behavioral Test Coverage

- [x] 3.1 Replace the scaffold test with coverage for first execution, synchronous and asynchronous values, nullable values, different-key concurrency, and instance isolation.
- [ ] 3.2 Add completer-driven tests for same-key in-flight drops and reentrant same-key submissions.
- [ ] 3.3 Add deterministic timer tests for cooldown drops, cooldown beginning after completion, expiration, zero duration, and cleanup safety.
- [ ] 3.4 Add tests proving synchronous throws and asynchronous failures propagate and permit an immediate same-key retry.
- [ ] 3.5 Add construction and key-semantics tests for negative cooldowns, equal keys, and distinct keys.

## 4. Package Documentation

- [ ] 4.1 Add a runnable example demonstrating exhaustive handling of executed and dropped results.
- [ ] 4.2 Rewrite the README with scope, installation, usage, result semantics, cooldown/error behavior, lifecycle limits, and non-goals.
- [ ] 4.3 Update the changelog and package metadata for the 0.1.0 release.

## 5. Verification

- [ ] 5.1 Run Dart formatting, static analysis, and the complete test suite, fixing all failures within the change scope.
- [ ] 5.2 Run the package publication dry run and address package-quality warnings that are actionable for v0.1.0.
- [ ] 5.3 Validate the completed OpenSpec change in strict mode.
