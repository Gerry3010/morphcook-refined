import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_export_harness.dart';

const _paths = MethodChannel('plugins.flutter.io/path_provider');
const _share = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  testWidgets('backup export anchors the share sheet for iPad popovers', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('morphcook-export-test');
    final messenger = tester.binding.defaultBinaryMessenger;
    Map<Object?, Object?>? shared;
    messenger.setMockMethodCallHandler(_paths, (call) async => temp.path);
    messenger.setMockMethodCallHandler(_share, (call) async {
      shared = call.arguments as Map<Object?, Object?>;
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(_paths, null);
      messenger.setMockMethodCallHandler(_share, null);
      temp.deleteSync(recursive: true);
    });

    await openBackupExportPrompt(tester);
    await tester.tap(find.text('ok')); // no password: no confirmation prompt
    await settleRealAsync(tester, () => shared != null);

    // share_plus refuses on iPad without a non-empty popover anchor.
    expect(shared, isNotNull);
    expect(shared!['originWidth'] as double, greaterThan(0));
    expect(shared!['originHeight'] as double, greaterThan(0));
  });
}
