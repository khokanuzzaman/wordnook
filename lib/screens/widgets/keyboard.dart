import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';

class Keyboard extends StatelessWidget {
  final GameController controller;
  const Keyboard({super.key, required this.controller});

  static const _rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < _rows.length; r++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (r == 2) _key(context, 'ENTER', flex: 3),
              for (final ch in _rows[r].split('')) _key(context, ch),
              if (r == 2) _key(context, 'DEL', flex: 3),
            ],
          ),
      ],
    );
  }

  Widget _key(BuildContext context, String label, {int flex = 2}) {
    final status = controller.keyStatus[label];
    final color =
        status == null ? AppPalette.keyIdle : AppPalette.forStatus(status);
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            controller.onKey(label);
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
