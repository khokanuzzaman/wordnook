# CLAUDE.md

Context and working agreement for Claude Code on this project. Read this fully
before making changes.

## What we're building

A daily word-guessing puzzle game for Android + iOS (Flutter). The player guesses
a hidden 5-letter word in a limited number of tries, with per-letter feedback
(right letter & spot / right letter wrong spot / not in word).

**Two modes, on purpose:**
- **Daily mode** — one shared puzzle per day. Drives retention via streaks and a
  shareable result. Keep this flow clean (no interstitial ads here).
- **Practice mode** — unlimited rounds. This is the ad-inventory engine
  (interstitials between rounds, frequency-capped).

**Target audience:** US / Tier-1 English speakers (high ad eCPM). All copy in English.

**Monetization:** ad-first (AdMob).
- Rewarded video (highest eCPM): hint / reveal a letter / extra guess / streak restore.
- Interstitial: Practice mode round-end only, frequency-capped.
- Optional banner on the stats screen.

## Hard guardrails (do not violate)

1. **Legal/IP:** This is NOT "Wordle". Never use the name "Wordle" anywhere in
   code, UI, store listing, or assets. Do NOT reproduce Wordle's green/yellow/gray
   color scheme — we use our own palette (teal/amber/slate, see `lib/theme/app_theme.dart`).
   The guessing *mechanic* is fine to use; the brand/look is not.
2. **No secrets in the repo.** Real AdMob ad unit IDs and app IDs go in
   `--dart-define` or a gitignored config, never hardcoded. Test ad unit IDs
   (Google's public ones) are fine as defaults.
3. **Keep the core logic pure and tested.** `lib/logic/game_engine.dart` must
   stay free of Flutter/UI imports so it remains unit-testable. Add tests for any
   logic change in `test/`.
4. **No heavy state-management dependency.** We use `ChangeNotifier` +
   `ListenableBuilder` (built into Flutter). Don't add provider/riverpod/bloc
   unless explicitly asked.
5. **Ask before adding dependencies.** Keep the dependency list small.

## Architecture

```
lib/
  main.dart                 # entry point; initializes services then runs app
  app.dart                  # MaterialApp + theme wiring
  theme/app_theme.dart      # palette + ThemeData (our colors, NOT Wordle's)
  models/
    letter_status.dart      # LetterStatus enum
    game_result.dart        # immutable result of an evaluated guess + game stats
  logic/
    game_engine.dart        # PURE functions: evaluateGuess, etc. No Flutter imports.
  data/
    word_repository.dart    # loads answers/allowed lists from assets; daily word pick
  services/
    storage_service.dart    # shared_preferences: streak, stats, daily completion
    ads_service.dart        # AdMob rewarded/interstitial wrappers
  state/
    game_controller.dart    # ChangeNotifier holding all game state + orchestration
  screens/
    game_screen.dart        # main screen
    stats_sheet.dart        # stats / share bottom sheet
    widgets/
      board_grid.dart       # the guess grid
      letter_tile.dart      # one tile
      keyboard.dart         # on-screen keyboard with letter coloring
assets/words/
  answers.txt               # curated common 5-letter words (the daily answers)
  allowed.txt               # large list of valid guesses (superset of answers)
test/
  game_engine_test.dart     # unit tests for evaluateGuess (incl. duplicate letters)
```

**Data flow:** `GameController` (ChangeNotifier) owns state. UI widgets listen via
`ListenableBuilder`. Controller calls `WordRepository` (words), `GameEngine`
(evaluation), `StorageService` (persistence), `AdsService` (ads).

## Current status

Implemented (working scaffold):
- Core guess evaluation with correct duplicate-letter handling + unit tests.
- Word repository with deterministic daily-word selection + asset loading
  (falls back to a small built-in list if assets missing).
- Game controller, board, keyboard, tiles, mode toggle, hint flow (stubbed).
- Storage service with full API but **persistence calls are partially stubbed**.
- Ads service structured with Google **test** ad unit IDs; load/show methods are
  implemented against `google_mobile_ads` but need verification on device.

## Roadmap (prioritized — pick the top open item unless told otherwise)

1. **Word lists** — replace placeholder `assets/words/*.txt` with real lists.
   `answers.txt` = a few hundred common, fair words. `allowed.txt` = large
   dictionary (e.g. derived from dwyl/english-words, filtered to length 5).
   Wire guess validation against `allowed.txt`.
2. **Persistence** — finish `StorageService`: streak (current/best), last-played
   date, win %, guess distribution, and save/restore today's daily board so a
   refresh doesn't reset progress. Reset streak on a missed day.
3. **AdMob** — verify rewarded (hint/extra-guess/streak-restore) and Practice
   interstitial (frequency-capped). Keep Daily mode ad-free. Add consent flow
   (UMP) for GDPR/Tier-1.
4. **Share result** — generate an emoji grid in OUR OWN format (not Wordle's
   squares) + share via `share_plus`.
5. **Daily reminder notification** — local notification once/day ("Today's puzzle
   is live"). One per day max.
6. **Theme/niche** — optionally specialize the word list around a niche
   (food / tech / movies / slang) for differentiation and community sharing.
7. **Polish** — tile flip animation, haptics, light/dark, onboarding, settings.

## Conventions

- Dart style: `flutter analyze` must pass clean; format with `dart format`.
- Prefer small widgets and pure functions. Business logic stays out of widgets.
- Name ad placements clearly (e.g. `rewarded_hint`, `interstitial_practice_end`).
- Comments explain *why*, not *what*.

## Run / test

```bash
flutter pub get
flutter run                 # uses Google test ad unit IDs by default
flutter test                # runs unit tests
flutter analyze
```

Real ad IDs (later): pass via `--dart-define=ADMOB_REWARDED=ca-app-pub-...` etc.
(see `ads_service.dart` for the keys it reads).
