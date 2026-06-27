import 'package:flutter/material.dart';

import '../branding.dart';
import '../services/coin_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import 'how_to_play_sheet.dart';

/// Settings: difficulty, board themes, daily reminder, how-to-play, about.
class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final CoinService coins;
  const SettingsScreen({super.key, required this.storage, required this.coins});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StorageService get _storage => widget.storage;
  late final ThemeService _themes = ThemeService(_storage, widget.coins);

  late bool _reminderEnabled = _storage.reminderEnabled;
  late TimeOfDay _reminderTime =
      TimeOfDay(hour: _storage.reminderHour, minute: _storage.reminderMinute);
  late bool _hardMode = _storage.hardMode;

  Future<void> _onToggleHardMode(bool value) async {
    setState(() => _hardMode = value);
    await _storage.setHardMode(value);
  }

  Future<void> _onToggleReminder(bool value) async {
    setState(() => _reminderEnabled = value);
    await _storage.setReminderEnabled(value);
    if (value) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Enable notifications in system settings to get reminders.'),
          ),
        );
      }
      await NotificationService.instance.scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }
  }

  Future<void> _onPickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked == null) return;
    setState(() => _reminderTime = picked);
    await _storage.setReminderTime(picked.hour, picked.minute);
    if (_reminderEnabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  Future<void> _onTapTheme(GameTheme t) async {
    if (_themes.isUnlocked(t)) {
      await _themes.select(t.id);
      return;
    }
    final ok = await _themes.unlock(t.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Need ${t.cost} coins — play or watch to earn')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Game'),
          SwitchListTile(
            secondary: const Icon(Icons.fitness_center),
            title: const Text('Hard mode'),
            subtitle:
                const Text('Revealed hints must be used in later guesses.'),
            value: _hardMode,
            onChanged: _onToggleHardMode,
          ),
          const Divider(),
          const _SectionHeader('Board theme'),
          ListenableBuilder(
            listenable: Listenable.merge([_themes, widget.coins]),
            builder: (context, _) => Column(
              children: [
                for (final t in _themes.all)
                  _ThemeTile(
                    theme: t,
                    selected: _themes.isSelected(t),
                    unlocked: _themes.isUnlocked(t),
                    onTap: () => _onTapTheme(t),
                  ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Reminders'),
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle:
                const Text("A once-a-day nudge that the new puzzle is up."),
            value: _reminderEnabled,
            onChanged: _onToggleReminder,
          ),
          ListTile(
            enabled: _reminderEnabled,
            title: const Text('Reminder time'),
            subtitle: Text(_reminderTime.format(context)),
            trailing: const Icon(Icons.schedule),
            onTap: _reminderEnabled ? _onPickTime : null,
          ),
          const Divider(),
          ListTile(
            title: const Text('How to play'),
            trailing: const Icon(Icons.help_outline),
            onTap: () => HowToPlaySheet.show(context),
          ),
          const AboutListTile(
            applicationName: Branding.appName,
            applicationVersion: '0.1.0',
            aboutBoxChildren: [Text(Branding.appTagline)],
            icon: Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }
}

/// One row in the board-theme picker: swatches + select / unlock control.
class _ThemeTile extends StatelessWidget {
  final GameTheme theme;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    if (selected) {
      trailing = const Icon(Icons.check_circle, color: AppPalette.correct);
    } else if (unlocked) {
      trailing = const Text('Select', style: TextStyle(color: Colors.white70));
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on,
              size: 16, color: Color(0xFFF2C24B)),
          const SizedBox(width: 4),
          Text('${theme.cost}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Icon(Icons.lock_outline, size: 16, color: Colors.white54),
        ],
      );
    }

    return ListTile(
      onTap: onTap,
      leading: _Swatches(theme: theme),
      title: Text(theme.name),
      subtitle: theme.accessibility ? const Text('Accessibility') : null,
      trailing: trailing,
    );
  }
}

class _Swatches extends StatelessWidget {
  final GameTheme theme;
  const _Swatches({required this.theme});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [dot(theme.correct), dot(theme.present), dot(theme.absent)],
    );
  }
}

/// Small section label for grouping settings.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: AppPalette.correct,
        ),
      ),
    );
  }
}
