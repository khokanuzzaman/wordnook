import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Draws the app behind transparent status and navigation bars on every
/// Android version, not only on Android 15+ where it is enforced (Play
/// Console: "Edge-to-edge may not display for all users"). Screens already
/// wrap their content in [SafeArea], so nothing ends up under the bars.
/// The app is dark-only, so the bar icons are always light.
Future<void> enableEdgeToEdge() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(edgeToEdgeOverlayStyle);
}

/// Bar style used with [enableEdgeToEdge]. Transparent colors only matter
/// below Android 15; from Android 15 the system ignores bar colors.
const edgeToEdgeOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);
