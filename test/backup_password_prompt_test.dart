import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/ui/screens/settings_screen.dart';
import 'package:morphcook/ui/strings.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

const _s = S('en');

Future<AppState> _state() async {
  final state = AppState(
    corpus: await loadRealCorpus(all: false),
    store: MemoryStore(),
  );
  await state.load();
  await state.completeOnboarding(Profile(name: 'cook', lang: 'en'));
  return state;
}

Future<void> _openExportPrompt(WidgetTester tester) async {
  final state = (await tester.runAsync(_state))!;
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: morphThemeData(MorphColors.light),
        home: const Scaffold(body: SettingsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final export = find.text(_s('exportBackup'));
  await tester.scrollUntilVisible(
    export,
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(export);
  // Export first awaits the screen's cache cleanup, which makes several
  // round trips to the (absent) picker and path plugins outside the fake clock.
  for (var i = 0; i < 10 && find.byType(AlertDialog).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
  expect(find.text(_s('backupPassword')), findsOneWidget);
}

void main() {
  // showDialog completes when the exit transition starts; the closing dialog
  // still builds its field and winds down text input for a few frames, so
  // its controller must outlive the awaited result. (One test: the export's
  // share-file queue is module state that must not span fake-async zones.)
  testWidgets('password prompts close cleanly when cancelled or confirmed', (
    tester,
  ) async {
    await _openExportPrompt(tester);
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text(_s('cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text(_s('exportBackup')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_s('confirmBackupPassword')), findsOneWidget);
    await tester.tap(find.text(_s('cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
