# Daily Word Game

A daily word-guessing puzzle (Flutter, Android + iOS). Ad-monetized, built for a
Tier-1 (US) audience. See `CLAUDE.md` for full architecture, guardrails, and the
prioritized roadmap.

## First-time setup

This folder contains the source (`lib/`, `assets/`, `test/`, configs) but NOT the
generated platform folders (`android/`, `ios/`). Generate them once:

```bash
# From this folder, generate platform scaffolding in place:
flutter create .

# Then fetch dependencies and run:
flutter pub get
flutter run
```

`flutter create .` will not overwrite the existing `lib/`, `pubspec.yaml`, or
`assets/` — it only adds the missing native folders.

## Commands

```bash
flutter run        # runs with Google TEST ad unit IDs (safe for dev)
flutter test       # unit tests for the core engine
flutter analyze    # lints
dart format .      # format
```

## Real AdMob IDs (later, not committed)

```bash
flutter run \
  --dart-define=ADMOB_REWARDED=ca-app-pub-XXX/YYY \
  --dart-define=ADMOB_INTERSTITIAL=ca-app-pub-XXX/ZZZ
```

You'll also need to add your AdMob App ID to the native config
(AndroidManifest.xml / Info.plist) — see the google_mobile_ads setup docs.

## Important

- This is **not** "Wordle". Don't use that name or its green/yellow/gray palette.
- Replace the placeholder `assets/words/*.txt` with real word lists before launch.
