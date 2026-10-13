import 'package:share_plus/share_plus.dart';

import '../../services/analytics_service.dart';
import '../../state/game_controller.dart';

/// Shares the current result (our emoji grid + store link) and logs it. One
/// path for every Share button, so analytics stay consistent.
void shareResult(GameController controller, {required String from}) {
  final text = controller.shareText;
  if (text == null) return;
  AnalyticsService.instance.logEvent(AnalyticsEvents.shareResult, {
    AnalyticsParams.mode: controller.mode.name,
    AnalyticsParams.source: from,
  });
  SharePlus.instance.share(ShareParams(text: text));
}
