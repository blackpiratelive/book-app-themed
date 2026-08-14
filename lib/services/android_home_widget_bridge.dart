import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidHomeWidgetBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.blackpiratex.book/android_widget',
  );

  static Future<void> refreshReadingWidget() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('refreshReadingWidget');
    } on MissingPluginException {
      // Android platform scaffolding is generated in CI and may be absent locally.
    } catch (_) {
      // Widget refresh failures should never block normal app usage.
    }
  }
}
