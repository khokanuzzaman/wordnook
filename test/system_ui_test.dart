import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_word_game/system_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bars are transparent with light icons (dark-only app)', () {
    const s = edgeToEdgeOverlayStyle;
    expect(s.statusBarColor, Colors.transparent);
    expect(s.systemNavigationBarColor, Colors.transparent);
    expect(s.systemNavigationBarDividerColor, Colors.transparent);
    expect(s.statusBarIconBrightness, Brightness.light);
    expect(s.systemNavigationBarIconBrightness, Brightness.light);
    expect(s.systemNavigationBarContrastEnforced, isFalse);
  });

  test('enableEdgeToEdge asks the platform for edge-to-edge mode', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await enableEdgeToEdge();

    final mode = calls.firstWhere(
        (c) => c.method == 'SystemChrome.setEnabledSystemUIMode');
    expect(mode.arguments, 'SystemUiMode.edgeToEdge');
  });
}
