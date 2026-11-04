import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommandKey {
  static const add = 'action.new';
  static const edit = 'action.edit';
  static const save = 'action.save';
  static const search = 'action.search';
  static const print = 'action.print';
  static const printBoth = 'action.printBoth';
  static const refresh = 'action.refresh';
  static const cancel = 'action.cancel';
  static const remove = 'action.delete';
  static const palette = 'action.palette';
  static const help = 'action.help';
}

const commandLabels = <String, (String, String, String)>{
  'nav.dashboard': ('Dashboard', 'عمومي کتنه', 'داشبورد'),
  'nav.customers': ('Customers', 'پېرودونکي', 'مشتریان'),
  'nav.orders': ('Orders / Invoices', 'فرمایشونه / بلونه', 'سفارش‌ها / بل‌ها'),
  'nav.delivery': ('Delivery Board', 'د سپارلو تخته', 'تابلوی تحویل'),
  'nav.fabric': ('Fabric Stock', 'د ټوکر زېرمه', 'موجودی تکه'),
  'nav.suppliers': ('Suppliers', 'عرضه کوونکي', 'تهیه‌کنندگان'),
  'nav.payments': ('Customer Payments', 'د پېرودونکو تادیې', 'پرداخت‌های مشتریان'),
  'nav.workers': ('Workers', 'کارکوونکي', 'کارکنان'),
  'nav.reports': ('Reports', 'راپورونه', 'گزارش‌ها'),
  'nav.purchases': ('Fabric Purchases', 'د ټوکر پېرود', 'خرید تکه'),
  'nav.customerLedger': ('Customer Ledger', 'د پېرودونکي حساب', 'دفتر حساب مشتری'),
  'nav.supplierLedger': ('Supplier Ledger', 'د عرضه کوونکي حساب', 'دفتر حساب تهیه‌کننده'),
  'nav.expenses': ('Expenses', 'لګښتونه', 'مصارف'),
  'nav.measurements': ('Measurements', 'اندازې', 'اندازه‌ها'),
  'nav.history': ('Delivered / Archived Orders', 'سپارل شوي / آرشیف شوي فرمایشونه', 'سفارش‌های تحویل‌شده / آرشیف‌شده'),
  'nav.settings': ('Settings', 'تنظیمات', 'تنظیمات'),
  'nav.backup': ('Backup and Restore settings', 'د بیک اپ او بیا رغولو تنظیمات', 'تنظیمات پشتیبان‌گیری و بازیابی'),
  CommandKey.add: ('Add / New on this screen', 'په دې پاڼه کې نوی ثبت', 'افزودن / جدید در این صفحه'),
  CommandKey.edit: ('Edit selected record', 'ټاکل شوی ریکارډ سمول', 'ویرایش ریکارد انتخاب‌شده'),
  CommandKey.save: ('Save / Review active form', 'روان فورم ثبت / کتنه', 'ثبت / بررسی فورم جاری'),
  CommandKey.search: ('Search this screen', 'په دې پاڼه کې لټون', 'جستجو در این صفحه'),
  CommandKey.print: ('Print preview / Print options', 'د چاپ مخکتنه / غوراوي', 'پیش‌نمایش / گزینه‌های چاپ'),
  CommandKey.printBoth: ('Print customer bill and measurement slip', 'د پېرودونکي بل او د اندازو پاڼه چاپول', 'چاپ بل مشتری و ورق اندازه‌ها'),
  CommandKey.refresh: ('Refresh current data', 'روان معلومات تازه کول', 'تازه‌سازی اطلاعات جاری'),
  CommandKey.cancel: ('Close / Cancel editing', 'تړل / سمون لغوه کول', 'بستن / لغو ویرایش'),
  CommandKey.remove: ('Remove selected record (confirmation)', 'ټاکلی ریکارډ لرې کول (تایید)', 'حذف ریکارد انتخاب‌شده (تأیید)'),
  CommandKey.palette: ('Global command palette', 'د ټولو امرونو لټون', 'جستجوی تمام فرمان‌ها'),
  CommandKey.help: ('Keyboard shortcut help', 'د کیبورډ لنډلارو لارښود', 'راهنمای کلیدهای میان‌بر'),
  'order.deliver': ('Mark order delivered', 'فرمایش سپارل شوی نښه کول', 'ثبت تحویل سفارش'),
  'order.archive': ('Archive delivered order', 'سپارل شوی فرمایش آرشیف کول', 'آرشیف سفارش تحویل‌شده'),
  'order.cancel': ('Cancel order', 'فرمایش لغوه کول', 'لغو سفارش'),
  'order.return': ('Return / Refund order', 'فرمایش بېرته اخیستل / پیسې بېرته ورکول', 'برگشت سفارش / بازپرداخت'),
  'order.restore': ('Restore archived order', 'آرشیف شوی فرمایش بېرته فعالول', 'بازگردانی سفارش آرشیف‌شده'),
  'customers.add': ('Add customer', 'پېرودونکی زیاتول', 'افزودن مشتری'),
  'customers.edit': ('Edit customer', 'پېرودونکی سمول', 'ویرایش مشتری'),
  'customers.remove': ('Remove / Archive customer', 'پېرودونکی لرې / آرشیف کول', 'حذف / آرشیف مشتری'),
  'customers.profile': ('Open customer profile', 'د پېرودونکي پاڼه', 'بازکردن پروفایل مشتری'),
  'customers.restore': ('Restore archived customer', 'آرشیف شوی پېرودونکی بېرته فعالول', 'بازگردانی مشتری آرشیف‌شده'),
  'measurements.add': ('Add / Edit measurements', 'اندازې زیاتول / سمول', 'افزودن / ویرایش اندازه‌ها'),
  'measurements.history': ('Measurement history', 'د اندازو مخینه', 'تاریخچه اندازه‌ها'),
  'orders.add': ('New order / invoice', 'نوی فرمایش / بل', 'سفارش / بل جدید'),
  'orders.edit': ('Edit invoice', 'بل سمول', 'ویرایش بل'),
  'orders.drafts': ('Open invoice drafts', 'د بلونو مسودې', 'مسوده‌های بل'),
  'orders.print': ('Customer bill print options', 'د پېرودونکي بل د چاپ غوراوي', 'گزینه‌های چاپ بل مشتری'),
  'orders.printBoth': ('Print Both: customer bill and measurements', 'دواړه چاپول: بل او اندازې', 'چاپ هر دو: بل و اندازه‌ها'),
  'orders.refund': ('Refund customer credit for an order', 'د فرمایش پیسې بېرته ورکول', 'بازپرداخت اعتبار مشتری برای سفارش'),
  'orders.remove': ('Cancel / Archive invoice and preserve history', 'بل لغوه / آرشیف کول او مخینه ساتل', 'لغو / آرشیف بل و حفظ تاریخچه'),
  'customers.archive': ('Archive customer', 'پېرودونکی آرشیف کول', 'آرشیف مشتری'),
  'orders.measurementPrint': ('Print measurement slip', 'د اندازو پاڼه چاپول', 'چاپ ورق اندازه‌ها'),
  'orders.history': ('Order change history', 'د فرمایش د بدلونونو مخینه', 'تاریخچه تغییرات سفارش'),
  'fabric.add': ('Add fabric', 'ټوکر زیاتول', 'افزودن تکه'),
  'fabric.edit': ('Edit fabric', 'ټوکر سمول', 'ویرایش تکه'),
  'fabric.remove': ('Remove fabric (existing policy)', 'ټوکر لرې کول', 'حذف تکه'),
  'fabric.sale': ('Fabric-only sale', 'یوازې د ټوکر پلور', 'فروش مستقل تکه'),
  'fabric.stockIn': ('Record fabric stock in', 'د ټوکر راتګ ثبتول', 'ثبت ورود تکه'),
  'fabric.adjust': ('Adjust fabric stock', 'د ټوکر زېرمه سمول', 'اصلاح موجودی تکه'),
  'fabric.archive': ('Archive / Restore fabric', 'ټوکر آرشیف / بېرته فعالول', 'آرشیف / بازگردانی تکه'),
  'fabric.details': ('Fabric details and history', 'د ټوکر جزئیات او مخینه', 'جزئیات و تاریخچه تکه'),
  'suppliers.add': ('Add supplier', 'عرضه کوونکی زیاتول', 'افزودن تهیه‌کننده'),
  'suppliers.edit': ('Edit supplier', 'عرضه کوونکی سمول', 'ویرایش تهیه‌کننده'),
  'suppliers.remove': ('Remove supplier (existing policy)', 'عرضه کوونکی لرې کول', 'حذف تهیه‌کننده'),
  'suppliers.archive': ('Archive / Restore supplier', 'عرضه کوونکی آرشیف / بېرته فعالول', 'آرشیف / بازگردانی تهیه‌کننده'),
  'suppliers.payment': ('Pay supplier', 'عرضه کوونکي ته تادیه', 'پرداخت به تهیه‌کننده'),
  'purchases.new': ('New fabric purchase', 'د ټوکر نوی پېرود', 'خرید جدید تکه'),
  'purchases.drafts': ('Open purchase drafts', 'د پېرود مسودې', 'مسوده‌های خرید'),
  'purchases.saveDraft': ('Save purchase draft', 'د پېرود مسوده ثبتول', 'ثبت مسوده خرید'),
  'purchases.confirm': ('Review / Confirm purchase', 'پېرود کتل / تاییدول', 'بررسی / تأیید خرید'),
  'purchases.print': ('Print posted purchase', 'ثبت شوی پېرود چاپول', 'چاپ خرید ثبت‌شده'),
  'payments.add': ('Receive customer payment', 'د پېرودونکي تادیه اخیستل', 'دریافت پرداخت مشتری'),
  'payments.details': ('Payment details', 'د تادیې جزئیات', 'جزئیات پرداخت'),
  'payments.print': ('Payment receipt print preview', 'د تادیې رسید د چاپ مخکتنه', 'پیش‌نمایش چاپ رسید پرداخت'),
  'payments.reverse': ('Reverse posted payment', 'ثبت شوې تادیه بېرته ګرځول', 'برگشت پرداخت ثبت‌شده'),
  'workers.add': ('Add worker', 'کارکوونکی زیاتول', 'افزودن کارمند'),
  'workers.edit': ('Edit worker', 'کارکوونکی سمول', 'ویرایش کارمند'),
  'workers.profile': ('Worker profile and salary history', 'د کارکوونکي پاڼه او د معاش مخینه', 'پروفایل کارمند و تاریخچه معاش'),
  'workers.salary': ('Create salary draft', 'د معاش مسوده جوړول', 'ایجاد مسوده معاش'),
  'expenses.add': ('Add expense', 'لګښت زیاتول', 'افزودن مصرف'),
  'expenses.reverse': ('Reverse posted expense', 'ثبت شوی لګښت بېرته ګرځول', 'برگشت مصرف ثبت‌شده'),
  'expenses.categories': ('Manage expense categories', 'د لګښتونو ډولونه اداره کول', 'مدیریت دسته‌های مصارف'),
  'expenses.templates': ('Expense templates', 'د لګښتونو قالبونه', 'قالب‌های مصارف'),
  'expenses.csv': ('Export expenses CSV', 'لګښتونه CSV ته ایستل', 'خروجی CSV مصارف'),
  'expenses.print': ('Print expense report', 'د لګښتونو راپور چاپول', 'چاپ گزارش مصارف'),
  'reports.generate': ('Generate / Refresh report', 'راپور جوړول / تازه کول', 'تهیه / تازه‌سازی گزارش'),
  'reports.range': ('Custom report date range', 'د راپور ټاکلې نېټې', 'محدوده تاریخ دلخواه گزارش'),
  'reports.pdf': ('Save report PDF', 'راپور PDF ته ثبتول', 'ذخیره PDF گزارش'),
  'reports.csv': ('Export report CSV', 'راپور CSV ته ایستل', 'خروجی CSV گزارش'),
  'reports.print': ('Print report preview', 'د راپور د چاپ مخکتنه', 'پیش‌نمایش چاپ گزارش'),
  'reports.overview': ('Overview report', 'عمومي راپور', 'گزارش عمومی'),
  'reports.stitching': ('Stitching report', 'د ګنډلو راپور', 'گزارش دوخت'),
  'reports.fabric': ('Fabric report', 'د ټوکر راپور', 'گزارش تکه'),
  'settings.language': ('Language settings', 'د ژبې تنظیمات', 'تنظیمات زبان'),
  'settings.calendar': ('Calendar settings', 'د کلیزې تنظیمات', 'تنظیمات تقویم'),
  'settings.theme': ('Light / Dark theme settings', 'روښانه / تیاره بڼه', 'تنظیمات ظاهر روشن / تاریک'),
  'settings.printing': ('Printer and paper settings', 'د چاپګر او کاغذ تنظیمات', 'تنظیمات چاپگر و کاغذ'),
  'settings.profile': ('Shop profile settings', 'د دوکان د معلوماتو تنظیمات', 'تنظیمات پروفایل دکان'),
  'settings.backup': ('Create business backup', 'د کاروبار بیک اپ جوړول', 'ایجاد پشتیبان کسب‌وکار'),
  'settings.restore': ('Choose backup to restore', 'د بیا رغولو بیک اپ ټاکل', 'انتخاب پشتیبان برای بازیابی'),
  'settings.signOut': ('Sign out', 'وتل', 'خروج'),
};

String commandText(BuildContext context, String id) {
  final key = id.startsWith('go.') ? id.substring(3) : id;
  final labels = commandLabels[key] ?? commandLabels[CommandKey.help]!;
  return localizedCommandText(context, labels.$1, labels.$2, labels.$3);
}

String localizedCommandText(BuildContext context, String en, String ps, String fa) =>
    switch (Localizations.localeOf(context).languageCode) { 'ps' => ps, 'fa' => fa, _ => en };

const commandShortcutLabels = <String, String>{
  'nav.dashboard': 'Ctrl+1', 'nav.customers': 'Ctrl+2', 'nav.orders': 'Ctrl+3',
  'nav.delivery': 'Ctrl+4', 'nav.fabric': 'Ctrl+5', 'nav.suppliers': 'Ctrl+6',
  'nav.payments': 'Ctrl+7', 'nav.workers': 'Ctrl+8', 'nav.reports': 'Ctrl+9',
  'nav.purchases': 'Ctrl+Shift+1', 'nav.customerLedger': 'Ctrl+Shift+2',
  'nav.supplierLedger': 'Ctrl+Shift+3', 'nav.expenses': 'Ctrl+Shift+4',
  'nav.measurements': 'Ctrl+Shift+5', 'nav.history': 'Ctrl+Shift+H',
  'nav.settings': 'Ctrl+,', 'nav.backup': 'Ctrl+Shift+B',
  CommandKey.add: 'Ctrl+N', CommandKey.edit: 'F2', CommandKey.save: 'Ctrl+S',
  CommandKey.search: 'Ctrl+F', CommandKey.print: 'Ctrl+P', CommandKey.printBoth: 'Ctrl+Shift+P',
  CommandKey.refresh: 'F5', CommandKey.palette: 'Ctrl+K', CommandKey.help: 'F1',
  CommandKey.cancel: 'Escape', CommandKey.remove: 'Delete',
  'order.deliver': 'Ctrl+Shift+D', 'order.archive': 'Ctrl+Shift+A',
  'order.cancel': 'Ctrl+Shift+X', 'order.return': 'Ctrl+Shift+T',
};

Map<ShortcutActivator, String> commandActivators() {
  SingleActivator key(LogicalKeyboardKey value, {bool control = false, bool shift = false}) =>
      SingleActivator(value, control: control, shift: shift, includeRepeats: false);
  final result = <ShortcutActivator, String>{};
  const destinations = ['nav.dashboard','nav.customers','nav.orders','nav.delivery','nav.fabric','nav.suppliers','nav.payments','nav.workers','nav.reports'];
  const numbers = [LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5, LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8, LogicalKeyboardKey.digit9];
  for (var index = 0; index < numbers.length; index++) { result[key(numbers[index], control: true)] = destinations[index]; }
  const shifted = ['nav.purchases','nav.customerLedger','nav.supplierLedger','nav.expenses','nav.measurements'];
  for (var index = 0; index < shifted.length; index++) { result[key(numbers[index], control: true, shift: true)] = shifted[index]; }
  for (final (logicalKey, id) in const [
    (LogicalKeyboardKey.keyN, CommandKey.add), (LogicalKeyboardKey.keyS, CommandKey.save),
    (LogicalKeyboardKey.keyF, CommandKey.search), (LogicalKeyboardKey.keyP, CommandKey.print),
    (LogicalKeyboardKey.keyK, CommandKey.palette), (LogicalKeyboardKey.comma, 'nav.settings'),
  ]) { result[key(logicalKey, control: true)] = id; }
  for (final (logicalKey, id) in const [
    (LogicalKeyboardKey.keyP, CommandKey.printBoth), (LogicalKeyboardKey.keyD, 'order.deliver'),
    (LogicalKeyboardKey.keyA, 'order.archive'), (LogicalKeyboardKey.keyX, 'order.cancel'),
    (LogicalKeyboardKey.keyT, 'order.return'), (LogicalKeyboardKey.keyH, 'nav.history'),
    (LogicalKeyboardKey.keyB, 'nav.backup'),
  ]) { result[key(logicalKey, control: true, shift: true)] = id; }
  for (final (logicalKey, id) in const [(LogicalKeyboardKey.f1, CommandKey.help),
    (LogicalKeyboardKey.f2, CommandKey.edit), (LogicalKeyboardKey.f5, CommandKey.refresh),
    (LogicalKeyboardKey.escape, CommandKey.cancel), (LogicalKeyboardKey.delete, CommandKey.remove)]) {
    result[key(logicalKey)] = id;
  }
  // Physical equivalents keep Ctrl shortcuts usable on Pashto/Dari layouts,
  // including shifted digits whose logical key becomes a punctuation mark.
  final physical = <LogicalKeyboardKey, PhysicalKeyboardKey>{
    LogicalKeyboardKey.digit1: PhysicalKeyboardKey.digit1, LogicalKeyboardKey.digit2: PhysicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3: PhysicalKeyboardKey.digit3, LogicalKeyboardKey.digit4: PhysicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5: PhysicalKeyboardKey.digit5, LogicalKeyboardKey.digit6: PhysicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7: PhysicalKeyboardKey.digit7, LogicalKeyboardKey.digit8: PhysicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9: PhysicalKeyboardKey.digit9, LogicalKeyboardKey.keyN: PhysicalKeyboardKey.keyN,
    LogicalKeyboardKey.keyS: PhysicalKeyboardKey.keyS, LogicalKeyboardKey.keyF: PhysicalKeyboardKey.keyF,
    LogicalKeyboardKey.keyP: PhysicalKeyboardKey.keyP, LogicalKeyboardKey.keyK: PhysicalKeyboardKey.keyK,
    LogicalKeyboardKey.keyD: PhysicalKeyboardKey.keyD, LogicalKeyboardKey.keyA: PhysicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyX: PhysicalKeyboardKey.keyX, LogicalKeyboardKey.keyT: PhysicalKeyboardKey.keyT,
    LogicalKeyboardKey.keyH: PhysicalKeyboardKey.keyH, LogicalKeyboardKey.keyB: PhysicalKeyboardKey.keyB,
    LogicalKeyboardKey.comma: PhysicalKeyboardKey.comma,
  };
  for (final entry in result.entries.toList()) {
    final activator = entry.key as SingleActivator;
    final equivalent = physical[activator.trigger];
    if (activator.control && equivalent != null) {
      result[_PhysicalCommandActivator(equivalent, activator.shift)] = entry.value;
    }
  }
  return result;
}

class _PhysicalCommandActivator implements ShortcutActivator {
  const _PhysicalCommandActivator(this.key, this.shift);
  final PhysicalKeyboardKey key;
  final bool shift;
  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;
  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) => event is KeyDownEvent &&
      event.physicalKey == key && state.isControlPressed && state.isShiftPressed == shift &&
      !state.isAltPressed && !state.isMetaPressed;
  @override
  String debugDescribeKeys() => 'Ctrl+${shift ? 'Shift+' : ''}${key.debugName}';
}
