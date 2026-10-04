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

const backupStrings = S('en');

/// Lets work outside the fake clock (plugin channels, file IO) finish while
/// frames keep pumping, until [done] holds or the rounds run out.
Future<void> settleRealAsync(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 20 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

/// Pumps Settings and opens the first backup-export password prompt; returns
/// the tapped row's rect. Export awaits the screen's cache cleanup, which
/// runs outside the fake clock.
Future<Rect> openBackupExportPrompt(WidgetTester tester) async {
  final state = (await tester.runAsync(() async {
    final state = AppState(
      corpus: await loadRealCorpus(all: false),
      store: MemoryStore(),
    );
    await state.load();
    await state.completeOnboarding(Profile(name: 'cook', lang: 'en'));
    return state;
  }))!;
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
  final export = find.text(backupStrings('exportBackup'));
  await tester.scrollUntilVisible(
    export,
    500,
    scrollable: find.byType(Scrollable).first,
  );
  final row = tester.getRect(
    find.ancestor(of: export, matching: find.byType(InkWell)).first,
  );
  await tester.tap(export);
  await settleRealAsync(
    tester,
    () => find.byType(AlertDialog).evaluate().isNotEmpty,
  );
  expect(find.text(backupStrings('backupPassword')), findsOneWidget);
  return row;
}
