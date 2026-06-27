import 'package:flutter/material.dart';

import '../branding.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'how_to_play_sheet.dart';

/// Settings: daily-reminder toggle + time, how-to-play, and about info.
class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  const SettingsScreen({super.key, required this.storage});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StorageService get _storage => widget.storage;

  late bool _reminderEnabled = _storage.reminderEnabled;
  late TimeOfDay _reminderTime =
      TimeOfDay(hour: _storage.reminderHour, minute: _storage.reminderMinute);
  late bool _hardMode = _storage.hardMode;
  late bool _highContrast = _storage.highContrast;

  Future<void> _onToggleHardMode(bool value) async {
    setState(() => _hardMode = value);
    await _storage.setHardMode(value);
  }

  Future<void> _onToggleHighContrast(bool value) async {
    setState(() => _highContrast = value);
    await _storage.setHighContrast(value);
    AppPalette.highContrast.value = value; // repaints the board live
  }

  Future<void> _onToggleReminder(bool value) async {
    setState(() => _reminderEnabled = value);
    await _storage.setReminderEnabled(value);
    if (value) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable notifications in system settings to get reminders.'),
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
            subtitle: const Text('Revealed hints must be used in later guesses.'),
            value: _hardMode,
            onChanged: _onToggleHardMode,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.contrast),
            title: const Text('High-contrast colours'),
            subtitle: const Text('Colour-blind-friendly blue / orange tiles.'),
            value: _highContrast,
            onChanged: _onToggleHighContrast,
          ),
          const Divider(),
          const _SectionHeader('Reminders'),
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: const Text("A once-a-day nudge that the new puzzle is up."),
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
