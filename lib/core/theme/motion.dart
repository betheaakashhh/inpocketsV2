import 'package:flutter/animation.dart';

/// Every animation in the app pulls its timing from here. Keeping motion
/// on a shared scale is what makes an app *feel* designed rather than
/// assembled from defaults — a fast micro-interaction (button press) and
/// a slow macro one (screen transition) should always be in proportion.
class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 360);
  static const Duration slow = Duration(milliseconds: 560);
  static const Duration deliberate = Duration(milliseconds: 900);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuint;
  static const Curve spring = Curves.elasticOut;
  static const Curve bounceIn = Curves.easeOutBack;
  static const Curve sharp = Curves.easeInOutCubic;
}
