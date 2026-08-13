import 'dart:async';

import 'guard_result.dart';

/// Coordinates synchronous and asynchronous actions independently by key.
///
/// State belongs to this guard instance and is not shared across isolates or
/// processes. Keys must keep stable equality and hash-code behavior while an
/// action or cooldown is active.
final class EventGuard<K> {
  /// Creates a guard that applies [cooldown] after each successful action.
  ///
  /// The cooldown defaults to zero. A negative duration is rejected.
  EventGuard({this.cooldown = Duration.zero}) {
    if (cooldown.isNegative) {
      throw ArgumentError.value(cooldown, 'cooldown', 'Must not be negative.');
    }
  }

  /// The duration for which a key remains unavailable after a successful run.
  final Duration cooldown;

  final Map<K, _KeyState> _states = <K, _KeyState>{};

  /// Runs [action] when [key] is not already running or cooling down.
  ///
  /// Synchronous and asynchronous failures are forwarded to the caller. A
  /// failed action does not start a cooldown, so the key can be retried
  /// immediately.
  Future<GuardResult<R>> run<R>({
    required K key,
    required FutureOr<R> Function() action,
  }) async {
    final existingState = _states[key];
    if (existingState is _Running) {
      return Dropped<R>(DropReason.alreadyRunning);
    }
    if (existingState is _CoolingDown) {
      return Dropped<R>(DropReason.cooldown);
    }

    final runningState = _Running();
    _states[key] = runningState;

    try {
      final value = await Future<R>.sync(action);
      _finishSuccessfully(key, runningState);
      return Executed<R>(value);
    } catch (_) {
      _removeIfCurrent(key, runningState);
      rethrow;
    }
  }

  void _finishSuccessfully(K key, _Running runningState) {
    if (cooldown == Duration.zero) {
      _removeIfCurrent(key, runningState);
      return;
    }

    final cooldownState = _CoolingDown();
    if (!identical(_states[key], runningState)) {
      return;
    }

    _states[key] = cooldownState;
    Timer(cooldown, () => _removeIfCurrent(key, cooldownState));
  }

  void _removeIfCurrent(K key, _KeyState expectedState) {
    if (identical(_states[key], expectedState)) {
      _states.remove(key);
    }
  }
}

sealed class _KeyState {
  const _KeyState();
}

final class _Running extends _KeyState {
  const _Running();
}

final class _CoolingDown extends _KeyState {
  const _CoolingDown();
}
