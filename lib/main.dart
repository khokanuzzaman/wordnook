import 'dart:async';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/word_repository.dart';
import 'services/ads_service.dart';
import 'services/storage_service.dart';
import 'state/game_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  final words = WordRepository();
  await words.load();

  // Ads init is fire-and-forget so it doesn't block first paint.
  // Comment this out if running on a platform without AdMob configured yet.
  unawaited(AdsService.instance.init());

  final controller = GameController(words: words, storage: storage);

  runApp(WordGameApp(controller: controller));
}
