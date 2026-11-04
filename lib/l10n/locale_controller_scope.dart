import 'package:flutter/widgets.dart';

import 'locale_controller.dart';

class LocaleControllerScope extends InheritedNotifier<LocaleController> {
  const LocaleControllerScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LocaleControllerScope>()!
      .notifier!;

  static LocaleController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LocaleControllerScope>()
      ?.notifier;
}
