# stream_event_guard

Keyed duplicate suppression and cooldown control for synchronous and asynchronous Dart events.

`EventGuard` prevents the same logical event from running more than once at the same time or during a configurable post-success cooldown. Each key has independent state, so unrelated events can still run concurrently.

## Features

- Drops duplicate work while the same key is running.
- Applies an optional cooldown after successful work.
- Keeps different keys independent.
- Accepts synchronous and asynchronous actions.
- Preserves nullable action results.
- Reports whether work executed or why it was dropped.
- Releases failed keys immediately for retry.
- Removes per-key state when it is no longer needed.
- Uses no runtime dependencies and works in Dart and Flutter applications.

## Installation

```shell
dart pub add stream_event_guard
```

For a Flutter application, use `flutter pub add stream_event_guard`.

## Stream usage

Create a guard with the type used to identify equivalent events. The following
listener allows different QR codes to run concurrently while deduplicating
bursts of the same code:

```dart
import 'dart:async';

import 'package:stream_event_guard/stream_event_guard.dart';

final scanGuard = EventGuard<String>(
  cooldown: const Duration(seconds: 2),
);

void listenToScanner(Stream<String> scannerStream) {
  scannerStream.listen((code) {
    unawaited(handleScan(code));
  });
}

Future<void> handleScan(String code) async {
  try {
    final result = await scanGuard.run(
      key: code,
      action: () => processCode(code),
    );

    switch (result) {
      case Executed(value: final value):
        print('Processed: $value');
      case Dropped(reason: final reason):
        print('Ignored: $code ($reason)');
    }
  } catch (error, stackTrace) {
    reportError(error, stackTrace);
  }
}

Future<String> processCode(String code) async => 'product:$code';

void reportError(Object error, StackTrace stackTrace) {
  // Forward the failure to your logger or error reporting service.
}
```

`EventGuard` does not transform or subscribe to the stream itself. It is used
at the event-processing boundary, so the same API also works with QR/barcode
scanners, NFC, BLE, sensors, button events, WebSockets, and direct method calls.

For a given key, the lifecycle is:

```text
absent -> running -> cooldown -> absent
              |
              +-- failure ----> absent
```

While running, another submission returns `Dropped` with `DropReason.alreadyRunning`. After a successful action, duplicates during the configured cooldown return `DropReason.cooldown`. The cooldown begins when the action completes, not when it starts.

The default cooldown is `Duration.zero`, which only protects against overlapping executions:

```dart
final submitGuard = EventGuard<int>();
```

## Result handling

`run<R>` returns `Future<GuardResult<R>>`:

- `Executed<R>` contains the exact value returned by the action, including `null` when `R` is nullable.
- `Dropped<R>` contains either `DropReason.alreadyRunning` or `DropReason.cooldown`.

The action can return `R` or `Future<R>`. If it throws synchronously or completes with an error, the original error is propagated. Failed actions do not start a cooldown, so the same key can be retried immediately.

## Scope and limitations

State is local to one `EventGuard` instance in one isolate. The package does not provide distributed idempotency, persistence, retries, cancellation, queueing, joining, or exactly-once delivery.

Keys use normal Dart `==` and `hashCode` semantics. Their equality and hash code must remain stable while an action or cooldown is active.

See [`example/stream_event_guard_example.dart`](example/stream_event_guard_example.dart) for a complete runnable example.

## Contributing

Issues and pull requests are welcome in the [GitHub repository](https://github.com/rodrigorafaeldamaceno/stream_event_guard).
