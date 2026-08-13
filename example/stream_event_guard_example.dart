import 'package:stream_event_guard/stream_event_guard.dart';

Future<void> main() async {
  final guard = EventGuard<String>(cooldown: const Duration(seconds: 2));

  final first = guard.run(key: 'ABC123', action: () => _processCode('ABC123'));
  final duplicate = await guard.run(
    key: 'ABC123',
    action: () => _processCode('ABC123'),
  );

  _printResult(duplicate);
  _printResult(await first);
}

Future<String> _processCode(String code) async {
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return 'product:$code';
}

void _printResult(GuardResult<String> result) {
  switch (result) {
    case Executed(value: final value):
      print('Processed: $value');
    case Dropped(reason: final reason):
      print('Ignored: $reason');
  }
}
