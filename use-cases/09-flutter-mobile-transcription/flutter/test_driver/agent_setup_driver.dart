import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory(
    Platform.environment['EVERYVOICE_TEST_OUTPUT'] ?? 'build/test-output',
  );
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes,
        [Map<String, Object?>? args]) async {
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await File('${directory.path}/EveryVoice-$safeName.png')
          .writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (_) async {},
  ).timeout(const Duration(seconds: 120));
}
