import 'package:flutter/material.dart';

import '../branding.dart';
import '../services/analytics_service.dart';
import '../services/coin_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'how_to_play_screen.dart';
import 'widgets/cozy_background.dart';
import 'widgets/secondary_header.dart';

/// Settings (addendum §D): difficulty, board themes, daily reminder, and links
/// to How-to-play / About — restyled to the warm system. Presentation only:
/// every toggle and the theme unlock/select flow keep their original handlers.
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
    AnalyticsService.instance.logEvent(
        AnalyticsEvents.hardModeToggled, {AnalyticsParams.enabled: value});
  }

  Future<void> _onToggleReminder(bool value) async {
    setState(() => _reminderEnabled = value);
    await _storage.setReminderEnabled(value);
    AnalyticsService.instance.logEvent(value
        ? AnalyticsEvents.reminderEnabled
        : AnalyticsEvents.reminderDisabled);
    AnalyticsService.instance.syncReminder(value);
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
    return CozyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              const SecondaryHeader(title: 'Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    const _Eyebrow('Game'),
                    const SizedBox(height: 10),
                    _GroupedCard(children: [
                      _ToggleRow(
                        title: 'Hard mode',
                        subtitle: 'Revealed hints must be reused.',
                        value: _hardMode,
                        onChanged: _onToggleHardMode,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    const _Eyebrow('Board theme'),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: Listenable.merge([_themes, widget.coins]),
                      builder: (context, _) => _ThemeGrid(
                        themes: _themes.all,
                        isSelected: _themes.isSelected,
                        isUnlocked: _themes.isUnlocked,
                        onTap: _onTapTheme,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _Eyebrow('Reminders'),
                    const SizedBox(height: 10),
                    _GroupedCard(children: [
                      _ToggleRow(
                        title: 'Daily reminder',
                        subtitle: 'A gentle nudge for the new word.',
                        value: _reminderEnabled,
                        onChanged: _onToggleReminder,
                      ),
                      const _RowDivider(),
                      _TimeRow(
                        enabled: _reminderEnabled,
                        time: _reminderTime,
                        onTap: _onPickTime,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _LinkRow(
                      label: 'How to play',
                      onTap: () => HowToPlayScreen.show(context),
                    ),
                    const SizedBox(height: 12),
                    _LinkRow(
                      label: 'About ${Branding.appName}',
                      onTap: () => AboutScreen.show(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uppercase amber section label (addendum §A).
class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(text.toUpperCase(),
          style: AppType.nunito(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppPalette.dailyKicker)),
    );
  }
}

/// A surface card that groups one or more rows (addendum §D).
class _GroupedCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupedCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.chipFill,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppPalette.chipBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppPalette.chipBorder);
}

/// A title + subtitle row with a trailing cozy toggle.
class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppType.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        AppType.nunito(fontSize: 12, color: AppPalette.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CozyToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// The 46×27 warm toggle (addendum §D). Honours reduced motion.
class _CozyToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CozyToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dur = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      toggled: value,
      container: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: dur,
          width: 46,
          height: 27,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppPalette.correct : AppPalette.toggleOffTrack,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: value
                    ? AppPalette.toggleOnBorder
                    : AppPalette.toggleOffBorder),
          ),
          child: AnimatedAlign(
            duration: dur,
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 21,
              height: 21,
              decoration: const BoxDecoration(
                color: AppPalette.toggleKnob,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 3,
                      offset: Offset(0, 1))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reminder-time row inside the reminders card; dims + disables when the
/// reminder toggle is off (addendum §D).
class _TimeRow extends StatelessWidget {
  final bool enabled;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeRow(
      {required this.enabled, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      key: const Key('reminder-time-dim'),
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Text('Reminder time',
                    style: AppType.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.ink)),
              ),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppPalette.timePillFill,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppPalette.coinPillBorder),
                  ),
                  child: Text(time.format(context),
                      style: AppType.fredoka(
                          fontSize: 14, color: AppPalette.coinsAmber)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A standalone tappable link row with a trailing chevron (addendum §D).
class _LinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: AppPalette.chipFill,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppPalette.chipBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: AppType.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.ink)),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppPalette.absentGlyph),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three-column grid of board-theme swatches. Prices, lock and selected states
/// come straight from [ThemeService] — the real app values, not the mockup's.
class _ThemeGrid extends StatelessWidget {
  final List<GameTheme> themes;
  final bool Function(GameTheme) isSelected;
  final bool Function(GameTheme) isUnlocked;
  final void Function(GameTheme) onTap;
  const _ThemeGrid({
    required this.themes,
    required this.isSelected,
    required this.isUnlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final itemW = ((c.maxWidth - gap * 2) / 3).floorToDouble();
      return Wrap(
        spacing: gap,
        runSpacing: 14,
        children: [
          for (final t in themes)
            SizedBox(
              width: itemW,
              child: _ThemeSwatch(
                theme: t,
                selected: isSelected(t),
                unlocked: isUnlocked(t),
                onTap: () => onTap(t),
              ),
            ),
        ],
      );
    });
  }
}

class _ThemeSwatch extends StatelessWidget {
  final GameTheme theme;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  static List<Color> _bg(Color base) {
    final hsl = HSLColor.fromColor(base);
    return [
      hsl.withLightness((hsl.lightness + 0.04).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - 0.03).clamp(0.0, 1.0)).toColor(),
    ];
  }

  static List<Color> _mini(Color base) {
    final hsl = HSLColor.fromColor(base);
    return [
      hsl.withLightness((hsl.lightness + 0.055).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - 0.055).clamp(0.0, 1.0)).toColor(),
    ];
  }

  Widget _miniTile(Color base) => Container(
        width: 15,
        height: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _mini(base)),
          borderRadius: BorderRadius.circular(5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final locked = !unlocked;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            children: [
              Opacity(
                opacity: locked ? 0.72 : 1,
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _bg(theme.absent)),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: selected
                            ? AppPalette.swatchSelBorder
                            : AppPalette.swatchBorder,
                        width: selected ? 1.5 : 1),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                                color: AppPalette.swatchSelGlow, blurRadius: 14)
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniTile(theme.correct),
                      const SizedBox(width: 6),
                      _miniTile(theme.present),
                    ],
                  ),
                ),
              ),
              if (selected)
                const Positioned(top: 6, right: 6, child: _CheckBadge()),
              if (locked)
                Positioned(top: 6, right: 6, child: _PriceTag(cost: theme.cost)),
            ],
          ),
          const SizedBox(height: 6),
          Text(theme.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? AppPalette.swatchSelLabel : AppPalette.muted)),
        ],
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppPalette.lockPillFill,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, size: 14, color: AppPalette.correct),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final int cost;
  const _PriceTag({required this.cost});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppPalette.lockPillFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 10, color: AppPalette.coinsAmber),
          const SizedBox(width: 3),
          Text('$cost',
              style: AppType.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.coinsAmber)),
        ],
      ),
    );
  }
}
