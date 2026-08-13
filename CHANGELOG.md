## 0.1.0

- Add key-scoped synchronous and asynchronous action execution.
- Drop duplicate keys while work is running or cooling down.
- Add explicit executed and dropped result variants.
- Propagate action failures and allow immediate retries.
- Clean up per-key state after failures, zero-cooldown success, or cooldown expiration.
- Support Dart and Flutter consumers without runtime dependencies.
