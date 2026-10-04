# Native PDF dependency notices

These files accompany the native PDF importer and are available from Settings →
Licenses. The upstream license and notice text is retained without alteration.

- `pdfbox-android-LICENSE.txt` and `pdfbox-android-NOTICE.txt`: PdfBox-Android
  2.0.27.0, including its PDFBox, FontBox, Adobe and PaDaF notices.
  Sources: https://raw.githubusercontent.com/TomRoush/PdfBox-Android/v2.0.27.0/LICENSE.txt
  and https://raw.githubusercontent.com/TomRoush/PdfBox-Android/v2.0.27.0/NOTICE.txt
- `bouncycastle-LICENSE.txt`: Bouncy Castle 1.72, covering bcprov-jdk15to18,
  bcpkix-jdk15to18 and bcutil-jdk15to18. Extracted from the `licenseText` supplied
  by `org.bouncycastle.LICENSE` in the Maven artifact; corresponding source:
  https://raw.githubusercontent.com/bcgit/bc-java/r1rv72/core/src/main/java/org/bouncycastle/LICENSE.java
- `liberation-fonts-LICENSE.txt`: Liberation Fonts 2.1.5. The font bundled in
  the PdfBox-Android AAR identifies itself as Liberation Sans version 2.1.5,
  with Google 2010 and Red Hat 2012 copyrights and SIL OFL 1.1.
  Source: https://raw.githubusercontent.com/liberationfonts/liberation-fonts/2.1.5/LICENSE
- `unicode-LICENSE.txt`: Unicode data terms downloaded on 2026-09-07.
  PdfBox-Android bundles BidiMirroring-8.0.0 and Scripts-10.0.0 with their
  original copyright headers. Source: https://www.unicode.org/license.txt

The PDFBox AAR and its classes JAR do not embed readable LICENSE or NOTICE
files. These assets supply the missing notices in the application package and
the Flutter licenses page. The new runtime dependencies are open source Java
libraries from Maven Central; the PDFBox dependency adds no native `.so` files
or Google service dependency.

# iOS CocoaPods notices

On iOS the PDF importer uses Apple's PDFKit, so none of the PDFBox notices
above ship there. Instead `file_picker` links these CocoaPods into the app
(versions pinned by `ios/Podfile.lock`). Each file is the unaltered `LICENSE`
from the pod at that tag; all are MIT.

- `dkimagepickercontroller-LICENSE.txt`: DKImagePickerController 4.3.9,
  https://github.com/zhangao0086/DKImagePickerController/tree/4.3.9
- `dkphotogallery-LICENSE.txt`: DKPhotoGallery 0.0.19,
  https://github.com/zhangao0086/DKPhotoGallery/tree/0.0.19
- `sdwebimage-LICENSE.txt`: SDWebImage 5.21.7,
  https://github.com/SDWebImage/SDWebImage/tree/5.21.7
- `swiftygif-LICENSE.txt`: SwiftyGif 5.4.5,
  https://github.com/kirualex/SwiftyGif/tree/5.4.5
