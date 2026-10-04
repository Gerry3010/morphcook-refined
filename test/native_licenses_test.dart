import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/native_licenses.dart';

Future<String Function(String)> _registeredLicenses() async {
  registerNativeLicenses();
  registerBundledFontLicenses();
  final entries = await LicenseRegistry.licenses.toList();
  return (package) => entries
      .where((entry) => entry.packages.contains(package))
      .expand((entry) => entry.paragraphs)
      .map((paragraph) => paragraph.text)
      .join('\n');
}

const _iosPods = [
  'DKImagePickerController 4.3.9',
  'DKPhotoGallery 0.0.19',
  'SDWebImage 5.21.7',
  'SwiftyGif 5.4.5',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(LicenseRegistry.reset);

  test(
    'native PDF notices are bundled and available offline to the licenses page',
    () async {
      final textFor = await _registeredLicenses();

      for (final font in [
        'Atkinson Hyperlegible',
        'Caveat',
        'JetBrains Mono',
        'Playfair Display',
      ]) {
        expect(textFor(font), contains('SIL OPEN FONT LICENSE'), reason: font);
      }
      final pdf = textFor('PdfBox-Android 2.0.27.0');
      expect(pdf, contains('Apache License'));
      expect(pdf, contains('Copyright 2014 The Apache Software Foundation'));
      expect(pdf, contains('Adobe Font Metrics'));
      expect(pdf, contains('https://github.com/TomRoush/PdfBox-Android'));
      expect(textFor('Bouncy Castle 1.72'), contains('2000-2022'));
      expect(
        textFor('Bouncy Castle 1.72'),
        contains('Permission is hereby granted'),
      );
      expect(
        textFor('Liberation Fonts 2.1.5 (PDFBox)'),
        contains('SIL OPEN FONT LICENSE'),
      );
      expect(textFor('Unicode data (PDFBox)'), contains('UNICODE LICENSE V3'));
      for (final pod in _iosPods) {
        expect(textFor(pod), isEmpty, reason: '$pod is not in the APK');
      }
    },
  );

  test('iOS lists the bundled pods instead of the Android PDF stack', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final textFor = await _registeredLicenses();

    for (final pod in _iosPods) {
      expect(
        textFor(pod),
        contains('Permission is hereby granted'),
        reason: pod,
      );
      expect(textFor(pod), contains('https://github.com/'), reason: pod);
    }
    expect(textFor('SDWebImage 5.21.7'), contains('Olivier Poitrey'));
    expect(textFor('PdfBox-Android 2.0.27.0'), isEmpty);
    expect(textFor('Bouncy Castle 1.72'), isEmpty);
    expect(textFor('Playfair Display'), contains('SIL OPEN FONT LICENSE'));
  });
}
