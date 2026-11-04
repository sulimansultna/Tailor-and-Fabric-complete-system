import 'package:flutter/material.dart';

import '../generated/app_localizations.dart';
import '../locale_controller.dart';
import '../locale_controller_scope.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = LocaleControllerScope.maybeOf(context);
    final current =
        controller?.locale ??
        LocaleController.parse(Localizations.localeOf(context).toLanguageTag());
    final l10n = AppLocalizations.of(context)!;
    return DropdownButtonFormField<String>(
      initialValue: current.toLanguageTag(),
      decoration: InputDecoration(
        labelText: compact ? null : l10n.selectLanguage,
        prefixIcon: const Icon(Icons.translate),
      ),
      items: [
        for (final locale in LocaleController.supportedLocales)
          DropdownMenuItem(
            value: locale.toLanguageTag(),
            child: Text(LocaleController.nativeName(locale)),
          ),
      ],
      onChanged: (tag) {
        if (tag == null) return;
        final locale = LocaleController.parse(tag);
        controller?.setLocale(locale);
      },
    );
  }
}
