import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// Owns the coin balance. A [ChangeNotifier] so the app bar (and anything else)
/// repaints when coins are earned or spent. Persistence is delegated to
/// [StorageService]; the balance math lives in CoinRules.
class CoinService extends ChangeNotifier {
  CoinService(this._storage);
  final StorageService _storage;

  int get coins => _storage.coins;

  bool canAfford(int cost) => coins >= cost;

  /// Adds [amount] coins (no-op for non-positive amounts).
  Future<void> award(int amount) async {
    if (amount <= 0) return;
    await _storage.setCoins(coins + amount);
    notifyListeners();
  }

  /// Deducts [amount] if affordable and returns true; otherwise returns false
  /// and changes nothing.
  Future<bool> trySpend(int amount) async {
    if (amount <= 0) return true;
    if (coins < amount) return false;
    await _storage.setCoins(coins - amount);
    notifyListeners();
    return true;
  }
}
