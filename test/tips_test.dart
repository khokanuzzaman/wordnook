import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/tips.dart';
import 'package:daily_word_game/models/letter_status.dart';
import 'package:daily_word_game/screens/widgets/toast.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/analytics_service.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

class _FakeAds implements GameAds {
  @override
  Future<bool> showRewarded() async => true;
  @override
  void maybeShowJourneyInterstitial() {}
}

class _RecordingAnalytics implements Analytics {
  final List<Map<String, Object>?> tips = [];
  @override
  void logEvent(String name, [Map<String, Object>? p]) {
    if (name == AnalyticsEvents.tipShown) tips.add(p);
  }

  @override
  void setUserProperty(String name, String value) {}
}

const _a = LetterStatus.absent;
const _p = LetterStatus.present;
const _c = LetterStatus.correct;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TipRules.afterGuess', () {
    (Tip, String?)? pick(List<LetterStatus> st,
            {Map<String, LetterStatus> before = const {},
            Set<Tip> seen = const {},
            int games = 0,
            String guess = 'PLUMP'}) =>
        TipRules.afterGuess(
          guess: guess,
          statuses: st,
          keyStatusBefore: before,
          seen: seen,
          gamesFinished: games,
        );

    test('all grey → no matches', () {
      expect(pick([_a, _a, _a, _a, _a])?.$1, Tip.noMatches);
    });

    test('an amber tile → first amber', () {
      expect(pick([_a, _p, _a, _a, _a])?.$1, Tip.firstAmber);
    });

    test('nothing to teach on an all-green-and-grey row', () {
      expect(pick([_c, _a, _a, _a, _a]), isNull);
    });

    test('re-using a letter an earlier guess ruled out names that letter', () {
      final r = pick([_a, _a, _a, _a, _a],
          before: const {'L': LetterStatus.absent});
      expect(r?.$1, Tip.reusedGrey);
      expect(r?.$2, 'L');
      expect(TipRules.text(r!.$1, r.$2), 'You already ruled out L.');
    });

    test('a seen tip never repeats; the next useful one is offered', () {
      expect(pick([_a, _a, _a, _a, _a], seen: {Tip.noMatches}), isNull);
      expect(
          pick([_a, _p, _a, _a, _a], seen: {Tip.noMatches})?.$1, Tip.firstAmber);
    });

    test('no tips once a player has finished enough games', () {
      expect(pick([_a, _a, _a, _a, _a], games: TipRules.eligibleGames), isNull);
    });
  });

  group('idle tip eligibility', () {
    test('first games only, once', () {
      expect(TipRules.idleEligible(seen: {}, gamesFinished: 0), isTrue);
      expect(
          TipRules.idleEligible(
              seen: {}, gamesFinished: TipRules.idleEligibleGames),
          isFalse);
      expect(TipRules.idleEligible(seen: {Tip.idleStart}, gamesFinished: 0),
          isFalse);
    });
  });

  group('tips are styled as tips', () {
    for (final m in [
      TipRules.noMatchesText,
      TipRules.firstAmberText,
      TipRules.reusedGreyText('R'),
      TipRules.idleStartText,
    ]) {
      test(m, () => expect(classifyToast(m), ToastKind.tip));
    }
    test('ordinary messages are not tips', () {
      expect(classifyToast('Not in word list'), ToastKind.validation);
      expect(classifyToast('Hint: position 2 is "R"'), ToastKind.hint);
    });
  });

  group('controller', () {
    late StorageService storage;
    late _RecordingAnalytics analytics;

    Future<GameController> make() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      analytics = _RecordingAnalytics();
      // Answer CRANE; PLUMP shares no letters with it; ACORN has A, C, R, N
      // all in the word but in the wrong spots.
      return GameController(
        words: WordRepository()
          ..debugLoad(['CRANE'], allowed: {'PLUMP', 'ACORN', 'PILOT'}),
        storage: storage,
        coins: CoinService(storage),
        ads: _FakeAds(),
        analytics: analytics,
      )..startGame(GameMode.journey);
    }

    Future<void> type(GameController c, String w) async {
      for (final ch in w.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await Future<void>.delayed(Duration.zero);
    }

    test('each tip fires once, at the right moment, and is logged', () async {
      final c = await make();
      expect(c.answer, 'CRANE');

      await type(c, 'PLUMP'); // nothing matches
      expect(c.message, TipRules.noMatchesText);
      c.clearMessage();

      await type(c, 'PILOT'); // re-uses P and L, both ruled out
      expect(c.message, 'You already ruled out P.');
      c.clearMessage();

      await type(c, 'ACORN'); // ambers (O was ruled out, but that tip is used)
      expect(c.message, TipRules.firstAmberText);
      c.clearMessage();

      await type(c, 'PLUMP'); // all already taught → no tip
      expect(c.message, isNull);

      expect(analytics.tips.map((p) => p?[AnalyticsParams.tip]),
          ['no_matches', 'reused_grey', 'first_amber']);
      expect(storage.tipsSeen,
          {'no_matches', 'reused_grey', 'first_amber'});
    });

    test('the idle tip shows once on an untouched board', () async {
      final c = await make();
      expect(c.idleTipEligible, isTrue);
      c.showIdleTip();
      expect(c.message, TipRules.idleStartText);
      c.clearMessage();
      expect(c.idleTipEligible, isFalse);
      c.showIdleTip();
      expect(c.message, isNull);
    });

    test('typing makes the board ineligible for the idle tip', () async {
      final c = await make();
      c.onKey('P');
      expect(c.idleTipEligible, isFalse);
    });

    test('finishing games counts toward the tips window', () async {
      final c = await make();
      await type(c, 'CRANE');
      expect(storage.gamesFinished, 1);
    });
  });
}
