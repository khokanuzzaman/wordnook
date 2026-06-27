import 'package:flutter/foundation.dart';

import '../theme/app_theme.dart';
import 'coin_service.dart';
import 'storage_service.dart';

/// Owns board-theme selection and coin-unlocks. Storage-backed (no in-memory
/// state beyond what it reads), and applies the active theme to
/// [AppPalette.selectedTheme] so the board repaints.
class ThemeService extends ChangeNotifier {
  ThemeService(this._storage, this._coins);
  final StorageService _storage;
  final CoinService _coins;

  List<GameTheme> get all => ThemeRegistry.all;
  String get selectedId => _storage.selectedThemeId;

  bool isUnlocked(GameTheme t) =>
      t.cost == 0 || _storage.unlockedThemes.contains(t.id);
  bool isSelected(GameTheme t) => t.id == selectedId;

  /// Pushes the persisted selection into the live palette. Call once at startup.
  void applySelected() {
    AppPalette.selectedTheme.value = ThemeRegistry.byId(selectedId);
  }

  /// Selects an already-unlocked theme.
  Future<void> select(String id) async {
    final t = ThemeRegistry.byId(id);
    if (!isUnlocked(t)) return;
    await _storage.setSelectedThemeId(id);
    AppPalette.selectedTheme.value = t;
    notifyListeners();
  }

  /// Spends coins to unlock [id]; on success also selects it. Returns false if
  /// the player can't afford it (nothing changes).
  Future<bool> unlock(String id) async {
    final t = ThemeRegistry.byId(id);
    if (isUnlocked(t)) {
      await select(id);
      return true;
    }
    if (!await _coins.trySpend(t.cost)) return false;
    await _storage.addUnlockedTheme(id);
    await select(id);
    return true;
  }
}
