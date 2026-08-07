import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// The rounded "W" brand mark (addendum §F / §G). Shared by the About screen
/// and the menu-drawer header, sized by [size].
class AppMark extends StatelessWidget {
  final double size;
  const AppMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C2620), Color(0xFF211C17)],
        ),
        borderRadius: BorderRadius.circular(size * 0.29),
        border: Border.all(color: AppPalette.coinPillBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Text('W',
          style: AppType.fredoka(
              fontSize: size * 0.53, color: AppPalette.present)),
    );
  }
}
