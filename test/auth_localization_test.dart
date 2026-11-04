import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailor_shop/auth/auth_text.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';

void main() {
  for (final locale in const [Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets('auth strings are localized for ${locale.languageCode}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('ps'), Locale('fa', 'AF')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            TailorShopCupertinoLocalizationsDelegate.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  Text(authText(context, 'loginTitle')),
                  Text(authText(context, 'recoveryTitle')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Owner sign in'), findsNothing);
      expect(find.text('Save your recovery code'), findsNothing);
      expect(
        find.text(
          authText(tester.element(find.byType(Scaffold)), 'loginTitle'),
        ),
        findsOneWidget,
      );
    });
  }
}
