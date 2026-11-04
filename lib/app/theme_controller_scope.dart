import 'package:flutter/widgets.dart';

import 'theme_controller.dart';

class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ThemeControllerScope>()!
      .notifier!;
}
