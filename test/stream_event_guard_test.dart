import 'dart:async';

import 'package:stream_event_guard/stream_event_guard.dart';
import 'package:test/test.dart';

void main() {
  group('EventGuard', () {
    test(
      'executes the first synchronous action and preserves its value',
      () async {
        final guard = EventGuard<String>();

        final result = await guard.run(key: 'A', action: () => 42);

        expect(result, isA<Executed<int>>());
        expect((result as Executed<int>).value, 42);
      },
    );

    test('executes asynchronous actions', () async {
      final guard = EventGuard<String>();

      final result = await guard.run(key: 'A', action: () async => 'processed');

      expect(result, isA<Executed<String>>());
      expect((result as Executed<String>).value, 'processed');
    });

    test('preserves null as a successful value', () async {
      final guard = EventGuard<String>();

      final result = await guard.run<String?>(key: 'A', action: () => null);

      expect(result, isA<Executed<String?>>());
      expect((result as Executed<String?>).value, isNull);
    });

    test('allows different keys to run concurrently', () async {
      final guard = EventGuard<String>();
      final firstCompleter = Completer<int>();
      final first = guard.run(key: 'A', action: () => firstCompleter.future);

      final second = await guard.run(key: 'B', action: () => 2);
      firstCompleter.complete(1);

      expect(second, isA<Executed<int>>());
      expect((await first as Executed<int>).value, 1);
    });

    test('does not share state between guard instances', () async {
      final firstGuard = EventGuard<String>();
      final secondGuard = EventGuard<String>();
      final completer = Completer<void>();
      final first = firstGuard.run(key: 'A', action: () => completer.future);

      final second = await secondGuard.run(key: 'A', action: () => 2);
      completer.complete();
      await first;

      expect(second, isA<Executed<int>>());
    });
  });
}
