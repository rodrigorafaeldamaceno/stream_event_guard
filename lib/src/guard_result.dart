/// The reason an event submission was not executed.
enum DropReason {
  /// Another action for the same key is still running.
  alreadyRunning,

  /// The key is still inside its post-success cooldown window.
  cooldown,
}

/// The outcome of submitting an action to an event guard.
sealed class GuardResult<T> {
  const GuardResult();
}

/// A result produced by an action that ran successfully.
final class Executed<T> extends GuardResult<T> {
  /// Creates an executed result containing [value].
  const Executed(this.value);

  /// The value returned by the action.
  final T value;
}

/// A result produced when an action was not admitted by the guard.
final class Dropped<T> extends GuardResult<T> {
  /// Creates a dropped result with [reason].
  const Dropped(this.reason);

  /// Why the action was not executed.
  final DropReason reason;
}
