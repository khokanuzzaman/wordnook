/// A themed set of answer words for Journey mode. Packs let us ship themed
/// content (e.g. "Everyday", "Nature", "Food") and unlock more later via
/// rewarded ad / IAP. [answers] is the play order for the pack's levels.
class WordPack {
  final String id;
  final String name;
  final List<String> answers;

  const WordPack({
    required this.id,
    required this.name,
    required this.answers,
  });

  int get length => answers.length;

  /// The answer for a 1-based [level], wrapping around if the pack is exhausted.
  String wordForLevel(int level) {
    if (answers.isEmpty) return '';
    final i = (level - 1) % answers.length;
    return answers[i < 0 ? i + answers.length : i];
  }
}
