import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:stream_event_guard/stream_event_guard.dart';
import 'package:test/test.dart';

void main() {
  group('stream integration', () {
    test(
      'deduplicates a QR burst by key without blocking another code',
      () async {
        final controller = StreamController<String>(sync: true);
        final guard = EventGuard<String>(cooldown: const Duration(seconds: 2));
        final firstCodeCompleter = Completer<void>();
        final invocations = <String, int>{};
        final outcomes = <({String code, GuardResult<String> result})>[];
        final pending = <Future<void>>[];

        controller.stream.listen((code) {
          final execution = guard.run(
            key: code,
            action: () async {
              invocations.update(code, (count) => count + 1, ifAbsent: () => 1);
              if (code == 'ABC123') {
                await firstCodeCompleter.future;
              }
              return code;
            },
          );
          pending.add(
            execution.then(
              (result) => outcomes.add((code: code, result: result)),
            ),
          );
        });

        controller
          ..add('ABC123')
          ..add('ABC123')
          ..add('ABC123')
          ..add('XYZ999')
          ..add('ABC123');

        firstCodeCompleter.complete();
        await controller.close();
        await Future.wait(pending);

        expect(invocations, {'ABC123': 1, 'XYZ999': 1});
        expect(
          outcomes.where(
            (outcome) =>
                outcome.code == 'ABC123' && outcome.result is Executed<String>,
          ),
          hasLength(1),
        );
        expect(
          outcomes.where(
            (outcome) =>
                outcome.code == 'ABC123' &&
                outcome.result is Dropped<String> &&
                (outcome.result as Dropped<String>).reason ==
                    DropReason.alreadyRunning,
          ),
          hasLength(3),
        );
        expect(
          outcomes.where(
            (outcome) =>
                outcome.code == 'XYZ999' && outcome.result is Executed<String>,
          ),
          hasLength(1),
        );
      },
    );

    test('drops stream events during cooldown and accepts them afterward', () {
      fakeAsync((async) {
        final controller = StreamController<String>(sync: true);
        final guard = EventGuard<String>(cooldown: const Duration(seconds: 2));
        final outcomes = <GuardResult<String>>[];
        var invocations = 0;

        final subscription = controller.stream.listen((code) {
          guard
              .run(
                key: code,
                action: () {
                  invocations++;
                  return code;
                },
              )
              .then(outcomes.add);
        });

        controller.add('ABC123');
        async.flushMicrotasks();
        controller
          ..add('ABC123')
          ..add('ABC123');
        async.flushMicrotasks();

        expect(invocations, 1);
        expect(outcomes.first, isA<Executed<String>>());
        expect(
          outcomes.where(
            (result) =>
                result is Dropped<String> &&
                result.reason == DropReason.cooldown,
          ),
          hasLength(2),
        );

        async.elapse(const Duration(seconds: 2));
        controller.add('ABC123');
        async.flushMicrotasks();

        expect(invocations, 2);
        expect(outcomes.last, isA<Executed<String>>());

        unawaited(subscription.cancel());
        unawaited(controller.close());
        async.flushMicrotasks();
      });
    });
  });

  group('execution', () {
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

  group('in-flight suppression', () {
    test('drops the same key while its first action is pending', () async {
      final guard = EventGuard<String>();
      final completer = Completer<int>();
      var duplicateInvoked = false;
      final first = guard.run(key: 'A', action: () => completer.future);

      final duplicate = await guard.run(
        key: 'A',
        action: () {
          duplicateInvoked = true;
          return 2;
        },
      );

      expect(duplicateInvoked, isFalse);
      expect(duplicate, isA<Dropped<int>>());
      expect((duplicate as Dropped<int>).reason, DropReason.alreadyRunning);

      completer.complete(1);
      expect((await first as Executed<int>).value, 1);
    });

    test('drops a reentrant submission for the running key', () async {
      final guard = EventGuard<String>();
      GuardResult<int>? nested;

      final outer = await guard.run(
        key: 'A',
        action: () async {
          nested = await guard.run(key: 'A', action: () => 2);
          return 1;
        },
      );

      expect((outer as Executed<int>).value, 1);
      expect(nested, isA<Dropped<int>>());
      expect((nested! as Dropped<int>).reason, DropReason.alreadyRunning);
    });
  });

  group('cooldown', () {
    test('drops during cooldown and runs again after expiration', () {
      fakeAsync((async) {
        final guard = EventGuard<String>(cooldown: const Duration(seconds: 2));
        var invocations = 0;

        final first = _complete(
          guard.run(key: 'A', action: () => ++invocations),
          async,
        );
        final duringCooldown = _complete(
          guard.run(key: 'A', action: () => ++invocations),
          async,
        );

        expect((first as Executed<int>).value, 1);
        expect((duringCooldown as Dropped<int>).reason, DropReason.cooldown);
        expect(invocations, 1);

        async.elapse(const Duration(seconds: 2));
        final afterCooldown = _complete(
          guard.run(key: 'A', action: () => ++invocations),
          async,
        );

        expect((afterCooldown as Executed<int>).value, 2);
      });
    });

    test('starts the full cooldown after the action completes', () {
      fakeAsync((async) {
        final guard = EventGuard<String>(cooldown: const Duration(seconds: 2));
        final completer = Completer<int>();
        final first = guard.run(key: 'A', action: () => completer.future);

        async.elapse(const Duration(seconds: 10));
        completer.complete(1);
        expect(_complete(first, async), isA<Executed<int>>());

        async.elapse(const Duration(seconds: 1));
        final tooEarly = _complete(guard.run(key: 'A', action: () => 2), async);
        expect((tooEarly as Dropped<int>).reason, DropReason.cooldown);

        async.elapse(const Duration(seconds: 1));
        final allowed = _complete(guard.run(key: 'A', action: () => 3), async);
        expect((allowed as Executed<int>).value, 3);
      });
    });

    test('zero cooldown allows an immediate next run', () async {
      final guard = EventGuard<String>();

      await guard.run(key: 'A', action: () => 1);
      final second = await guard.run(key: 'A', action: () => 2);

      expect((second as Executed<int>).value, 2);
    });

    test('expired cleanup cannot unprotect a newer running action', () {
      fakeAsync((async) {
        final guard = EventGuard<String>(cooldown: const Duration(seconds: 1));
        expect(
          _complete(guard.run(key: 'A', action: () => 1), async),
          isA<Executed<int>>(),
        );
        expect(async.nonPeriodicTimerCount, 1);

        async.elapse(const Duration(seconds: 1));
        expect(async.nonPeriodicTimerCount, 0);

        final completer = Completer<int>();
        final newer = guard.run(key: 'A', action: () => completer.future);
        async.flushMicrotasks();
        async.elapse(const Duration(hours: 1));

        final duplicate = _complete(
          guard.run(key: 'A', action: () => 3),
          async,
        );
        expect((duplicate as Dropped<int>).reason, DropReason.alreadyRunning);

        completer.complete(2);
        expect((_complete(newer, async) as Executed<int>).value, 2);
      });
    });
  });

  group('failures', () {
    test('propagates a synchronous throw and allows immediate retry', () async {
      final guard = EventGuard<String>(cooldown: const Duration(minutes: 1));
      final error = StateError('sync failure');

      await expectLater(
        guard.run<void>(key: 'A', action: () => throw error),
        throwsA(same(error)),
      );
      final retry = await guard.run(key: 'A', action: () => 2);

      expect((retry as Executed<int>).value, 2);
    });

    test(
      'propagates an asynchronous error and allows immediate retry',
      () async {
        final guard = EventGuard<String>(cooldown: const Duration(minutes: 1));
        final error = StateError('async failure');

        await expectLater(
          guard.run<void>(key: 'A', action: () => Future<void>.error(error)),
          throwsA(same(error)),
        );
        final retry = await guard.run(key: 'A', action: () => 2);

        expect((retry as Executed<int>).value, 2);
      },
    );
  });

  group('configuration and key semantics', () {
    test('rejects a negative cooldown', () {
      expect(
        () => EventGuard<String>(cooldown: const Duration(microseconds: -1)),
        throwsArgumentError,
      );
    });

    test('treats equal keys as the same key', () async {
      final guard = EventGuard<_EquivalentKey>();
      final completer = Completer<void>();
      final first = guard.run(
        key: const _EquivalentKey('A'),
        action: () => completer.future,
      );

      final duplicate = await guard.run(
        key: const _EquivalentKey('A'),
        action: () => 2,
      );

      expect((duplicate as Dropped<int>).reason, DropReason.alreadyRunning);
      completer.complete();
      await first;
    });

    test('treats unequal keys independently', () async {
      final guard = EventGuard<_EquivalentKey>();
      final completer = Completer<void>();
      final first = guard.run(
        key: const _EquivalentKey('A'),
        action: () => completer.future,
      );

      final other = await guard.run(
        key: const _EquivalentKey('B'),
        action: () => 2,
      );

      expect((other as Executed<int>).value, 2);
      completer.complete();
      await first;
    });

    test('deduplicates distinct objects by a derived identifier', () async {
      final guard = EventGuard<String>();
      final firstOrder = _Order(id: 'order-1', description: 'first instance');
      final repeatedOrder = _Order(
        id: 'order-1',
        description: 'another instance',
      );
      final completer = Completer<void>();
      final first = guard.run(
        key: firstOrder.id,
        action: () => completer.future,
      );

      final duplicate = await guard.run(
        key: repeatedOrder.id,
        action: () => repeatedOrder.description,
      );

      expect(identical(firstOrder, repeatedOrder), isFalse);
      expect((duplicate as Dropped<String>).reason, DropReason.alreadyRunning);
      completer.complete();
      await first;
    });

    test('uses object equality when the object itself is the key', () async {
      final guard = EventGuard<_EquivalentKey>();
      final completer = Completer<void>();
      final first = guard.run(
        key: const _EquivalentKey('order-1'),
        action: () => completer.future,
      );

      final duplicate = await guard.run(
        key: const _EquivalentKey('order-1'),
        action: () => 2,
      );

      expect((duplicate as Dropped<int>).reason, DropReason.alreadyRunning);
      completer.complete();
      await first;
    });
  });
}

GuardResult<T>? _complete<T>(Future<GuardResult<T>> future, FakeAsync async) {
  GuardResult<T>? result;
  future.then((value) => result = value);
  async.flushMicrotasks();
  return result;
}

final class _EquivalentKey {
  const _EquivalentKey(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is _EquivalentKey && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class _Order {
  const _Order({required this.id, required this.description});

  final String id;
  final String description;
}
