# MorphCook

> [!IMPORTANT]
> **iOS port fork — for testing only.** This is a fork of
> [TheMorpheus407/morphcook-refined](https://github.com/TheMorpheus407/morphcook-refined)
> that adds a working iOS implementation. It is not upstreamed.
>
> | | |
> |---|---|
> | Ported by | Claude Code, driven by Gerald Hofbauer |
> | Model | Claude Opus 5.5 (`claude-opus-5-5`) |
> | Thinking / effort level | `xhigh` (fast mode off) |
> | Claude Code | 2.1.280 inside the Claude desktop app 2.2553.13 (Agent SDK 0.3.280), macOS 26.5.2 |
> | Toolchain | Xcode 26.6 (17F113), Flutter 3.38.3 / Dart 3.10.1 (the pinned `submodules/flutter`), CocoaPods 1.16.2 |
> | Verified on | iOS Simulator: iPhone 16 Pro (iOS 18.6), iPhone 17 Pro (iOS 26.5), iPhone SE 3rd gen (iOS 17.0) |
> | Date | 2026-10-04 |
>
> **What the port adds:** native PDF text import via PDFKit/CoreGraphics on the
> `morphcook/pdf_import` channel (same limits and error codes as the Android
> PDFBox extractor, covered by XCTests), UIScene lifecycle, the real app icon,
> a light/dark launch screen, EN/DE localization, a privacy manifest and the
> bundle ID `net.geraldhofbauer.morphcook`. Shared code now names AirDrop
> instead of Bluetooth/Quick Share on iOS, lists the iOS pods' licenses, and
> keeps status-bar icons legible on every screen (on Android too).
>
> **Known iOS differences:** PDFKit can merge tightly-leaded lines (e.g. plain
> text-to-PDF output), so such PDFs may fall back to the unstructured-text
> import; browser- and ReportLab-generated recipe PDFs import fully structured.
> Broken page content is reported as "no text" where Android says "invalid PDF".
>
> Build for iOS (after `git submodule update --init`):
> `submodules/flutter/bin/flutter run -d <simulator>`; native
> tests: `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

*The same dish exists for every body.*

Recipe apps treat dietary needs as filters that remove dishes from the world:
go vegan and the Döner disappears, develop a nut allergy and Pad Thai is gone.
MorphCook inverts this. Every dish exists as fully-authored variants — vegan
Döner, gluten-free Alfredo, keto burger — and your profile decides which
variant of each dish you see. You keep the whole cookbook.

The app is an offline-first Flutter app (Android + iOS): no backend, no
accounts, no telemetry, no runtime AI, no network permission. The bilingual
(EN/DE) recipe corpus ships bundled with the app.

This repository is the maintained, actively-refined build of MorphCook. It was
originally produced by Claude Fable 5 as one entry in a
[multi-model comparison](https://github.com/TheMorpheus407/morphcook) and has
been developed by hand since.

## Build

```sh
flutter pub get
flutter test
flutter run
```

Release APK (what F-Droid builds):

```sh
flutter build apk --release
```

For reproducible F-Droid builds the Flutter SDK is pinned as a git submodule
(`submodules/flutter`, currently 3.38.3). A normal clone ignores it; the
F-Droid buildserver initializes it and builds with that exact toolchain. Local
development can just use your system Flutter.

## Privacy

MorphCook is offline-first and collects no analytics. Website requests and optional photo downloads occur only when you choose an import. See
[PRIVACY.md](PRIVACY.md).

## Licenses

- Application code and recipe corpus: **MIT** — see [LICENSE](LICENSE).
- Bundled fonts, all under the **SIL Open Font License 1.1**:
  - Playfair Display — `assets/fonts/OFL-PlayfairDisplay.txt`
  - JetBrains Mono — `assets/fonts/OFL-JetBrainsMono.txt`
  - Caveat — `assets/fonts/OFL-Caveat.txt`

## Website imports

In the cookbook, use the link icon to import a recipe URL. Review its ingredients,
steps, time and servings before saving. Text is available offline; photos download
only if selected. Website diet and allergy claims are unverified. Ambiguous
amounts retain their original text and are explicitly marked as unscaled.

## Recipe sharing

Share one recipe from its details or the whole cookbook from the sharing screen.
The ZIP includes readable text and importable recipe data, with optional photos.
Recipients preview additions; their profile, plans and history stay private.
Android offers Bluetooth, Quick Share and other installed compatible apps.
iOS offers AirDrop, Save to Files and other apps in the share sheet.

## PDF import, manual and feedback

Import selectable-text PDF recipes from the cookbook and review before saving.
Settings includes the offline EN/DE manual, feedback drafts and license notices.
Recipe details let you request and privately record attributed expert assessments.
The app does not supply professional reviews or verify credentials. Notes travel
only in full backups, with a warning when the assessed recipe changes.
