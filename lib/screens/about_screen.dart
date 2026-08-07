import 'package:flutter/material.dart';

import '../branding.dart';
import '../theme/app_theme.dart';
import 'widgets/app_mark.dart';
import 'widgets/cozy_background.dart';
import 'widgets/secondary_header.dart';

/// About (addendum §F): a warm full screen — the "W" mark, the app name +
/// version, the cozy positioning blurb, and a quiet footer note.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AboutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return CozyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              const SecondaryHeader(title: 'About'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    const SizedBox(height: 8),
                    const Center(child: AppMark(size: 76)),
                    const SizedBox(height: 20),
                    Text(Branding.appName,
                        textAlign: TextAlign.center,
                        style: AppType.fredoka(
                            fontSize: 26, color: AppPalette.ink)),
                    const SizedBox(height: 4),
                    Text('Version ${Branding.version}',
                        textAlign: TextAlign.center,
                        style: AppType.nunito(
                            fontSize: 13, color: AppPalette.muted)),
                    const SizedBox(height: 22),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          Branding.appDescription,
                          textAlign: TextAlign.center,
                          style: AppType.nunito(
                              fontSize: 15,
                              color: AppPalette.chipText,
                              height: 1.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Text('Made with care for quiet evenings.',
                    style: AppType.nunito(
                        fontSize: 12, color: AppPalette.faint)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
