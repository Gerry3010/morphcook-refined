import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native dependencies are not part of Flutter's generated package notices.
/// Register the notices of what the running platform actually bundles on the
/// same offline licenses page: Gradle libraries on Android, pods on iOS.
void registerNativeLicenses() {
  LicenseRegistry.addLicense(
    () => defaultTargetPlatform == TargetPlatform.iOS
        ? _iosNativeLicenses()
        : _androidNativeLicenses(),
  );
}

Stream<LicenseEntry> _androidNativeLicenses() async* {
  final pdfLicense = await rootBundle.loadString(
    'assets/licenses/pdfbox-android-LICENSE.txt',
  );
  final pdfNotice = await rootBundle.loadString(
    'assets/licenses/pdfbox-android-NOTICE.txt',
  );
  yield LicenseEntryWithLineBreaks(
    const ['PdfBox-Android 2.0.27.0'],
    'https://github.com/TomRoush/PdfBox-Android/tree/v2.0.27.0\n\n'
    '$pdfNotice\n$pdfLicense',
  );
  for (final entry in const [
    (
      'Bouncy Castle 1.72',
      'bouncycastle-LICENSE.txt',
      'https://github.com/bcgit/bc-java/tree/r1rv72',
    ),
    (
      'Liberation Fonts 2.1.5 (PDFBox)',
      'liberation-fonts-LICENSE.txt',
      'https://github.com/liberationfonts/liberation-fonts/tree/2.1.5',
    ),
    (
      'Unicode data (PDFBox)',
      'unicode-LICENSE.txt',
      'https://www.unicode.org/license.txt',
    ),
  ]) {
    final license = await rootBundle.loadString('assets/licenses/${entry.$2}');
    yield LicenseEntryWithLineBreaks([entry.$1], '${entry.$3}\n\n$license');
  }
}

/// CocoaPods that file_picker links into the iOS app (see SOURCES.md). The
/// PDF importer uses Apple's PDFKit there, so no PDFBox notices apply.
Stream<LicenseEntry> _iosNativeLicenses() async* {
  for (final entry in const [
    (
      'DKImagePickerController 4.3.9',
      'dkimagepickercontroller-LICENSE.txt',
      'https://github.com/zhangao0086/DKImagePickerController/tree/4.3.9',
    ),
    (
      'DKPhotoGallery 0.0.19',
      'dkphotogallery-LICENSE.txt',
      'https://github.com/zhangao0086/DKPhotoGallery/tree/0.0.19',
    ),
    (
      'SDWebImage 5.21.7',
      'sdwebimage-LICENSE.txt',
      'https://github.com/SDWebImage/SDWebImage/tree/5.21.7',
    ),
    (
      'SwiftyGif 5.4.5',
      'swiftygif-LICENSE.txt',
      'https://github.com/kirualex/SwiftyGif/tree/5.4.5',
    ),
  ]) {
    final license = await rootBundle.loadString('assets/licenses/${entry.$2}');
    yield LicenseEntryWithLineBreaks([entry.$1], '${entry.$3}\n\n$license');
  }
}

/// Include each bundled interface font's full OFL notice in offline licenses.
void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in const [
      ('Atkinson Hyperlegible', 'AtkinsonHyperlegible'),
      ('Caveat', 'Caveat'),
      ('JetBrains Mono', 'JetBrainsMono'),
      ('Playfair Display', 'PlayfairDisplay'),
    ]) {
      final text = await rootBundle.loadString(
        'assets/fonts/OFL-${entry.$2}.txt',
      );
      yield LicenseEntryWithLineBreaks([entry.$1], text);
    }
  });
}
