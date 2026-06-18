# CLAUDE.md

Context and working agreement for Claude Code on this project. Read this fully
before making changes.

## What we're building

A word-puzzle game for Android + iOS (Flutter), built for a Tier-1 (US / first-
world English-speaking) audience, monetized primarily with ads.

The core mechanic is word-guessing: guess a hidden 5-letter word in a limited
number of tries, with per-letter feedback (right letter & spot / right letter
wrong spot / not in word).

### Product direction (decided)

Market research finding: in the US, the commercially dominant word games
(Wordscapes, Words of Wonders, Word Search Explorer) are LEVEL-PROGRESSION games
monetized via interstitials-between-levels + rewarded boosters + IAP. A pure
daily-guess (Wordle-style) format has great virality but very low ad inventory
(one puzzle/day) and is largely owned by NYT. The #1 user complaint across the
category is ad fatigue / intrusive ads.

So this app has **two modes**:

- **Daily** — one shared puzzle per day. The retention + virality hook: streaks,
  shareable result. Keep this flow **clean / ad-light** (no interstitials).
- **Journey** — a long, themed run of word-guess levels (this replaces the old
  "Practice" mode). This is the **ad-revenue engine**: interstitial every few
  levels (frequency-capped), rewarded boosters (hint / reveal / extra guess),
  optional banner. Reuses the SAME guess engine — no new core mechanic.

### Differentiators (these are the product, not nice-to-haves)

1. **"Fewer, Fairer Ads"** — Daily mode fully clean; Journey ads capped; a single
   "remove ads" IAP. This directly targets the category's biggest complaint.
2. **Cozy / brain-training positioning** — calm, relaxing aesthetic; "sharpen
   your mind in a few minutes a day" framing. This is the US word-game sweet spot.
3. **Social proof** — show "X% of players solved this" on levels (a proven hook).
4. **Streak + shareable result** in our OWN emoji format (never Wordle's squares).
5. **Themed word packs** unlockable via rewarded ad / IAP.

### Branding (DECISION PENDING — placeholder for now)

Brand name is a placeholder. Candidate names: "Lexa", "WordNest", "Daily Lexicon".
Use a clearly-marked placeholder in code (e.g. APP_NAME constant) so it's a
one-line change later. Do NOT invent a final name yet — flag it for the owner.

## Hard guardrails (do not violate)

1. **Legal/IP:** This is NOT "Wordle". Never use the name "Wordle" anywhere in
   code, UI, store listing, or assets. Do NOT reproduce Wordle's green/yellow/gray
   color scheme or layout — we use our own palette (teal/amber/slate, see
   `lib/theme/app_theme.dart`). The guessing *mechanic* is fine; the brand/look is not.
2. **No secrets in the repo.** Real AdMob ad unit IDs / app IDs go in
   `--dart-define` or gitignored config, never hardcoded. Google's public TEST ad
   unit IDs are fine as defaults.
3. **Keep core logic pure & tested.** `lib/logic/game_engine.dart` must stay free
   of Flutter/UI imports. Add tests in `test/` for any logic change.
4. **No heavy state-management dependency.** We use `ChangeNotifier` +
   `ListenableBuilder`. Don't add provider/riverpod/bloc unless asked.
5. **Ask before adding dependencies.** Keep the list small.

## Architecture

```
lib/
  main.dart                 # entry point; init services then run app
  app.dart                  # MaterialApp + theme
  theme/app_theme.dart      # palette (our colors, NOT Wordle's) + ThemeData
  models/
    letter_status.dart      # LetterStatus enum + rank
    game_result.dart        # GameStats (persisted)
  logic/
    game_engine.dart        # PURE evaluateGuess/isWinning. No Flutter imports.
  data/
    word_repository.dart    # loads answers/allowed from assets; daily word pick
  services/
    storage_service.dart    # shared_preferences: streak, stats, daily board
    ads_service.dart        # AdMob rewarded/interstitial wrappers
  state/
    game_controller.dart    # ChangeNotifier; owns state + orchestration
  screens/
    game_screen.dart        # main screen
    stats_sheet.dart        # stats / share sheet
    widgets/{board_grid,letter_tile,keyboard}.dart
assets/words/{answers,allowed}.txt
test/game_engine_test.dart
```

## AUDIT — known issues to fix (verified by static review; not yet compiled)

The lib/ code was written without a compiler. Run `flutter analyze` and fix all
errors/warnings first. Specific items found in review:

- **[blocker] AdMob native config missing.** Add the AdMob sample App ID to
  android/app/src/main/AndroidManifest.xml as a <meta-data> (name:
  com.google.android.gms.ads.APPLICATION_ID, value:
  ca-app-pub-3940256099942544~3347511713) and the iOS equivalent
  (GADApplicationIdentifier in Info.plist). Ads won't load (and init may throw)
  without it.
- **[moderate] Extra-guess renders no row.** `BoardGrid` is fixed to
  `maxGuesses` rows; `useExtraGuess()` re-opens the game but there's no 7th row.
  Make the grid render `max(maxGuesses, guesses.length + 1)` rows before wiring
  the extra-guess button.
- **[moderate] Returning user doesn't see the stats sheet.** In
  `game_screen.dart`, `startGame` runs before `addListener`, so an already-
  completed daily won't auto-open the stats sheet. Handle the "already done
  today" case explicitly on first build.
- **[minor] Lint:** expect `prefer_final_locals` infos (e.g. `int newStreak;` in
  storage_service). Clean them up with `dart fix --apply`.
- **[minor] Unused for now:** `share_plus` dep, `WordRepository.isLoaded`,
  `restoreStreak`, `useExtraGuess` — these are intentional forward hooks.

Logic verified correct in review: guess evaluation (incl. duplicate letters,
all unit tests pass logically), streak rules, deterministic daily-word selection.

## Roadmap (prioritized — pick the top open item unless told otherwise)

1. **Make it run cleanly.** flutter create ., pub get, analyze (fix all), test
   (engine tests pass), AdMob native config, flutter run.
2. **Rename "Practice" -> "Journey" and make it a leveled progression:** a level
   counter, themed word packs, persistent progress, and the ad cadence
   (interstitial every 3 levels, rewarded boosters). Daily stays ad-light.
3. **Word lists:** replace placeholders. answers.txt = a curated ~500 common/fair
   5-letter words; allowed.txt = a large real 5-letter dictionary. Wire guess
   validation against allowed.txt (already called in controller).
4. **Persistence:** finish/verify streak (current/best), win%, guess
   distribution, daily board save/restore, and the rewarded "restore streak".
5. **Share result:** OUR OWN emoji format (not Wordle's) via share_plus.
6. **"Fewer, Fairer Ads" + remove-ads IAP**; social-proof "% solved" on levels.
7. **Daily reminder notification** (once/day max).
8. **Polish:** tile flip animation, haptics, onboarding/how-to-play, settings,
   cozy theme pass. Finalize brand name (owner decision).

## Conventions

- `flutter analyze` clean; format with `dart format`.
- Small widgets, pure functions; business logic stays out of widgets.
- Name ad placements clearly (e.g. rewarded_hint, interstitial_journey).
- Commit after each working step: `git add -A && git commit -m "..."`.

## Run / test

```bash
flutter pub get
flutter run                 # uses Google TEST ad unit IDs by default
flutter test
flutter analyze
```

Real ad IDs later: --dart-define=ADMOB_REWARDED=... ADMOB_INTERSTITIAL=...