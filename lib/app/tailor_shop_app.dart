import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../commands/app_commands.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_screens.dart';

import '../data/shop_database.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../l10n/locale_controller_scope.dart';
import '../l10n/pashto_cupertino_localizations.dart';
import '../screens/setup/setup_screen.dart';
import '../screens/shell/main_shell.dart';
import 'app_theme.dart';
import 'theme_controller.dart';
import 'theme_controller_scope.dart';

class TailorShopApp extends StatefulWidget {
  const TailorShopApp({
    super.key,
    required this.database,
    required this.authController,
  });
  final ShopDatabase database;
  final AuthController authController;

  @override
  State<TailorShopApp> createState() => _TailorShopAppState();
}

class _TailorShopAppState extends State<TailorShopApp>
    with WidgetsBindingObserver {
  late final LocaleController localeController;
  late final ThemeController themeController;
  late Future<Map<String, Object?>> settingsFuture;
  late Future<void> themeReadyFuture;
  bool _reduceMotion = false;
  String _appName = 'KhayatPro';
  final commands = AppCommandRegistry();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    localeController = LocaleController(widget.database);
    themeController = ThemeController(widget.database);
    settingsFuture = widget.database.settings();
    themeReadyFuture = themeController.load(settingsFuture);
    settingsFuture.then((settings) {
      final name = settings['shop_name']?.toString().trim();
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => _appName = name);
      }
    });
    localeController.load(settingsFuture);
    widget.authController.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    localeController.dispose();
    themeController.dispose();
    commands.dispose();
    widget.authController.dispose();
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (_reduceMotion == reduceMotion) return;
    setState(() => _reduceMotion = reduceMotion);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([localeController, themeController]),
    builder: (context, _) => LocaleControllerScope(
      controller: localeController,
      child: ThemeControllerScope(
        controller: themeController,
        child: MaterialApp(
          navigatorObservers: [commands.observer],
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(reduceMotion: _reduceMotion),
          darkTheme: buildDarkAppTheme(reduceMotion: _reduceMotion),
          themeMode: themeController.themeMode,
          themeAnimationDuration: _reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 250),
          themeAnimationCurve: Curves.easeInOut,
          locale: localeController.locale,
          builder: (context, child) => AppCommandHost(
            registry: commands,
            child: Directionality(
            // Flutter's built-in locale data does not provide Pashto direction
            // on every supported platform. Keep the app direction tied to the
            // selected language so the entire shell (including dialogs) follows.
            textDirection:
                const {
                  'fa',
                  'ps',
                }.contains(localeController.locale.languageCode)
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
            ),
          ),
          supportedLocales: LocaleController.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            TailorShopCupertinoLocalizationsDelegate.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: FutureBuilder<void>(
            future: themeReadyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return AnimatedBuilder(
                animation: widget.authController,
                builder: (context, _) => _authHome(),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _authHome() {
    switch (widget.authController.state) {
      case AuthViewState.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthViewState.signedOut:
        return LoginScreen(
          controller: widget.authController,
          appName: _appName,
        );
      case AuthViewState.initialPasswordChange:
        return InitialPasswordScreen(controller: widget.authController);
      case AuthViewState.recoveryCodeSetup:
        return RecoveryCodeScreen(controller: widget.authController);
      case AuthViewState.signedIn:
        return FutureBuilder<Map<String, Object?>>(
          future: settingsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return (snapshot.data!['shop_name'] == null)
                ? SetupScreen(
                    database: widget.database,
                    onSetupComplete: _refreshSettings,
                  )
                : MainShell(
                    database: widget.database,
                    shopName: snapshot.data!['shop_name'] as String,
                    authController: widget.authController,
                    onBusinessRestored: () async {
                      await localeController.reloadFromDatabase();
                      await themeController.reloadFromDatabase();
                      await _refreshSettings();
                      await widget.authController.logout();
                    },
                  );
          },
        );
    }
  }

  Future<void> _refreshSettings() async {
    final settings = await widget.database.settings();
    final name = settings['shop_name']?.toString().trim();
    if (!mounted) return;
    setState(() {
      settingsFuture = Future.value(settings);
      _appName = name == null || name.isEmpty ? 'KhayatPro' : name;
    });
  }
}
