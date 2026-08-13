import 'dart:async';

import 'package:stream_event_guard/stream_event_guard.dart';

Future<void> main() async {
  final scanner = StreamController<String>();
  final guard = EventGuard<String>(cooldown: const Duration(seconds: 2));

  scanner.stream.listen((code) {
    guard.run(
      key: code,
      action: () async {
        await _processCode(code);
      },
    );
  });

  scanner
    ..add('ABC123')
    ..add('ABC123')
    ..add('ABC123')
    ..add('XYZ999');

  await scanner.close();
}

Future<void> _processCode(String code) async {
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('Processed: $code');
}
