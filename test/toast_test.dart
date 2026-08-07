import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/coin_rules.dart';
import 'package:daily_word_game/screens/widgets/toast.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

class _FakeAds implements GameAds {
  @override
  Future<bool> showRewarded() async => true;
  @override
  void maybeShowJourneyInterstitial() {}
}

Future<GameController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return GameController(
    words: WordRepository()..debugLoad(const ['CRANE', 'SLATE', 'BRINE']),
    storage: storage,
    coins: CoinService(storage),
    ads: _FakeAds(),
  );
}

Future<void> _pumpHost(WidgetTester tester, GameController c) async {
  tester.view.physicalSize = const Size(1170, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Column(children: [const Spacer(), ToastHost(controller: c)]),
    ),
    builder: (context, w) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: w!,
    ),
  ));
}

Future<void> _pumpCard(WidgetTester tester, ToastKind kind, String text) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: CozyToast(kind: kind, text: text, entrance: 1, life: 0, reduce: true),
        ),
      ),
    ),
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('classifyToast — real controller strings → kind', () {
    final cases = <String, ToastKind>{
      'Hint: position 3 is "E"': ToastKind.hint,
      '+25 coins!': ToastKind.reward,
      'Extra guess granted': ToastKind.reward,
      'Streak restored to 3!': ToastKind.reward,
      'Genius!': ToastKind.reward, // win praise
      'Impressive!  🔥 3-day streak': ToastKind.reward, // win + streak
      'Not in word list': ToastKind.validation,
      'Not enough letters': ToastKind.validation,
      'Hard mode: must use E': ToastKind.validation,
      'Need 15 coins — tap the coin to watch & earn': ToastKind.validation,
      'Every letter is already revealed': ToastKind.validation,
      'Out of guesses — the word was CRANE': ToastKind.validation,
      'No ad available — try again in a moment': ToastKind.unavailable,
    };
    cases.forEach((msg, kind) {
      test('"$msg" → $kind', () => expect(classifyToast(msg), kind));
    });

    test('isWinPraise distinguishes solves from coin rewards', () {
      expect(isWinPraise('Genius!'), isTrue);
      expect(isWinPraise('Splendid!'), isTrue);
      expect(isWinPraise('+25 coins!'), isFalse);
      expect(isWinPraise('Not in word list'), isFalse);
    });
  });

  group('CozyToast — badges use real code values', () {
    testWidgets('hint toast shows the REAL hint cost, not the mockup\'s -5',
        (tester) async {
      expect(CoinRules.hintCost, 15); // guard: mockup says 5
      await _pumpCard(tester, ToastKind.hint, 'Hint: position 3 is "E"');
      expect(find.text('-15'), findsOneWidget);
      expect(find.text('-5'), findsNothing);
      expect(find.textContaining('position 3'), findsOneWidget);
    });

    testWidgets('reward toast shows the "Nice" badge', (tester) async {
      await _pumpCard(tester, ToastKind.reward, '+25 coins!');
      expect(find.text('Nice'), findsOneWidget);
      expect(find.text('+25 coins!'), findsOneWidget);
    });

    testWidgets('validation toast has no badge', (tester) async {
      await _pumpCard(tester, ToastKind.validation, 'Not in word list');
      expect(find.text('Nice'), findsNothing);
      expect(find.textContaining('-'), findsNothing);
      expect(find.text('Not in word list'), findsOneWidget);
    });
  });

  group('ToastHost — win-moment ownership', () {
    testWidgets('daily win praise is suppressed (Stats screen owns it)',
        (tester) async {
      final c = await _controller();
      c.startGame(GameMode.daily);
      await _pumpHost(tester, c);

      for (final ch in c.answer.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(c.gameOver && c.won, isTrue);
      expect(find.byType(CozyToast), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('journey win praise DOES toast (no result screen there)',
        (tester) async {
      final c = await _controller();
      c.startGame(GameMode.journey);
      await _pumpHost(tester, c);

      for (final ch in c.answer.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(c.gameOver && c.won, isTrue);
      expect(find.byType(CozyToast), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
