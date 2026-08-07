import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shared header for the secondary screens (addendum §B): a 40×40 back button
/// on the left, a centered Fredoka title, balanced by an equal spacer on the
/// right so the title stays optically centered.
class SecondaryHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  const SecondaryHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Row(
        children: [
          _BackButton(onTap: onBack ?? () => Navigator.of(context).maybePop()),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.fredoka(fontSize: 19, color: AppPalette.ink),
            ),
          ),
          const SizedBox(width: 40), // balances the back button
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppPalette.backBtnFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.chipBorder),
          ),
          child: const Icon(Icons.chevron_left,
              size: 24, color: AppPalette.iconStroke),
        ),
      ),
    );
  }
}
