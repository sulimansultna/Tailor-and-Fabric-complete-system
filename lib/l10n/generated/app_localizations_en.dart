// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginBrandHeading => 'Your shop, organized.';

  @override
  String get loginBrandMessage =>
      'Manage customers, measurements, orders, and accounts in one place.';

  @override
  String get loginWelcomeBack => 'Welcome back.';

  @override
  String get loginSignInSubtitle => 'Sign in to continue.';

  @override
  String get loginOfflineNote => 'Works offline on this computer.';

  @override
  String get loginRememberHint => 'Use only on a trusted computer.';

  @override
  String get loginUsernameRequired => 'Enter your username.';

  @override
  String get loginPasswordRequired => 'Enter your password.';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get loginArtworkDescription => 'Tailoring scissors and a shirt emblem';

  @override
  String get appTitle => 'Tailor Shop';

  @override
  String get setupTitle => 'Set up your shop';

  @override
  String get setupDescription =>
      'Your records stay on this computer. You can change these details in Settings.';

  @override
  String get shopName => 'Shop name';

  @override
  String get ownerName => 'Owner name';

  @override
  String get mobileNumber => 'Mobile number';

  @override
  String get secondNumber => 'Second number (optional)';

  @override
  String get address => 'Address';

  @override
  String get receiptFooter => 'Receipt footer';

  @override
  String get language => 'Language';

  @override
  String get continueButton => 'Continue';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Try again';

  @override
  String get addCustomer => 'Add customer';

  @override
  String get customers => 'Customers';

  @override
  String get orders => 'Orders';

  @override
  String get delivery => 'Delivery';

  @override
  String get deliveryBoard => 'Delivery board';

  @override
  String get fabric => 'Fabric';

  @override
  String get fabricInventory => 'Fabric inventory';

  @override
  String get workers => 'Workers';

  @override
  String get expenses => 'Expenses';

  @override
  String get reports => 'Reports';

  @override
  String get settings => 'Settings';

  @override
  String get settingsPageSubtitle =>
      'Customize your shop and application preferences.';

  @override
  String get settingsAccountSecurity => 'Account & Security';

  @override
  String get settingsAccountSecurityDescription =>
      'Manage your username and account security.';

  @override
  String get settingsShopProfileSection => 'Shop Profile';

  @override
  String get settingsShopProfileDescription =>
      'View and update your shop name and contact details.';

  @override
  String get settingsEditShopProfile => 'Edit Shop Profile';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceDescription =>
      'Choose how the application looks on this computer.';

  @override
  String get settingsLightMode => 'Light Mode';

  @override
  String get settingsDarkMode => 'Dark Mode';

  @override
  String get settingsLightModeDescription =>
      'A light page with white cards and teal actions.';

  @override
  String get settingsDarkModeDescription =>
      'A dark page with comfortable light text.';

  @override
  String get settingsSelected => 'Selected';

  @override
  String get settingsLanguageCalendar => 'Language & Calendar';

  @override
  String get settingsLanguageCalendarDescription =>
      'Choose the application language and date calendar.';

  @override
  String get settingsPrimaryDate => 'Primary date';

  @override
  String get settingsSecondaryDate => 'Secondary date';

  @override
  String get settingsPaymentsReceipts => 'Payments & Receipts';

  @override
  String get settingsPaymentsReceiptsDescription =>
      'Payment methods and information shown on receipts.';

  @override
  String get settingsPaymentMethods => 'Payment Methods';

  @override
  String get settingsPaymentMethodsDescription =>
      'Available methods for recording payments.';

  @override
  String get settingsReceiptFooterDescription =>
      'Printed at the bottom of receipts.';

  @override
  String get settingsCurrencyDescription =>
      'Currency used for shop transactions.';

  @override
  String get settingsApplicationInformation => 'Application Information';

  @override
  String get settingsApplicationInformationDescription =>
      'Local storage and application details.';

  @override
  String get settingsDataStoredLocally =>
      'Your data is stored on this computer.';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsDatabasePath => 'Database path';

  @override
  String get settingsCopyPath => 'Copy path';

  @override
  String get settingsCopyPathTooltip => 'Copy the full path';

  @override
  String get settingsPathCopied => 'Path copied.';

  @override
  String get settingsBackupSectionDescription =>
      'Create a safe copy of shop data or restore a validated backup.';

  @override
  String get settingsBackupCreateDescription =>
      'Choose a folder and create a verified backup file.';

  @override
  String get settingsBackupRestoreDescription =>
      'Select a backup file to review it before restoring.';

  @override
  String get settingsNoBackupFolder =>
      'Choose a folder before creating a backup.';

  @override
  String get settingsNoBackupFile =>
      'Choose and validate a backup file before restoring.';

  @override
  String settingsThemeSaveError(Object error) {
    return 'Could not save the appearance preference: $error';
  }

  @override
  String get settingsLoadError => 'Settings could not be loaded.';

  @override
  String get settingsNoData => 'No settings data is available.';

  @override
  String get settingsMethodsCommaSeparated => 'Comma-separated methods';

  @override
  String get settingsPaymentMethodsHelp =>
      'These are manual records. Transfers are not verified.';

  @override
  String get settingsEnterPaymentMethod => 'Enter at least one payment method.';

  @override
  String settingsPaymentMethodsSaveError(Object error) {
    return 'Could not save payment methods: $error';
  }

  @override
  String get orderPrintingSettings => 'Order printing';

  @override
  String get orderPrintingSettingsDescription =>
      'Choose separate printers and paper sizes for the work slip and customer bill.';

  @override
  String get measurementPrinter => 'Measurement sheet printer';

  @override
  String get customerBillPrinter => 'Customer bill printer';

  @override
  String get defaultPrinter => 'Choose in the print dialog';

  @override
  String get paperSize => 'Paper size';

  @override
  String get paperA5 => 'A5';

  @override
  String get paperA4 => 'A4';

  @override
  String get paper80mm => '80 mm roll';

  @override
  String get paper55mm => '55 mm roll';

  @override
  String get refreshPrinters => 'Refresh printers';

  @override
  String get settingsSelectedBackupFile => 'Selected backup file';

  @override
  String get settingsBackupDisabledFolder =>
      'Choose a backup folder to enable this action.';

  @override
  String get settingsBackupDisabledFile =>
      'Choose a valid backup file to enable restore.';

  @override
  String get settingsNeverBackedUp => 'No successful backup yet.';

  @override
  String get home => 'Home';

  @override
  String get more => 'More';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get shopProfileAndData => 'Shop profile and local data';

  @override
  String get localDatabase => 'Local SQLite database';

  @override
  String get databaseStoredHere =>
      'Stored in the application support folder for this Windows user.';

  @override
  String get backupRestore => 'Backup / restore';

  @override
  String get backupPlanned =>
      'Backup and restore are planned for a future implementation stage.';

  @override
  String get modulePlanned =>
      'This module is reserved for a future implementation stage.';

  @override
  String get newOrder => 'New order';

  @override
  String get receivePayment => 'Receive payment';

  @override
  String get recordPayment => 'Record payment';

  @override
  String get saveOrder => 'Save order';

  @override
  String get reviewOrder => 'Review order';

  @override
  String get orderConfirmation => 'Confirm order';

  @override
  String get reviewOrderBeforeSaving =>
      'Review the saved measurement copies and charges before saving.';

  @override
  String get measurementWorkSlip => 'Measurement / work slip';

  @override
  String get customerBill => 'Customer bill';

  @override
  String get previewMeasurements => 'Preview measurements';

  @override
  String get previewCustomerBill => 'Preview customer bill';

  @override
  String get printMeasurements => 'Print measurements';

  @override
  String get printCustomerBill => 'Print customer bill';

  @override
  String get printBoth => 'Print both';

  @override
  String get saveOrderPrintBoth => 'Save order & print both';

  @override
  String get savedOrderPrintOptions =>
      'Your order and any advance payment are saved. Choose a document to preview, print, or export.';

  @override
  String get saveAsPdf => 'Save as PDF';

  @override
  String get printDocument => 'Print';

  @override
  String get preview => 'Preview';

  @override
  String get printCancelled =>
      'Printing was cancelled. Retry when the printer is ready.';

  @override
  String get printFailedRetry =>
      'Could not open the print job. Retry without saving the order again.';

  @override
  String get manualBillNumberHelp =>
      'Enter the bill number. Prefixes and leading zeros are kept.';

  @override
  String get editForThisOrder => 'Edit for this order';

  @override
  String get useMeasurementsForOrder => 'Use these measurements for this order';

  @override
  String get updateSavedMeasurements =>
      'Also update the saved customer measurements';

  @override
  String get confirmUpdateSavedMeasurements =>
      'Save these changes to the customer\'s active measurement profile? This is separate from the order snapshot.';

  @override
  String get savedMeasurementsUpdated => 'Customer measurements updated.';

  @override
  String get designInstructions => 'Design instructions';

  @override
  String get fittingInstructions => 'Fitting instructions';

  @override
  String get stitchingInstructions => 'Stitching instructions';

  @override
  String get designChoices => 'Design choices';

  @override
  String get measurementsHeading => 'Measurements';

  @override
  String get measurementValue => 'Value';

  @override
  String get optionYes => 'Yes';

  @override
  String get optionNo => 'No';

  @override
  String get designCuff => 'Cuff';

  @override
  String get designCollar => 'Collar';

  @override
  String get designBelt => 'Belt';

  @override
  String get designFrontPlacket => 'Front placket';

  @override
  String get designChestPocket => 'Chest pocket';

  @override
  String get designSidePocket => 'Side pocket';

  @override
  String get designRoundNeck => 'Round neck';

  @override
  String get designStraightNeck => 'Straight neck';

  @override
  String get designButtons => 'Buttons';

  @override
  String get designLining => 'Lining';

  @override
  String get designBackBelt => 'Back belt';

  @override
  String get designRoundedHem => 'Rounded hem';

  @override
  String get designVent => 'Back vent';

  @override
  String get designLapels => 'Lapels';

  @override
  String get orderInstructions => 'Order instructions';

  @override
  String get extraCharge => 'Extra charge (AFN)';

  @override
  String get discount => 'Discount (AFN)';

  @override
  String get orderSaved => 'Order saved';

  @override
  String get billNumber => 'Bill number';

  @override
  String get automaticBillNumber => 'Assigned automatically when saved';

  @override
  String get viewInvoice => 'View invoice';

  @override
  String get invoiceDetails => 'Invoice details';

  @override
  String get customerSuppliedNoCharge => 'Customer-supplied fabric (no charge)';

  @override
  String get paymentForSelectedBill =>
      'This payment will be applied to this bill only.';

  @override
  String get stitchingAmount => 'Stitching';

  @override
  String get fabricAmount => 'Shop fabric';

  @override
  String get billNotAssigned => 'Not assigned';

  @override
  String get billNumberRequired =>
      'Enter the bill number before confirming this order.';

  @override
  String get billNumberAlreadyUsed =>
      'That bill number is already in use. Enter a different number.';

  @override
  String get editOrder => 'Edit order';

  @override
  String get editInvoice => 'Edit Invoice';

  @override
  String editInvoiceTitle(Object billNumber) {
    return 'Edit Invoice — $billNumber';
  }

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get invoiceWorkerAssignments => 'Assigned workers';

  @override
  String get invoiceAssignedWorker => 'Worker';

  @override
  String get invoiceWorkLocked =>
      'Work has started. Change this assignment from the Workers screen.';

  @override
  String get invoiceCustomerLocked =>
      'The customer cannot be changed after payments have been recorded.';

  @override
  String get billNumberUpdated => 'Bill number updated.';

  @override
  String get saveCustomer => 'Save customer';

  @override
  String get saveMeasurements => 'Save measurements';

  @override
  String get refreshDashboard => 'Refresh dashboard';

  @override
  String get greeting => 'Good day';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get ordersReceivedToday => 'Orders received today';

  @override
  String get toHandOverToday => 'To be handed over today';

  @override
  String get pastDueDate => 'Past the due date';

  @override
  String get readyForPickup => 'Ready for customer pickup';

  @override
  String get paymentsToday => 'Payments today';

  @override
  String get paymentsRecordedToday => 'Payments recorded today';

  @override
  String get currentLedgerBalance => 'Current ledger balance';

  @override
  String get searchCustomers => 'Search customers';

  @override
  String get searchCustomersHint => 'Search by name, phone, or customer ID';

  @override
  String get searchCustomerByNamePhone =>
      'Search customer by name or mobile number';

  @override
  String get searchOrderHint => 'Search order number, customer, or phone';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get customerId => 'Customer ID';

  @override
  String get outstanding => 'Outstanding';

  @override
  String get outstandingBalance => 'Outstanding balance';

  @override
  String get noMatchingCustomers =>
      'No matching customers. Add a new customer to begin.';

  @override
  String get noCustomersYet =>
      'No customers yet. Add a customer to start taking orders.';

  @override
  String get recentCustomers => 'Recent customers';

  @override
  String get noResults => 'No customers found';

  @override
  String get viewAll => 'View all';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get searchError => 'Search could not be completed.';

  @override
  String get chooseCustomer => 'Choose a customer';

  @override
  String get searchNamePhone => 'Search name or mobile number';

  @override
  String get noCustomerToOrder => 'No customers found. Add a customer first.';

  @override
  String get dashboardLoadError => 'Dashboard data could not be loaded.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get attention => 'Needs attention';

  @override
  String get emptyOrders => 'No orders in this group.';

  @override
  String get openOrder => 'Open order';

  @override
  String get markDelivered => 'Mark delivered';

  @override
  String get upcomingDeliveries => 'Upcoming deliveries';

  @override
  String get emptyDeliveries => 'No upcoming deliveries.';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get emptyActivity => 'No recent activity.';

  @override
  String get paymentActivity => 'Payment received';

  @override
  String get readyActivity => 'Order ready';

  @override
  String get deliveredActivity => 'Order delivered';

  @override
  String get newOrderActivity => 'New order';

  @override
  String get refresh => 'Refresh dashboard';

  @override
  String get newToday => 'New today';

  @override
  String get dueToday => 'Due today';

  @override
  String get overdue => 'Overdue';

  @override
  String get ready => 'Ready';

  @override
  String get customerBalance => 'Customer balance';

  @override
  String get newOrdersDescription => 'Orders received today';

  @override
  String get toHandOverDescription => 'To be handed over today';

  @override
  String get pastDueDescription => 'Past the due date';

  @override
  String get pickupDescription => 'Ready for customer pickup';

  @override
  String get paymentsRecordedDescription => 'Payments recorded today';

  @override
  String get ledgerBalanceDescription => 'Current ledger balance';

  @override
  String get shalwar => 'Shalwar Kameez';

  @override
  String get waistcoat => 'Waistcoat';

  @override
  String get coat => 'Coat';

  @override
  String get kameezLength => 'Kameez length';

  @override
  String get shoulderWidth => 'Shoulder width';

  @override
  String get sleeveLength => 'Sleeve length';

  @override
  String get chest => 'Chest';

  @override
  String get waist => 'Waist';

  @override
  String get hipSeat => 'Hip / seat';

  @override
  String get neckCollar => 'Neck / collar';

  @override
  String get neck => 'Neck';

  @override
  String get upperArm => 'Upper arm';

  @override
  String get cuffWrist => 'Cuff / wrist';

  @override
  String get shalwarLength => 'Shalwar length';

  @override
  String get shalwarWaist => 'Shalwar waist';

  @override
  String get thigh => 'Thigh';

  @override
  String get bottomOpening => 'Bottom opening';

  @override
  String get waistcoatLength => 'Waistcoat length';

  @override
  String get armhole => 'Armhole';

  @override
  String get coatLength => 'Coat length';

  @override
  String get wristSleeveOpening => 'Wrist / sleeve opening';

  @override
  String get finishedGarmentLength => 'Finished garment length';

  @override
  String get finishedSleeveLength => 'Finished sleeve length';

  @override
  String get width => 'Width';

  @override
  String get circumference => 'Circumference';

  @override
  String get received => 'Received';

  @override
  String get cutting => 'Cutting';

  @override
  String get stitching => 'Stitching';

  @override
  String get delivered => 'Delivered';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get garment => 'Garment';

  @override
  String get measurementProfile => 'Measurement profile';

  @override
  String get noProfileDraftOrder => 'No profile · draft order';

  @override
  String get quantity => 'Quantity';

  @override
  String get pricePerItem => 'Stitching charge (AFN)';

  @override
  String get orderDetails => 'Order details';

  @override
  String get orderSummary => 'Order summary';

  @override
  String get advancePayment => 'Advance payment (AFN)';

  @override
  String get remainingBalance => 'Remaining balance';

  @override
  String get advancePaymentLedgerHint =>
      'This payment reduces the balance and is recorded in the customer ledger.';

  @override
  String get deliveryDate => 'Delivery date (YYYY-MM-DD)';

  @override
  String get styleOrderNotes => 'Style / order notes';

  @override
  String get reviewMeasurements => 'Review measurements';

  @override
  String get checkOrderAmounts => 'Check quantity, price, and advance amount.';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get addMeasurements => 'Add measurements';

  @override
  String get profileName => 'Profile name';

  @override
  String get measurementUnit => 'Measurement unit';

  @override
  String get inches => 'Inches';

  @override
  String get centimeters => 'Centimeters';

  @override
  String get measurementInstructions =>
      'Enter body measurements unless marked “finished garment”.';

  @override
  String get additionalNotes => 'Additional notes';

  @override
  String get noProfiles => 'No profiles saved yet.';

  @override
  String get duplicateEdit => 'Duplicate / edit';

  @override
  String get newProfile => 'New profile';

  @override
  String get view => 'View';

  @override
  String get notAdded => 'Not added';

  @override
  String get addCustomerDialog => 'Add customer';

  @override
  String get fullName => 'Full name';

  @override
  String get enterCustomerName => 'Enter the customer name';

  @override
  String get enterMobile => 'Enter a mobile number';

  @override
  String get optional => 'optional';

  @override
  String get numberAlreadyUsed => 'Number already in use';

  @override
  String get duplicatePhoneQuestion =>
      'This number belongs to another customer. Save it as a shared family number?';

  @override
  String get goBack => 'Go back';

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get customerAdded => 'Customer added';

  @override
  String get receivePaymentTitle => 'Receive payment';

  @override
  String get customer => 'Customer';

  @override
  String get amountAFN => 'Amount (AFN)';

  @override
  String get method => 'Method';

  @override
  String get cash => 'Cash';

  @override
  String get bankTransfer => 'Bank transfer';

  @override
  String get other => 'Other';

  @override
  String get selectCustomerAndAmount =>
      'Select a customer and enter an amount greater than zero.';

  @override
  String get paymentRecorded => 'Payment recorded';

  @override
  String get paymentReceived => 'Payment received';

  @override
  String get addCustomerTitle => 'Add customer';

  @override
  String get customerOrders => 'Customer orders';

  @override
  String get customerLedger => 'Customer ledger';

  @override
  String get customerInformation => 'Customer information';

  @override
  String get noOrdersYet => 'No orders yet.';

  @override
  String get noLedgerEntries => 'No ledger entries.';

  @override
  String get notSet => 'Not set';

  @override
  String get balanceWord => 'balance';

  @override
  String get newCustomerCode => 'New';

  @override
  String get searchRecent => 'Recent customers';

  @override
  String get outstandingFilter => 'Outstanding balance';

  @override
  String get noOrdersFound => 'No orders found.';

  @override
  String get all => 'All';

  @override
  String get searchOrders => 'Search order number, customer, or phone';

  @override
  String get noDeliveries => 'No upcoming deliveries.';

  @override
  String get due => 'Due';

  @override
  String get openOrderAction => 'Open order';

  @override
  String get sellFabric => 'Sell fabric';

  @override
  String get fabricLoadError => 'Fabric and customer data could not be loaded.';

  @override
  String get noActiveFabric => 'No active fabric stock is available.';

  @override
  String get fabricName => 'Fabric';

  @override
  String get customerOptionalPaid => 'Customer (optional for paid sale)';

  @override
  String get walkInCustomer => 'Walk-in customer';

  @override
  String get unitPrice => 'Unit price (AFN)';

  @override
  String get paidNow => 'Paid now (AFN)';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get saleTotal => 'Sale total';

  @override
  String get remainingStock => 'Remaining stock';

  @override
  String get fabricNotEnoughStock =>
      'Not enough available fabric for this quantity.';

  @override
  String get recordSale => 'Record sale';

  @override
  String get orderDeliveredConfirm => 'Mark order delivered?';

  @override
  String get orderDelivered => 'Order marked delivered';

  @override
  String get orderUpdateFailed => 'Could not update order.';

  @override
  String get manageCustomersDescription =>
      'Manage customers, measurements, orders, and balances.';

  @override
  String get searchCustomersHintFull =>
      'Search by name, mobile number, or customer ID';

  @override
  String get filterAllCustomers => 'All customers';

  @override
  String get filterWithOutstanding => 'With outstanding balance';

  @override
  String get filterWithActiveOrders => 'With active orders';

  @override
  String get filterArchived => 'Archived';

  @override
  String get sortCustomers => 'Sort customers';

  @override
  String get sortByName => 'Name';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortOutstanding => 'Outstanding balance';

  @override
  String get activeOrders => 'Active orders';

  @override
  String get copyPhone => 'Copy phone number';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get customerArchived => 'Customer archived';

  @override
  String get customerRestored => 'Customer restored';

  @override
  String get archiveCustomer => 'Archive customer';

  @override
  String get restoreCustomer => 'Restore customer';

  @override
  String get noSearchResultsFor => 'No results for';

  @override
  String get openingBalance => 'Opening balance (AFN)';

  @override
  String get openingBalanceHelp =>
      'Enter a starting amount if the customer already owes you or has credit.';

  @override
  String get debt => 'Owes shop';

  @override
  String get credit => 'Customer credit';

  @override
  String get customerUpdated => 'Customer updated';

  @override
  String get editCustomer => 'Edit customer';

  @override
  String get optionalDetails => 'Optional details and opening balance';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get discardChanges => 'Discard the changes you made?';

  @override
  String get discard => 'Discard';

  @override
  String get totalBilled => 'Total billed';

  @override
  String get totalPaid => 'Total paid';

  @override
  String get measurementsSaved => 'Measurements saved';

  @override
  String get noMeasurementsYet => 'No measurements yet';

  @override
  String get viewMeasurements => 'View measurements';

  @override
  String get customerCredit => 'Available customer credit';

  @override
  String get customerRegistrationDate => 'Registered';

  @override
  String get paymentStatus => 'Payment status';

  @override
  String get productionStatus => 'Production status';

  @override
  String get paidInFull => 'Paid in full';

  @override
  String get partiallyPaid => 'Partially paid';

  @override
  String get unpaid => 'Unpaid';

  @override
  String get orderDate => 'Order date';

  @override
  String get noOrdersMatch => 'No orders match these filters.';

  @override
  String get outstandingZero => 'No outstanding balance';

  @override
  String get confirmArchiveCustomer =>
      'This hides the customer from active lists. Their orders, measurements, and ledger remain saved.';

  @override
  String get openProfile => 'Open profile';

  @override
  String get dateFilter => 'Filter from date';

  @override
  String get payments => 'Payments';

  @override
  String get backup => 'Backup';

  @override
  String get currency => 'Currency';

  @override
  String get restore => 'Restore';

  @override
  String get amountGreaterZero => 'Amount must be greater than zero.';

  @override
  String get dateFormat => 'Date (YYYY-MM-DD)';

  @override
  String get profileStandard => 'Standard';

  @override
  String get style => 'Style';

  @override
  String get reference => 'Reference';

  @override
  String get status => 'Status';

  @override
  String get total => 'Total';

  @override
  String get clear => 'Clear';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get selectLanguage => 'Choose language';

  @override
  String get english => 'English';

  @override
  String get pashto => 'پښتو';

  @override
  String get dari => 'دری';

  @override
  String get paymentMethodLabel => 'Payment method';

  @override
  String get languageChanged => 'Language changed';

  @override
  String get garmentSummaryHeader => 'Garment summary';

  @override
  String get noProfilesYet => 'No profiles saved yet.';

  @override
  String get fabricFormDetails => 'Fabric Details';

  @override
  String get fabricFormName => 'Fabric name';

  @override
  String get fabricFormCode => 'Fabric code';

  @override
  String get fabricFormCategory => 'Category';

  @override
  String get fabricFormAddCategory => 'Add category';

  @override
  String get fabricFormCategoryName => 'Category name';

  @override
  String get fabricFormColor => 'Color';

  @override
  String get fabricFormUnit => 'Unit';

  @override
  String fabricFormUnitDisplay(Object unit) {
    return 'Unit: $unit';
  }

  @override
  String fabricFormUnitReview(Object unit) {
    return 'Unit needs review: $unit';
  }

  @override
  String fabricFormCategoryReview(Object category) {
    return 'Review the existing category “$category”. Check the fabric record, then select Clothing Fabric or Waistcoat / Coat Fabric. Saving a category change does not change stock quantities or prices.';
  }

  @override
  String get fabricFormCategoryUncategorized => 'Uncategorized';

  @override
  String get fabricFormMeter => 'Meter';

  @override
  String get fabricFormOpeningPrices => 'Opening Stock & Prices';

  @override
  String get fabricFormLowStock => 'Low-stock alert (meters)';

  @override
  String get fabricFormOpeningHelp =>
      'Opening quantity is stock already held when registering this fabric.';

  @override
  String get fabricFormNotes => 'Notes';

  @override
  String get fabricFormOptionalNotes => 'Optional notes';

  @override
  String get fabricFormSave => 'Save Fabric';

  @override
  String get fabricFormSaveAnother => 'Save & Add Another';

  @override
  String get fabricFormNameRequired => 'Fabric name is required.';

  @override
  String get fabricFormCodeRequired => 'Fabric code is required.';

  @override
  String get fabricFormMoneyPrecision =>
      'Enter an amount with at most two decimal places.';

  @override
  String get fabricFormDuplicateCode => 'Fabric code already exists.';

  @override
  String get fabricFormSaved => 'Fabric saved.';

  @override
  String get fabricFormAdd => 'Add fabric';

  @override
  String get fabricFormEdit => 'Edit fabric';

  @override
  String get gregorianMiladi => 'Gregorian / Miladi';

  @override
  String get gregorianLabel => 'Gregorian';

  @override
  String get dateCalendarTitle => 'Date & Calendar';

  @override
  String get showBothDates => 'Show both dates';

  @override
  String get calendarLabel => 'Calendar';

  @override
  String get afghanSolarHijri => 'Afghan Solar Hijri / Shamsi';

  @override
  String get solarHijriLabel => 'Solar Hijri';

  @override
  String get allMethodsLabel => 'All methods';

  @override
  String get expensesDescription =>
      'Record shop expenses and review spending for the selected period.';

  @override
  String get printExpenseAmount => 'Amount';

  @override
  String get done => 'Done';

  @override
  String get suggestedAmountOptional => 'Suggested amount (optional)';

  @override
  String get amountLabel => 'Amount';

  @override
  String get expenseSaved => 'Expense saved.';

  @override
  String get receiptFormatError => 'Choose a PNG, JPEG, or WebP image.';

  @override
  String get newest => 'Newest';

  @override
  String get expensesToday => 'Expenses today';

  @override
  String get saveExpense => 'Save expense';

  @override
  String get archive => 'Archive';

  @override
  String get expenseDateLabel => 'Expense date';

  @override
  String get expenseCategories => 'Expense categories';

  @override
  String get amountRequired => 'Amount *';

  @override
  String get templateName => 'Template name';

  @override
  String get receipt => 'Receipt';

  @override
  String get allCategories => 'All categories';

  @override
  String get reasonRequired => 'Reason *';

  @override
  String get receiptSizeError => 'Receipt photos must be 5 MB or smaller.';

  @override
  String get selectedMonth => 'Selected month';

  @override
  String get thisMonthFilter => 'This month';

  @override
  String get categoryRequired => 'Category *';

  @override
  String get amountLowToHigh => 'Amount: low to high';

  @override
  String get reversal => 'Reversal';

  @override
  String get noTemplates => 'No templates saved.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get reverseExpense => 'Reverse expense';

  @override
  String get descriptionRequired => 'Description is required';

  @override
  String get amountHighToLow => 'Amount: high to low';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get printExpenseCategories => 'Category';

  @override
  String get referenceOptional => 'Reference (optional)';

  @override
  String get searchExpense => 'Search expense, payee, or reference';

  @override
  String get allStatusesLabel => 'All statuses';

  @override
  String get expenseNumber => 'Expense no.';

  @override
  String get payeeOptional => 'Payee (optional)';

  @override
  String get enterPositiveAmount => 'Enter an amount greater than zero';

  @override
  String get allMethods => 'All methods';

  @override
  String get expenseStatus => 'Status';

  @override
  String get selectedPeriodMetric => 'Selected period';

  @override
  String get selectedMonthMetric => 'Selected month';

  @override
  String get addExpense => 'Add expense';

  @override
  String get printExpenseDescription => 'Description';

  @override
  String get toDate => 'To date';

  @override
  String get chooseCategory => 'Add or choose a category';

  @override
  String get descriptionPayeeLabel => 'Description / payee';

  @override
  String get addCategory => 'Add category';

  @override
  String get selectDate => 'Select date';

  @override
  String get payeeLabel => 'Payee';

  @override
  String get allStatuses => 'All statuses';

  @override
  String get descriptionField => 'Description *';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get categoryLabel => 'Category';

  @override
  String get posted => 'Posted';

  @override
  String get renameCategory => 'Rename category';

  @override
  String get expenseNo => 'Expense no.';

  @override
  String get methodLabel => 'Method';

  @override
  String get none => 'None';

  @override
  String get card => 'Card';

  @override
  String get noSuggestedAmount => 'No suggested amount';

  @override
  String get oldest => 'Oldest';

  @override
  String get expenseNumberLabel => 'Expense no.';

  @override
  String get newTemplate => 'New template';

  @override
  String get amount => 'Amount';

  @override
  String get expenseTodayMetric => 'Expenses today';

  @override
  String get expensesDescriptionShort =>
      'Record shop expenses and review spending.';

  @override
  String get saveTemplate => 'Save template';

  @override
  String get expenseTemplates => 'Expense templates';

  @override
  String get categoryName => 'Category name';

  @override
  String get attachReceipt => 'Attach receipt photo (5 MB max)';

  @override
  String get noExpensesForPeriod =>
      'No expenses for this period. Add your first expense.';

  @override
  String get category => 'Category';

  @override
  String get rename => 'Rename';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get fromDate => 'From date';

  @override
  String get useTemplate => 'Use template';

  @override
  String get thisMonth => 'This month';

  @override
  String get reverse => 'Reverse';

  @override
  String get reversed => 'Reversed';

  @override
  String get date => 'Date';

  @override
  String get largestCategory => 'Largest category';

  @override
  String get expenseReport => 'Expense report';

  @override
  String get deleteTemplate => 'Delete template';

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get printReport => 'Print report';

  @override
  String get payee => 'Payee';

  @override
  String get no => 'No.';

  @override
  String get dateLabel => 'Date';

  @override
  String get descriptionPayee => 'Description / payee';

  @override
  String get saveAndAddAnother => 'Save & add another';

  @override
  String get statusLabel => 'Status';

  @override
  String get selectedPeriod => 'Selected period';

  @override
  String get notes => 'Notes';

  @override
  String get search => 'Search';

  @override
  String get addExpenseDescription =>
      'Record an ordinary shop cost. Worker salary is recorded in Workers.';

  @override
  String get viewDetails => 'View details';

  @override
  String get printExpenseMethod => 'Method';

  @override
  String get reportsDescription =>
      'Understand your shop\'s orders, sales, collections, stock, and expenses.';

  @override
  String get reportSavePdf => 'Save Full Report as PDF';

  @override
  String get reportPrintFull => 'Print Full Report';

  @override
  String get reportPrintFullTitle => 'Print full report';

  @override
  String get reportPrintFullConfirm =>
      'The complete report includes Overview, Orders, Sales, Collections, Customer Balances, Fabric, Purchases & Suppliers, Workers, Expenses, Profit, and calculation notes.';

  @override
  String get reportContinue => 'Continue';

  @override
  String get reportToday => 'Today';

  @override
  String get reportYesterday => 'Yesterday';

  @override
  String get reportThisWeek => 'This Week';

  @override
  String get reportThisMonth => 'This Month';

  @override
  String get reportLastMonth => 'Last Month';

  @override
  String get reportThisYear => 'This Year';

  @override
  String get reportCustomRange => 'Custom Range';

  @override
  String get reportFromDate => 'From date';

  @override
  String get reportToDate => 'To date';

  @override
  String get reportDateOrderError => 'From date must be on or before To date.';

  @override
  String get reportGenerationError =>
      'Report generation failed. Please try again.';

  @override
  String get reportGenerating => 'Generating…';

  @override
  String get reportGenerate => 'Generate Report';

  @override
  String get reportNeedsRegeneration => 'Needs regeneration';

  @override
  String get reportSelectPeriod =>
      'Select a period and generate a report from saved records.';

  @override
  String get reportDismiss => 'Dismiss';

  @override
  String get reportPrintCurrentSection => 'Print Current Section';

  @override
  String get reportUnavailable => 'Unavailable';

  @override
  String get reportNoActivity => 'No activity in this period.';

  @override
  String get reportSearchSection => 'Search customer, bill, garment, or fabric';

  @override
  String get reportNoActivityOrSearch =>
      'No activity in this period, or no rows match the search.';

  @override
  String get reportFullTitle => 'Full report';

  @override
  String get reportShopTitle => 'Shop report';

  @override
  String get reportPeriod => 'Period';

  @override
  String get reportThrough => 'through';

  @override
  String get reportGenerated => 'Generated';

  @override
  String get reportSection => 'Section';

  @override
  String get reportField => 'Field';

  @override
  String get reportValue => 'Value';

  @override
  String get reportCalculationNotes => 'Calculation notes and limitations';

  @override
  String get reportOverview => 'Overview';

  @override
  String get reportActiveFilters => 'Filters';

  @override
  String get reportSales => 'Sales';

  @override
  String get reportCollections => 'Collections';

  @override
  String get reportCustomerBalances => 'Customer balances';

  @override
  String get reportPurchasesSuppliers => 'Purchases & suppliers';

  @override
  String get reportProfit => 'Profit';

  @override
  String get reportCustomerCollections => 'Customer collections';

  @override
  String get reportCustomerClosingBalances => 'Customer closing balances';

  @override
  String get reportFabricMovements => 'Fabric movements and closing stock';

  @override
  String get reportFabricPurchases => 'Fabric purchases and supplier balances';

  @override
  String get reportOperatingExpenses => 'Operating expenses';

  @override
  String get reportProfitSummary => 'Profit summary';

  @override
  String get reportCalculationLimitations =>
      'Calculation notes and limitations';

  @override
  String get reportMetricOrders => 'Confirmed orders created';

  @override
  String get reportMetricSales => 'Net invoiced sales';

  @override
  String get reportMetricReceipts => 'Customer payments received';

  @override
  String get reportMetricRefunds => 'Customer refunds';

  @override
  String get reportMetricNetCollections => 'Net customer collections';

  @override
  String get reportMetricExpenses => 'Operating expenses';

  @override
  String get reportMetricCustomerDebt =>
      'Customer outstanding debt at period end';

  @override
  String get reportMetricCustomerCredit => 'Customer credit at period end';

  @override
  String get reportMetricWorkerPayable => 'Worker payable at period end';

  @override
  String get reportMetricSupplierPayable => 'Supplier payable at period end';

  @override
  String get reportMetricGrossProfit => 'Gross profit';

  @override
  String get reportMetricNetProfit => 'Net profit';

  @override
  String get reportBalanceLimitations =>
      'Balances are calculated through the selected period end. Fabric reservation figures show current reserved stock.';

  @override
  String get reportProfitUnavailable =>
      'Reliable cost of sales and complete historical status data are not available for a full accrual profit calculation.';

  @override
  String get reportNoteDates =>
      'Both selected dates are included. Dates are stored internally as Gregorian ISO dates.';

  @override
  String get reportNoteOrderStatus =>
      'Order status is current except delivery and cancellation events, which come from status history.';

  @override
  String get reportNoteBalances =>
      'Customer and supplier balances are derived from dated ledger entries through the selected end date.';

  @override
  String get reportNoteWorkerPayable =>
      'Worker payable combines dated earnings, posted monthly salary, and posted payments. Advances may not reconcile to this simplified report balance.';

  @override
  String get reportNoteFabricReservation =>
      'Fabric reserved quantity is current; reservation history is not stored by effective date.';

  @override
  String get reportOrdersGroup => 'Created';

  @override
  String get reportDeliveryEvents => 'Delivery events';

  @override
  String get reportRecords => 'Records';

  @override
  String get reportInvoiced => 'Invoiced';

  @override
  String get reportDirectFabric => 'Direct fabric sales';

  @override
  String get reportReceipts => 'Receipts';

  @override
  String get reportRefunds => 'Refunds';

  @override
  String get reportRefundTotal => 'Refund total';

  @override
  String get reportNet => 'Net';

  @override
  String get reportRows => 'Rows';

  @override
  String get reportDebt => 'Debt';

  @override
  String get reportCredit => 'Credit';

  @override
  String get reportMovements => 'Movements';

  @override
  String get reportPurchases => 'Purchases';

  @override
  String get reportSupplierPayments => 'Supplier payments';

  @override
  String get reportReturnsCredits => 'Returns and credits';

  @override
  String get reportSuppliers => 'Suppliers';

  @override
  String get reportPayable => 'Payable';

  @override
  String get reportEarnings => 'Earnings';

  @override
  String get reportSalaries => 'Salaries';

  @override
  String get reportPayments => 'Payments';

  @override
  String get reportBalances => 'Balances';

  @override
  String get reportCategories => 'Categories';

  @override
  String get reportCategorySubtotals => 'Category subtotals';

  @override
  String get reportFieldId => 'ID';

  @override
  String get reportFieldName => 'Name';

  @override
  String get reportFieldCustomer => 'Customer';

  @override
  String get reportFieldPhone => 'Phone';

  @override
  String get reportFieldOrderDate => 'Order date';

  @override
  String get reportFieldBillNumber => 'Bill number';

  @override
  String get reportFieldNumber => 'Number';

  @override
  String get reportFieldDueDate => 'Due date';

  @override
  String get reportFieldStatus => 'Status';

  @override
  String get reportFieldTotal => 'Total';

  @override
  String get reportFieldDiscount => 'Discount';

  @override
  String get reportFieldExtra => 'Extra charge';

  @override
  String get reportFieldStitchingTotal => 'Stitching total';

  @override
  String get reportFieldGarments => 'Garments';

  @override
  String get reportFieldDate => 'Date';

  @override
  String get reportFieldReference => 'Reference';

  @override
  String get reportFieldMethod => 'Method';

  @override
  String get reportFieldAmount => 'Amount';

  @override
  String get reportFieldReason => 'Reason';

  @override
  String get reportFieldBalance => 'Balance';

  @override
  String get reportFieldCode => 'Code';

  @override
  String get reportFieldFabric => 'Fabric';

  @override
  String get reportFieldUnit => 'Unit';

  @override
  String get reportFieldAverageCost => 'Average cost';

  @override
  String get reportFieldOpeningMilli => 'Opening quantity (milliunits)';

  @override
  String get reportFieldMovementMilli => 'Movement quantity (milliunits)';

  @override
  String get reportFieldClosingMilli => 'Closing quantity (milliunits)';

  @override
  String get reportFieldKind => 'Type';

  @override
  String get reportFieldSourceType => 'Source type';

  @override
  String get reportFieldQuantityMilli => 'Quantity (milliunits)';

  @override
  String get reportFieldOpeningMeters => 'Opening quantity (meters)';

  @override
  String get reportFieldMovementMeters => 'Movement quantity (meters)';

  @override
  String get reportFieldClosingMeters => 'Closing quantity (meters)';

  @override
  String get reportFieldQuantityMeters => 'Meters sold';

  @override
  String get reportFieldNetMeters => 'Net meters';

  @override
  String get reportFieldNetRevenue => 'Sales amount';

  @override
  String get reportFieldRecordedCost => 'Fabric cost';

  @override
  String get reportFieldGrossProfit => 'Gross profit (AFN)';

  @override
  String get reportFieldProfitPerMeter => 'Profit per meter (AFN)';

  @override
  String get reportFieldAverageRevenuePerMeter =>
      'Average revenue per meter (AFN)';

  @override
  String get reportFieldAverageCostPerMeter => 'Average cost per meter (AFN)';

  @override
  String get reportFieldReturnedMeters => 'Returned meters';

  @override
  String get reportFieldUnpricedStitchingLines =>
      'Unpriced stitching fabric lines';

  @override
  String get reportFieldMissingCostLines => 'Sales with missing cost';

  @override
  String get reportFieldCostAvailable => 'Cost available';

  @override
  String get reportFilterAll => 'All';

  @override
  String get reportNoteFabricProfit =>
      'Fabric profit includes posted direct fabric sales and separately priced shop fabric on stitching orders. Customer-owned fabric and stitching charges are excluded. Bundled or unpriced fabric lines are flagged; missing historical costs make gross profit unavailable for that fabric.';

  @override
  String get reportFieldUnitCost => 'Unit cost';

  @override
  String get reportFieldCostTotal => 'Total cost';

  @override
  String get reportFieldInvoiceReference => 'Invoice reference';

  @override
  String get reportFieldSupplier => 'Supplier';

  @override
  String get reportFieldPaid => 'Paid';

  @override
  String get reportFieldRefundAmount => 'Refund amount';

  @override
  String get reportFieldWorker => 'Worker';

  @override
  String get reportFieldTask => 'Task';

  @override
  String get reportFieldAcceptedQuantity => 'Accepted quantity';

  @override
  String get reportFieldRate => 'Rate';

  @override
  String get reportFieldPayable => 'Payable';

  @override
  String get reportFieldCategory => 'Category';

  @override
  String get reportFieldDescription => 'Description';

  @override
  String get reportFieldPayee => 'Payee';

  @override
  String get reportFieldReversalReason => 'Reversal reason';

  @override
  String get reportFieldSource => 'Source';

  @override
  String get reportStitchingOrder => 'Stitching order';

  @override
  String get reportDirectFabricSale => 'Direct fabric sale';

  @override
  String get workerDescription =>
      'Manage workers, monthly salary periods, and salary payments.';

  @override
  String get workerAdd => 'Add worker';

  @override
  String get workerEdit => 'Edit worker';

  @override
  String get workerFullName => 'Full name *';

  @override
  String get workerNameRequired => 'Name is required';

  @override
  String get workerMobile => 'Mobile number';

  @override
  String get workerMonthlySalary => 'Monthly salary (AFN) *';

  @override
  String get workerPositiveSalary => 'Enter a salary greater than zero';

  @override
  String get workerNotes => 'Notes';

  @override
  String get workerActive => 'Active';

  @override
  String get workerInactive => 'Inactive';

  @override
  String get workerPhoneUsedTitle => 'Phone number already used';

  @override
  String get workerPhoneUsedBody =>
      'Another worker has this mobile number. Shared numbers are allowed; continue if this is intentional.';

  @override
  String get workerReview => 'Review';

  @override
  String get workerSaving => 'Saving…';

  @override
  String get workerSave => 'Save worker';

  @override
  String get workerLoadError => 'Could not load workers. Please try again.';

  @override
  String get workerSaveError => 'Could not save worker. Please try again.';

  @override
  String get workerDraftSalaryTitle => 'Draft monthly salary';

  @override
  String get workerSalaryAmount => 'Salary amount (AFN)';

  @override
  String get workerSalaryReviewHint =>
      'Review the amount before posting. Each worker can have one salary entry per month.';

  @override
  String get workerSaveDraft => 'Save draft';

  @override
  String get workerPaymentAmount => 'Payment amount (AFN)';

  @override
  String get workerPaymentMethod => 'Method';

  @override
  String get workerMethodBank => 'Bank';

  @override
  String get workerReferenceOptional => 'Reference (optional)';

  @override
  String get workerNotesOptional => 'Notes (optional)';

  @override
  String get workerRecordSalaryPayment => 'Record salary payment';

  @override
  String get workerEditAction => 'Edit worker';

  @override
  String get workerDraftSalaryAction => 'Draft monthly salary';

  @override
  String get workerNoSalaryPeriods =>
      'No salary periods yet. Draft a monthly salary to begin.';

  @override
  String get workerReviewAndPost => 'Review and post';

  @override
  String get workerClose => 'Close';

  @override
  String get workerAddAction => 'Add worker';

  @override
  String get workerMetricActive => 'Active workers';

  @override
  String get workerMetricPostedSalary => 'Posted salary in selected period';

  @override
  String get workerMetricSalaryOwed => 'Salary still owed';

  @override
  String get workerMetricPayroll => 'Total monthly payroll';

  @override
  String get workerSearch => 'Search name, mobile, or worker ID';

  @override
  String get workerAllStatus => 'All statuses';

  @override
  String get workerSalaryDue => 'Salary due';

  @override
  String get workerSelectSalaryPeriod => 'Select salary period';

  @override
  String get workerNoSearchResults => 'No workers match this search.';

  @override
  String get workerColumnWorkerId => 'Worker / ID';

  @override
  String get workerColumnMobile => 'Mobile';

  @override
  String get workerColumnMonthlySalary => 'Monthly salary';

  @override
  String get workerColumnSalaryDue => 'Salary due';

  @override
  String get workerColumnStatus => 'Status';

  @override
  String get workerOpenProfile => 'Open profile';

  @override
  String get workerSalaryDueShort => 'Salary due';

  @override
  String get workerDraftStatus => 'Draft';

  @override
  String billNumberValue(Object billNumber) {
    return 'Bill number: $billNumber';
  }

  @override
  String customersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      zero: 'No customers',
      one: '# customer',
      other: '# customers',
    );
    return '$_temp0';
  }

  @override
  String newOrderFor(Object customerName) {
    return 'New order · $customerName';
  }

  @override
  String measurementsTitle(Object action, Object garment) {
    return '$action $garment measurements';
  }

  @override
  String measurementProfiles(Object garment) {
    return '$garment profiles';
  }

  @override
  String savedProfile(Object profileName) {
    return 'Saved · $profileName';
  }

  @override
  String updatedDate(Object date) {
    return 'Updated $date';
  }

  @override
  String currentBalance(Object amount) {
    return 'Current balance: $amount';
  }

  @override
  String phoneLabel(Object phone) {
    return 'Phone: $phone';
  }

  @override
  String addressLabel(Object address) {
    return 'Address: $address';
  }

  @override
  String notesLabel(Object notes) {
    return 'Notes: $notes';
  }

  @override
  String dueDateValue(Object date) {
    return 'Due $date';
  }

  @override
  String balanceLabel(Object amount) {
    return 'Balance $amount';
  }

  @override
  String customerIdPhone(Object customerId, Object phone) {
    return '$customerId · $phone';
  }

  @override
  String remaining(Object amount) {
    return 'Remaining $amount';
  }

  @override
  String available(Object quantity, Object unit) {
    return 'Available: $quantity $unit';
  }

  @override
  String stillOutstanding(Object amount) {
    return 'This order still has $amount outstanding. You can still mark it delivered.';
  }

  @override
  String confirmHandedOver(Object orderNumber) {
    return 'Confirm that order $orderNumber has been handed to the customer.';
  }

  @override
  String profileCount(Object count) {
    return '$count profiles';
  }

  @override
  String requiredField(Object field) {
    return 'Please enter $field.';
  }

  @override
  String monthDay(Object date) {
    return '$date';
  }

  @override
  String activityEntry(Object activity, Object customerName) {
    return '$activity · $customerName';
  }

  @override
  String referenceAndDate(Object date, Object reference) {
    return '$reference · $date';
  }

  @override
  String garmentCount(Object count, Object garment) {
    return '$garment × $count';
  }

  @override
  String dueDateLabel(Object date) {
    return 'Due $date';
  }

  @override
  String get fabricFormOpeningQty => 'Opening quantity (meters)';

  @override
  String get fabricFormPurchaseCost => 'Buying price per meter (AFN)';

  @override
  String get fabricFormSellingPrice => 'Selling price per meter (AFN)';

  @override
  String fabricFormOpeningValue(Object amount) {
    return 'Opening stock cost: $amount';
  }

  @override
  String fabricFormPrecision(Object places) {
    return 'Enter a non-negative number with up to $places decimal places.';
  }

  @override
  String saveExpenseError(Object error) {
    return 'Could not save expense: $error';
  }

  @override
  String expenseDescriptionField(Object value) {
    return 'Description: $value';
  }

  @override
  String filteredPostedTotal(Object amount) {
    return 'Filtered posted total: $amount';
  }

  @override
  String reverseExpenseConfirmation(Object expenseNumber) {
    return 'This keeps expense $expenseNumber in the history and removes it from expense totals.';
  }

  @override
  String expenseDate(Object value) {
    return 'Date: $value';
  }

  @override
  String loadExpensesError(Object error) {
    return 'Could not load expenses: $error';
  }

  @override
  String recordedAt(Object value) {
    return 'Recorded: $value';
  }

  @override
  String expenseCategory(Object value) {
    return 'Category: $value';
  }

  @override
  String reportGeneratedAt(Object date) {
    return 'Generated $date';
  }

  @override
  String reportDateBasis(Object calendar) {
    return 'Display calendar: $calendar. Dates are stored internally as Gregorian ISO dates.';
  }

  @override
  String reportPeriodDateBasis(Object calendar, Object period) {
    return 'Period: $period · Display calendar: $calendar. Records are stored as Gregorian ISO dates.';
  }

  @override
  String workerSalaryPeriod(Object period) {
    return 'Salary period: $period';
  }

  @override
  String workerPaySalaryTitle(Object period) {
    return 'Pay $period salary';
  }

  @override
  String workerRemainingSalary(Object amount) {
    return 'Remaining salary: $amount AFN';
  }

  @override
  String workerVoucherSaved(Object voucher) {
    return 'Voucher $voucher saved';
  }

  @override
  String workerMonthlySalaryInfo(Object amount, Object phone) {
    return 'Monthly salary: $amount AFN · $phone';
  }

  @override
  String workerSalaryEntryStatus(Object period, Object status) {
    return '$period · $status';
  }

  @override
  String workerSalaryEntryAmounts(Object due, Object paid, Object salary) {
    return 'Salary $salary AFN · paid $paid AFN · due $due AFN';
  }

  @override
  String get reportNoteProfit =>
      'Operating expenses are deducted after combining fabric profit and net stitching revenue.';

  @override
  String get reportProfitFabric => 'Fabric profit';

  @override
  String get reportProfitStitching => 'Stitching total';

  @override
  String get reportTypeStitching => 'Stitching Report';

  @override
  String get reportTypeFabric => 'Fabric Report';

  @override
  String get reportCategoryClothing => 'Clothing Fabric';

  @override
  String get reportCategoryWaistcoatCoat => 'Waistcoat / Coat Fabric';

  @override
  String get reportDatePreset => 'Date preset';

  @override
  String get reportNetStitchingRevenue => 'Net Stitching Revenue';

  @override
  String get reportDirectStitchingCosts => 'Direct Stitching Costs';

  @override
  String get reportGarmentQuantity => 'Garment Quantity';

  @override
  String get reportGarmentQuantityDefinition =>
      'Total garment pieces on confirmed orders created during the selected period.';

  @override
  String get reportNetMetersSold => 'Total meters sold';

  @override
  String get reportNetFabricSalesRevenue => 'Total fabric sales revenue';

  @override
  String get reportFabricCostOfSales => 'Total fabric cost';

  @override
  String get reportColumnFabricProfit => 'Fabric profit';

  @override
  String get reportFilterSource => 'Sale source';

  @override
  String get reportSourceAll => 'All Fabric Sales';

  @override
  String get reportSourceDirect => 'Direct Fabric Sales';

  @override
  String get reportSourceStitching => 'Fabric Supplied with Stitching';

  @override
  String get reportFieldGarment => 'Garment Type';

  @override
  String get reportFieldStitchingRevenue => 'Net Stitching Charge (AFN)';

  @override
  String get reportFieldDirectStitchingCost => 'Direct Stitching Cost (AFN)';

  @override
  String get reportFieldCostRate => 'Purchase/cost rate per meter';

  @override
  String get reportFieldSellingRate => 'Selling rate per meter';

  @override
  String get reportFieldTransactionType => 'Transaction Type';

  @override
  String get reportFieldCostStatus => 'Cost Status';

  @override
  String get reportTransactionSale => 'Sale';

  @override
  String get reportTransactionReturn => 'Return';

  @override
  String get reportCostStatusRecorded => 'Recorded inventory cost';

  @override
  String get reportCostStatusEstimated =>
      'Estimated · recorded worker earnings only';

  @override
  String get reportCostStatusIncomplete =>
      'Incomplete · some costs are not recorded';

  @override
  String get reportCostStatusUnavailable =>
      'Unavailable · required costs are missing';

  @override
  String get reportStitchingCostNote =>
      'Stitching profit uses the service charge after its share of invoice discounts, minus worker earnings linked to each order line. It is an estimate where other direct sewing costs are not allocated per order. Worker payments, advances, monthly salaries, and general shop expenses are not counted as order costs. Rows are selected by order date; linked worker earnings are included regardless of earning date.';

  @override
  String get reportFabricCostNote =>
      'Fabric profit uses the selling price and purchase cost saved on each shop-fabric sale or customer order. Customer-owned fabric is excluded. Sale returns reverse revenue and restocked cost; shared order discounts are allocated once between stitching and shop fabric. Missing or unpriced rates are shown as incomplete.';

  @override
  String get reportProfitWorkerSalaries => 'Worker salaries and earnings';

  @override
  String get reportMetricMonthlyProfit => 'Monthly profit';

  @override
  String get deleteCustomer => 'Delete customer';

  @override
  String get confirmDeleteCustomer =>
      'Permanently delete this customer? This cannot be undone.';

  @override
  String get customerDeleted => 'Customer deleted';

  @override
  String get customerHasHistoryArchiveInstead =>
      'This customer has saved records. Archive the customer instead.';

  @override
  String get reportStitchingGrossProfit => 'Stitching Gross Profit';

  @override
  String get reportFabricGrossProfit => 'Total fabric profit';

  @override
  String get reportClearFilters => 'Clear filters';

  @override
  String get reportGrandTotal => 'Grand total';

  @override
  String get reportCalculationBasis => 'Calculation basis';

  @override
  String get reportFieldPage => 'Page';

  @override
  String get fabricFormCategoryRequired => 'Choose a fabric category.';

  @override
  String get reportFabricProfitByItem => 'Profit by Fabric';

  @override
  String get reportFabricTransactions => 'Sales Transactions';

  @override
  String get reportBuyingPricePerMeter => 'Buying Price / Meter (AFN)';

  @override
  String get reportSellingPricePerMeter => 'Selling Price / Meter (AFN)';

  @override
  String get reportProfitPerMeter => 'Profit / Meter (AFN)';

  @override
  String get reportFabricPriceView => 'Fabric Profit / Meter';

  @override
  String get reportFabricPriceProfitNote =>
      'Profit per meter is the current selling price minus the saved buying price for each active fabric. This current price comparison is not limited to the selected date range. Earned fabric profit continues to use recorded transaction prices and costs.';
}
