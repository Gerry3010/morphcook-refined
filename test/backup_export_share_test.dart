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

    final row = await openBackupExportPrompt(tester);
    await tester.tap(find.text('ok')); // no password: no confirmation prompt
    await settleRealAsync(tester, () => shared != null);

    // share_plus refuses on iPad without an anchor, and a whole-screen anchor
    // leaves the popover squeezed against an edge: it must be the tapped row.
    expect(shared, isNotNull);
    expect(
      Rect.fromLTWH(
        shared!['originX'] as double,
        shared!['originY'] as double,
        shared!['originWidth'] as double,
        shared!['originHeight'] as double,
      ),
      row,
    );
  });
}
