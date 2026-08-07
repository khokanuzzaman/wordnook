import 'package:flutter/material.dart';

import '../../branding.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../about_screen.dart';
import '../how_to_play_screen.dart';
import '../settings_screen.dart';
import '../statistics_screen.dart';
import 'app_mark.dart';

/// Warm slide-in menu drawer (addendum §G). The navigation hub: Play (the
/// current screen), Statistics, Settings, How to play, About — plus a coin
/// footer. The built-in [Drawer] gives us the slide, scrim, swipe and
/// back-to-close for free, and it honours reduced motion.
class AppDrawer extends StatelessWidget {
  final GameController controller;
  const AppDrawer({super.key, required this.controller});

  void _go(BuildContext context, VoidCallback action) {
    Scaffold.of(context).closeDrawer();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.76;
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: width,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.92),
            radius: 1.15,
            colors: [
              AppPalette.drawerBgInner,
              AppPalette.drawerBgMid,
              AppPalette.drawerBgOuter,
            ],
            stops: [0.0, 0.6, 1.0],
          ),
          border: Border(
              right: BorderSide(color: AppPalette.chipBorder, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppMark(size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(Branding.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.fredoka(
                              fontSize: 22, color: AppPalette.ink)),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _MenuItem(
                  label: 'Play',
                  active: true,
                  onTap: () => Scaffold.of(context).closeDrawer(),
                ),
                _MenuItem(
                  label: 'Statistics',
                  onTap: () => _go(context,
                      () => StatisticsScreen.show(context, controller)),
                ),
                _MenuItem(
                  label: 'Settings',
                  onTap: () => _go(
                    context,
                    () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                              storage: controller.storage,
                              coins: controller.coinService),
                        )),
                  ),
                ),
                _MenuItem(
                  label: 'How to play',
                  onTap: () =>
                      _go(context, () => HowToPlayScreen.show(context)),
                ),
                _MenuItem(
                  label: 'About ${Branding.appName}',
                  onTap: () => _go(context, () => AboutScreen.show(context)),
                ),
                const Spacer(),
                _CoinCard(coins: controller.coins),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: active ? AppPalette.menuActiveFill : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: active ? const _ActiveDot() : null,
                ),
                Text(label,
                    style: AppType.nunito(
                        fontSize: 16,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w600,
                        color: active
                            ? AppPalette.ink
                            : AppPalette.menuInactiveText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppPalette.correct,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0x804F9B8E), blurRadius: 6, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

class _CoinCard extends StatelessWidget {
  final int coins;
  const _CoinCard({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppPalette.infoNoteFill,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppPalette.infoNoteBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppPalette.coinTop, AppPalette.coinBottom]),
            ),
          ),
          const SizedBox(width: 10),
          Text('$coins coins',
              style: AppType.fredoka(
                  fontSize: 14, color: AppPalette.coinsAmber)),
        ],
      ),
    );
  }
}
