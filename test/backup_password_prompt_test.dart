import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_export_harness.dart';

void main() {
  // showDialog completes when the exit transition starts; the closing dialog
  // still builds its field and winds down text input for a few frames, so
  // its controller must outlive the awaited result. (One test: the export's
  // share-file queue is module state that must not span fake-async zones.)
  testWidgets('password prompts close cleanly when cancelled or confirmed', (
    tester,
  ) async {
    await openBackupExportPrompt(tester);
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text(backupStrings('cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text(backupStrings('exportBackup')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(backupStrings('confirmBackupPassword')), findsOneWidget);
    await tester.tap(find.text(backupStrings('cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
