/// Journey chip text for how many levels the player has finished.
///
/// [cleared] is a count of completed levels (the controller's current level
/// minus one), so a fresh install reads "No levels cleared yet". Pure and
/// testable.
String levelsClearedLabel(int cleared) {
  if (cleared <= 0) return 'No levels cleared yet';
  if (cleared == 1) return '1 level cleared';
  return '$cleared levels cleared';
}
