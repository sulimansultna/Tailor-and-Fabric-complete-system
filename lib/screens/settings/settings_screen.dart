import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../app/theme_controller.dart';
import '../../app/theme_controller_scope.dart';
import '../../data/shop_database.dart';
import '../../data/backup_service.dart';
import '../../core/windows_image_picker.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/widgets/language_selector.dart';
import '../../core/calendar_service.dart';
import '../../l10n/locale_controller_scope.dart';
import '../../l10n/locale_controller.dart';
import 'shop_profile_screen.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_screens.dart';
import '../../auth/auth_text.dart';
import '../../widgets/shop_logo.dart';
import '../../reports/order_document_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.database,
    required this.authController,
    this.onShopNameChanged,
    this.onDataRestored,
    this.onOperationBusyChanged,
  });
  final ShopDatabase database;
  final AuthController authController;
  final ValueChanged<String>? onShopNameChanged;
  final Future<void> Function()? onDataRestored;
  final ValueChanged<bool>? onOperationBusyChanged;

  @override
  State<SettingsScreen> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsScreen> {
  late Future<Map<String, Object?>> future;
  Map<String, dynamic> backupPrefs = {};
  Map<String, dynamic>? restorePreview;
  String? restorePath;
  bool backupBusy = false;
  String? backupStep;
  List<Printer> printers = [];
  bool printersLoading = false;
  final _backupKey = GlobalKey();
  final _languageKey = GlobalKey();
  final _themeKey = GlobalKey();
  final _printingKey = GlobalKey();
  final _profileKey = GlobalKey();

  Future<void> _showSection(GlobalKey key) async {
    final section = key.currentContext;
    if (section != null) await Scrollable.ensureVisible(section, duration: const Duration(milliseconds: 200), alignment: .1);
  }

  List<AppCommand> _keyboardCommands() => [
    AppCommand('nav.backup', () => _showSection(_backupKey)),
    AppCommand('settings.language', () => _showSection(_languageKey)),
    AppCommand('settings.calendar', () => _showSection(_languageKey)),
    AppCommand('settings.theme', () => _showSection(_themeKey)),
    AppCommand('settings.printing', () => _showSection(_printingKey)),
    AppCommand('settings.profile', () => _showSection(_profileKey)),
    AppCommand('settings.backup', _createBackup, disabledReason: () => backupBusy || backupPrefs['folder'] == null
      ? localizedCommandText(context, 'Choose a backup folder first, and wait for any current backup operation.', 'لومړی د بیک اپ فولډر وټاکئ.', 'ابتدا پوشه پشتیبان را انتخاب کنید و منتظر پایان عملیات جاری بمانید.') : null),
    AppCommand('settings.restore', _chooseBackupFile, disabledReason: () => backupBusy ? _tr('processing') : null),
    AppCommand('settings.signOut', () async {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountSecurityScreen(controller: widget.authController)));
      final registry = AppCommandRegistry.maybeOf(context);
      if (registry != null) await registry.forward(() async {}, 'settings.signOut');
    }),
    AppCommand(CommandKey.refresh, () async { final next = widget.database.settings(); setState(() => future = next); await next; }),
  ];

  @override
  void initState() {
    super.initState();
    future = widget.database.settings();
    BackupService.preferences().then((value) {
      if (mounted) setState(() => backupPrefs = value);
    });
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    if (mounted) setState(() => printersLoading = true);
    try {
      final result = await Printing.listPrinters();
      if (mounted) setState(() => printers = result);
    } catch (error) {
      debugPrint('Printer list unavailable: $error');
      if (mounted) setState(() => printers = []);
    } finally {
      if (mounted) setState(() => printersLoading = false);
    }
  }

  Future<void> _saveOrderPrintSetting(String key, String value) async {
    try {
      await widget.database.saveSettings({key: value});
      if (mounted) setState(() => future = widget.database.settings());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.errorGeneric}: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<Map<String, Object?>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_outlined, size: 38),
                  const SizedBox(height: 12),
                  Text(
                    l10n.settingsLoadError,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () =>
                        setState(() => future = widget.database.settings()),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: Text(l10n.settingsNoData));
        }
        final settings = snapshot.data!;
        final calendarController = LocaleControllerScope.of(context);
        final themeController = ThemeControllerScope.of(context);
        return CommandScope(commands: _keyboardCommands(), builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 940;
            return Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.settings,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(l10n.settingsPageSubtitle),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.refresh,
                              onPressed: () => setState(
                                () => future = widget.database.settings(),
                              ),
                              icon: const Icon(Icons.refresh_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _sectionPair(
                          context,
                          wide,
                          _accountSection(context, l10n),
                          KeyedSubtree(key: _profileKey, child: _shopProfileSection(context, settings, l10n)),
                        ),
                        const SizedBox(height: 18),
                        _sectionPair(
                          context,
                          wide,
                          KeyedSubtree(key: _themeKey, child: _appearanceSection(context, themeController, l10n)),
                          KeyedSubtree(key: _languageKey, child: _languageCalendarSection(
                            context,
                            calendarController,
                            l10n,
                          )),
                        ),
                        const SizedBox(height: 18),
                        _sectionPair(
                          context,
                          wide,
                          _paymentsSection(context, settings, l10n),
                          _applicationInfoSection(context, l10n),
                        ),
                        const SizedBox(height: 18),
                        KeyedSubtree(key: _printingKey, child: _orderPrintingSection(context, settings, l10n)),
                        const SizedBox(height: 18),
                        KeyedSubtree(key: _backupKey, child: _backupRestoreCard(context, l10n)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ));
      },
    );
  }

  Widget _sectionPair(
    BuildContext context,
    bool wide,
    Widget first,
    Widget second,
  ) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, const SizedBox(height: 18), second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 18),
        Expanded(child: second),
      ],
    );
  }

  Widget _accountSection(BuildContext context, AppLocalizations l10n) =>
      _SettingsSection(
        icon: Icons.shield_outlined,
        title: l10n.settingsAccountSecurity,
        description: l10n.settingsAccountSecurityDescription,
        child: _settingsRow(
          context,
          icon: Icons.person_outline,
          title: authText(context, 'username'),
          value: widget.authController.username,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AccountSecurityScreen(controller: widget.authController),
            ),
          ),
        ),
      );

  Widget _shopProfileSection(
    BuildContext context,
    Map<String, Object?> settings,
    AppLocalizations l10n,
  ) {
    final shopName = (settings['shop_name'] as String? ?? '').trim();
    final phone = (settings['phone'] as String? ?? '').trim();
    final owner = (settings['owner_name'] as String? ?? '').trim();
    final address = (settings['address'] as String? ?? '').trim();
    final details = [
      owner,
      phone,
      address,
    ].where((value) => value.isNotEmpty).join(' · ');
    return _SettingsSection(
      icon: Icons.storefront_outlined,
      title: l10n.settingsShopProfileSection,
      description: l10n.settingsShopProfileDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShopLogo(path: settings['shop_logo_path'] as String?, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName.isEmpty ? l10n.shopName : shopName,
                      maxLines: 3,
                      softWrap: true,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(details, softWrap: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ShopProfileScreen(
                    database: widget.database,
                    onShopNameChanged: widget.onShopNameChanged,
                  ),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.settingsEditShopProfile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appearanceSection(
    BuildContext context,
    ThemeController controller,
    AppLocalizations l10n,
  ) => _SettingsSection(
    icon: Icons.palette_outlined,
    title: l10n.settingsAppearance,
    description: l10n.settingsAppearanceDescription,
    child: Column(
      children: [
        _ThemePreviewTile(
          mode: ThemeMode.light,
          title: l10n.settingsLightMode,
          description: l10n.settingsLightModeDescription,
          selected: controller.themeMode == ThemeMode.light,
          busy: controller.isSaving,
          onTap: () => _selectTheme(controller, ThemeMode.light),
        ),
        const SizedBox(height: 10),
        _ThemePreviewTile(
          mode: ThemeMode.dark,
          title: l10n.settingsDarkMode,
          description: l10n.settingsDarkModeDescription,
          selected: controller.themeMode == ThemeMode.dark,
          busy: controller.isSaving,
          onTap: () => _selectTheme(controller, ThemeMode.dark),
        ),
      ],
    ),
  );

  Future<void> _selectTheme(ThemeController controller, ThemeMode mode) async {
    try {
      await controller.setThemeMode(mode);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsThemeSaveError('$error'))),
      );
    }
  }

  Widget _languageCalendarSection(
    BuildContext context,
    LocaleController controller,
    AppLocalizations l10n,
  ) => _SettingsSection(
    icon: Icons.language_outlined,
    title: l10n.settingsLanguageCalendar,
    description: l10n.settingsLanguageCalendarDescription,
    child: Column(
      children: [
        const LanguageSelector(),
        const SizedBox(height: 12),
        _DateCalendarSettings(controller: controller),
      ],
    ),
  );

  Widget _paymentsSection(
    BuildContext context,
    Map<String, Object?> settings,
    AppLocalizations l10n,
  ) => _SettingsSection(
    icon: Icons.payments_outlined,
    title: l10n.settingsPaymentsReceipts,
    description: l10n.settingsPaymentsReceiptsDescription,
    child: Column(
      children: [
        _settingsRow(
          context,
          icon: Icons.payments_outlined,
          title: l10n.settingsPaymentMethods,
          value:
              (settings['payment_methods'] as String?) ??
              'Cash, Bank transfer, Other',
          actionLabel: l10n.edit,
          onTap: () => _editPaymentMethods(settings),
        ),
        _settingsRow(
          context,
          icon: Icons.receipt_long_outlined,
          title: l10n.receiptFooter,
          value:
              (settings['receipt_footer'] as String?)?.trim().isNotEmpty == true
              ? settings['receipt_footer'] as String
              : '—',
          description: l10n.settingsReceiptFooterDescription,
        ),
        _settingsRow(
          context,
          icon: Icons.currency_exchange_outlined,
          title: l10n.currency,
          value: (settings['currency'] as String?)?.trim().isNotEmpty == true
              ? settings['currency'] as String
              : 'AFN',
          description: l10n.settingsCurrencyDescription,
          showDivider: false,
        ),
      ],
    ),
  );

  Widget _applicationInfoSection(BuildContext context, AppLocalizations l10n) =>
      _SettingsSection(
        icon: Icons.info_outline,
        title: l10n.settingsApplicationInformation,
        description: l10n.settingsApplicationInformationDescription,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _settingsRow(
              context,
              icon: Icons.computer_outlined,
              title: l10n.settingsDataStoredLocally,
              value: '',
              showDivider: false,
            ),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .08),
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune_outlined),
                title: Text(l10n.settingsAdvanced),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.settingsDatabasePath,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                  _PathField(
                    path: widget.database.db.path,
                    tooltip: l10n.settingsCopyPathTooltip,
                    onCopy: () => _copyPath(widget.database.db.path),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _orderPrintingSection(
    BuildContext context,
    Map<String, Object?> settings,
    AppLocalizations l10n,
  ) => _SettingsSection(
    icon: Icons.print_outlined,
    title: l10n.orderPrintingSettings,
    description: l10n.orderPrintingSettingsDescription,
    child: Column(
      children: [
        _printerSetting(
          context,
          settings,
          title: l10n.measurementPrinter,
          printerKey: orderMeasurementPrinterSetting,
          paperKey: orderMeasurementPaperSetting,
          papers: {'55mm': l10n.paper55mm},
          defaultPaper: '55mm',
          l10n: l10n,
        ),
        const SizedBox(height: 14),
        _printerSetting(
          context,
          settings,
          title: l10n.customerBillPrinter,
          printerKey: orderBillPrinterSetting,
          paperKey: orderBillPaperSetting,
          papers: {'55mm': l10n.paper55mm},
          defaultPaper: '55mm',
          l10n: l10n,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: printersLoading ? null : _loadPrinters,
            icon: printersLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(l10n.refreshPrinters),
          ),
        ),
      ],
    ),
  );

  Widget _printerSetting(
    BuildContext context,
    Map<String, Object?> settings, {
    required String title,
    required String printerKey,
    required String paperKey,
    required Map<String, String> papers,
    required String defaultPaper,
    required AppLocalizations l10n,
  }) {
    final savedPrinter = settings[printerKey]?.toString() ?? '';
    final printerOptions = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: '', child: Text(l10n.defaultPrinter)),
      for (final printer in printers)
        DropdownMenuItem(value: printer.url, child: Text(printer.name)),
      if (savedPrinter.isNotEmpty &&
          !printers.any((printer) => printer.url == savedPrinter))
        DropdownMenuItem(value: savedPrinter, child: Text(savedPrinter)),
    ];
    final storedPaper = settings[paperKey]?.toString();
    final savedPaper = papers.containsKey(storedPaper)
        ? storedPaper!
        : defaultPaper;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final printerField = DropdownButtonFormField<String>(
                  key: ValueKey('$printerKey:$savedPrinter'),
                  initialValue: savedPrinter,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: title),
                  items: printerOptions,
                  onChanged: (value) {
                    if (value != null) {
                      _saveOrderPrintSetting(printerKey, value);
                    }
                  },
                );
                final paperField = DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('$paperKey:$savedPaper'),
                  initialValue: papers.containsKey(savedPaper)
                      ? savedPaper
                      : defaultPaper,
                  decoration: InputDecoration(labelText: l10n.paperSize),
                  items: [
                    for (final entry in papers.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) _saveOrderPrintSetting(paperKey, value);
                  },
                );
                if (narrow) {
                  return Column(
                    children: [
                      printerField,
                      const SizedBox(height: 10),
                      paperField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: printerField),
                    const SizedBox(width: 12),
                    SizedBox(width: 210, child: paperField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    String? description,
    String? actionLabel,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Semantics(
          button: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (value.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(value, softWrap: true),
                        ],
                        if (description != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actionLabel != null)
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: Text(actionLabel),
                    )
                  else if (onTap != null)
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left
                          : Icons.chevron_right,
                      color: colors.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: .7),
          ),
      ],
    );
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.settingsPathCopied)),
    );
  }

  String _tr(String key) {
    final lang = Localizations.localeOf(context).languageCode;
    const en = {
      'title': 'Backup & Restore',
      'backup': 'Backup',
      'restore': 'Restore',
      'location': 'Backup location',
      'chooseFolder': 'Choose folder',
      'create': 'Create backup',
      'last': 'Last successful backup',
      'openFolder': 'Open backup folder',
      'chooseFile': 'Choose backup file',
      'restoreNow': 'Restore backup',
      'replace': 'Restoring replaces the current shop data with this backup. It does not merge databases.',
      'confirm': 'Confirm restore',
      'cancel': 'Cancel',
      'success': 'Backup created successfully.',
      'restored': 'Backup restored. Sign in again to continue.',
      'sameDevice': 'A backup stored on this device does not protect against device loss. Choose a USB drive or another safe location.',
      'preview': 'Backup information',
      'created': 'Created',
      'shop': 'Shop',
      'appVersion': 'App version',
      'missingAssets': 'Missing referenced files',
      'missingCleared':
          'Missing files were excluded and their paths cleared: {count}',
      'schema': 'Database schema',
      'attachments': 'Attachments',
      'valid': 'Validated',
      'processing': 'Working…',
      'error': 'Backup or restore failed',
      'notSelected': 'No folder selected',
      'restoring': 'Restoring…',
      'backupStep': 'Creating consistent database snapshot…',
      'retry': 'Retry',
    };
    const ps = {
      'title': 'شاتړ او بېرته راګرځول',
      'backup': 'شاتړ',
      'restore': 'بېرته راګرځول',
      'location': 'د شاتړ ځای',
      'chooseFolder': 'پوښۍ وټاکئ',
      'create': 'شاتړ جوړ کړئ',
      'last': 'وروستی بریالی شاتړ',
      'openFolder': 'د شاتړ پوښۍ پرانیزئ',
      'chooseFile': 'د شاتړ فایل وټاکئ',
      'restoreNow': 'شاتړ بېرته راولئ',
      'replace': 'بېرته راګرځول د اوسني دوکان معلومات له دې شاتړ سره بدلوي؛ دواړه ډیټابېسونه نه یوځای کوي.',
      'confirm': 'بېرته راګرځول تایید کړئ',
      'cancel': 'لغوه',
      'success': 'شاتړ په بریالیتوب جوړ شو.',
      'restored': 'شاتړ بېرته راوګرځول شو. د دوام لپاره بیا ننوزئ.',
      'sameDevice': 'په همدې وسیله کې ساتل شوی شاتړ د وسیلې له ورکېدو څخه ساتنه نه کوي. USB یا بل خوندي ځای وټاکئ.',
      'preview': 'د شاتړ معلومات',
      'created': 'جوړ شوی',
      'shop': 'دوکان',
      'appVersion': 'د اپلېکېشن نسخه',
      'missingAssets': 'ورکې ضمیمې',
      'missingCleared':
          'ورک شوي فایلونه له شاتړ څخه لرې او د هغوی لارې پاکې شوې: {count}',
      'schema': 'د ډیټابېس بڼه',
      'attachments': 'ضمیمې',
      'valid': 'تایید شو',
      'processing': 'کار روان دی…',
      'error': 'د شاتړ یا بېرته راګرځولو ستونزه',
      'notSelected': 'پوښۍ نه ده ټاکل شوې',
      'restoring': 'بېرته راګرځول…',
      'backupStep': 'د ډیټابېس منظم انځور جوړېږي…',
      'retry': 'بیا هڅه',
    };
    const fa = {
      'title': 'پشتیبان‌گیری و بازیابی',
      'backup': 'پشتیبان‌گیری',
      'restore': 'بازیابی',
      'location': 'محل پشتیبان‌گیری',
      'chooseFolder': 'انتخاب پوشه',
      'create': 'ایجاد پشتیبان',
      'last': 'آخرین پشتیبان موفق',
      'openFolder': 'باز کردن پوشه پشتیبان',
      'chooseFile': 'انتخاب فایل پشتیبان',
      'restoreNow': 'بازیابی پشتیبان',
      'replace': 'بازیابی، اطلاعات فعلی دکان را با این پشتیبان جایگزین می‌کند و دو پایگاه داده را ادغام نمی‌کند.',
      'confirm': 'تأیید بازیابی',
      'cancel': 'لغو',
      'success': 'پشتیبان با موفقیت ایجاد شد.',
      'restored': 'پشتیبان بازیابی شد. برای ادامه دوباره وارد شوید.',
      'sameDevice': 'پشتیبان ذخیره‌شده در همین دستگاه در برابر گم‌شدن دستگاه محافظت نمی‌کند. USB یا محل امن دیگری انتخاب کنید.',
      'preview': 'اطلاعات پشتیبان',
      'created': 'تاریخ ایجاد',
      'shop': 'دکان',
      'appVersion': 'نسخه برنامه',
      'missingAssets': 'فایل‌های ضمیمه‌شده موجود نیست',
      'missingCleared': 'فایل‌های مفقود از پشتیبان کنار گذاشته و مسیرهای آن‌ها پاک شد: {count}',
      'schema': 'نسخه پایگاه داده',
      'attachments': 'ضمیمه‌ها',
      'valid': 'تأیید شد',
      'processing': 'در حال انجام…',
      'error': 'پشتیبان‌گیری یا بازیابی ناموفق شد',
      'notSelected': 'پوشه‌ای انتخاب نشده',
      'restoring': 'در حال بازیابی…',
      'backupStep': 'در حال تهیه نسخه سازگار پایگاه داده…',
      'retry': 'تلاش دوباره',
    };
    return (lang == 'ps'
            ? ps
            : lang == 'fa'
            ? fa
            : en)[key] ??
        key;
  }

  Widget _backupRestoreCard(BuildContext context, AppLocalizations l10n) {
    final folder = backupPrefs['folder'] as String?;
    final lastAt = backupPrefs['last_at']?.toString();
    final dateText = lastAt == null
        ? '—'
        : CalendarService.format(
            DateTime.tryParse(lastAt) ?? DateTime.now(),
            calendar: LocaleControllerScope.of(context).calendar,
            locale: Localizations.localeOf(context).toLanguageTag(),
          );
    return _SettingsSection(
      icon: Icons.backup_outlined,
      title: _tr('title'),
      description: l10n.settingsBackupSectionDescription,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 780;
          final create = _BackupSubsection(
            icon: Icons.backup_outlined,
            title: _tr('backup'),
            description: l10n.settingsBackupCreateDescription,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _tr('location'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 7),
                _PathField(
                  path: folder ?? _tr('notSelected'),
                  tooltip: folder ?? _tr('notSelected'),
                  onCopy: folder == null ? null : () => _copyPath(folder),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: backupBusy ? null : _chooseBackupFolder,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(_tr('chooseFolder')),
                    ),
                    FilledButton.icon(
                      onPressed: backupBusy || folder == null
                          ? null
                          : _createBackup,
                      icon: backupBusy && backupStep == _tr('backupStep')
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.backup_outlined),
                      label: Text(_tr('create')),
                    ),
                    if (folder != null)
                      TextButton.icon(
                        onPressed: backupBusy
                            ? null
                            : () => _openBackupFolder(folder),
                        icon: const Icon(Icons.open_in_new_outlined),
                        label: Text(_tr('openFolder')),
                      ),
                  ],
                ),
                if (folder == null) ...[
                  const SizedBox(height: 5),
                  Text(
                    l10n.settingsBackupDisabledFolder,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      lastAt == null
                          ? Icons.info_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: lastAt == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lastAt == null
                            ? l10n.settingsNeverBackedUp
                            : '${_tr('last')}: $dateText',
                      ),
                    ),
                  ],
                ),
                if (backupPrefs['last_file'] is String) ...[
                  const SizedBox(height: 7),
                  _PathField(
                    path: backupPrefs['last_file'] as String,
                    tooltip: backupPrefs['last_file'] as String,
                    onCopy: () => _copyPath(backupPrefs['last_file'] as String),
                  ),
                ],
                const SizedBox(height: 12),
                _InfoCallout(icon: Icons.info_outline, text: _tr('sameDevice')),
              ],
            ),
          );
          final restore = _BackupSubsection(
            icon: Icons.restore_outlined,
            title: _tr('restore'),
            description: l10n.settingsBackupRestoreDescription,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: backupBusy ? null : _chooseBackupFile,
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(_tr('chooseFile')),
                    ),
                    OutlinedButton.icon(
                      onPressed: backupBusy || restorePreview == null
                          ? null
                          : _confirmRestore,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      icon: const Icon(Icons.restore_outlined),
                      label: Text(_tr('restoreNow')),
                    ),
                  ],
                ),
                if (restorePath == null) ...[
                  const SizedBox(height: 5),
                  Text(
                    l10n.settingsBackupDisabledFile,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (restorePreview != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.settingsSelectedBackupFile,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 7),
                  _PathField(
                    path: restorePath ?? '',
                    tooltip: restorePath ?? '',
                    onCopy: restorePath == null
                        ? null
                        : () => _copyPath(restorePath!),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _tr('preview'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    children: [
                      Text(
                        '${_tr('created')}: ${CalendarService.format(DateTime.tryParse('${restorePreview!['created_at']}') ?? DateTime.now(), calendar: LocaleControllerScope.of(context).calendar, locale: Localizations.localeOf(context).toLanguageTag())}',
                      ),
                      Text(
                        '${_tr('shop')}: ${restorePreview!['shop_name'] ?? ''}',
                      ),
                      Text(
                        '${_tr('appVersion')}: ${restorePreview!['application_version']}',
                      ),
                      Text(
                        '${_tr('schema')}: ${restorePreview!['database_version']}',
                      ),
                      Text(
                        '${_tr('attachments')}: ${restorePreview!['attachment_count']}',
                      ),
                      Text(_tr('valid')),
                    ],
                  ),
                  if ((restorePreview!['missing_asset_count'] as int? ?? 0) >
                      0) ...[
                    const SizedBox(height: 8),
                    _InfoCallout(
                      icon: Icons.warning_amber_outlined,
                      isWarning: true,
                      text:
                          '${_tr('missingAssets')}: ${restorePreview!['missing_asset_count']}',
                    ),
                  ],
                ],
                if (restorePreview == null) ...[
                  const SizedBox(height: 12),
                  _InfoCallout(icon: Icons.info_outline, text: _tr('replace')),
                ],
              ],
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: create),
                    const SizedBox(width: 14),
                    Expanded(child: restore),
                  ],
                )
              else ...[
                create,
                const SizedBox(height: 14),
                restore,
              ],
              if (backupBusy) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
                const SizedBox(height: 5),
                Text(backupStep ?? _tr('processing')),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openBackupFolder(String folder) async {
    try {
      await Process.start('explorer.exe', [folder]);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _chooseBackupFolder() async {
    try {
      final path = pickBackupFolderPath();
      if (path == null) return;
      await BackupService.savePreferences({'folder': path});
      final prefs = await BackupService.preferences();
      if (mounted) setState(() => backupPrefs = prefs);
    } catch (error) {
      _showError(error, retry: _chooseBackupFolder);
    }
  }

  Future<void> _createBackup() async {
    widget.onOperationBusyChanged?.call(true);
    setState(() {
      backupBusy = true;
      backupStep = _tr('backupStep');
    });
    try {
      final file = await BackupService.createBackup(
        widget.database,
        backupPrefs['folder'] as String,
      );
      final backupInfo = await BackupService.inspect(file.path);
      final prefs = await BackupService.preferences();
      final missingCount = backupInfo['missing_asset_count'] as int? ?? 0;
      if (mounted) {
        setState(() => backupPrefs = prefs);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_tr('success')} ${missingCount == 0 ? '' : _tr('missingCleared').replaceAll('{count}', '$missingCount')} ${file.path}',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (error) {
      _showError(error, retry: _createBackup);
    } finally {
      widget.onOperationBusyChanged?.call(false);
      if (mounted) setState(() => backupBusy = false);
    }
  }

  Future<void> _chooseBackupFile() async {
    try {
      final path = pickBackupFilePath();
      if (path == null) return;
      widget.onOperationBusyChanged?.call(true);
      setState(() {
        restorePreview = null;
        restorePath = null;
        backupBusy = true;
        backupStep = _tr('processing');
      });
      final preview = await BackupService.inspect(path);
      if (mounted) {
        setState(() {
          restorePreview = preview;
          restorePath = path;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          restorePreview = null;
          restorePath = null;
        });
      }
      _showError(error, retry: _chooseBackupFile);
    } finally {
      widget.onOperationBusyChanged?.call(false);
      if (mounted) setState(() => backupBusy = false);
    }
  }

  Future<void> _confirmRestore() async {
    final localeController = LocaleControllerScope.of(context);
    final password = TextEditingController();
    String? error;
    final confirmedPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(_tr('confirm')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authText(ctx, 'restorePassword')),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: authText(ctx, 'currentPassword'),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_tr('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final valid = await widget.authController.service
                    .verifyCurrentPassword(password.text);
                if (!valid) {
                  setDialog(
                    () => error = authText(ctx, 'invalidCurrentPassword'),
                  );
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, password.text);
              },
              child: Text(_tr('restoreNow')),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    if (!mounted || confirmedPassword == null || restorePath == null) return;
    widget.onOperationBusyChanged?.call(true);
    setState(() {
      backupBusy = true;
      backupStep = _tr('restoring');
    });
    try {
      await BackupService.restore(widget.database, restorePath!);
      await localeController.reloadFromDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_tr('restored'))));
      }
      await widget.onDataRestored?.call();
      await widget.authController.logout();
      if (mounted) {
        setState(() {
          future = widget.database.settings();
        });
      }
    } catch (error) {
      _showError(error, retry: _confirmRestore);
    } finally {
      widget.onOperationBusyChanged?.call(false);
      if (mounted) setState(() => backupBusy = false);
    }
  }

  void _showError(Object error, {VoidCallback? retry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_tr('error')}: $error'),
        action: retry == null
            ? null
            : SnackBarAction(label: _tr('retry'), onPressed: retry),
      ),
    );
  }

  Future<void> _editPaymentMethods(Map<String, Object?> settings) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text:
          (settings['payment_methods'] as String?) ??
          'Cash, Bank transfer, Other',
    );
    final methods = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsPaymentMethods),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.settingsMethodsCommaSeparated,
            helperText: l10n.settingsPaymentMethodsHelp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(AppLocalizations.of(ctx)!.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (methods == null) return;
    final normalized = methods
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .join(', ');
    if (normalized.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsEnterPaymentMethod)),
        );
      }
      return;
    }
    try {
      await widget.database.saveSettings({'payment_methods': normalized});
      if (mounted) setState(() => future = widget.database.settings());
    } catch (error) {
      debugPrint('Payment methods save failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.settingsPaymentMethodsSaveError('$error')),
          ),
        );
      }
    }
  }
}

class _DateCalendarSettings extends StatelessWidget {
  const _DateCalendarSettings({required this.controller});
  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = CalendarService.shopToday();
    final primary = CalendarService.format(
      today,
      calendar: controller.calendar,
      locale: locale,
    );
    final secondary = CalendarService.format(
      today,
      calendar: controller.calendar == CalendarService.gregorian
          ? CalendarService.solarHijri
          : CalendarService.gregorian,
      locale: locale,
    );
    final secondaryLabel = controller.calendar == CalendarService.gregorian
        ? l10n.solarHijriLabel
        : l10n.gregorianLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(controller.calendar),
          isExpanded: true,
          initialValue: controller.calendar,
          decoration: InputDecoration(
            labelText: l10n.calendarLabel,
            prefixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          items: [
            DropdownMenuItem(
              value: CalendarService.solarHijri,
              child: Text(
                l10n.afghanSolarHijri,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: CalendarService.gregorian,
              child: Text(
                l10n.gregorianMiladi,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) controller.setCalendar(value);
          },
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.showBothDates),
          value: controller.showBothDates,
          onChanged: controller.setShowBothDates,
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.today_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.today,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      controller.showBothDates
                          ? '${l10n.settingsPrimaryDate}: $primary'
                          : primary,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (controller.showBothDates)
                      Text(
                        '${l10n.settingsSecondaryDate} ($secondaryLabel): $secondary',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, progress, section) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 6),
          child: section,
        ),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewTile extends StatelessWidget {
  const _ThemePreviewTile({
    required this.mode,
    required this.title,
    required this.description,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final ThemeMode mode;
  final String title;
  final String description;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = mode == ThemeMode.dark;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$title. $description${selected ? '. ${AppLocalizations.of(context)!.settingsSelected}' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primary.withValues(alpha: .07)
                  : colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            size: 19,
                            color: selected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (selected) ...[
                            Icon(
                              Icons.check_circle,
                              color: colors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.settingsSelected,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ThemeMiniPreview(isDark: isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeMiniPreview extends StatelessWidget {
  const _ThemeMiniPreview({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final background = isDark
        ? const Color(0xff0f172a)
        : const Color(0xfff5f7fa);
    final surface = isDark ? const Color(0xff1e293b) : Colors.white;
    final rail = isDark ? const Color(0xff111c30) : const Color(0xff142238);
    final accent = isDark ? const Color(0xff5eead4) : const Color(0xff087f8c);
    final line = isDark ? const Color(0xff475569) : const Color(0xffe2e8f0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 92,
        height: 62,
        color: background,
        child: Row(
          children: [
            Container(width: 17, color: rail),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 4, width: 32, color: line),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: line),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: Container(
                            width: 23,
                            height: 7,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupSubsection extends StatelessWidget {
  const _BackupSubsection({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PathField extends StatelessWidget {
  const _PathField({
    required this.path,
    required this.tooltip,
    required this.onCopy,
  });

  final String path;
  final String tooltip;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: 10, end: 3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(path, textDirection: TextDirection.ltr),
            ),
            if (onCopy != null)
              IconButton(
                tooltip: AppLocalizations.of(context)!.settingsCopyPathTooltip,
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCallout extends StatelessWidget {
  const _InfoCallout({
    required this.icon,
    required this.text,
    this.isWarning = false,
  });

  final IconData icon;
  final String text;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isWarning
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xffffc857)
              : const Color(0xffa76608))
        : colors.secondary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, softWrap: true)),
        ],
      ),
    );
  }
}
