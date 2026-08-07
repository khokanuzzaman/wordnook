import 'package:flutter/material.dart';
import '../models/letter_status.dart';
import 'game_theme.dart';

export 'game_theme.dart';

/// Brand typography. Fredoka for headings/tiles/keys/numerals, Nunito for body
/// and captions — applied app-wide via [buildTheme] so every surface (real
/// board included) shares one voice with the onboarding.
///
/// Both families are BUNDLED as assets (see pubspec `fonts:`), so they render
/// fully offline with no first-launch network fetch or pop-in.
class AppType {
  const AppType._();

  static const String fredokaFamily = 'Fredoka';
  static const String nunitoFamily = 'Nunito';

  static TextStyle fredoka({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: fredokaFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle nunito({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: nunitoFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
}

/// App palette. The three status colours come from the active [selectedTheme]
/// (a cosmetic, unlockable palette); the neutral chrome below is shared by all
/// themes. Intentionally NOT the green/yellow/gray of the best-known word game.
class AppPalette {
  // Warm-evening base (redesign §5). Never pure black.
  static const Color background = Color(0xFF191410); // warm scaffold base
  static const Color surface = Color(0xFF221C16); // warm sheets / cards

  // Cozy brand accents used by non-board chrome (labels, stat bars). Now the
  // warm teal/amber so chrome matches the redesigned Cozy board.
  static const Color correct = Color(0xFF4F9B8E); // teal
  static const Color present = Color(0xFFE0A857); // amber
  static const Color absent = Color(0xFF34302A); // warm grey

  // Shared neutral chrome for the board (same across all themes).
  static const Color empty = Color(0xFF211C17); // warm empty tile
  static const Color border = Color(0xFF3A342C);
  static const Color keyIdle = Color(0xFF332D26);

  // Text tokens.
  static const Color ink = Color(0xFFF4F1EC); // primary text
  static const Color muted = Color(0xFF9A9084); // subtitle / captions
  static const Color faint = Color(0xFF6C7B76); // skip / tertiary
  static const Color inkOnAmber = Color(0xFF3B2A08); // glyph on amber

  // --- Warm cozy redesign tokens (board & home, §1/§4/§5) ------------------
  static const Color bgGlow = Color(0x1AE0A857); // lamp glow (amber 0.10)
  static const Color bgTop = Color(0xFF241F19);
  static const Color bgMid = Color(0xFF191410);
  static const Color bgBottom = Color(0xFF130F0B);

  static const Color chipFill = Color(0x09FFF0DC); // rgba(255,240,220,.035)
  static const Color chipBorder = Color(0x0FFFF0DC); // rgba(255,240,220,.06)
  static const Color chipText = Color(0xFFD8CFC2); // streak label
  static const Color absentGlyph = Color(0xFF8A8175); // letter on absent tiles

  // Empty tile gradients.
  static const Color emptyTop = Color(0xFF2C2620);
  static const Color emptyBottom = Color(0xFF211C17);
  static const Color activeTop = Color(0xFF352C22);
  static const Color activeBottom = Color(0xFF28211A);
  static const Color activeRing = Color(0x61E0A857); // amber 0.38
  static const Color caret = Color(0xFFE0A857);

  // Identity accents.
  static const Color dailyKicker = Color(0xFFC79A5A);
  static const Color dailyDot = Color(0xFF5CA99B);
  static const Color journeyKicker = Color(0xFF7FBEB1);
  static const Color journeyDot = Color(0xFFE0A857);
  static const Color firstGuessPrompt = Color(0xFFC79A5A);

  // Coin pill.
  static const Color coinsAmber = Color(0xFFEBBB73);
  static const Color coinTop = Color(0xFFF2C67E);
  static const Color coinBottom = Color(0xFFD89F4E);
  static const Color coinPillBorder = Color(0x38E0A857); // amber 0.22

  // Icons.
  static const Color iconStroke = Color(0xFFB8AEA1);

  // Keyboard faces.
  static const Color keyFaceTop = Color(0xFF39332C);
  static const Color keyFaceBottom = Color(0xFF2C2721);
  static const Color keyGlyph = Color(0xFFEDE7DD);
  static const Color keyAbsentTop = Color(0xFF241F1A);
  static const Color keyAbsentBottom = Color(0xFF1D1915);
  static const Color keyAbsentGlyph = Color(0xFF6E655B);

  // Switcher (§6): one lifted fill; the lit dot cues the mode.
  static const Color switcherTrackBg = Color(0x47000000); // black 0.28
  static const Color switcherBorder = Color(0x0DFFF0DC); // 0.05
  static const Color switcherSelTop = Color(0xFF2E3A36);
  static const Color switcherSelBottom = Color(0xFF26302D);
  static const Color switcherOffText = Color(0xFF8A8175);

  // --- Secondary screens (addendum §A–§G) ---------------------------------
  // Section eyebrow reuses `dailyKicker` (#C79A5A); surface fill/border reuse
  // `chipFill`/`chipBorder`; time-pill border reuses `coinPillBorder`.

  // §B screen header — back button.
  static const Color backBtnFill = Color(0x08FFF0DC); // rgba(255,240,220,.03)

  // §A info-note (how-to tip, drawer coin card).
  static const Color infoNoteFill = Color(0x14E0A857); // amber 0.08
  static const Color infoNoteBorder = Color(0x2EE0A857); // amber 0.18

  // §C guess-distribution bars.
  static const Color distTrack = Color(0x0AFFF0DC); // rgba(255,240,220,.04)
  static const Color distNormalStart = Color(0xFF38564F);
  static const Color distNormalEnd = Color(0xFF43715F);
  static const Color distNormalCount = Color(0xFFEDE7DD);
  static const Color distBestStart = Color(0xFF4A9184);
  static const Color distBestEnd = Color(0xFF5CA99B);
  static const Color distBestCount = Color(0xFF0E1513);

  // §C share button ink (on the teal fill).
  static const Color onTealInk = Color(0xFF0E1513);
  static const Color tealBtnStart = Color(0xFF57A99B);
  static const Color tealBtnEnd = Color(0xFF4A9184);

  // §D toggle.
  static const Color toggleOffTrack = Color(0xFF2C2721);
  static const Color toggleOffBorder = Color(0x14FFF0DC); // 0.08
  static const Color toggleOnBorder = Color(0x804F9B8E); // teal 0.5
  static const Color toggleKnob = Color(0xFFF4F1EC);

  // §D time pill fill (border reuses coinPillBorder; text reuses coinsAmber).
  static const Color timePillFill = Color(0x1AE0A857); // amber 0.10

  // §D theme swatch states.
  static const Color swatchSelBorder = Color(0x994F9B8E); // teal 0.6
  static const Color swatchSelGlow = Color(0x404F9B8E); // teal 0.25
  static const Color swatchSelLabel = Color(0xFF8FD3C6);
  static const Color swatchBorder = Color(0x12FFF0DC); // 0.07
  static const Color lockPillFill = Color(0xB30A0806); // rgba(10,8,6,.7)

  // §G menu drawer.
  static const Color drawerBgInner = Color(0xFF262019);
  static const Color drawerBgMid = Color(0xFF1A1611);
  static const Color drawerBgOuter = Color(0xFF141009);
  static const Color drawerScrim = Color(0x8C090705); // rgba(9,7,5,.55)
  static const Color menuActiveFill = Color(0x1F4F9B8E); // teal 0.12
  static const Color menuInactiveText = Color(0xFFC7BEB2);

  // --- Toast / message system (handoff-toast §C) --------------------------
  // Shared drop shadow (0 14px 30px -12px rgba(0,0,0,0.7)).
  static const Color toastShadow = Color(0xB3000000);
  // Progress-hairline track (rgba(255,255,255,0.08)); fill = per-type accent.
  static const Color toastTrack = Color(0x14FFFFFF);

  // Hint (amber). Icon reuses `present`; badge text reuses `coinsAmber`.
  static const Color toastHintTop = Color(0xFF2A2318);
  static const Color toastHintBottom = Color(0xFF221C13);
  static const Color toastHintBorder = Color(0x47E0A857); // amber 0.28
  static const Color toastHintWell = Color(0x29E0A857); // amber 0.16
  static const Color toastHintBadgeFill = Color(0x24E0A857); // amber 0.14
  static const Color toastHintBadgeBorder = Color(0x40E0A857); // amber 0.25

  // Reward (teal). Icon reuses the coin gradient; accent reuses `dailyDot`.
  static const Color toastRewardTop = Color(0xFF1E2A26);
  static const Color toastRewardBottom = Color(0xFF18211E);
  static const Color toastRewardBorder = Color(0x4D5CA99B); // teal 0.30
  static const Color toastRewardWell = Color(0x295CA99B); // teal 0.16
  static const Color toastRewardBadgeFill = Color(0x245CA99B); // teal 0.14
  static const Color toastRewardBadgeBorder = Color(0x475CA99B); // teal 0.28
  static const Color toastRewardBadgeText = Color(0xFF8FD3C6);

  // Validation (gentle warm). Icon reuses `present`.
  static const Color toastValidTop = Color(0xFF282219);
  static const Color toastValidBottom = Color(0xFF201B14);
  static const Color toastValidBorder = Color(0x1FFFF0DC); // 0.12
  static const Color toastValidWell = Color(0x1FE0A857); // amber 0.12
  static const Color toastValidAccent = Color(0xFFC99A5A);

  // Unavailable (muted). Icon + accent reuse `muted`; text reuses `chipText`.
  static const Color toastUnavailTop = Color(0xFF211D18);
  static const Color toastUnavailBottom = Color(0xFF1A1712);
  static const Color toastUnavailBorder = Color(0x14FFF0DC); // 0.08
  static const Color toastUnavailWell = Color(0x0FFFF0DC); // 0.06

  /// The active board theme. Tiles/keyboard rebuild when this changes (it's
  /// merged into the game screen's listeners).
  static final ValueNotifier<GameTheme> selectedTheme =
      ValueNotifier<GameTheme>(ThemeRegistry.defaultTheme);

  /// Status colour for a tile/key, from the active theme (empty uses chrome).
  static Color forStatus(LetterStatus s) {
    final t = selectedTheme.value;
    switch (s) {
      case LetterStatus.correct:
        return t.correct;
      case LetterStatus.present:
        return t.present;
      case LetterStatus.absent:
        return t.absent;
      case LetterStatus.empty:
        return empty;
    }
  }

  /// The subtle vertical gradient painted around a scored tile's base colour.
  /// Shared by the board [LetterTile] and the How-to-play legend so the two
  /// never drift apart.
  static List<Color> statusGradient(LetterStatus s) {
    final hsl = HSLColor.fromColor(forStatus(s));
    return [
      hsl.withLightness((hsl.lightness + 0.055).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - 0.055).clamp(0.0, 1.0)).toColor(),
    ];
  }

  /// Glyph colour for a letter sitting on a scored status tile.
  static Color statusGlyph(LetterStatus s) {
    if (s == LetterStatus.absent) return absentGlyph;
    // Light fills (amber/present) get dark ink for contrast; dark fills get ink.
    return forStatus(s).computeLuminance() > 0.55 ? inkOnAmber : ink;
  }
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  // Body/caption text is Nunito; display/headline/title are Fredoka. Applied
  // through the theme so all existing screens pick up the brand type too.
  TextTheme applyFamilies(TextTheme t) => t.copyWith(
        displayLarge: t.displayLarge?.copyWith(fontFamily: AppType.fredokaFamily),
        displayMedium:
            t.displayMedium?.copyWith(fontFamily: AppType.fredokaFamily),
        displaySmall: t.displaySmall?.copyWith(fontFamily: AppType.fredokaFamily),
        headlineLarge:
            t.headlineLarge?.copyWith(fontFamily: AppType.fredokaFamily),
        headlineMedium:
            t.headlineMedium?.copyWith(fontFamily: AppType.fredokaFamily),
        headlineSmall:
            t.headlineSmall?.copyWith(fontFamily: AppType.fredokaFamily),
        titleLarge: t.titleLarge?.copyWith(fontFamily: AppType.fredokaFamily),
      );
  // Nunito as the base family for everything else.
  final textTheme = applyFamilies(
    base.textTheme.apply(fontFamily: AppType.nunitoFamily),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppPalette.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppPalette.surface,
      titleTextStyle: AppType.fredoka(
        fontSize: 21,
        color: AppPalette.ink,
        letterSpacing: 0.3,
      ),
    ),
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppPalette.correct,
      brightness: Brightness.dark,
    ),
  );
}
