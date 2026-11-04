import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_ps.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
    Locale('fa', 'AF'),
    Locale('ps'),
  ];

  /// No description provided for @loginBrandHeading.
  ///
  /// In en, this message translates to:
  /// **'Your shop, organized.'**
  String get loginBrandHeading;

  /// No description provided for @loginBrandMessage.
  ///
  /// In en, this message translates to:
  /// **'Manage customers, measurements, orders, and accounts in one place.'**
  String get loginBrandMessage;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back.'**
  String get loginWelcomeBack;

  /// No description provided for @loginSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue.'**
  String get loginSignInSubtitle;

  /// No description provided for @loginOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Works offline on this computer.'**
  String get loginOfflineNote;

  /// No description provided for @loginRememberHint.
  ///
  /// In en, this message translates to:
  /// **'Use only on a trusted computer.'**
  String get loginRememberHint;

  /// No description provided for @loginUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your username.'**
  String get loginUsernameRequired;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get loginPasswordRequired;

  /// No description provided for @loginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

  /// No description provided for @loginArtworkDescription.
  ///
  /// In en, this message translates to:
  /// **'Tailoring scissors and a shirt emblem'**
  String get loginArtworkDescription;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tailor Shop'**
  String get appTitle;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your shop'**
  String get setupTitle;

  /// No description provided for @setupDescription.
  ///
  /// In en, this message translates to:
  /// **'Your records stay on this computer. You can change these details in Settings.'**
  String get setupDescription;

  /// No description provided for @shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get shopName;

  /// No description provided for @ownerName.
  ///
  /// In en, this message translates to:
  /// **'Owner name'**
  String get ownerName;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber;

  /// No description provided for @secondNumber.
  ///
  /// In en, this message translates to:
  /// **'Second number (optional)'**
  String get secondNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @receiptFooter.
  ///
  /// In en, this message translates to:
  /// **'Receipt footer'**
  String get receiptFooter;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomer;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @deliveryBoard.
  ///
  /// In en, this message translates to:
  /// **'Delivery board'**
  String get deliveryBoard;

  /// No description provided for @fabric.
  ///
  /// In en, this message translates to:
  /// **'Fabric'**
  String get fabric;

  /// No description provided for @fabricInventory.
  ///
  /// In en, this message translates to:
  /// **'Fabric inventory'**
  String get fabricInventory;

  /// No description provided for @workers.
  ///
  /// In en, this message translates to:
  /// **'Workers'**
  String get workers;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize your shop and application preferences.'**
  String get settingsPageSubtitle;

  /// No description provided for @settingsAccountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account & Security'**
  String get settingsAccountSecurity;

  /// No description provided for @settingsAccountSecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage your username and account security.'**
  String get settingsAccountSecurityDescription;

  /// No description provided for @settingsShopProfileSection.
  ///
  /// In en, this message translates to:
  /// **'Shop Profile'**
  String get settingsShopProfileSection;

  /// No description provided for @settingsShopProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'View and update your shop name and contact details.'**
  String get settingsShopProfileDescription;

  /// No description provided for @settingsEditShopProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Shop Profile'**
  String get settingsEditShopProfile;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how the application looks on this computer.'**
  String get settingsAppearanceDescription;

  /// No description provided for @settingsLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get settingsLightMode;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsLightModeDescription.
  ///
  /// In en, this message translates to:
  /// **'A light page with white cards and teal actions.'**
  String get settingsLightModeDescription;

  /// No description provided for @settingsDarkModeDescription.
  ///
  /// In en, this message translates to:
  /// **'A dark page with comfortable light text.'**
  String get settingsDarkModeDescription;

  /// No description provided for @settingsSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get settingsSelected;

  /// No description provided for @settingsLanguageCalendar.
  ///
  /// In en, this message translates to:
  /// **'Language & Calendar'**
  String get settingsLanguageCalendar;

  /// No description provided for @settingsLanguageCalendarDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the application language and date calendar.'**
  String get settingsLanguageCalendarDescription;

  /// No description provided for @settingsPrimaryDate.
  ///
  /// In en, this message translates to:
  /// **'Primary date'**
  String get settingsPrimaryDate;

  /// No description provided for @settingsSecondaryDate.
  ///
  /// In en, this message translates to:
  /// **'Secondary date'**
  String get settingsSecondaryDate;

  /// No description provided for @settingsPaymentsReceipts.
  ///
  /// In en, this message translates to:
  /// **'Payments & Receipts'**
  String get settingsPaymentsReceipts;

  /// No description provided for @settingsPaymentsReceiptsDescription.
  ///
  /// In en, this message translates to:
  /// **'Payment methods and information shown on receipts.'**
  String get settingsPaymentsReceiptsDescription;

  /// No description provided for @settingsPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get settingsPaymentMethods;

  /// No description provided for @settingsPaymentMethodsDescription.
  ///
  /// In en, this message translates to:
  /// **'Available methods for recording payments.'**
  String get settingsPaymentMethodsDescription;

  /// No description provided for @settingsReceiptFooterDescription.
  ///
  /// In en, this message translates to:
  /// **'Printed at the bottom of receipts.'**
  String get settingsReceiptFooterDescription;

  /// No description provided for @settingsCurrencyDescription.
  ///
  /// In en, this message translates to:
  /// **'Currency used for shop transactions.'**
  String get settingsCurrencyDescription;

  /// No description provided for @settingsApplicationInformation.
  ///
  /// In en, this message translates to:
  /// **'Application Information'**
  String get settingsApplicationInformation;

  /// No description provided for @settingsApplicationInformationDescription.
  ///
  /// In en, this message translates to:
  /// **'Local storage and application details.'**
  String get settingsApplicationInformationDescription;

  /// No description provided for @settingsDataStoredLocally.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored on this computer.'**
  String get settingsDataStoredLocally;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// No description provided for @settingsDatabasePath.
  ///
  /// In en, this message translates to:
  /// **'Database path'**
  String get settingsDatabasePath;

  /// No description provided for @settingsCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get settingsCopyPath;

  /// No description provided for @settingsCopyPathTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy the full path'**
  String get settingsCopyPathTooltip;

  /// No description provided for @settingsPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied.'**
  String get settingsPathCopied;

  /// No description provided for @settingsBackupSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a safe copy of shop data or restore a validated backup.'**
  String get settingsBackupSectionDescription;

  /// No description provided for @settingsBackupCreateDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder and create a verified backup file.'**
  String get settingsBackupCreateDescription;

  /// No description provided for @settingsBackupRestoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a backup file to review it before restoring.'**
  String get settingsBackupRestoreDescription;

  /// No description provided for @settingsNoBackupFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder before creating a backup.'**
  String get settingsNoBackupFolder;

  /// No description provided for @settingsNoBackupFile.
  ///
  /// In en, this message translates to:
  /// **'Choose and validate a backup file before restoring.'**
  String get settingsNoBackupFile;

  /// No description provided for @settingsThemeSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the appearance preference: {error}'**
  String settingsThemeSaveError(Object error);

  /// No description provided for @settingsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be loaded.'**
  String get settingsLoadError;

  /// No description provided for @settingsNoData.
  ///
  /// In en, this message translates to:
  /// **'No settings data is available.'**
  String get settingsNoData;

  /// No description provided for @settingsMethodsCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated methods'**
  String get settingsMethodsCommaSeparated;

  /// No description provided for @settingsPaymentMethodsHelp.
  ///
  /// In en, this message translates to:
  /// **'These are manual records. Transfers are not verified.'**
  String get settingsPaymentMethodsHelp;

  /// No description provided for @settingsEnterPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one payment method.'**
  String get settingsEnterPaymentMethod;

  /// No description provided for @settingsPaymentMethodsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save payment methods: {error}'**
  String settingsPaymentMethodsSaveError(Object error);

  /// No description provided for @orderPrintingSettings.
  ///
  /// In en, this message translates to:
  /// **'Order printing'**
  String get orderPrintingSettings;

  /// No description provided for @orderPrintingSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose separate printers and paper sizes for the work slip and customer bill.'**
  String get orderPrintingSettingsDescription;

  /// No description provided for @measurementPrinter.
  ///
  /// In en, this message translates to:
  /// **'Measurement sheet printer'**
  String get measurementPrinter;

  /// No description provided for @customerBillPrinter.
  ///
  /// In en, this message translates to:
  /// **'Customer bill printer'**
  String get customerBillPrinter;

  /// No description provided for @defaultPrinter.
  ///
  /// In en, this message translates to:
  /// **'Choose in the print dialog'**
  String get defaultPrinter;

  /// No description provided for @paperSize.
  ///
  /// In en, this message translates to:
  /// **'Paper size'**
  String get paperSize;

  /// No description provided for @paperA5.
  ///
  /// In en, this message translates to:
  /// **'A5'**
  String get paperA5;

  /// No description provided for @paperA4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get paperA4;

  /// No description provided for @paper80mm.
  ///
  /// In en, this message translates to:
  /// **'80 mm roll'**
  String get paper80mm;

  /// No description provided for @paper55mm.
  ///
  /// In en, this message translates to:
  /// **'55 mm roll'**
  String get paper55mm;

  /// No description provided for @refreshPrinters.
  ///
  /// In en, this message translates to:
  /// **'Refresh printers'**
  String get refreshPrinters;

  /// No description provided for @settingsSelectedBackupFile.
  ///
  /// In en, this message translates to:
  /// **'Selected backup file'**
  String get settingsSelectedBackupFile;

  /// No description provided for @settingsBackupDisabledFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup folder to enable this action.'**
  String get settingsBackupDisabledFolder;

  /// No description provided for @settingsBackupDisabledFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid backup file to enable restore.'**
  String get settingsBackupDisabledFile;

  /// No description provided for @settingsNeverBackedUp.
  ///
  /// In en, this message translates to:
  /// **'No successful backup yet.'**
  String get settingsNeverBackedUp;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @shopProfileAndData.
  ///
  /// In en, this message translates to:
  /// **'Shop profile and local data'**
  String get shopProfileAndData;

  /// No description provided for @localDatabase.
  ///
  /// In en, this message translates to:
  /// **'Local SQLite database'**
  String get localDatabase;

  /// No description provided for @databaseStoredHere.
  ///
  /// In en, this message translates to:
  /// **'Stored in the application support folder for this Windows user.'**
  String get databaseStoredHere;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup / restore'**
  String get backupRestore;

  /// No description provided for @backupPlanned.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore are planned for a future implementation stage.'**
  String get backupPlanned;

  /// No description provided for @modulePlanned.
  ///
  /// In en, this message translates to:
  /// **'This module is reserved for a future implementation stage.'**
  String get modulePlanned;

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get newOrder;

  /// No description provided for @receivePayment.
  ///
  /// In en, this message translates to:
  /// **'Receive payment'**
  String get receivePayment;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPayment;

  /// No description provided for @saveOrder.
  ///
  /// In en, this message translates to:
  /// **'Save order'**
  String get saveOrder;

  /// No description provided for @reviewOrder.
  ///
  /// In en, this message translates to:
  /// **'Review order'**
  String get reviewOrder;

  /// No description provided for @orderConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get orderConfirmation;

  /// No description provided for @reviewOrderBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Review the saved measurement copies and charges before saving.'**
  String get reviewOrderBeforeSaving;

  /// No description provided for @measurementWorkSlip.
  ///
  /// In en, this message translates to:
  /// **'Measurement / work slip'**
  String get measurementWorkSlip;

  /// No description provided for @customerBill.
  ///
  /// In en, this message translates to:
  /// **'Customer bill'**
  String get customerBill;

  /// No description provided for @previewMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Preview measurements'**
  String get previewMeasurements;

  /// No description provided for @previewCustomerBill.
  ///
  /// In en, this message translates to:
  /// **'Preview customer bill'**
  String get previewCustomerBill;

  /// No description provided for @printMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Print measurements'**
  String get printMeasurements;

  /// No description provided for @printCustomerBill.
  ///
  /// In en, this message translates to:
  /// **'Print customer bill'**
  String get printCustomerBill;

  /// No description provided for @printBoth.
  ///
  /// In en, this message translates to:
  /// **'Print both'**
  String get printBoth;

  /// No description provided for @saveOrderPrintBoth.
  ///
  /// In en, this message translates to:
  /// **'Save order & print both'**
  String get saveOrderPrintBoth;

  /// No description provided for @savedOrderPrintOptions.
  ///
  /// In en, this message translates to:
  /// **'Your order and any advance payment are saved. Choose a document to preview, print, or export.'**
  String get savedOrderPrintOptions;

  /// No description provided for @saveAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Save as PDF'**
  String get saveAsPdf;

  /// No description provided for @printDocument.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get printDocument;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @printCancelled.
  ///
  /// In en, this message translates to:
  /// **'Printing was cancelled. Retry when the printer is ready.'**
  String get printCancelled;

  /// No description provided for @printFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not open the print job. Retry without saving the order again.'**
  String get printFailedRetry;

  /// No description provided for @manualBillNumberHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the bill number. Prefixes and leading zeros are kept.'**
  String get manualBillNumberHelp;

  /// No description provided for @editForThisOrder.
  ///
  /// In en, this message translates to:
  /// **'Edit for this order'**
  String get editForThisOrder;

  /// No description provided for @useMeasurementsForOrder.
  ///
  /// In en, this message translates to:
  /// **'Use these measurements for this order'**
  String get useMeasurementsForOrder;

  /// No description provided for @updateSavedMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Also update the saved customer measurements'**
  String get updateSavedMeasurements;

  /// No description provided for @confirmUpdateSavedMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Save these changes to the customer\'s active measurement profile? This is separate from the order snapshot.'**
  String get confirmUpdateSavedMeasurements;

  /// No description provided for @savedMeasurementsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Customer measurements updated.'**
  String get savedMeasurementsUpdated;

  /// No description provided for @designInstructions.
  ///
  /// In en, this message translates to:
  /// **'Design instructions'**
  String get designInstructions;

  /// No description provided for @fittingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Fitting instructions'**
  String get fittingInstructions;

  /// No description provided for @stitchingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Stitching instructions'**
  String get stitchingInstructions;

  /// No description provided for @designChoices.
  ///
  /// In en, this message translates to:
  /// **'Design choices'**
  String get designChoices;

  /// No description provided for @measurementsHeading.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get measurementsHeading;

  /// No description provided for @measurementValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get measurementValue;

  /// No description provided for @optionYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get optionYes;

  /// No description provided for @optionNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get optionNo;

  /// No description provided for @designCuff.
  ///
  /// In en, this message translates to:
  /// **'Cuff'**
  String get designCuff;

  /// No description provided for @designCollar.
  ///
  /// In en, this message translates to:
  /// **'Collar'**
  String get designCollar;

  /// No description provided for @designBelt.
  ///
  /// In en, this message translates to:
  /// **'Belt'**
  String get designBelt;

  /// No description provided for @designFrontPlacket.
  ///
  /// In en, this message translates to:
  /// **'Front placket'**
  String get designFrontPlacket;

  /// No description provided for @designChestPocket.
  ///
  /// In en, this message translates to:
  /// **'Chest pocket'**
  String get designChestPocket;

  /// No description provided for @designSidePocket.
  ///
  /// In en, this message translates to:
  /// **'Side pocket'**
  String get designSidePocket;

  /// No description provided for @designRoundNeck.
  ///
  /// In en, this message translates to:
  /// **'Round neck'**
  String get designRoundNeck;

  /// No description provided for @designStraightNeck.
  ///
  /// In en, this message translates to:
  /// **'Straight neck'**
  String get designStraightNeck;

  /// No description provided for @designButtons.
  ///
  /// In en, this message translates to:
  /// **'Buttons'**
  String get designButtons;

  /// No description provided for @designLining.
  ///
  /// In en, this message translates to:
  /// **'Lining'**
  String get designLining;

  /// No description provided for @designBackBelt.
  ///
  /// In en, this message translates to:
  /// **'Back belt'**
  String get designBackBelt;

  /// No description provided for @designRoundedHem.
  ///
  /// In en, this message translates to:
  /// **'Rounded hem'**
  String get designRoundedHem;

  /// No description provided for @designVent.
  ///
  /// In en, this message translates to:
  /// **'Back vent'**
  String get designVent;

  /// No description provided for @designLapels.
  ///
  /// In en, this message translates to:
  /// **'Lapels'**
  String get designLapels;

  /// No description provided for @orderInstructions.
  ///
  /// In en, this message translates to:
  /// **'Order instructions'**
  String get orderInstructions;

  /// No description provided for @extraCharge.
  ///
  /// In en, this message translates to:
  /// **'Extra charge (AFN)'**
  String get extraCharge;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount (AFN)'**
  String get discount;

  /// No description provided for @orderSaved.
  ///
  /// In en, this message translates to:
  /// **'Order saved'**
  String get orderSaved;

  /// No description provided for @billNumber.
  ///
  /// In en, this message translates to:
  /// **'Bill number'**
  String get billNumber;

  /// No description provided for @automaticBillNumber.
  ///
  /// In en, this message translates to:
  /// **'Assigned automatically when saved'**
  String get automaticBillNumber;

  /// No description provided for @viewInvoice.
  ///
  /// In en, this message translates to:
  /// **'View invoice'**
  String get viewInvoice;

  /// No description provided for @invoiceDetails.
  ///
  /// In en, this message translates to:
  /// **'Invoice details'**
  String get invoiceDetails;

  /// No description provided for @customerSuppliedNoCharge.
  ///
  /// In en, this message translates to:
  /// **'Customer-supplied fabric (no charge)'**
  String get customerSuppliedNoCharge;

  /// No description provided for @paymentForSelectedBill.
  ///
  /// In en, this message translates to:
  /// **'This payment will be applied to this bill only.'**
  String get paymentForSelectedBill;

  /// No description provided for @stitchingAmount.
  ///
  /// In en, this message translates to:
  /// **'Stitching'**
  String get stitchingAmount;

  /// No description provided for @fabricAmount.
  ///
  /// In en, this message translates to:
  /// **'Shop fabric'**
  String get fabricAmount;

  /// No description provided for @billNotAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get billNotAssigned;

  /// No description provided for @billNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the bill number before confirming this order.'**
  String get billNumberRequired;

  /// No description provided for @billNumberAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'That bill number is already in use. Enter a different number.'**
  String get billNumberAlreadyUsed;

  /// No description provided for @editOrder.
  ///
  /// In en, this message translates to:
  /// **'Edit order'**
  String get editOrder;

  /// No description provided for @editInvoice.
  ///
  /// In en, this message translates to:
  /// **'Edit Invoice'**
  String get editInvoice;

  /// No description provided for @editInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Invoice — {billNumber}'**
  String editInvoiceTitle(Object billNumber);

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @invoiceWorkerAssignments.
  ///
  /// In en, this message translates to:
  /// **'Assigned workers'**
  String get invoiceWorkerAssignments;

  /// No description provided for @invoiceAssignedWorker.
  ///
  /// In en, this message translates to:
  /// **'Worker'**
  String get invoiceAssignedWorker;

  /// No description provided for @invoiceWorkLocked.
  ///
  /// In en, this message translates to:
  /// **'Work has started. Change this assignment from the Workers screen.'**
  String get invoiceWorkLocked;

  /// No description provided for @invoiceCustomerLocked.
  ///
  /// In en, this message translates to:
  /// **'The customer cannot be changed after payments have been recorded.'**
  String get invoiceCustomerLocked;

  /// No description provided for @billNumberUpdated.
  ///
  /// In en, this message translates to:
  /// **'Bill number updated.'**
  String get billNumberUpdated;

  /// No description provided for @saveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Save customer'**
  String get saveCustomer;

  /// No description provided for @saveMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Save measurements'**
  String get saveMeasurements;

  /// No description provided for @refreshDashboard.
  ///
  /// In en, this message translates to:
  /// **'Refresh dashboard'**
  String get refreshDashboard;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Good day'**
  String get greeting;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @ordersReceivedToday.
  ///
  /// In en, this message translates to:
  /// **'Orders received today'**
  String get ordersReceivedToday;

  /// No description provided for @toHandOverToday.
  ///
  /// In en, this message translates to:
  /// **'To be handed over today'**
  String get toHandOverToday;

  /// No description provided for @pastDueDate.
  ///
  /// In en, this message translates to:
  /// **'Past the due date'**
  String get pastDueDate;

  /// No description provided for @readyForPickup.
  ///
  /// In en, this message translates to:
  /// **'Ready for customer pickup'**
  String get readyForPickup;

  /// No description provided for @paymentsToday.
  ///
  /// In en, this message translates to:
  /// **'Payments today'**
  String get paymentsToday;

  /// No description provided for @paymentsRecordedToday.
  ///
  /// In en, this message translates to:
  /// **'Payments recorded today'**
  String get paymentsRecordedToday;

  /// No description provided for @currentLedgerBalance.
  ///
  /// In en, this message translates to:
  /// **'Current ledger balance'**
  String get currentLedgerBalance;

  /// No description provided for @searchCustomers.
  ///
  /// In en, this message translates to:
  /// **'Search customers'**
  String get searchCustomers;

  /// No description provided for @searchCustomersHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone, or customer ID'**
  String get searchCustomersHint;

  /// No description provided for @searchCustomerByNamePhone.
  ///
  /// In en, this message translates to:
  /// **'Search customer by name or mobile number'**
  String get searchCustomerByNamePhone;

  /// No description provided for @searchOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Search order number, customer, or phone'**
  String get searchOrderHint;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @customerId.
  ///
  /// In en, this message translates to:
  /// **'Customer ID'**
  String get customerId;

  /// No description provided for @outstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding;

  /// No description provided for @outstandingBalance.
  ///
  /// In en, this message translates to:
  /// **'Outstanding balance'**
  String get outstandingBalance;

  /// No description provided for @noMatchingCustomers.
  ///
  /// In en, this message translates to:
  /// **'No matching customers. Add a new customer to begin.'**
  String get noMatchingCustomers;

  /// No description provided for @noCustomersYet.
  ///
  /// In en, this message translates to:
  /// **'No customers yet. Add a customer to start taking orders.'**
  String get noCustomersYet;

  /// No description provided for @recentCustomers.
  ///
  /// In en, this message translates to:
  /// **'Recent customers'**
  String get recentCustomers;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get noResults;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @searchError.
  ///
  /// In en, this message translates to:
  /// **'Search could not be completed.'**
  String get searchError;

  /// No description provided for @chooseCustomer.
  ///
  /// In en, this message translates to:
  /// **'Choose a customer'**
  String get chooseCustomer;

  /// No description provided for @searchNamePhone.
  ///
  /// In en, this message translates to:
  /// **'Search name or mobile number'**
  String get searchNamePhone;

  /// No description provided for @noCustomerToOrder.
  ///
  /// In en, this message translates to:
  /// **'No customers found. Add a customer first.'**
  String get noCustomerToOrder;

  /// No description provided for @dashboardLoadError.
  ///
  /// In en, this message translates to:
  /// **'Dashboard data could not be loaded.'**
  String get dashboardLoadError;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @attention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get attention;

  /// No description provided for @emptyOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders in this group.'**
  String get emptyOrders;

  /// No description provided for @openOrder.
  ///
  /// In en, this message translates to:
  /// **'Open order'**
  String get openOrder;

  /// No description provided for @markDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark delivered'**
  String get markDelivered;

  /// No description provided for @upcomingDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Upcoming deliveries'**
  String get upcomingDeliveries;

  /// No description provided for @emptyDeliveries.
  ///
  /// In en, this message translates to:
  /// **'No upcoming deliveries.'**
  String get emptyDeliveries;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @emptyActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity.'**
  String get emptyActivity;

  /// No description provided for @paymentActivity.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get paymentActivity;

  /// No description provided for @readyActivity.
  ///
  /// In en, this message translates to:
  /// **'Order ready'**
  String get readyActivity;

  /// No description provided for @deliveredActivity.
  ///
  /// In en, this message translates to:
  /// **'Order delivered'**
  String get deliveredActivity;

  /// No description provided for @newOrderActivity.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get newOrderActivity;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh dashboard'**
  String get refresh;

  /// No description provided for @newToday.
  ///
  /// In en, this message translates to:
  /// **'New today'**
  String get newToday;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @customerBalance.
  ///
  /// In en, this message translates to:
  /// **'Customer balance'**
  String get customerBalance;

  /// No description provided for @newOrdersDescription.
  ///
  /// In en, this message translates to:
  /// **'Orders received today'**
  String get newOrdersDescription;

  /// No description provided for @toHandOverDescription.
  ///
  /// In en, this message translates to:
  /// **'To be handed over today'**
  String get toHandOverDescription;

  /// No description provided for @pastDueDescription.
  ///
  /// In en, this message translates to:
  /// **'Past the due date'**
  String get pastDueDescription;

  /// No description provided for @pickupDescription.
  ///
  /// In en, this message translates to:
  /// **'Ready for customer pickup'**
  String get pickupDescription;

  /// No description provided for @paymentsRecordedDescription.
  ///
  /// In en, this message translates to:
  /// **'Payments recorded today'**
  String get paymentsRecordedDescription;

  /// No description provided for @ledgerBalanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Current ledger balance'**
  String get ledgerBalanceDescription;

  /// No description provided for @shalwar.
  ///
  /// In en, this message translates to:
  /// **'Shalwar Kameez'**
  String get shalwar;

  /// No description provided for @waistcoat.
  ///
  /// In en, this message translates to:
  /// **'Waistcoat'**
  String get waistcoat;

  /// No description provided for @coat.
  ///
  /// In en, this message translates to:
  /// **'Coat'**
  String get coat;

  /// No description provided for @kameezLength.
  ///
  /// In en, this message translates to:
  /// **'Kameez length'**
  String get kameezLength;

  /// No description provided for @shoulderWidth.
  ///
  /// In en, this message translates to:
  /// **'Shoulder width'**
  String get shoulderWidth;

  /// No description provided for @sleeveLength.
  ///
  /// In en, this message translates to:
  /// **'Sleeve length'**
  String get sleeveLength;

  /// No description provided for @chest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get chest;

  /// No description provided for @waist.
  ///
  /// In en, this message translates to:
  /// **'Waist'**
  String get waist;

  /// No description provided for @hipSeat.
  ///
  /// In en, this message translates to:
  /// **'Hip / seat'**
  String get hipSeat;

  /// No description provided for @neckCollar.
  ///
  /// In en, this message translates to:
  /// **'Neck / collar'**
  String get neckCollar;

  /// No description provided for @neck.
  ///
  /// In en, this message translates to:
  /// **'Neck'**
  String get neck;

  /// No description provided for @upperArm.
  ///
  /// In en, this message translates to:
  /// **'Upper arm'**
  String get upperArm;

  /// No description provided for @cuffWrist.
  ///
  /// In en, this message translates to:
  /// **'Cuff / wrist'**
  String get cuffWrist;

  /// No description provided for @shalwarLength.
  ///
  /// In en, this message translates to:
  /// **'Shalwar length'**
  String get shalwarLength;

  /// No description provided for @shalwarWaist.
  ///
  /// In en, this message translates to:
  /// **'Shalwar waist'**
  String get shalwarWaist;

  /// No description provided for @thigh.
  ///
  /// In en, this message translates to:
  /// **'Thigh'**
  String get thigh;

  /// No description provided for @bottomOpening.
  ///
  /// In en, this message translates to:
  /// **'Bottom opening'**
  String get bottomOpening;

  /// No description provided for @waistcoatLength.
  ///
  /// In en, this message translates to:
  /// **'Waistcoat length'**
  String get waistcoatLength;

  /// No description provided for @armhole.
  ///
  /// In en, this message translates to:
  /// **'Armhole'**
  String get armhole;

  /// No description provided for @coatLength.
  ///
  /// In en, this message translates to:
  /// **'Coat length'**
  String get coatLength;

  /// No description provided for @wristSleeveOpening.
  ///
  /// In en, this message translates to:
  /// **'Wrist / sleeve opening'**
  String get wristSleeveOpening;

  /// No description provided for @finishedGarmentLength.
  ///
  /// In en, this message translates to:
  /// **'Finished garment length'**
  String get finishedGarmentLength;

  /// No description provided for @finishedSleeveLength.
  ///
  /// In en, this message translates to:
  /// **'Finished sleeve length'**
  String get finishedSleeveLength;

  /// No description provided for @width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;

  /// No description provided for @circumference.
  ///
  /// In en, this message translates to:
  /// **'Circumference'**
  String get circumference;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @cutting.
  ///
  /// In en, this message translates to:
  /// **'Cutting'**
  String get cutting;

  /// No description provided for @stitching.
  ///
  /// In en, this message translates to:
  /// **'Stitching'**
  String get stitching;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @garment.
  ///
  /// In en, this message translates to:
  /// **'Garment'**
  String get garment;

  /// No description provided for @measurementProfile.
  ///
  /// In en, this message translates to:
  /// **'Measurement profile'**
  String get measurementProfile;

  /// No description provided for @noProfileDraftOrder.
  ///
  /// In en, this message translates to:
  /// **'No profile · draft order'**
  String get noProfileDraftOrder;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @pricePerItem.
  ///
  /// In en, this message translates to:
  /// **'Stitching charge (AFN)'**
  String get pricePerItem;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetails;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get orderSummary;

  /// No description provided for @advancePayment.
  ///
  /// In en, this message translates to:
  /// **'Advance payment (AFN)'**
  String get advancePayment;

  /// No description provided for @remainingBalance.
  ///
  /// In en, this message translates to:
  /// **'Remaining balance'**
  String get remainingBalance;

  /// No description provided for @advancePaymentLedgerHint.
  ///
  /// In en, this message translates to:
  /// **'This payment reduces the balance and is recorded in the customer ledger.'**
  String get advancePaymentLedgerHint;

  /// No description provided for @deliveryDate.
  ///
  /// In en, this message translates to:
  /// **'Delivery date (YYYY-MM-DD)'**
  String get deliveryDate;

  /// No description provided for @styleOrderNotes.
  ///
  /// In en, this message translates to:
  /// **'Style / order notes'**
  String get styleOrderNotes;

  /// No description provided for @reviewMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Review measurements'**
  String get reviewMeasurements;

  /// No description provided for @checkOrderAmounts.
  ///
  /// In en, this message translates to:
  /// **'Check quantity, price, and advance amount.'**
  String get checkOrderAmounts;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @addMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Add measurements'**
  String get addMeasurements;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get profileName;

  /// No description provided for @measurementUnit.
  ///
  /// In en, this message translates to:
  /// **'Measurement unit'**
  String get measurementUnit;

  /// No description provided for @inches.
  ///
  /// In en, this message translates to:
  /// **'Inches'**
  String get inches;

  /// No description provided for @centimeters.
  ///
  /// In en, this message translates to:
  /// **'Centimeters'**
  String get centimeters;

  /// No description provided for @measurementInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter body measurements unless marked “finished garment”.'**
  String get measurementInstructions;

  /// No description provided for @additionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Additional notes'**
  String get additionalNotes;

  /// No description provided for @noProfiles.
  ///
  /// In en, this message translates to:
  /// **'No profiles saved yet.'**
  String get noProfiles;

  /// No description provided for @duplicateEdit.
  ///
  /// In en, this message translates to:
  /// **'Duplicate / edit'**
  String get duplicateEdit;

  /// No description provided for @newProfile.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get newProfile;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @notAdded.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get notAdded;

  /// No description provided for @addCustomerDialog.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomerDialog;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @enterCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Enter the customer name'**
  String get enterCustomerName;

  /// No description provided for @enterMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter a mobile number'**
  String get enterMobile;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @numberAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'Number already in use'**
  String get numberAlreadyUsed;

  /// No description provided for @duplicatePhoneQuestion.
  ///
  /// In en, this message translates to:
  /// **'This number belongs to another customer. Save it as a shared family number?'**
  String get duplicatePhoneQuestion;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @saveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get saveAnyway;

  /// No description provided for @customerAdded.
  ///
  /// In en, this message translates to:
  /// **'Customer added'**
  String get customerAdded;

  /// No description provided for @receivePaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive payment'**
  String get receivePaymentTitle;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @amountAFN.
  ///
  /// In en, this message translates to:
  /// **'Amount (AFN)'**
  String get amountAFN;

  /// No description provided for @method.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get method;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get bankTransfer;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @selectCustomerAndAmount.
  ///
  /// In en, this message translates to:
  /// **'Select a customer and enter an amount greater than zero.'**
  String get selectCustomerAndAmount;

  /// No description provided for @paymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get paymentRecorded;

  /// No description provided for @paymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get paymentReceived;

  /// No description provided for @addCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomerTitle;

  /// No description provided for @customerOrders.
  ///
  /// In en, this message translates to:
  /// **'Customer orders'**
  String get customerOrders;

  /// No description provided for @customerLedger.
  ///
  /// In en, this message translates to:
  /// **'Customer ledger'**
  String get customerLedger;

  /// No description provided for @customerInformation.
  ///
  /// In en, this message translates to:
  /// **'Customer information'**
  String get customerInformation;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet.'**
  String get noOrdersYet;

  /// No description provided for @noLedgerEntries.
  ///
  /// In en, this message translates to:
  /// **'No ledger entries.'**
  String get noLedgerEntries;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @balanceWord.
  ///
  /// In en, this message translates to:
  /// **'balance'**
  String get balanceWord;

  /// No description provided for @newCustomerCode.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newCustomerCode;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent customers'**
  String get searchRecent;

  /// No description provided for @outstandingFilter.
  ///
  /// In en, this message translates to:
  /// **'Outstanding balance'**
  String get outstandingFilter;

  /// No description provided for @noOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No orders found.'**
  String get noOrdersFound;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @searchOrders.
  ///
  /// In en, this message translates to:
  /// **'Search order number, customer, or phone'**
  String get searchOrders;

  /// No description provided for @noDeliveries.
  ///
  /// In en, this message translates to:
  /// **'No upcoming deliveries.'**
  String get noDeliveries;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @openOrderAction.
  ///
  /// In en, this message translates to:
  /// **'Open order'**
  String get openOrderAction;

  /// No description provided for @sellFabric.
  ///
  /// In en, this message translates to:
  /// **'Sell fabric'**
  String get sellFabric;

  /// No description provided for @fabricLoadError.
  ///
  /// In en, this message translates to:
  /// **'Fabric and customer data could not be loaded.'**
  String get fabricLoadError;

  /// No description provided for @noActiveFabric.
  ///
  /// In en, this message translates to:
  /// **'No active fabric stock is available.'**
  String get noActiveFabric;

  /// No description provided for @fabricName.
  ///
  /// In en, this message translates to:
  /// **'Fabric'**
  String get fabricName;

  /// No description provided for @customerOptionalPaid.
  ///
  /// In en, this message translates to:
  /// **'Customer (optional for paid sale)'**
  String get customerOptionalPaid;

  /// No description provided for @walkInCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in customer'**
  String get walkInCustomer;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price (AFN)'**
  String get unitPrice;

  /// No description provided for @paidNow.
  ///
  /// In en, this message translates to:
  /// **'Paid now (AFN)'**
  String get paidNow;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @saleTotal.
  ///
  /// In en, this message translates to:
  /// **'Sale total'**
  String get saleTotal;

  /// No description provided for @remainingStock.
  ///
  /// In en, this message translates to:
  /// **'Remaining stock'**
  String get remainingStock;

  /// No description provided for @fabricNotEnoughStock.
  ///
  /// In en, this message translates to:
  /// **'Not enough available fabric for this quantity.'**
  String get fabricNotEnoughStock;

  /// No description provided for @recordSale.
  ///
  /// In en, this message translates to:
  /// **'Record sale'**
  String get recordSale;

  /// No description provided for @orderDeliveredConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mark order delivered?'**
  String get orderDeliveredConfirm;

  /// No description provided for @orderDelivered.
  ///
  /// In en, this message translates to:
  /// **'Order marked delivered'**
  String get orderDelivered;

  /// No description provided for @orderUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update order.'**
  String get orderUpdateFailed;

  /// No description provided for @manageCustomersDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage customers, measurements, orders, and balances.'**
  String get manageCustomersDescription;

  /// No description provided for @searchCustomersHintFull.
  ///
  /// In en, this message translates to:
  /// **'Search by name, mobile number, or customer ID'**
  String get searchCustomersHintFull;

  /// No description provided for @filterAllCustomers.
  ///
  /// In en, this message translates to:
  /// **'All customers'**
  String get filterAllCustomers;

  /// No description provided for @filterWithOutstanding.
  ///
  /// In en, this message translates to:
  /// **'With outstanding balance'**
  String get filterWithOutstanding;

  /// No description provided for @filterWithActiveOrders.
  ///
  /// In en, this message translates to:
  /// **'With active orders'**
  String get filterWithActiveOrders;

  /// No description provided for @filterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get filterArchived;

  /// No description provided for @sortCustomers.
  ///
  /// In en, this message translates to:
  /// **'Sort customers'**
  String get sortCustomers;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortByName;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding balance'**
  String get sortOutstanding;

  /// No description provided for @activeOrders.
  ///
  /// In en, this message translates to:
  /// **'Active orders'**
  String get activeOrders;

  /// No description provided for @copyPhone.
  ///
  /// In en, this message translates to:
  /// **'Copy phone number'**
  String get copyPhone;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @customerArchived.
  ///
  /// In en, this message translates to:
  /// **'Customer archived'**
  String get customerArchived;

  /// No description provided for @customerRestored.
  ///
  /// In en, this message translates to:
  /// **'Customer restored'**
  String get customerRestored;

  /// No description provided for @archiveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Archive customer'**
  String get archiveCustomer;

  /// No description provided for @restoreCustomer.
  ///
  /// In en, this message translates to:
  /// **'Restore customer'**
  String get restoreCustomer;

  /// No description provided for @noSearchResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for'**
  String get noSearchResultsFor;

  /// No description provided for @openingBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance (AFN)'**
  String get openingBalance;

  /// No description provided for @openingBalanceHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter a starting amount if the customer already owes you or has credit.'**
  String get openingBalanceHelp;

  /// No description provided for @debt.
  ///
  /// In en, this message translates to:
  /// **'Owes shop'**
  String get debt;

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'Customer credit'**
  String get credit;

  /// No description provided for @customerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Customer updated'**
  String get customerUpdated;

  /// No description provided for @editCustomer.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get editCustomer;

  /// No description provided for @optionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Optional details and opening balance'**
  String get optionalDetails;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard the changes you made?'**
  String get discardChanges;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @totalBilled.
  ///
  /// In en, this message translates to:
  /// **'Total billed'**
  String get totalBilled;

  /// No description provided for @totalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get totalPaid;

  /// No description provided for @measurementsSaved.
  ///
  /// In en, this message translates to:
  /// **'Measurements saved'**
  String get measurementsSaved;

  /// No description provided for @noMeasurementsYet.
  ///
  /// In en, this message translates to:
  /// **'No measurements yet'**
  String get noMeasurementsYet;

  /// No description provided for @viewMeasurements.
  ///
  /// In en, this message translates to:
  /// **'View measurements'**
  String get viewMeasurements;

  /// No description provided for @customerCredit.
  ///
  /// In en, this message translates to:
  /// **'Available customer credit'**
  String get customerCredit;

  /// No description provided for @customerRegistrationDate.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get customerRegistrationDate;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment status'**
  String get paymentStatus;

  /// No description provided for @productionStatus.
  ///
  /// In en, this message translates to:
  /// **'Production status'**
  String get productionStatus;

  /// No description provided for @paidInFull.
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get paidInFull;

  /// No description provided for @partiallyPaid.
  ///
  /// In en, this message translates to:
  /// **'Partially paid'**
  String get partiallyPaid;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @orderDate.
  ///
  /// In en, this message translates to:
  /// **'Order date'**
  String get orderDate;

  /// No description provided for @noOrdersMatch.
  ///
  /// In en, this message translates to:
  /// **'No orders match these filters.'**
  String get noOrdersMatch;

  /// No description provided for @outstandingZero.
  ///
  /// In en, this message translates to:
  /// **'No outstanding balance'**
  String get outstandingZero;

  /// No description provided for @confirmArchiveCustomer.
  ///
  /// In en, this message translates to:
  /// **'This hides the customer from active lists. Their orders, measurements, and ledger remain saved.'**
  String get confirmArchiveCustomer;

  /// No description provided for @openProfile.
  ///
  /// In en, this message translates to:
  /// **'Open profile'**
  String get openProfile;

  /// No description provided for @dateFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter from date'**
  String get dateFilter;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @amountGreaterZero.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero.'**
  String get amountGreaterZero;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date (YYYY-MM-DD)'**
  String get dateFormat;

  /// No description provided for @profileStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get profileStandard;

  /// No description provided for @style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get style;

  /// No description provided for @reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reference;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @pashto.
  ///
  /// In en, this message translates to:
  /// **'پښتو'**
  String get pashto;

  /// No description provided for @dari.
  ///
  /// In en, this message translates to:
  /// **'دری'**
  String get dari;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethodLabel;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed'**
  String get languageChanged;

  /// No description provided for @garmentSummaryHeader.
  ///
  /// In en, this message translates to:
  /// **'Garment summary'**
  String get garmentSummaryHeader;

  /// No description provided for @noProfilesYet.
  ///
  /// In en, this message translates to:
  /// **'No profiles saved yet.'**
  String get noProfilesYet;

  /// No description provided for @fabricFormDetails.
  ///
  /// In en, this message translates to:
  /// **'Fabric Details'**
  String get fabricFormDetails;

  /// No description provided for @fabricFormName.
  ///
  /// In en, this message translates to:
  /// **'Fabric name'**
  String get fabricFormName;

  /// No description provided for @fabricFormCode.
  ///
  /// In en, this message translates to:
  /// **'Fabric code'**
  String get fabricFormCode;

  /// No description provided for @fabricFormCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fabricFormCategory;

  /// No description provided for @fabricFormAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get fabricFormAddCategory;

  /// No description provided for @fabricFormCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get fabricFormCategoryName;

  /// No description provided for @fabricFormColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get fabricFormColor;

  /// No description provided for @fabricFormUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get fabricFormUnit;

  /// No description provided for @fabricFormUnitDisplay.
  ///
  /// In en, this message translates to:
  /// **'Unit: {unit}'**
  String fabricFormUnitDisplay(Object unit);

  /// No description provided for @fabricFormUnitReview.
  ///
  /// In en, this message translates to:
  /// **'Unit needs review: {unit}'**
  String fabricFormUnitReview(Object unit);

  /// No description provided for @fabricFormCategoryReview.
  ///
  /// In en, this message translates to:
  /// **'Review the existing category “{category}”. Check the fabric record, then select Clothing Fabric or Waistcoat / Coat Fabric. Saving a category change does not change stock quantities or prices.'**
  String fabricFormCategoryReview(Object category);

  /// No description provided for @fabricFormCategoryUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get fabricFormCategoryUncategorized;

  /// No description provided for @fabricFormMeter.
  ///
  /// In en, this message translates to:
  /// **'Meter'**
  String get fabricFormMeter;

  /// No description provided for @fabricFormOpeningPrices.
  ///
  /// In en, this message translates to:
  /// **'Opening Stock & Prices'**
  String get fabricFormOpeningPrices;

  /// No description provided for @fabricFormLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low-stock alert (meters)'**
  String get fabricFormLowStock;

  /// No description provided for @fabricFormOpeningHelp.
  ///
  /// In en, this message translates to:
  /// **'Opening quantity is stock already held when registering this fabric.'**
  String get fabricFormOpeningHelp;

  /// No description provided for @fabricFormNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fabricFormNotes;

  /// No description provided for @fabricFormOptionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Optional notes'**
  String get fabricFormOptionalNotes;

  /// No description provided for @fabricFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save Fabric'**
  String get fabricFormSave;

  /// No description provided for @fabricFormSaveAnother.
  ///
  /// In en, this message translates to:
  /// **'Save & Add Another'**
  String get fabricFormSaveAnother;

  /// No description provided for @fabricFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Fabric name is required.'**
  String get fabricFormNameRequired;

  /// No description provided for @fabricFormCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Fabric code is required.'**
  String get fabricFormCodeRequired;

  /// No description provided for @fabricFormMoneyPrecision.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount with at most two decimal places.'**
  String get fabricFormMoneyPrecision;

  /// No description provided for @fabricFormDuplicateCode.
  ///
  /// In en, this message translates to:
  /// **'Fabric code already exists.'**
  String get fabricFormDuplicateCode;

  /// No description provided for @fabricFormSaved.
  ///
  /// In en, this message translates to:
  /// **'Fabric saved.'**
  String get fabricFormSaved;

  /// No description provided for @fabricFormAdd.
  ///
  /// In en, this message translates to:
  /// **'Add fabric'**
  String get fabricFormAdd;

  /// No description provided for @fabricFormEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit fabric'**
  String get fabricFormEdit;

  /// No description provided for @gregorianMiladi.
  ///
  /// In en, this message translates to:
  /// **'Gregorian / Miladi'**
  String get gregorianMiladi;

  /// No description provided for @gregorianLabel.
  ///
  /// In en, this message translates to:
  /// **'Gregorian'**
  String get gregorianLabel;

  /// No description provided for @dateCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Date & Calendar'**
  String get dateCalendarTitle;

  /// No description provided for @showBothDates.
  ///
  /// In en, this message translates to:
  /// **'Show both dates'**
  String get showBothDates;

  /// No description provided for @calendarLabel.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarLabel;

  /// No description provided for @afghanSolarHijri.
  ///
  /// In en, this message translates to:
  /// **'Afghan Solar Hijri / Shamsi'**
  String get afghanSolarHijri;

  /// No description provided for @solarHijriLabel.
  ///
  /// In en, this message translates to:
  /// **'Solar Hijri'**
  String get solarHijriLabel;

  /// No description provided for @allMethodsLabel.
  ///
  /// In en, this message translates to:
  /// **'All methods'**
  String get allMethodsLabel;

  /// No description provided for @expensesDescription.
  ///
  /// In en, this message translates to:
  /// **'Record shop expenses and review spending for the selected period.'**
  String get expensesDescription;

  /// No description provided for @printExpenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get printExpenseAmount;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @suggestedAmountOptional.
  ///
  /// In en, this message translates to:
  /// **'Suggested amount (optional)'**
  String get suggestedAmountOptional;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @expenseSaved.
  ///
  /// In en, this message translates to:
  /// **'Expense saved.'**
  String get expenseSaved;

  /// No description provided for @receiptFormatError.
  ///
  /// In en, this message translates to:
  /// **'Choose a PNG, JPEG, or WebP image.'**
  String get receiptFormatError;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @expensesToday.
  ///
  /// In en, this message translates to:
  /// **'Expenses today'**
  String get expensesToday;

  /// No description provided for @saveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save expense'**
  String get saveExpense;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @expenseDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense date'**
  String get expenseDateLabel;

  /// No description provided for @expenseCategories.
  ///
  /// In en, this message translates to:
  /// **'Expense categories'**
  String get expenseCategories;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount *'**
  String get amountRequired;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateName;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @reasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Reason *'**
  String get reasonRequired;

  /// No description provided for @receiptSizeError.
  ///
  /// In en, this message translates to:
  /// **'Receipt photos must be 5 MB or smaller.'**
  String get receiptSizeError;

  /// No description provided for @selectedMonth.
  ///
  /// In en, this message translates to:
  /// **'Selected month'**
  String get selectedMonth;

  /// No description provided for @thisMonthFilter.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonthFilter;

  /// No description provided for @categoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get categoryRequired;

  /// No description provided for @amountLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Amount: low to high'**
  String get amountLowToHigh;

  /// No description provided for @reversal.
  ///
  /// In en, this message translates to:
  /// **'Reversal'**
  String get reversal;

  /// No description provided for @noTemplates.
  ///
  /// In en, this message translates to:
  /// **'No templates saved.'**
  String get noTemplates;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @reverseExpense.
  ///
  /// In en, this message translates to:
  /// **'Reverse expense'**
  String get reverseExpense;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get descriptionRequired;

  /// No description provided for @amountHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Amount: high to low'**
  String get amountHighToLow;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @printExpenseCategories.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get printExpenseCategories;

  /// No description provided for @referenceOptional.
  ///
  /// In en, this message translates to:
  /// **'Reference (optional)'**
  String get referenceOptional;

  /// No description provided for @searchExpense.
  ///
  /// In en, this message translates to:
  /// **'Search expense, payee, or reference'**
  String get searchExpense;

  /// No description provided for @allStatusesLabel.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatusesLabel;

  /// No description provided for @expenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Expense no.'**
  String get expenseNumber;

  /// No description provided for @payeeOptional.
  ///
  /// In en, this message translates to:
  /// **'Payee (optional)'**
  String get payeeOptional;

  /// No description provided for @enterPositiveAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero'**
  String get enterPositiveAmount;

  /// No description provided for @allMethods.
  ///
  /// In en, this message translates to:
  /// **'All methods'**
  String get allMethods;

  /// No description provided for @expenseStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get expenseStatus;

  /// No description provided for @selectedPeriodMetric.
  ///
  /// In en, this message translates to:
  /// **'Selected period'**
  String get selectedPeriodMetric;

  /// No description provided for @selectedMonthMetric.
  ///
  /// In en, this message translates to:
  /// **'Selected month'**
  String get selectedMonthMetric;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @printExpenseDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get printExpenseDescription;

  /// No description provided for @toDate.
  ///
  /// In en, this message translates to:
  /// **'To date'**
  String get toDate;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Add or choose a category'**
  String get chooseCategory;

  /// No description provided for @descriptionPayeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Description / payee'**
  String get descriptionPayeeLabel;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @payeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get payeeLabel;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatuses;

  /// No description provided for @descriptionField.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get descriptionField;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @posted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get posted;

  /// No description provided for @renameCategory.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get renameCategory;

  /// No description provided for @expenseNo.
  ///
  /// In en, this message translates to:
  /// **'Expense no.'**
  String get expenseNo;

  /// No description provided for @methodLabel.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get methodLabel;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @noSuggestedAmount.
  ///
  /// In en, this message translates to:
  /// **'No suggested amount'**
  String get noSuggestedAmount;

  /// No description provided for @oldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get oldest;

  /// No description provided for @expenseNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense no.'**
  String get expenseNumberLabel;

  /// No description provided for @newTemplate.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get newTemplate;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @expenseTodayMetric.
  ///
  /// In en, this message translates to:
  /// **'Expenses today'**
  String get expenseTodayMetric;

  /// No description provided for @expensesDescriptionShort.
  ///
  /// In en, this message translates to:
  /// **'Record shop expenses and review spending.'**
  String get expensesDescriptionShort;

  /// No description provided for @saveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save template'**
  String get saveTemplate;

  /// No description provided for @expenseTemplates.
  ///
  /// In en, this message translates to:
  /// **'Expense templates'**
  String get expenseTemplates;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @attachReceipt.
  ///
  /// In en, this message translates to:
  /// **'Attach receipt photo (5 MB max)'**
  String get attachReceipt;

  /// No description provided for @noExpensesForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No expenses for this period. Add your first expense.'**
  String get noExpensesForPeriod;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From date'**
  String get fromDate;

  /// No description provided for @useTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use template'**
  String get useTemplate;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @reverse.
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get reverse;

  /// No description provided for @reversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get reversed;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @largestCategory.
  ///
  /// In en, this message translates to:
  /// **'Largest category'**
  String get largestCategory;

  /// No description provided for @expenseReport.
  ///
  /// In en, this message translates to:
  /// **'Expense report'**
  String get expenseReport;

  /// No description provided for @deleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get deleteTemplate;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @printReport.
  ///
  /// In en, this message translates to:
  /// **'Print report'**
  String get printReport;

  /// No description provided for @payee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get payee;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No.'**
  String get no;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @descriptionPayee.
  ///
  /// In en, this message translates to:
  /// **'Description / payee'**
  String get descriptionPayee;

  /// No description provided for @saveAndAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Save & add another'**
  String get saveAndAddAnother;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @selectedPeriod.
  ///
  /// In en, this message translates to:
  /// **'Selected period'**
  String get selectedPeriod;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @addExpenseDescription.
  ///
  /// In en, this message translates to:
  /// **'Record an ordinary shop cost. Worker salary is recorded in Workers.'**
  String get addExpenseDescription;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @printExpenseMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get printExpenseMethod;

  /// No description provided for @reportsDescription.
  ///
  /// In en, this message translates to:
  /// **'Understand your shop\'s orders, sales, collections, stock, and expenses.'**
  String get reportsDescription;

  /// No description provided for @reportSavePdf.
  ///
  /// In en, this message translates to:
  /// **'Save Full Report as PDF'**
  String get reportSavePdf;

  /// No description provided for @reportPrintFull.
  ///
  /// In en, this message translates to:
  /// **'Print Full Report'**
  String get reportPrintFull;

  /// No description provided for @reportPrintFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Print full report'**
  String get reportPrintFullTitle;

  /// No description provided for @reportPrintFullConfirm.
  ///
  /// In en, this message translates to:
  /// **'The complete report includes Overview, Orders, Sales, Collections, Customer Balances, Fabric, Purchases & Suppliers, Workers, Expenses, Profit, and calculation notes.'**
  String get reportPrintFullConfirm;

  /// No description provided for @reportContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get reportContinue;

  /// No description provided for @reportToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get reportToday;

  /// No description provided for @reportYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get reportYesterday;

  /// No description provided for @reportThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get reportThisWeek;

  /// No description provided for @reportThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get reportThisMonth;

  /// No description provided for @reportLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get reportLastMonth;

  /// No description provided for @reportThisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get reportThisYear;

  /// No description provided for @reportCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get reportCustomRange;

  /// No description provided for @reportFromDate.
  ///
  /// In en, this message translates to:
  /// **'From date'**
  String get reportFromDate;

  /// No description provided for @reportToDate.
  ///
  /// In en, this message translates to:
  /// **'To date'**
  String get reportToDate;

  /// No description provided for @reportDateOrderError.
  ///
  /// In en, this message translates to:
  /// **'From date must be on or before To date.'**
  String get reportDateOrderError;

  /// No description provided for @reportGenerationError.
  ///
  /// In en, this message translates to:
  /// **'Report generation failed. Please try again.'**
  String get reportGenerationError;

  /// No description provided for @reportGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get reportGenerating;

  /// No description provided for @reportGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate Report'**
  String get reportGenerate;

  /// No description provided for @reportNeedsRegeneration.
  ///
  /// In en, this message translates to:
  /// **'Needs regeneration'**
  String get reportNeedsRegeneration;

  /// No description provided for @reportSelectPeriod.
  ///
  /// In en, this message translates to:
  /// **'Select a period and generate a report from saved records.'**
  String get reportSelectPeriod;

  /// No description provided for @reportDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get reportDismiss;

  /// No description provided for @reportPrintCurrentSection.
  ///
  /// In en, this message translates to:
  /// **'Print Current Section'**
  String get reportPrintCurrentSection;

  /// No description provided for @reportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get reportUnavailable;

  /// No description provided for @reportNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity in this period.'**
  String get reportNoActivity;

  /// No description provided for @reportSearchSection.
  ///
  /// In en, this message translates to:
  /// **'Search customer, bill, garment, or fabric'**
  String get reportSearchSection;

  /// No description provided for @reportNoActivityOrSearch.
  ///
  /// In en, this message translates to:
  /// **'No activity in this period, or no rows match the search.'**
  String get reportNoActivityOrSearch;

  /// No description provided for @reportFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Full report'**
  String get reportFullTitle;

  /// No description provided for @reportShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop report'**
  String get reportShopTitle;

  /// No description provided for @reportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get reportPeriod;

  /// No description provided for @reportThrough.
  ///
  /// In en, this message translates to:
  /// **'through'**
  String get reportThrough;

  /// No description provided for @reportGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get reportGenerated;

  /// No description provided for @reportSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get reportSection;

  /// No description provided for @reportField.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get reportField;

  /// No description provided for @reportValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get reportValue;

  /// No description provided for @reportCalculationNotes.
  ///
  /// In en, this message translates to:
  /// **'Calculation notes and limitations'**
  String get reportCalculationNotes;

  /// No description provided for @reportOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get reportOverview;

  /// No description provided for @reportActiveFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get reportActiveFilters;

  /// No description provided for @reportSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get reportSales;

  /// No description provided for @reportCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get reportCollections;

  /// No description provided for @reportCustomerBalances.
  ///
  /// In en, this message translates to:
  /// **'Customer balances'**
  String get reportCustomerBalances;

  /// No description provided for @reportPurchasesSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Purchases & suppliers'**
  String get reportPurchasesSuppliers;

  /// No description provided for @reportProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get reportProfit;

  /// No description provided for @reportCustomerCollections.
  ///
  /// In en, this message translates to:
  /// **'Customer collections'**
  String get reportCustomerCollections;

  /// No description provided for @reportCustomerClosingBalances.
  ///
  /// In en, this message translates to:
  /// **'Customer closing balances'**
  String get reportCustomerClosingBalances;

  /// No description provided for @reportFabricMovements.
  ///
  /// In en, this message translates to:
  /// **'Fabric movements and closing stock'**
  String get reportFabricMovements;

  /// No description provided for @reportFabricPurchases.
  ///
  /// In en, this message translates to:
  /// **'Fabric purchases and supplier balances'**
  String get reportFabricPurchases;

  /// No description provided for @reportOperatingExpenses.
  ///
  /// In en, this message translates to:
  /// **'Operating expenses'**
  String get reportOperatingExpenses;

  /// No description provided for @reportProfitSummary.
  ///
  /// In en, this message translates to:
  /// **'Profit summary'**
  String get reportProfitSummary;

  /// No description provided for @reportCalculationLimitations.
  ///
  /// In en, this message translates to:
  /// **'Calculation notes and limitations'**
  String get reportCalculationLimitations;

  /// No description provided for @reportMetricOrders.
  ///
  /// In en, this message translates to:
  /// **'Confirmed orders created'**
  String get reportMetricOrders;

  /// No description provided for @reportMetricSales.
  ///
  /// In en, this message translates to:
  /// **'Net invoiced sales'**
  String get reportMetricSales;

  /// No description provided for @reportMetricReceipts.
  ///
  /// In en, this message translates to:
  /// **'Customer payments received'**
  String get reportMetricReceipts;

  /// No description provided for @reportMetricRefunds.
  ///
  /// In en, this message translates to:
  /// **'Customer refunds'**
  String get reportMetricRefunds;

  /// No description provided for @reportMetricNetCollections.
  ///
  /// In en, this message translates to:
  /// **'Net customer collections'**
  String get reportMetricNetCollections;

  /// No description provided for @reportMetricExpenses.
  ///
  /// In en, this message translates to:
  /// **'Operating expenses'**
  String get reportMetricExpenses;

  /// No description provided for @reportMetricCustomerDebt.
  ///
  /// In en, this message translates to:
  /// **'Customer outstanding debt at period end'**
  String get reportMetricCustomerDebt;

  /// No description provided for @reportMetricCustomerCredit.
  ///
  /// In en, this message translates to:
  /// **'Customer credit at period end'**
  String get reportMetricCustomerCredit;

  /// No description provided for @reportMetricWorkerPayable.
  ///
  /// In en, this message translates to:
  /// **'Worker payable at period end'**
  String get reportMetricWorkerPayable;

  /// No description provided for @reportMetricSupplierPayable.
  ///
  /// In en, this message translates to:
  /// **'Supplier payable at period end'**
  String get reportMetricSupplierPayable;

  /// No description provided for @reportMetricGrossProfit.
  ///
  /// In en, this message translates to:
  /// **'Gross profit'**
  String get reportMetricGrossProfit;

  /// No description provided for @reportMetricNetProfit.
  ///
  /// In en, this message translates to:
  /// **'Net profit'**
  String get reportMetricNetProfit;

  /// No description provided for @reportBalanceLimitations.
  ///
  /// In en, this message translates to:
  /// **'Balances are calculated through the selected period end. Fabric reservation figures show current reserved stock.'**
  String get reportBalanceLimitations;

  /// No description provided for @reportProfitUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reliable cost of sales and complete historical status data are not available for a full accrual profit calculation.'**
  String get reportProfitUnavailable;

  /// No description provided for @reportNoteDates.
  ///
  /// In en, this message translates to:
  /// **'Both selected dates are included. Dates are stored internally as Gregorian ISO dates.'**
  String get reportNoteDates;

  /// No description provided for @reportNoteOrderStatus.
  ///
  /// In en, this message translates to:
  /// **'Order status is current except delivery and cancellation events, which come from status history.'**
  String get reportNoteOrderStatus;

  /// No description provided for @reportNoteBalances.
  ///
  /// In en, this message translates to:
  /// **'Customer and supplier balances are derived from dated ledger entries through the selected end date.'**
  String get reportNoteBalances;

  /// No description provided for @reportNoteWorkerPayable.
  ///
  /// In en, this message translates to:
  /// **'Worker payable combines dated earnings, posted monthly salary, and posted payments. Advances may not reconcile to this simplified report balance.'**
  String get reportNoteWorkerPayable;

  /// No description provided for @reportNoteFabricReservation.
  ///
  /// In en, this message translates to:
  /// **'Fabric reserved quantity is current; reservation history is not stored by effective date.'**
  String get reportNoteFabricReservation;

  /// No description provided for @reportOrdersGroup.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get reportOrdersGroup;

  /// No description provided for @reportDeliveryEvents.
  ///
  /// In en, this message translates to:
  /// **'Delivery events'**
  String get reportDeliveryEvents;

  /// No description provided for @reportRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get reportRecords;

  /// No description provided for @reportInvoiced.
  ///
  /// In en, this message translates to:
  /// **'Invoiced'**
  String get reportInvoiced;

  /// No description provided for @reportDirectFabric.
  ///
  /// In en, this message translates to:
  /// **'Direct fabric sales'**
  String get reportDirectFabric;

  /// No description provided for @reportReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get reportReceipts;

  /// No description provided for @reportRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get reportRefunds;

  /// No description provided for @reportRefundTotal.
  ///
  /// In en, this message translates to:
  /// **'Refund total'**
  String get reportRefundTotal;

  /// No description provided for @reportNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get reportNet;

  /// No description provided for @reportRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get reportRows;

  /// No description provided for @reportDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get reportDebt;

  /// No description provided for @reportCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get reportCredit;

  /// No description provided for @reportMovements.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get reportMovements;

  /// No description provided for @reportPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get reportPurchases;

  /// No description provided for @reportSupplierPayments.
  ///
  /// In en, this message translates to:
  /// **'Supplier payments'**
  String get reportSupplierPayments;

  /// No description provided for @reportReturnsCredits.
  ///
  /// In en, this message translates to:
  /// **'Returns and credits'**
  String get reportReturnsCredits;

  /// No description provided for @reportSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get reportSuppliers;

  /// No description provided for @reportPayable.
  ///
  /// In en, this message translates to:
  /// **'Payable'**
  String get reportPayable;

  /// No description provided for @reportEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get reportEarnings;

  /// No description provided for @reportSalaries.
  ///
  /// In en, this message translates to:
  /// **'Salaries'**
  String get reportSalaries;

  /// No description provided for @reportPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get reportPayments;

  /// No description provided for @reportBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get reportBalances;

  /// No description provided for @reportCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get reportCategories;

  /// No description provided for @reportCategorySubtotals.
  ///
  /// In en, this message translates to:
  /// **'Category subtotals'**
  String get reportCategorySubtotals;

  /// No description provided for @reportFieldId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get reportFieldId;

  /// No description provided for @reportFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reportFieldName;

  /// No description provided for @reportFieldCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get reportFieldCustomer;

  /// No description provided for @reportFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get reportFieldPhone;

  /// No description provided for @reportFieldOrderDate.
  ///
  /// In en, this message translates to:
  /// **'Order date'**
  String get reportFieldOrderDate;

  /// No description provided for @reportFieldBillNumber.
  ///
  /// In en, this message translates to:
  /// **'Bill number'**
  String get reportFieldBillNumber;

  /// No description provided for @reportFieldNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get reportFieldNumber;

  /// No description provided for @reportFieldDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get reportFieldDueDate;

  /// No description provided for @reportFieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get reportFieldStatus;

  /// No description provided for @reportFieldTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get reportFieldTotal;

  /// No description provided for @reportFieldDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get reportFieldDiscount;

  /// No description provided for @reportFieldExtra.
  ///
  /// In en, this message translates to:
  /// **'Extra charge'**
  String get reportFieldExtra;

  /// No description provided for @reportFieldStitchingTotal.
  ///
  /// In en, this message translates to:
  /// **'Stitching total'**
  String get reportFieldStitchingTotal;

  /// No description provided for @reportFieldGarments.
  ///
  /// In en, this message translates to:
  /// **'Garments'**
  String get reportFieldGarments;

  /// No description provided for @reportFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportFieldDate;

  /// No description provided for @reportFieldReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reportFieldReference;

  /// No description provided for @reportFieldMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get reportFieldMethod;

  /// No description provided for @reportFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get reportFieldAmount;

  /// No description provided for @reportFieldReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reportFieldReason;

  /// No description provided for @reportFieldBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get reportFieldBalance;

  /// No description provided for @reportFieldCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get reportFieldCode;

  /// No description provided for @reportFieldFabric.
  ///
  /// In en, this message translates to:
  /// **'Fabric'**
  String get reportFieldFabric;

  /// No description provided for @reportFieldUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get reportFieldUnit;

  /// No description provided for @reportFieldAverageCost.
  ///
  /// In en, this message translates to:
  /// **'Average cost'**
  String get reportFieldAverageCost;

  /// No description provided for @reportFieldOpeningMilli.
  ///
  /// In en, this message translates to:
  /// **'Opening quantity (milliunits)'**
  String get reportFieldOpeningMilli;

  /// No description provided for @reportFieldMovementMilli.
  ///
  /// In en, this message translates to:
  /// **'Movement quantity (milliunits)'**
  String get reportFieldMovementMilli;

  /// No description provided for @reportFieldClosingMilli.
  ///
  /// In en, this message translates to:
  /// **'Closing quantity (milliunits)'**
  String get reportFieldClosingMilli;

  /// No description provided for @reportFieldKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get reportFieldKind;

  /// No description provided for @reportFieldSourceType.
  ///
  /// In en, this message translates to:
  /// **'Source type'**
  String get reportFieldSourceType;

  /// No description provided for @reportFieldQuantityMilli.
  ///
  /// In en, this message translates to:
  /// **'Quantity (milliunits)'**
  String get reportFieldQuantityMilli;

  /// No description provided for @reportFieldOpeningMeters.
  ///
  /// In en, this message translates to:
  /// **'Opening quantity (meters)'**
  String get reportFieldOpeningMeters;

  /// No description provided for @reportFieldMovementMeters.
  ///
  /// In en, this message translates to:
  /// **'Movement quantity (meters)'**
  String get reportFieldMovementMeters;

  /// No description provided for @reportFieldClosingMeters.
  ///
  /// In en, this message translates to:
  /// **'Closing quantity (meters)'**
  String get reportFieldClosingMeters;

  /// No description provided for @reportFieldQuantityMeters.
  ///
  /// In en, this message translates to:
  /// **'Meters sold'**
  String get reportFieldQuantityMeters;

  /// No description provided for @reportFieldNetMeters.
  ///
  /// In en, this message translates to:
  /// **'Net meters'**
  String get reportFieldNetMeters;

  /// No description provided for @reportFieldNetRevenue.
  ///
  /// In en, this message translates to:
  /// **'Sales amount'**
  String get reportFieldNetRevenue;

  /// No description provided for @reportFieldRecordedCost.
  ///
  /// In en, this message translates to:
  /// **'Fabric cost'**
  String get reportFieldRecordedCost;

  /// No description provided for @reportFieldGrossProfit.
  ///
  /// In en, this message translates to:
  /// **'Gross profit (AFN)'**
  String get reportFieldGrossProfit;

  /// No description provided for @reportFieldProfitPerMeter.
  ///
  /// In en, this message translates to:
  /// **'Profit per meter (AFN)'**
  String get reportFieldProfitPerMeter;

  /// No description provided for @reportFieldAverageRevenuePerMeter.
  ///
  /// In en, this message translates to:
  /// **'Average revenue per meter (AFN)'**
  String get reportFieldAverageRevenuePerMeter;

  /// No description provided for @reportFieldAverageCostPerMeter.
  ///
  /// In en, this message translates to:
  /// **'Average cost per meter (AFN)'**
  String get reportFieldAverageCostPerMeter;

  /// No description provided for @reportFieldReturnedMeters.
  ///
  /// In en, this message translates to:
  /// **'Returned meters'**
  String get reportFieldReturnedMeters;

  /// No description provided for @reportFieldUnpricedStitchingLines.
  ///
  /// In en, this message translates to:
  /// **'Unpriced stitching fabric lines'**
  String get reportFieldUnpricedStitchingLines;

  /// No description provided for @reportFieldMissingCostLines.
  ///
  /// In en, this message translates to:
  /// **'Sales with missing cost'**
  String get reportFieldMissingCostLines;

  /// No description provided for @reportFieldCostAvailable.
  ///
  /// In en, this message translates to:
  /// **'Cost available'**
  String get reportFieldCostAvailable;

  /// No description provided for @reportFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reportFilterAll;

  /// No description provided for @reportNoteFabricProfit.
  ///
  /// In en, this message translates to:
  /// **'Fabric profit includes posted direct fabric sales and separately priced shop fabric on stitching orders. Customer-owned fabric and stitching charges are excluded. Bundled or unpriced fabric lines are flagged; missing historical costs make gross profit unavailable for that fabric.'**
  String get reportNoteFabricProfit;

  /// No description provided for @reportFieldUnitCost.
  ///
  /// In en, this message translates to:
  /// **'Unit cost'**
  String get reportFieldUnitCost;

  /// No description provided for @reportFieldCostTotal.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get reportFieldCostTotal;

  /// No description provided for @reportFieldInvoiceReference.
  ///
  /// In en, this message translates to:
  /// **'Invoice reference'**
  String get reportFieldInvoiceReference;

  /// No description provided for @reportFieldSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get reportFieldSupplier;

  /// No description provided for @reportFieldPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get reportFieldPaid;

  /// No description provided for @reportFieldRefundAmount.
  ///
  /// In en, this message translates to:
  /// **'Refund amount'**
  String get reportFieldRefundAmount;

  /// No description provided for @reportFieldWorker.
  ///
  /// In en, this message translates to:
  /// **'Worker'**
  String get reportFieldWorker;

  /// No description provided for @reportFieldTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get reportFieldTask;

  /// No description provided for @reportFieldAcceptedQuantity.
  ///
  /// In en, this message translates to:
  /// **'Accepted quantity'**
  String get reportFieldAcceptedQuantity;

  /// No description provided for @reportFieldRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get reportFieldRate;

  /// No description provided for @reportFieldPayable.
  ///
  /// In en, this message translates to:
  /// **'Payable'**
  String get reportFieldPayable;

  /// No description provided for @reportFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get reportFieldCategory;

  /// No description provided for @reportFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get reportFieldDescription;

  /// No description provided for @reportFieldPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get reportFieldPayee;

  /// No description provided for @reportFieldReversalReason.
  ///
  /// In en, this message translates to:
  /// **'Reversal reason'**
  String get reportFieldReversalReason;

  /// No description provided for @reportFieldSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get reportFieldSource;

  /// No description provided for @reportStitchingOrder.
  ///
  /// In en, this message translates to:
  /// **'Stitching order'**
  String get reportStitchingOrder;

  /// No description provided for @reportDirectFabricSale.
  ///
  /// In en, this message translates to:
  /// **'Direct fabric sale'**
  String get reportDirectFabricSale;

  /// No description provided for @workerDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage workers, monthly salary periods, and salary payments.'**
  String get workerDescription;

  /// No description provided for @workerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add worker'**
  String get workerAdd;

  /// No description provided for @workerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit worker'**
  String get workerEdit;

  /// No description provided for @workerFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name *'**
  String get workerFullName;

  /// No description provided for @workerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get workerNameRequired;

  /// No description provided for @workerMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get workerMobile;

  /// No description provided for @workerMonthlySalary.
  ///
  /// In en, this message translates to:
  /// **'Monthly salary (AFN) *'**
  String get workerMonthlySalary;

  /// No description provided for @workerPositiveSalary.
  ///
  /// In en, this message translates to:
  /// **'Enter a salary greater than zero'**
  String get workerPositiveSalary;

  /// No description provided for @workerNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get workerNotes;

  /// No description provided for @workerActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get workerActive;

  /// No description provided for @workerInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get workerInactive;

  /// No description provided for @workerPhoneUsedTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone number already used'**
  String get workerPhoneUsedTitle;

  /// No description provided for @workerPhoneUsedBody.
  ///
  /// In en, this message translates to:
  /// **'Another worker has this mobile number. Shared numbers are allowed; continue if this is intentional.'**
  String get workerPhoneUsedBody;

  /// No description provided for @workerReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get workerReview;

  /// No description provided for @workerSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get workerSaving;

  /// No description provided for @workerSave.
  ///
  /// In en, this message translates to:
  /// **'Save worker'**
  String get workerSave;

  /// No description provided for @workerLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load workers. Please try again.'**
  String get workerLoadError;

  /// No description provided for @workerSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save worker. Please try again.'**
  String get workerSaveError;

  /// No description provided for @workerDraftSalaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft monthly salary'**
  String get workerDraftSalaryTitle;

  /// No description provided for @workerSalaryAmount.
  ///
  /// In en, this message translates to:
  /// **'Salary amount (AFN)'**
  String get workerSalaryAmount;

  /// No description provided for @workerSalaryReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Review the amount before posting. Each worker can have one salary entry per month.'**
  String get workerSalaryReviewHint;

  /// No description provided for @workerSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get workerSaveDraft;

  /// No description provided for @workerPaymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Payment amount (AFN)'**
  String get workerPaymentAmount;

  /// No description provided for @workerPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get workerPaymentMethod;

  /// No description provided for @workerMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get workerMethodBank;

  /// No description provided for @workerReferenceOptional.
  ///
  /// In en, this message translates to:
  /// **'Reference (optional)'**
  String get workerReferenceOptional;

  /// No description provided for @workerNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get workerNotesOptional;

  /// No description provided for @workerRecordSalaryPayment.
  ///
  /// In en, this message translates to:
  /// **'Record salary payment'**
  String get workerRecordSalaryPayment;

  /// No description provided for @workerEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit worker'**
  String get workerEditAction;

  /// No description provided for @workerDraftSalaryAction.
  ///
  /// In en, this message translates to:
  /// **'Draft monthly salary'**
  String get workerDraftSalaryAction;

  /// No description provided for @workerNoSalaryPeriods.
  ///
  /// In en, this message translates to:
  /// **'No salary periods yet. Draft a monthly salary to begin.'**
  String get workerNoSalaryPeriods;

  /// No description provided for @workerReviewAndPost.
  ///
  /// In en, this message translates to:
  /// **'Review and post'**
  String get workerReviewAndPost;

  /// No description provided for @workerClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get workerClose;

  /// No description provided for @workerAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add worker'**
  String get workerAddAction;

  /// No description provided for @workerMetricActive.
  ///
  /// In en, this message translates to:
  /// **'Active workers'**
  String get workerMetricActive;

  /// No description provided for @workerMetricPostedSalary.
  ///
  /// In en, this message translates to:
  /// **'Posted salary in selected period'**
  String get workerMetricPostedSalary;

  /// No description provided for @workerMetricSalaryOwed.
  ///
  /// In en, this message translates to:
  /// **'Salary still owed'**
  String get workerMetricSalaryOwed;

  /// No description provided for @workerMetricPayroll.
  ///
  /// In en, this message translates to:
  /// **'Total monthly payroll'**
  String get workerMetricPayroll;

  /// No description provided for @workerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search name, mobile, or worker ID'**
  String get workerSearch;

  /// No description provided for @workerAllStatus.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get workerAllStatus;

  /// No description provided for @workerSalaryDue.
  ///
  /// In en, this message translates to:
  /// **'Salary due'**
  String get workerSalaryDue;

  /// No description provided for @workerSelectSalaryPeriod.
  ///
  /// In en, this message translates to:
  /// **'Select salary period'**
  String get workerSelectSalaryPeriod;

  /// No description provided for @workerNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No workers match this search.'**
  String get workerNoSearchResults;

  /// No description provided for @workerColumnWorkerId.
  ///
  /// In en, this message translates to:
  /// **'Worker / ID'**
  String get workerColumnWorkerId;

  /// No description provided for @workerColumnMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get workerColumnMobile;

  /// No description provided for @workerColumnMonthlySalary.
  ///
  /// In en, this message translates to:
  /// **'Monthly salary'**
  String get workerColumnMonthlySalary;

  /// No description provided for @workerColumnSalaryDue.
  ///
  /// In en, this message translates to:
  /// **'Salary due'**
  String get workerColumnSalaryDue;

  /// No description provided for @workerColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get workerColumnStatus;

  /// No description provided for @workerOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'Open profile'**
  String get workerOpenProfile;

  /// No description provided for @workerSalaryDueShort.
  ///
  /// In en, this message translates to:
  /// **'Salary due'**
  String get workerSalaryDueShort;

  /// No description provided for @workerDraftStatus.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get workerDraftStatus;

  /// No description provided for @billNumberValue.
  ///
  /// In en, this message translates to:
  /// **'Bill number: {billNumber}'**
  String billNumberValue(Object billNumber);

  /// No description provided for @customersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other {# customers} one {# customer} =0 {No customers}}'**
  String customersCount(num count);

  /// No description provided for @newOrderFor.
  ///
  /// In en, this message translates to:
  /// **'New order · {customerName}'**
  String newOrderFor(Object customerName);

  /// No description provided for @measurementsTitle.
  ///
  /// In en, this message translates to:
  /// **'{action} {garment} measurements'**
  String measurementsTitle(Object action, Object garment);

  /// No description provided for @measurementProfiles.
  ///
  /// In en, this message translates to:
  /// **'{garment} profiles'**
  String measurementProfiles(Object garment);

  /// No description provided for @savedProfile.
  ///
  /// In en, this message translates to:
  /// **'Saved · {profileName}'**
  String savedProfile(Object profileName);

  /// No description provided for @updatedDate.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String updatedDate(Object date);

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance: {amount}'**
  String currentBalance(Object amount);

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String phoneLabel(Object phone);

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address: {address}'**
  String addressLabel(Object address);

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes: {notes}'**
  String notesLabel(Object notes);

  /// No description provided for @dueDateValue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueDateValue(Object date);

  /// No description provided for @balanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance {amount}'**
  String balanceLabel(Object amount);

  /// No description provided for @customerIdPhone.
  ///
  /// In en, this message translates to:
  /// **'{customerId} · {phone}'**
  String customerIdPhone(Object customerId, Object phone);

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining {amount}'**
  String remaining(Object amount);

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available: {quantity} {unit}'**
  String available(Object quantity, Object unit);

  /// No description provided for @stillOutstanding.
  ///
  /// In en, this message translates to:
  /// **'This order still has {amount} outstanding. You can still mark it delivered.'**
  String stillOutstanding(Object amount);

  /// No description provided for @confirmHandedOver.
  ///
  /// In en, this message translates to:
  /// **'Confirm that order {orderNumber} has been handed to the customer.'**
  String confirmHandedOver(Object orderNumber);

  /// No description provided for @profileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} profiles'**
  String profileCount(Object count);

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Please enter {field}.'**
  String requiredField(Object field);

  /// No description provided for @monthDay.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String monthDay(Object date);

  /// No description provided for @activityEntry.
  ///
  /// In en, this message translates to:
  /// **'{activity} · {customerName}'**
  String activityEntry(Object activity, Object customerName);

  /// No description provided for @referenceAndDate.
  ///
  /// In en, this message translates to:
  /// **'{reference} · {date}'**
  String referenceAndDate(Object date, Object reference);

  /// No description provided for @garmentCount.
  ///
  /// In en, this message translates to:
  /// **'{garment} × {count}'**
  String garmentCount(Object count, Object garment);

  /// No description provided for @dueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueDateLabel(Object date);

  /// No description provided for @fabricFormOpeningQty.
  ///
  /// In en, this message translates to:
  /// **'Opening quantity (meters)'**
  String get fabricFormOpeningQty;

  /// No description provided for @fabricFormPurchaseCost.
  ///
  /// In en, this message translates to:
  /// **'Buying price per meter (AFN)'**
  String get fabricFormPurchaseCost;

  /// No description provided for @fabricFormSellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price per meter (AFN)'**
  String get fabricFormSellingPrice;

  /// No description provided for @fabricFormOpeningValue.
  ///
  /// In en, this message translates to:
  /// **'Opening stock cost: {amount}'**
  String fabricFormOpeningValue(Object amount);

  /// No description provided for @fabricFormPrecision.
  ///
  /// In en, this message translates to:
  /// **'Enter a non-negative number with up to {places} decimal places.'**
  String fabricFormPrecision(Object places);

  /// No description provided for @saveExpenseError.
  ///
  /// In en, this message translates to:
  /// **'Could not save expense: {error}'**
  String saveExpenseError(Object error);

  /// No description provided for @expenseDescriptionField.
  ///
  /// In en, this message translates to:
  /// **'Description: {value}'**
  String expenseDescriptionField(Object value);

  /// No description provided for @filteredPostedTotal.
  ///
  /// In en, this message translates to:
  /// **'Filtered posted total: {amount}'**
  String filteredPostedTotal(Object amount);

  /// No description provided for @reverseExpenseConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This keeps expense {expenseNumber} in the history and removes it from expense totals.'**
  String reverseExpenseConfirmation(Object expenseNumber);

  /// No description provided for @expenseDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {value}'**
  String expenseDate(Object value);

  /// No description provided for @loadExpensesError.
  ///
  /// In en, this message translates to:
  /// **'Could not load expenses: {error}'**
  String loadExpensesError(Object error);

  /// No description provided for @recordedAt.
  ///
  /// In en, this message translates to:
  /// **'Recorded: {value}'**
  String recordedAt(Object value);

  /// No description provided for @expenseCategory.
  ///
  /// In en, this message translates to:
  /// **'Category: {value}'**
  String expenseCategory(Object value);

  /// No description provided for @reportGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated {date}'**
  String reportGeneratedAt(Object date);

  /// No description provided for @reportDateBasis.
  ///
  /// In en, this message translates to:
  /// **'Display calendar: {calendar}. Dates are stored internally as Gregorian ISO dates.'**
  String reportDateBasis(Object calendar);

  /// No description provided for @reportPeriodDateBasis.
  ///
  /// In en, this message translates to:
  /// **'Period: {period} · Display calendar: {calendar}. Records are stored as Gregorian ISO dates.'**
  String reportPeriodDateBasis(Object calendar, Object period);

  /// No description provided for @workerSalaryPeriod.
  ///
  /// In en, this message translates to:
  /// **'Salary period: {period}'**
  String workerSalaryPeriod(Object period);

  /// No description provided for @workerPaySalaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay {period} salary'**
  String workerPaySalaryTitle(Object period);

  /// No description provided for @workerRemainingSalary.
  ///
  /// In en, this message translates to:
  /// **'Remaining salary: {amount} AFN'**
  String workerRemainingSalary(Object amount);

  /// No description provided for @workerVoucherSaved.
  ///
  /// In en, this message translates to:
  /// **'Voucher {voucher} saved'**
  String workerVoucherSaved(Object voucher);

  /// No description provided for @workerMonthlySalaryInfo.
  ///
  /// In en, this message translates to:
  /// **'Monthly salary: {amount} AFN · {phone}'**
  String workerMonthlySalaryInfo(Object amount, Object phone);

  /// No description provided for @workerSalaryEntryStatus.
  ///
  /// In en, this message translates to:
  /// **'{period} · {status}'**
  String workerSalaryEntryStatus(Object period, Object status);

  /// No description provided for @workerSalaryEntryAmounts.
  ///
  /// In en, this message translates to:
  /// **'Salary {salary} AFN · paid {paid} AFN · due {due} AFN'**
  String workerSalaryEntryAmounts(Object due, Object paid, Object salary);

  /// No description provided for @reportNoteProfit.
  ///
  /// In en, this message translates to:
  /// **'Operating expenses are deducted after combining fabric profit and net stitching revenue.'**
  String get reportNoteProfit;

  /// No description provided for @reportProfitFabric.
  ///
  /// In en, this message translates to:
  /// **'Fabric profit'**
  String get reportProfitFabric;

  /// No description provided for @reportProfitStitching.
  ///
  /// In en, this message translates to:
  /// **'Stitching total'**
  String get reportProfitStitching;

  /// No description provided for @reportTypeStitching.
  ///
  /// In en, this message translates to:
  /// **'Stitching Report'**
  String get reportTypeStitching;

  /// No description provided for @reportTypeFabric.
  ///
  /// In en, this message translates to:
  /// **'Fabric Report'**
  String get reportTypeFabric;

  /// No description provided for @reportCategoryClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing Fabric'**
  String get reportCategoryClothing;

  /// No description provided for @reportCategoryWaistcoatCoat.
  ///
  /// In en, this message translates to:
  /// **'Waistcoat / Coat Fabric'**
  String get reportCategoryWaistcoatCoat;

  /// No description provided for @reportDatePreset.
  ///
  /// In en, this message translates to:
  /// **'Date preset'**
  String get reportDatePreset;

  /// No description provided for @reportNetStitchingRevenue.
  ///
  /// In en, this message translates to:
  /// **'Net Stitching Revenue'**
  String get reportNetStitchingRevenue;

  /// No description provided for @reportDirectStitchingCosts.
  ///
  /// In en, this message translates to:
  /// **'Direct Stitching Costs'**
  String get reportDirectStitchingCosts;

  /// No description provided for @reportGarmentQuantity.
  ///
  /// In en, this message translates to:
  /// **'Garment Quantity'**
  String get reportGarmentQuantity;

  /// No description provided for @reportGarmentQuantityDefinition.
  ///
  /// In en, this message translates to:
  /// **'Total garment pieces on confirmed orders created during the selected period.'**
  String get reportGarmentQuantityDefinition;

  /// No description provided for @reportNetMetersSold.
  ///
  /// In en, this message translates to:
  /// **'Total meters sold'**
  String get reportNetMetersSold;

  /// No description provided for @reportNetFabricSalesRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total fabric sales revenue'**
  String get reportNetFabricSalesRevenue;

  /// No description provided for @reportFabricCostOfSales.
  ///
  /// In en, this message translates to:
  /// **'Total fabric cost'**
  String get reportFabricCostOfSales;

  /// No description provided for @reportColumnFabricProfit.
  ///
  /// In en, this message translates to:
  /// **'Fabric profit'**
  String get reportColumnFabricProfit;

  /// No description provided for @reportFilterSource.
  ///
  /// In en, this message translates to:
  /// **'Sale source'**
  String get reportFilterSource;

  /// No description provided for @reportSourceAll.
  ///
  /// In en, this message translates to:
  /// **'All Fabric Sales'**
  String get reportSourceAll;

  /// No description provided for @reportSourceDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct Fabric Sales'**
  String get reportSourceDirect;

  /// No description provided for @reportSourceStitching.
  ///
  /// In en, this message translates to:
  /// **'Fabric Supplied with Stitching'**
  String get reportSourceStitching;

  /// No description provided for @reportFieldGarment.
  ///
  /// In en, this message translates to:
  /// **'Garment Type'**
  String get reportFieldGarment;

  /// No description provided for @reportFieldStitchingRevenue.
  ///
  /// In en, this message translates to:
  /// **'Net Stitching Charge (AFN)'**
  String get reportFieldStitchingRevenue;

  /// No description provided for @reportFieldDirectStitchingCost.
  ///
  /// In en, this message translates to:
  /// **'Direct Stitching Cost (AFN)'**
  String get reportFieldDirectStitchingCost;

  /// No description provided for @reportFieldCostRate.
  ///
  /// In en, this message translates to:
  /// **'Purchase/cost rate per meter'**
  String get reportFieldCostRate;

  /// No description provided for @reportFieldSellingRate.
  ///
  /// In en, this message translates to:
  /// **'Selling rate per meter'**
  String get reportFieldSellingRate;

  /// No description provided for @reportFieldTransactionType.
  ///
  /// In en, this message translates to:
  /// **'Transaction Type'**
  String get reportFieldTransactionType;

  /// No description provided for @reportFieldCostStatus.
  ///
  /// In en, this message translates to:
  /// **'Cost Status'**
  String get reportFieldCostStatus;

  /// No description provided for @reportTransactionSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get reportTransactionSale;

  /// No description provided for @reportTransactionReturn.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get reportTransactionReturn;

  /// No description provided for @reportCostStatusRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded inventory cost'**
  String get reportCostStatusRecorded;

  /// No description provided for @reportCostStatusEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated · recorded worker earnings only'**
  String get reportCostStatusEstimated;

  /// No description provided for @reportCostStatusIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete · some costs are not recorded'**
  String get reportCostStatusIncomplete;

  /// No description provided for @reportCostStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable · required costs are missing'**
  String get reportCostStatusUnavailable;

  /// No description provided for @reportStitchingCostNote.
  ///
  /// In en, this message translates to:
  /// **'Stitching profit uses the service charge after its share of invoice discounts, minus worker earnings linked to each order line. It is an estimate where other direct sewing costs are not allocated per order. Worker payments, advances, monthly salaries, and general shop expenses are not counted as order costs. Rows are selected by order date; linked worker earnings are included regardless of earning date.'**
  String get reportStitchingCostNote;

  /// No description provided for @reportFabricCostNote.
  ///
  /// In en, this message translates to:
  /// **'Fabric profit uses the selling price and purchase cost saved on each shop-fabric sale or customer order. Customer-owned fabric is excluded. Sale returns reverse revenue and restocked cost; shared order discounts are allocated once between stitching and shop fabric. Missing or unpriced rates are shown as incomplete.'**
  String get reportFabricCostNote;

  /// No description provided for @reportProfitWorkerSalaries.
  ///
  /// In en, this message translates to:
  /// **'Worker salaries and earnings'**
  String get reportProfitWorkerSalaries;

  /// No description provided for @reportMetricMonthlyProfit.
  ///
  /// In en, this message translates to:
  /// **'Monthly profit'**
  String get reportMetricMonthlyProfit;

  /// No description provided for @deleteCustomer.
  ///
  /// In en, this message translates to:
  /// **'Delete customer'**
  String get deleteCustomer;

  /// No description provided for @confirmDeleteCustomer.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this customer? This cannot be undone.'**
  String get confirmDeleteCustomer;

  /// No description provided for @customerDeleted.
  ///
  /// In en, this message translates to:
  /// **'Customer deleted'**
  String get customerDeleted;

  /// No description provided for @customerHasHistoryArchiveInstead.
  ///
  /// In en, this message translates to:
  /// **'This customer has saved records. Archive the customer instead.'**
  String get customerHasHistoryArchiveInstead;

  /// No description provided for @reportStitchingGrossProfit.
  ///
  /// In en, this message translates to:
  /// **'Stitching Gross Profit'**
  String get reportStitchingGrossProfit;

  /// No description provided for @reportFabricGrossProfit.
  ///
  /// In en, this message translates to:
  /// **'Total fabric profit'**
  String get reportFabricGrossProfit;

  /// No description provided for @reportClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get reportClearFilters;

  /// No description provided for @reportGrandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand total'**
  String get reportGrandTotal;

  /// No description provided for @reportCalculationBasis.
  ///
  /// In en, this message translates to:
  /// **'Calculation basis'**
  String get reportCalculationBasis;

  /// No description provided for @reportFieldPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get reportFieldPage;

  /// No description provided for @fabricFormCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a fabric category.'**
  String get fabricFormCategoryRequired;

  /// No description provided for @reportFabricProfitByItem.
  ///
  /// In en, this message translates to:
  /// **'Profit by Fabric'**
  String get reportFabricProfitByItem;

  /// No description provided for @reportFabricTransactions.
  ///
  /// In en, this message translates to:
  /// **'Sales Transactions'**
  String get reportFabricTransactions;

  /// No description provided for @reportBuyingPricePerMeter.
  ///
  /// In en, this message translates to:
  /// **'Buying Price / Meter (AFN)'**
  String get reportBuyingPricePerMeter;

  /// No description provided for @reportSellingPricePerMeter.
  ///
  /// In en, this message translates to:
  /// **'Selling Price / Meter (AFN)'**
  String get reportSellingPricePerMeter;

  /// No description provided for @reportProfitPerMeter.
  ///
  /// In en, this message translates to:
  /// **'Profit / Meter (AFN)'**
  String get reportProfitPerMeter;

  /// No description provided for @reportFabricPriceView.
  ///
  /// In en, this message translates to:
  /// **'Fabric Profit / Meter'**
  String get reportFabricPriceView;

  /// No description provided for @reportFabricPriceProfitNote.
  ///
  /// In en, this message translates to:
  /// **'Profit per meter is the current selling price minus the saved buying price for each active fabric. This current price comparison is not limited to the selected date range. Earned fabric profit continues to use recorded transaction prices and costs.'**
  String get reportFabricPriceProfitNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa', 'ps'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'fa':
      {
        switch (locale.countryCode) {
          case 'AF':
            return AppLocalizationsFaAf();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
    case 'ps':
      return AppLocalizationsPs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
