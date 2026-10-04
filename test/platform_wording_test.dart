import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/user_manual.dart';
import 'package:morphcook/ui/strings.dart';

void main() {
  final sharing = userManualSections.firstWhere((s) => s.id == 'sharing');

  test('Android keeps its Bluetooth and Quick Share wording', () {
    expect(
      const S('en')('shareCookbookHint'),
      contains('Bluetooth, Quick Share'),
    );
    expect(
      const S('de')('shareCookbookHint'),
      contains('Bluetooth, Quick Share'),
    );
    expect(sharing.body('en'), contains('opens the Android share sheet'));
    expect(sharing.body('de'), contains('öffnet das Android-Teilen-Menü'));
  });

  test('iOS names AirDrop instead of Android-only share targets', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final lang in ['en', 'de']) {
      final hint = S(lang)('shareCookbookHint');
      final body = sharing.body(lang);
      for (final text in [hint, body]) {
        expect(text, contains('AirDrop'));
        expect(text, isNot(contains('Quick Share')));
        expect(text, isNot(contains('Bluetooth')));
        expect(text, isNot(contains('Android')));
      }
      // Receiving works the same way, so that half is shared verbatim.
      expect(
        body.split('\n\n').last,
        lang == 'de'
            ? sharing.bodyDe.split('\n\n').last
            : sharing.bodyEn.split('\n\n').last,
      );
    }
    // Keys without an iOS variant are unaffected.
    expect(const S('de')('shareCookbook'), 'Kochbuch teilen');
  });
}
