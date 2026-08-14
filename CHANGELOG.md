## 0.1.0

- Promote the initial keyed event guard API to a stable release.
- Document fire-and-forget stream usage for QR code, barcode, NFC, BLE, and sensor events.
- Document derived keys for object events without requiring an equality package.
- Verify keyed deduplication, cooldown behavior, object keys, and stream integration.

## 0.1.0-dev.1

- Add key-scoped synchronous and asynchronous action execution.
- Drop duplicate keys while work is running or cooling down.
- Add explicit executed and dropped result variants.
- Propagate action failures and allow immediate retries.
- Clean up per-key state after failures, zero-cooldown success, or cooldown expiration.
- Support Dart and Flutter consumers without runtime dependencies.
