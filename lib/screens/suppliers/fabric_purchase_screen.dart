import 'package:flutter/material.dart';

import '../../commands/app_commands.dart';

import 'package:intl/intl.dart' as intl;

import '../../core/app_date_picker.dart';
import '../../core/calendar_service.dart';
import '../../core/formatters.dart';
import '../../data/shop_database.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../../reports/fabric_purchase_invoice_service.dart';
import 'supplier_purchase_logic.dart';
import 'widgets/fabric_purchase_option_card.dart';
import 'widgets/purchase_invoice_line_card.dart';
import 'widgets/purchase_panel_shell.dart';
import 'widgets/supplier_ledger_view.dart';

typedef FabricPurchasePrinter = Future<bool> Function(
  ShopDatabase database,
  String purchaseNumber, {
  required String locale,
});

class FabricPurchaseScreen extends StatefulWidget {
  const FabricPurchaseScreen({
    super.key,
    required this.database,
    this.supplierId,
    this.draftId,
    this.fabricId,
    this.printInvoice = printFabricPurchaseInvoice,
  });
  final ShopDatabase database;
  final int? supplierId;
  final int? draftId;
  final int? fabricId;
  final FabricPurchasePrinter printInvoice;

  @override
  State<FabricPurchaseScreen> createState() => _FabricPurchaseScreenState();
}

class _PurchaseLine {
  _PurchaseLine(this.fabricId, {String quantity = '1', required String cost})
    : quantity = TextEditingController(text: quantity),
      cost = TextEditingController(text: cost);
  int fabricId;
  final TextEditingController quantity;
  final TextEditingController cost;
  final FocusNode quantityFocus = FocusNode();
  final GlobalKey rowKey = GlobalKey();
  String? quantityError;
  String? costError;
  void dispose() {
    quantity.dispose();
    cost.dispose();
    quantityFocus.dispose();
  }
}

typedef _NewFabricInput = ({
  String name,
  String color,
  int cost,
  int price,
  String category,
});

ThemeData _purchaseFieldTheme(BuildContext context) {
  final theme = Theme.of(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
  );
  return theme.copyWith(
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLow,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.8),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1.2),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1.8),
      ),
      disabledBorder: border.copyWith(
        borderSide: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

class _AddSupplierDialog extends StatefulWidget {
  const _AddSupplierDialog({required this.translate});

  final String Function(String) translate;

  @override
  State<_AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<_AddSupplierDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _showNameError = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.translate;
    return AlertDialog(
      title: Text(t('addSupplier')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              onChanged: (_) {
                if (_showNameError) setState(() => _showNameError = false);
              },
              decoration: InputDecoration(
                labelText: '${t('supplier')} *',
                hintText: t('supplierHint'),
                errorText: _showNameError ? t('requiredField') : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t('mobile'),
                hintText: '07xx xxx xxx',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _showNameError = true);
              return;
            }
            Navigator.pop(context, (_name.text.trim(), _phone.text.trim()));
          },
          child: Text(t('save')),
        ),
      ],
    );
  }
}

class _NewFabricDialog extends StatefulWidget {
  const _NewFabricDialog({required this.translate, required this.unitLabel});

  final String Function(String) translate;
  final String unitLabel;

  @override
  State<_NewFabricDialog> createState() => _NewFabricDialogState();
}

class _NewFabricDialogState extends State<_NewFabricDialog> {
  final _name = TextEditingController();
  final _color = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _price = TextEditingController(text: '0');
  String _category = 'Clothing Fabric';
  bool _showErrors = false;

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _cost.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.translate;
    final cost = parseMoneyMinor(_cost.text);
    final price = parseMoneyMinor(_price.text);
    return AlertDialog(
      title: Text(t('addFabric')),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _name,
                  onChanged: (_) {
                    if (_showErrors) setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: '${t('fabric')} *',
                    errorText: _showErrors && _name.text.trim().isEmpty
                        ? t('requiredField')
                        : null,
                  ),
                ),
                TextField(
                  controller: _color,
                  decoration: InputDecoration(labelText: t('color')),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(labelText: t('category')),
                  items: [
                    DropdownMenuItem(
                      value: 'Clothing Fabric',
                      child: Text(t('clothingFabric')),
                    ),
                    DropdownMenuItem(
                      value: 'Waistcoat / Coat Fabric',
                      child: Text(t('waistcoatFabric')),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
                InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  child: Text(widget.unitLabel),
                ),
                TextField(
                  controller: _cost,
                  onChanged: (_) {
                    if (_showErrors) setState(() {});
                  },
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: t('defaultBuyingPrice'),
                    suffixText: 'AFN/m',
                    errorText: _showErrors && cost == null
                        ? t('invalidAmount')
                        : null,
                  ),
                ),
                TextField(
                  controller: _price,
                  onChanged: (_) {
                    if (_showErrors) setState(() {});
                  },
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: t('sellingPricePerMeter'),
                    suffixText: 'AFN/m',
                    errorText: _showErrors && price == null
                        ? t('invalidAmount')
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(t('openingStockZero')),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        FilledButton(
          onPressed: () {
            final parsedCost = parseMoneyMinor(_cost.text);
            final parsedPrice = parseMoneyMinor(_price.text);
            if (_name.text.trim().isEmpty ||
                parsedCost == null ||
                parsedPrice == null) {
              setState(() => _showErrors = true);
              return;
            }
            Navigator.pop(context, (
              name: _name.text.trim(),
              color: _color.text.trim(),
              cost: parsedCost,
              price: parsedPrice,
              category: _category,
            ));
          },
          child: Text(t('save')),
        ),
      ],
    );
  }
}

class _FabricPurchaseScreenState extends State<FabricPurchaseScreen> {
  final _invoice = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _extraCost = TextEditingController(text: '0');
  final _paid = TextEditingController(text: '0');
  final _advanceApplied = TextEditingController(text: '0');
  final _paymentReference = TextEditingController();
  final _notes = TextEditingController();
  final _supplierSearch = TextEditingController();
  final _fabricSearch = TextEditingController();
  final _fabricResultsScroll = ScrollController();
  final _invoiceLinesScroll = ScrollController();
  final List<_PurchaseLine> _lines = [];
  List<Map<String, Object?>> _suppliers = [];
  List<Map<String, Object?>> _fabrics = [];
  List<String> _paymentMethods = const ['Cash', 'Bank transfer', 'Other'];
  int? _supplierId;
  DateTime _date = CalendarService.shopToday();
  String _method = 'Cash';
  String _categoryFilter = 'all';
  int _supplierAdvanceAvailable = 0;
  int _supplierPayableBefore = 0;
  bool _applySupplierAdvance = false;
  bool _showAdjustments = false;
  bool _showInvoiceOnSmall = false;
  bool _loading = true;
  bool _saving = false;
  bool _posting = false;
  bool _dirty = false;
  bool _initialFabricAdded = false;
  bool _allowPop = false;
  bool _posted = false;
  Object? _error;
  int? _draftId;
  String? _number;
  String? _postedNumber;
  String? _printMessage;
  bool _printFailed = false;
  bool _formError = false;
  String? _supplierError;
  String? _emptyLinesError;
  String? _discountError;
  String? _extraCostError;
  String? _paidError;
  String? _advanceError;
  late String _operationId;

  String get _language => Localizations.localeOf(context).languageCode;
  String _t(String key) =>
      _purchaseRedesignWords[_language]?[key] ??
      _purchaseNewWords[_language]?[key] ??
      _purchaseLocaleOverrides[_language]?[key] ??
      _words[_language]?[key] ??
      _words['en']![key]!;
  String _money(int value) =>
      '${intl.NumberFormat.decimalPatternDigits(locale: Localizations.localeOf(context).toLanguageTag(), decimalDigits: value.abs() % 100 == 0 ? 0 : 2).format(value / 100)} AFN';
  int _readMoney(TextEditingController controller) =>
      SupplierPurchaseLogic.parsePriceMinor(controller.text) ?? 0;
  int get _subtotal => _lines.fold(0, (sum, line) {
    final quantity = SupplierPurchaseLogic.parseQuantityMilli(
      line.quantity.text,
    );
    final cost = SupplierPurchaseLogic.parsePriceMinor(line.cost.text);
    if (quantity == null || cost == null) return sum;
    return sum + SupplierPurchaseLogic.lineTotalMinor(quantity, cost);
  });
  int get _grandTotal =>
      (_subtotal - _readMoney(_discount) + _readMoney(_extraCost))
          .clamp(0, 1 << 60)
          .toInt();
  int get _cashPaid => _readMoney(_paid);
  int get _advancePaid =>
      _applySupplierAdvance ? _readMoney(_advanceApplied) : 0;
  int get _remainingPayable => SupplierPurchaseLogic.remainingPayable(
    total: _grandTotal,
    cashPaid: SupplierPurchaseLogic.cashAppliedToPurchase(
      total: _grandTotal,
      cashPaid: _cashPaid,
      advanceApplied: _advancePaid,
    ),
    advanceApplied: _advancePaid,
  );
  int get _cashAdvance => SupplierPurchaseLogic.cashAdvance(
    total: _grandTotal,
    cashPaid: _cashPaid,
    advanceApplied: _advancePaid,
  );
  double get _totalMeters => _lines.fold(0, (sum, line) {
    final milli = SupplierPurchaseLogic.parseQuantityMilli(line.quantity.text);
    return sum + (milli ?? 0) / 1000;
  });

  @override
  void initState() {
    super.initState();
    _operationId = 'supplier-purchase-${DateTime.now().microsecondsSinceEpoch}';
    for (final controller in [
      _discount,
      _extraCost,
      _paid,
      _advanceApplied,
      _invoice,
      _notes,
      _paymentReference,
    ]) {
      controller.addListener(_changed);
    }
    _supplierSearch.addListener(_searchChanged);
    _fabricSearch.addListener(_searchChanged);
    _load();
  }

  void _changed() {
    if (mounted) {
      setState(() {
        _dirty = true;
        _formError = false;
      });
    }
  }

  void _searchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final suppliers = await widget.database.suppliers();
      final fabrics = await widget.database.fabrics(includeArchived: false);
      final settings = await widget.database.settings();
      final methods =
          ((settings['payment_methods'] as String?) ??
                  'Cash, Bank transfer, Other')
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList();
      if (methods.isEmpty) methods.addAll(['Cash', 'Bank transfer', 'Other']);
      if (!methods.contains(_method)) _method = methods.first;
      if (widget.draftId != null) {
        final draftRows = (await widget.database.fabricPurchaseDrafts())
            .where((row) => row['id'] == widget.draftId)
            .toList();
        if (draftRows.isEmpty) {
          throw StateError('Draft is no longer available.');
        }
        final draft = draftRows.single;
        _draftId = widget.draftId;
        _supplierId = draft['supplier_id'] as int;
        _operationId =
            draft['operation_id'] as String? ??
            'supplier-purchase-${DateTime.now().microsecondsSinceEpoch}';
        _invoice.text = '${draft['invoice_reference'] ?? ''}';
        _notes.text = '${draft['notes'] ?? ''}';
        _date = DateTime.parse(draft['date'] as String);
        _discount.text = _priceInput((draft['discount'] as num? ?? 0).toInt());
        _extraCost.text = _priceInput(
          (draft['extra_cost'] as num? ?? 0).toInt(),
        );
        _showAdjustments =
            _readMoney(_discount) > 0 || _readMoney(_extraCost) > 0;
        _paid.text = _priceInput((draft['paid'] as num? ?? 0).toInt());
        _advanceApplied.text = _priceInput(
          (draft['draft_advance_applied'] as num? ?? 0).toInt(),
        );
        _applySupplierAdvance =
            (draft['draft_advance_applied'] as num? ?? 0).toInt() > 0;
        _paymentReference.text = '${draft['draft_payment_reference'] ?? ''}';
        _method = '${draft['method'] ?? 'Cash'}';
        _number = '${draft['number']}';
        final oldLines = await widget.database.fabricPurchaseDraftLines(
          _draftId!,
        );
        for (final row in oldLines) {
          final line = _PurchaseLine(
            row['fabric_id'] as int,
            quantity: ((row['quantity_milli'] as int) / 1000).toString(),
            cost: _priceInput(row['unit_cost'] as int),
          );
          _attachLineListeners(line);
          _lines.add(line);
        }
      } else {
        _supplierId = widget.supplierId;
      }
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers;
        _supplierPayableBefore =
            ((suppliers
                            .where((row) => row['id'] == _supplierId)
                            .firstOrNull?['balance']
                        as num?) ??
                    0)
                .toInt()
                .clamp(0, 1 << 60);
        _fabrics = fabrics;
        _paymentMethods = methods;
        _loading = false;
        _error = null;
        _dirty = false;
      });
      if (_supplierId != null) await _refreshSupplierAdvance(_supplierId!);
      if (!_initialFabricAdded && widget.draftId == null) {
        final selected = _fabrics
            .where(
              (row) =>
                  row['id'] == widget.fabricId &&
                  row['unit'] == 'meter' &&
                  row['archived'] != 1,
            )
            .firstOrNull;
        if (selected != null) {
          _initialFabricAdded = true;
          await _addFabricToInvoice(selected);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  String _priceInput(int minor) =>
      '${minor ~/ 100}.${(minor % 100).abs().toString().padLeft(2, '0')}';

  void _attachLineListeners(_PurchaseLine line) {
    line.quantity.addListener(() {
      line.quantityError = null;
      _changed();
    });
    line.cost.addListener(() {
      line.costError = null;
      _changed();
    });
  }

  void _addLine(int fabricId, {String quantity = '1'}) {
    final fabric = _fabrics.firstWhere((row) => row['id'] == fabricId);
    final line = _PurchaseLine(
      fabricId,
      quantity: quantity,
      cost: _priceInput((fabric['purchase_cost'] as num? ?? 0).toInt()),
    );
    _attachLineListeners(line);
    setState(() {
      _lines.add(line);
      _emptyLinesError = null;
      _dirty = true;
    });
    _focusQuantity(line);
  }

  void _focusQuantity(_PurchaseLine line) {
    if (MediaQuery.sizeOf(context).width < 1000) {
      setState(() => _showInvoiceOnSmall = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _posted) return;
      final rowContext = line.rowKey.currentContext;
      if (rowContext != null) {
        await Scrollable.ensureVisible(
          rowContext,
          alignment: .35,
          duration: const Duration(milliseconds: 180),
        );
      }
      if (mounted && !_posted && _lines.contains(line)) {
        line.quantityFocus.requestFocus();
        line.quantity.selection = TextSelection(
          baseOffset: 0,
          extentOffset: line.quantity.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _invoice,
      _discount,
      _extraCost,
      _paid,
      _advanceApplied,
      _paymentReference,
      _notes,
      _supplierSearch,
      _fabricSearch,
      _fabricResultsScroll,
      _invoiceLinesScroll,
    ]) {
      c.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final date = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: CalendarService.shopToday(),
      helpText: _t('date'),
    );
    if (date != null && mounted) {
      setState(() {
        _date = date;
        _dirty = true;
      });
    }
  }

  Future<void> _addSupplier() async {
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (context) => Theme(
        data: _purchaseFieldTheme(context),
        child: _AddSupplierDialog(translate: _t),
      ),
    );
    if (result == null) return;
    try {
      final id = await widget.database.addSupplier(
        name: result.$1,
        phone: result.$2,
      );
      final rows = await widget.database.suppliers();
      if (!mounted) return;
      setState(() => _suppliers = rows);
      _selectSupplier(rows.firstWhere((row) => row['id'] == id));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addFabric() async {
    final result = await showDialog<_NewFabricInput>(
      context: context,
      builder: (context) => Theme(
        data: _purchaseFieldTheme(context),
        child: _NewFabricDialog(
          translate: _t,
          unitLabel: context.l10n.fabricFormUnitDisplay(
            context.l10n.fabricFormMeter,
          ),
        ),
      ),
    );
    if (result == null) return;
    try {
      final id = await widget.database.addFabric(
        name: result.name,
        color: result.color,
        cost: result.cost,
        price: result.price,
        unit: 'meter',
        lowStock: 0,
        openingQuantity: 0,
        category: result.category,
      );
      final rows = await widget.database.fabrics(includeArchived: false);
      if (!mounted) return;
      setState(() => _fabrics = rows);
      await _addFabricToInvoice(
        rows.firstWhere((fabric) => fabric['id'] == id),
      );
    } catch (error) {
      _showError(error);
    }
  }

  List<Map<String, Object?>> get _matchingFabrics {
    final query = _fabricSearch.text.trim().toLowerCase();
    return _fabrics.where((fabric) {
      final category = '${fabric['category'] ?? ''}';
      final categoryMatches = switch (_categoryFilter) {
        'clothing' => category == 'Clothing Fabric',
        'waistcoat' => category == 'Waistcoat / Coat Fabric',
        _ => true,
      };
      final queryMatches =
          query.isEmpty ||
          '${fabric['name']} ${fabric['code'] ?? ''} ${fabric['color'] ?? ''} ${fabric['barcode'] ?? ''}'
              .toLowerCase()
              .contains(query);
      return categoryMatches &&
          queryMatches &&
          fabric['archived'] != 1 &&
          fabric['unit'] == 'meter';
    }).toList();
  }

  Future<void> _refreshSupplierAdvance(int supplierId) async {
    try {
      final available = await widget.database.supplierAdvanceAvailable(
        supplierId,
      );
      if (!mounted || supplierId != _supplierId) return;
      final maximum = (_grandTotal - _cashPaid).clamp(0, 1 << 60).toInt();
      final nextAdvance = available < maximum ? available : maximum;
      if (!_posted &&
          _applySupplierAdvance &&
          _readMoney(_advanceApplied) > available) {
        _advanceApplied.text = _priceInput(nextAdvance);
      }
      setState(() => _supplierAdvanceAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _supplierAdvanceAvailable = 0);
    }
  }

  Future<void> _addFabricToInvoice(Map<String, Object?> fabric) async {
    if (_posted || _saving) return;
    final existing = _lines
        .where((line) => line.fabricId == fabric['id'])
        .firstOrNull;
    if (existing != null) {
      _focusQuantity(existing);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('alreadyAdded')),
          duration: const Duration(milliseconds: 1400),
        ),
      );
      return;
    }
    _addLine(fabric['id'] as int);
  }

  void _selectSupplier(Map<String, Object?> supplier) {
    _supplierSearch.clear();
    final id = supplier['id'] as int;
    _advanceApplied.text = '0';
    setState(() {
      _supplierId = id;
      _supplierPayableBefore = ((supplier['balance'] as num?) ?? 0)
          .toInt()
          .clamp(0, 1 << 60);
      _supplierError = null;
      _supplierAdvanceAvailable = 0;
      _applySupplierAdvance = false;
      _dirty = true;
    });
    _refreshSupplierAdvance(id);
  }

  Future<void> _pickSupplier() async {
    _supplierSearch.clear();
    final selected = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => Theme(
        data: _purchaseFieldTheme(dialogContext),
        child: StatefulBuilder(
          builder: (dialogContext, refresh) {
            final query = normalizeLocalizedDigits(_supplierSearch.text)
                .trim()
                .toLowerCase();
            final results = _suppliers
                .where(
                  (row) => normalizeLocalizedDigits(
                    '${row['name']} ${row['phone'] ?? ''} ${row['phone2'] ?? ''} ${row['code'] ?? ''}',
                  ).toLowerCase().contains(query),
                )
                .toList();
            return AlertDialog(
              title: Text(_t('chooseSupplier')),
              content: SizedBox(
                width: 460,
                height: 340,
                child: Column(
                  children: [
                    TextField(
                      key: const ValueKey('purchase-supplier-search'),
                      controller: _supplierSearch,
                      autofocus: true,
                      onChanged: (_) => refresh(() {}),
                      decoration: InputDecoration(
                        labelText: _t('supplierHint'),
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: results.isEmpty
                          ? Center(child: Text(_t('noSupplierMatches')))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final supplier = results[index];
                                return ListTile(
                                  title: Text(
                                    '${supplier['name']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${supplier['phone'] ?? ''}',
                                    textDirection: TextDirection.ltr,
                                  ),
                                  leading: const Icon(Icons.storefront_rounded),
                                  trailing: _supplierId == supplier['id']
                                      ? const Icon(Icons.check_circle_outline)
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(dialogContext, supplier),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_t('cancel')),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (selected != null && mounted) _selectSupplier(selected);
  }

  Future<void> _removeLine(int index) async {
    final line = _lines[index];
    final quantity =
        SupplierPurchaseLogic.parseQuantityMilli(line.quantity.text) ?? 0;
    final cost = SupplierPurchaseLogic.parsePriceMinor(line.cost.text) ?? 0;
    if (quantity > 0 && cost > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t('remove')),
          content: Text(_t('confirmRemove')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('remove')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _lines.removeAt(index);
      _emptyLinesError = _lines.isEmpty ? _t('emptyInvoice') : null;
      _dirty = true;
    });
    line.dispose();
  }

  void _setApplyAdvance(bool apply) {
    final maximum = (_grandTotal - _cashPaid).clamp(0, 1 << 60).toInt();
    final amount = _supplierAdvanceAvailable < maximum
        ? _supplierAdvanceAvailable
        : maximum;
    _advanceApplied.text = apply ? _priceInput(amount) : '0';
    setState(() {
      _applySupplierAdvance = apply;
      _advanceError = null;
      _dirty = true;
    });
  }

  Future<void> _saveDraft() async {
    if (_posted || _saving || !_validate()) return;
    setState(() {
      _saving = true;
      _formError = false;
    });
    try {
      _draftId = await widget.database.saveFabricPurchaseDraft(
        draftId: _draftId,
        supplierId: _supplierId!,
        lines: _lineValues(),
        date: _date,
        discount: _readMoney(_discount),
        extraCost: _readMoney(_extraCost),
        invoiceReference: _invoice.text,
        notes: _notes.text,
        method: _method,
        plannedPayment: _cashPaid,
        advanceApplied: _advancePaid,
        paymentReference: _paymentReference.text,
        operationId: _operationId,
      );
      if (mounted) {
        setState(() {
          _dirty = false;
          _allowPop = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, 'draft-saved');
        });
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _validate() {
    var valid = true;
    _supplierError = _supplierId == null ? _t('selectSupplier') : null;
    _emptyLinesError = _lines.isEmpty ? _t('emptyInvoice') : null;
    if (_supplierError != null || _lines.isEmpty) valid = false;
    for (final line in _lines) {
      final quantity = SupplierPurchaseLogic.parseQuantityMilli(
        line.quantity.text,
      );
      final price = SupplierPurchaseLogic.parsePriceMinor(line.cost.text);
      line.quantityError = quantity == null || quantity <= 0
          ? _t('invalidQuantity')
          : null;
      line.costError = price == null ? _t('invalidPrice') : null;
      if (line.quantityError != null || line.costError != null) valid = false;
    }
    final discount = SupplierPurchaseLogic.parsePriceMinor(_discount.text);
    final extra = SupplierPurchaseLogic.parsePriceMinor(_extraCost.text);
    final paid = SupplierPurchaseLogic.parsePriceMinor(_paid.text);
    final advance = SupplierPurchaseLogic.parsePriceMinor(_advanceApplied.text);
    _discountError = discount == null || discount > _subtotal
        ? _t('invalidDiscount')
        : null;
    _extraCostError = extra == null ? _t('invalidAmount') : null;
    _paidError = paid == null ? _t('invalidAmount') : null;
    _advanceError =
        _applySupplierAdvance &&
            (advance == null ||
                advance > _supplierAdvanceAvailable ||
                advance > _grandTotal)
        ? _t('invalidAdvance')
        : null;
    if (_discountError != null ||
        _extraCostError != null ||
        _paidError != null ||
        _advanceError != null) {
      valid = false;
    }
    if (_discountError != null || _extraCostError != null) {
      _showAdjustments = true;
    }
    if (!valid && MediaQuery.sizeOf(context).width < 1000) {
      _showInvoiceOnSmall = true;
    }
    if (mounted) setState(() {});
    return valid;
  }

  List<Map<String, Object?>> _lineValues() => _lines
      .map(
        (line) => {
          'fabric_id': line.fabricId,
          'quantity':
              SupplierPurchaseLogic.parseQuantityMilli(line.quantity.text)! /
              1000,
          'unit_cost': SupplierPurchaseLogic.parsePriceMinor(line.cost.text)!,
        },
      )
      .toList();

  Future<bool> _showPurchaseReview() async {
    final supplier = _suppliers
        .where((row) => row['id'] == _supplierId)
        .firstOrNull;
    final advance = _advancePaid;
    final cashApplied = _cashPaid < _grandTotal - advance
        ? _cashPaid
        : _grandTotal - advance;
    final remaining = _grandTotal - advance - cashApplied;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_t('reviewPurchase')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _reviewRow(
                    _t('supplier'),
                    (supplier?['name'] ?? '').toString(),
                  ),
                  _reviewRow(_t('fabricItemCount'), _lines.length.toString()),
                  _reviewRow(
                    _t('totalMeters'),
                    '${SupplierPurchaseLogic.formatMeters(_totalMeters)} m',
                  ),
                  _reviewRow(_t('purchaseTotal'), _money(_grandTotal)),
                  _reviewRow(_t('paidNow'), _money(_cashPaid)),
                  if (advance > 0)
                    _reviewRow(_t('advanceApplied'), _money(advance)),
                  _reviewRow(_t('remaining'), _money(remaining)),
                  if (_cashAdvance > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _t('cashAdvanceNotice')
                            .replaceAll('{amount}', _money(_cashAdvance)),
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_t('confirmPurchase')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Future<void> _post({bool printAfter = false}) async {
    if (_posted || _saving || !_validate()) return;
    setState(() {
      _saving = true;
      _formError = false;
    });
    try {
      if (_invoice.text.trim().isNotEmpty &&
          await widget.database.supplierInvoiceExists(
            _supplierId!,
            _invoice.text,
          )) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_t('possibleDuplicate')),
            content: Text(_t('duplicateInvoice')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_t('continueAnyway')),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      if (!await _showPurchaseReview() || !mounted) return;
      setState(() => _posting = true);
      final number = await widget.database.confirmFabricPurchase(
        draftId: _draftId,
        supplierId: _supplierId!,
        lines: _lineValues(),
        date: _date,
        discount: _readMoney(_discount),
        extraCost: _readMoney(_extraCost),
        invoiceReference: _invoice.text,
        notes: _notes.text,
        method: _method,
        paid: _cashPaid,
        advanceApplied: _advancePaid,
        paymentReference: _paymentReference.text,
        operationId: _operationId,
      );
      if (!mounted) return;
      setState(() {
        _number = number;
        _postedNumber = number;
        _posted = true;
        _dirty = false;
      });
      await _refreshCatalogs();
      if (printAfter && mounted) await _printPostedPurchase();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _posting = false;
        });
      }
    }
  }

  Future<void> _refreshCatalogs() async {
    try {
      final suppliers = await widget.database.suppliers();
      final fabrics = await widget.database.fabrics(includeArchived: false);
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers;
        _fabrics = fabrics;
      });
      if (_supplierId != null) await _refreshSupplierAdvance(_supplierId!);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _printPostedPurchase() async {
    final number = _postedNumber;
    if (number == null) return;
    try {
      final opened = await widget.printInvoice(
        widget.database,
        number,
        locale: Localizations.localeOf(context).toLanguageTag(),
      );
      if (!mounted) return;
      setState(() {
        _printFailed = !opened;
        _printMessage = opened ? _t('printOpened') : _t('printFailed');
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('Purchase printing failed: $error');
      setState(() {
        _printFailed = true;
        _printMessage = _t('printFailed');
      });
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    debugPrint('Purchase entry failed: $error');
    setState(() {
      _formError = true;
      _showInvoiceOnSmall = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _invoiceLinesScroll.hasClients) {
        _invoiceLinesScroll.jumpTo(0);
      }
    });
  }

  Future<bool> _confirmLeave() async {
    if (_saving) return false;
    if (_saving || _posted || !_dirty) return !_saving;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_t('unsavedChanges')),
            content: Text(_t('discardChanges')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_t('discard')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _requestLeave() async {
    if (!await _confirmLeave() || !mounted) return;
    setState(() {
      _dirty = false;
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(_postedNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rtl = _language == 'ps' || _language == 'fa';
    return CommandScope(
      beforeLeave: _confirmLeave,
      priority: 30,
      commands: [
        AppCommand(
          'purchases.confirm',
          () => _post(),
          aliases: [CommandKey.save],
          disabledReason: () => _posted || _saving ? _t('posted') : null,
        ),
        AppCommand(
          'purchases.saveDraft',
          _saveDraft,
          disabledReason: () => _posted || _saving ? _t('posted') : null,
        ),
        AppCommand(
          'purchases.print',
          _printPostedPurchase,
          aliases: [CommandKey.print],
          disabledReason: () => !_posted || _saving
              ? localizedCommandText(
                  context,
                  'Confirm the purchase before printing its posted document.',
                  'لومړی پېرود تایید کړئ.',
                  'ابتدا خرید را تأیید کنید.',
                )
              : null,
        ),
        AppCommand(
          CommandKey.refresh,
          _refreshCatalogs,
          disabledReason: () => _saving ? _t('saving') : null,
        ),
        AppCommand(
          CommandKey.cancel,
          _requestLeave,
          disabledReason: () => _saving ? _t('saving') : null,
        ),
        AppCommand(
          'purchases.new',
          () => AppCommandRegistry.maybeOf(context)!.invoke('nav.purchases'),
          aliases: [CommandKey.add],
        ),
        AppCommand(CommandKey.search, () async {
          setState(() => _showInvoiceOnSmall = false);
          await WidgetsBinding.instance.endOfFrame;
          await focusCommandSearch(_fabricSearch);
        }),
      ],
      child: Theme(
        data: _purchaseFieldTheme(context),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: PopScope(
            canPop: _allowPop,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _requestLeave();
            },
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1000;
                    return Column(
                      children: [
                        _buildPageHeader(wide, rtl),
                        if (!wide) _buildSmallScreenTabs(),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _error != null
                              ? _buildLoadError()
                              : wide
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Row(
                                    textDirection: TextDirection.ltr,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        flex: 40,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: KeyedSubtree(
                                            key: const ValueKey(
                                              'purchase-fabric-panel',
                                            ),
                                            child: _buildFabricPanel(rtl),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 60,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: KeyedSubtree(
                                            key: const ValueKey(
                                              'purchase-invoice-panel',
                                            ),
                                            child: _buildInvoicePanel(rtl),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  child: _showInvoiceOnSmall
                                      ? _buildInvoicePanel(rtl)
                                      : _buildFabricPanel(rtl),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(bool wide, bool rtl) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: _t('back'),
                  onPressed: _saving ? null : _requestLeave,
                  icon: Icon(rtl ? Icons.arrow_forward : Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('newPurchase'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _t('pageDescription'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Chip(
                  label: Text(_posted ? _t('posted') : _t('draft')),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _posted
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${_t('purchaseNumber')}: ${_number ?? _t('notAssigned')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 18 : 8, 8, wide ? 24 : 8, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: _t('back'),
            onPressed: _saving ? null : _requestLeave,
            icon: Icon(rtl ? Icons.arrow_forward : Icons.arrow_back),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('newPurchase'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _t('pageDescription'),
                  maxLines: wide ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_t('purchaseNumber')}: ${_number ?? _t('notAssigned')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Chip(
                label: Text(_posted ? _t('posted') : _t('draft')),
                visualDensity: VisualDensity.compact,
                backgroundColor: _posted
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallScreenTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Row(
      children: [
        Expanded(
          child: _showInvoiceOnSmall
              ? OutlinedButton.icon(
                  onPressed: () => setState(() => _showInvoiceOnSmall = false),
                  icon: const Icon(Icons.texture_outlined),
                  label: Text(_t('findFabric')),
                )
              : FilledButton.tonalIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.texture_outlined),
                  label: Text(_t('findFabric')),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _showInvoiceOnSmall
              ? FilledButton.tonalIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text('${_t('viewInvoice')} (${_lines.length})'),
                )
              : OutlinedButton.icon(
                  onPressed: () => setState(() => _showInvoiceOnSmall = true),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text('${_t('viewInvoice')} (${_lines.length})'),
                ),
        ),
      ],
    ),
  );

  Widget _buildLoadError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_t('loadError')),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _load();
          },
          icon: const Icon(Icons.refresh),
          label: Text(_t('retry')),
        ),
      ],
    ),
  );
  Widget _buildFabricPanel(bool rtl) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: PurchasePanelShell(
      title: _t('findFabric'),
      description: _t('fabricDescription'),
      icon: Icons.texture_outlined,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: CustomScrollView(
          key: const PageStorageKey('supplier-purchase-fabrics'),
          controller: _fabricResultsScroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _fabricSearch,
                    enabled: !_posted,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: _t('fabricSearchLabel'),
                      hintText: _t('fabricSearchHint'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _fabricSearch.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: _t('clearSearch'),
                              onPressed: _fabricSearch.clear,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: Text(_t('allCategories')),
                        selected: _categoryFilter == 'all',
                        onSelected: (_) =>
                            setState(() => _categoryFilter = 'all'),
                      ),
                      ChoiceChip(
                        label: Text(_t('clothingFabric')),
                        selected: _categoryFilter == 'clothing',
                        onSelected: (_) =>
                            setState(() => _categoryFilter = 'clothing'),
                      ),
                      ChoiceChip(
                        label: Text(_t('waistcoatFabric')),
                        selected: _categoryFilter == 'waistcoat',
                        onSelected: (_) =>
                            setState(() => _categoryFilter = 'waistcoat'),
                      ),
                    ],
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: _posted || _saving ? null : _addFabric,
                      icon: const Icon(Icons.add),
                      label: Text(_t('addFabric')),
                    ),
                  ),
                ],
              ),
            ),
            _matchingFabrics.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        _fabrics.isEmpty
                            ? _t('noFabrics')
                            : _t('noFabricMatches'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SliverList.separated(
                    itemCount: _matchingFabrics.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final fabric = _matchingFabrics[index];
                      final stock =
                          (fabric['on_hand'] as num?) ??
                          (fabric['available'] as num? ?? 0);
                      return FabricPurchaseOptionCard(
                        key: ValueKey('purchase-fabric-${fabric['id']}'),
                        fabric: fabric,
                        stockLabel: _t('stock'),
                        stock: '${SupplierPurchaseLogic.formatMeters(stock)} m',
                        buyingLabel: _t('buyingPrice'),
                        buyingPrice: _money(
                          (fabric['purchase_cost'] as num? ?? 0).toInt(),
                        ),
                        sellingLabel: _t('sellingPricePerMeter'),
                        sellingPrice: _money(
                          (fabric['selling_price'] as num? ?? 0).toInt(),
                        ),
                        addLabel: _t('addShort'),
                        addedLabel: _t('added'),
                        added: _lines.any(
                          (line) => line.fabricId == fabric['id'],
                        ),
                        onAdd: _posted || _saving
                            ? null
                            : () => _addFabricToInvoice(fabric),
                      );
                    },
                  ),
          ],
        ),
      ),
    ),
  );

  Widget _buildInvoicePanel(bool rtl) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: PurchasePanelShell(
      title: _t('purchaseInvoice'),
      description: _t('invoiceDescription'),
      icon: Icons.receipt_long_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const PageStorageKey('supplier-purchase-invoice'),
                controller: _invoiceLinesScroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
                    if (_formError)
                      Padding(
                        key: const ValueKey('purchase-save-error'),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_t('saveError'))),
                          ],
                        ),
                      ),
                    if (_printMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              _printFailed
                                  ? Icons.info_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: _printFailed
                                  ? Theme.of(context).colorScheme.error
                                  : _paidColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_printMessage!)),
                          ],
                        ),
                      ),
                    _buildSupplierBlock(),
                    _buildInvoiceLinesContent(),
                    _buildTotalsAndPayment(),
                  ],
                ),
              ),
            ),
            _buildInvoiceFooter(compact: constraints.maxHeight < 350),
          ],
        ),
      ),
    ),
  );

  Widget _buildInvoiceLinesContent() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_t('fabricItems')} (${_lines.length})',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_lines.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.playlist_add_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  _emptyLinesError ?? _t('emptyInvoice'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                if (constraints.maxWidth >= purchaseTableBreakpoint)
                  PurchaseInvoiceTableHeader(
                    fabricLabel: _t('fabric'),
                    quantityLabel: _t('quantityMeters'),
                    rateLabel: _t('actualBuyingPrice'),
                    totalLabel: _t('lineTotal'),
                    removeLabel: _t('remove'),
                  ),
                for (var index = 0; index < _lines.length; index++) ...[
                  if (index > 0) const SizedBox(height: 6),
                  _buildInvoiceLineCard(index),
                ],
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buildInvoiceLineCard(int index) {
    final line = _lines[index];
    final fabric = _fabrics
        .where((row) => row['id'] == line.fabricId)
        .firstOrNull;
    final quantity =
        SupplierPurchaseLogic.parseQuantityMilli(line.quantity.text) ?? 0;
    final price = SupplierPurchaseLogic.parsePriceMinor(line.cost.text) ?? 0;
    return PurchaseInvoiceLineCard(
      key: line.rowKey,
      fabricName: (fabric?['name'] ?? '').toString(),
      fabricCode: (fabric?['code'] ?? '').toString(),
      color: (fabric?['color'] ?? '').toString(),
      stockLabel: _t('stock'),
      stock: SupplierPurchaseLogic.formatMeters(
        (fabric?['on_hand'] as num?) ?? (fabric?['available'] as num? ?? 0),
      ),
      quantityLabel: _t('quantityMeters'),
      quantityController: line.quantity,
      quantityFocusNode: line.quantityFocus,
      quantityError: line.quantityError,
      buyingPriceLabel: _t('actualBuyingPrice'),
      buyingPriceController: line.cost,
      buyingPriceError: line.costError,
      lineTotalLabel: _t('lineTotal'),
      lineTotal: _money(SupplierPurchaseLogic.lineTotalMinor(quantity, price)),
      removeLabel: _t('remove'),
      enabled: !_posted && !_saving,
      onRemove: () => _removeLine(index),
      onChanged: () {
        if (mounted) setState(() => _dirty = true);
      },
    );
  }

  Widget _fieldLabel(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 5),
      child,
    ],
  );

  Widget _buildSupplierBlock() {
    final supplier = _suppliers
        .where((row) => row['id'] == _supplierId)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return _buildCompactSupplierBlock(supplier);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(
                _t('supplier'),
                OutlinedButton.icon(
                  key: const ValueKey('purchase-supplier-picker'),
                  onPressed: _posted || _saving ? null : _pickSupplier,
                  style: OutlinedButton.styleFrom(
                    alignment: AlignmentDirectional.centerStart,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.storefront_rounded, size: 20),
                  label: Text(
                    supplier == null
                        ? _t('chooseSupplier')
                        : '${supplier['name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_supplierError != null)
                Text(
                  _supplierError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (supplier != null &&
                      '${supplier['phone'] ?? ''}'.isNotEmpty)
                    Text(
                      '${supplier['phone']}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 12),
                    ),
                  TextButton.icon(
                    onPressed: _posted || _saving ? null : _addSupplier,
                    icon: const Icon(Icons.person_add_alt_rounded, size: 17),
                    label: Text(_t('addSupplier')),
                  ),
                  if (supplier != null)
                    TextButton.icon(
                      onPressed: _saving ? null : _showSelectedSupplierLedger,
                      icon: const Icon(Icons.history_rounded, size: 17),
                      label: Text(_t('viewLedger')),
                    ),
                ],
              ),
              if (supplier != null) _supplierSummary(supplier),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final invoice = _fieldLabel(
                    _t('invoiceNumber'),
                    TextField(
                      controller: _invoice,
                      enabled: !_posted && !_saving,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _t('invoiceNumber'),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        isDense: true,
                      ),
                    ),
                  );
                  final date = _fieldLabel(
                    _t('date'),
                    OutlinedButton.icon(
                      onPressed: _posted || _saving ? null : _chooseDate,
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(
                        formatDate(
                          _date.toIso8601String(),
                          locale: Localizations.localeOf(context)
                              .toLanguageTag(),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                      ),
                    ),
                  );
                  return constraints.maxWidth < 380
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [invoice, const SizedBox(height: 8), date],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: invoice),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: date),
                          ],
                        );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactSupplierBlock(Map<String, Object?>? supplier) {
    final enabled = !_posted && !_saving;
    Widget labeled(String label, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Text(
              label,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: labeled(
                  _t('supplier'),
                  OutlinedButton.icon(
                    key: const ValueKey('purchase-supplier-picker'),
                    onPressed: enabled ? _pickSupplier : null,
                    style: OutlinedButton.styleFrom(
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.storefront_rounded, size: 18),
                    label: Text(
                      supplier == null
                          ? _t('chooseSupplier')
                          : '${supplier['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: labeled(
                  _t('invoiceNumber'),
                  TextField(
                    controller: _invoice,
                    enabled: enabled,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _t('invoiceNumber'),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: labeled(
                  _t('date'),
                  OutlinedButton.icon(
                    onPressed: enabled ? _chooseDate : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 17),
                    label: Text(
                      formatDate(
                        _date.toIso8601String(),
                        locale: Localizations.localeOf(context).toLanguageTag(),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_supplierError != null)
            Text(
              _supplierError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (supplier != null) ...[
                Text(
                  '${supplier['phone'] ?? ''}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${_t('existingPayable')}: ${_money(_supplierPayableBefore)}',
                  key: const ValueKey('purchase-previous-balance'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _supplierPayableBefore > 0
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_supplierAdvanceAvailable > 0)
                  Text(
                    '${_t('availableAdvance')}: ${_money(_supplierAdvanceAvailable)}',
                    style: TextStyle(fontSize: 12, color: _paidColor),
                  ),
              ],
              TextButton.icon(
                onPressed: enabled ? _addSupplier : null,
                icon: const Icon(Icons.person_add_alt_rounded, size: 17),
                label: Text(_t('addSupplier')),
              ),
              if (supplier != null)
                TextButton.icon(
                  onPressed: _saving ? null : _showSelectedSupplierLedger,
                  icon: const Icon(Icons.history_rounded, size: 17),
                  label: Text(_t('viewLedger')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color get _paidColor => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xff86efac)
      : const Color(0xff15803d);

  Widget _supplierSummary(Map<String, Object?> supplier) {
    final payable = _supplierPayableBefore;
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('purchase-previous-balance'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(
            '${_t('existingPayable')}: ${_money(payable)}',
            style: TextStyle(
              fontSize: 12,
              color: payable > 0 ? colors.error : colors.onSurfaceVariant,
            ),
          ),
          if (_supplierAdvanceAvailable > 0)
            Text(
              '${_t('availableAdvance')}: ${_money(_supplierAdvanceAvailable)}',
              style: TextStyle(fontSize: 12, color: _paidColor),
            ),
        ],
      ),
    );
  }

  void _payFull() {
    _paid.text = _priceInput((_grandTotal - _advancePaid).clamp(0, 1 << 60));
    setState(() => _paidError = null);
  }

  void _buyOnCredit() {
    _paid.text = '0';
    _advanceApplied.text = '0';
    setState(() {
      _applySupplierAdvance = false;
      _paidError = null;
      _advanceError = null;
    });
  }

  Widget _buildTotalsAndPayment() {
    final methods = {
      ..._paymentMethods,
      _method,
    }.where((value) => value.isNotEmpty).toList();
    final colors = Theme.of(context).colorScheme;
    final enabled = !_posted && !_saving;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('totalsPayment'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _moneyInput(
                  _paid,
                  _t('paidNow'),
                  errorText: _paidError,
                  enabled: enabled,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _fieldLabel(
                  _t('paymentMethod'),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: methods.contains(_method) ? _method : null,
                    decoration: const InputDecoration(isDense: true),
                    items: methods
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(
                              _paymentMethodLabel(method),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: !enabled
                        ? null
                        : (value) => setState(() {
                            _method = value ?? _method;
                            _dirty = true;
                          }),
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                key: const ValueKey('purchase-pay-full'),
                onPressed: enabled ? _payFull : null,
                icon: Icon(
                  Icons.payments_outlined,
                  size: 17,
                  color: _paidColor,
                ),
                label: Text(_t('payFull')),
              ),
              TextButton.icon(
                key: const ValueKey('purchase-buy-credit'),
                onPressed: enabled ? _buyOnCredit : null,
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 17,
                ),
                label: Text(_t('buyCredit')),
              ),
            ],
          ),
          if (_supplierId != null &&
              (_supplierAdvanceAvailable > 0 || _applySupplierAdvance)) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _applySupplierAdvance,
              onChanged: !enabled || _supplierAdvanceAvailable <= 0
                  ? null
                  : (v) => _setApplyAdvance(v ?? false),
              title: Text(_t('applyAdvance')),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_applySupplierAdvance)
              _moneyInput(
                _advanceApplied,
                _t('advanceToApply'),
                errorText: _advanceError,
                enabled: enabled,
              ),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('purchase-adjustments'),
              onPressed: () =>
                  setState(() => _showAdjustments = !_showAdjustments),
              icon: Icon(
                _showAdjustments
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(_t('adjustments')),
            ),
          ),
          if (_showAdjustments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _moneyInput(
                      _discount,
                      _t('discountFixed'),
                      errorText: _discountError,
                      enabled: enabled,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _moneyInput(
                      _extraCost,
                      _t('extraCosts'),
                      errorText: _extraCostError,
                      enabled: enabled,
                    ),
                  ),
                ],
              ),
            ),
          _moneyRow(_t('subtotal'), _subtotal),
          _moneyRow(_t('discountFixed'), -_readMoney(_discount)),
          _moneyRow(_t('extraCosts'), _readMoney(_extraCost)),
          _moneyRow(
            _t('paidNow'),
            _cashPaid,
            color: _paidColor,
            icon: Icons.check_circle_outline_rounded,
          ),
          if (_advancePaid > 0)
            _moneyRow(_t('advanceApplied'), _advancePaid, color: _paidColor),
          if (_cashAdvance > 0)
            Container(
              key: const ValueKey('purchase-new-advance'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _t('cashAdvanceNotice')
                    .replaceAll('{amount}', _money(_cashAdvance)),
                style: TextStyle(color: colors.onSecondaryContainer),
              ),
            ),
          ExpansionTile(
            key: const PageStorageKey('purchase-extra-details'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              _t('optionalDetails'),
              style: const TextStyle(fontSize: 13),
            ),
            children: [
              _fieldLabel(
                _t('paymentReference'),
                TextField(
                  controller: _paymentReference,
                  enabled: enabled,
                  decoration: InputDecoration(
                    labelText: _t('paymentReference'),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _fieldLabel(
                _t('notes'),
                TextField(
                  controller: _notes,
                  enabled: enabled,
                  decoration: InputDecoration(
                    labelText: _t('notes'),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String method) => switch (method) {
    'Cash' => _t('cash'),
    'Bank transfer' => _t('bankTransfer'),
    'Other' => _t('other'),
    _ => method,
  };

  Widget _buildInvoiceFooter({bool compact = false}) {
    final colors = Theme.of(context).colorScheme;
    final compactStyle = compact
        ? ButtonStyle(
            textStyle: WidgetStatePropertyAll(
              Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 12),
            ),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            minimumSize: WidgetStatePropertyAll(Size(0, 36)),
            visualDensity: VisualDensity.compact,
          )
        : null;
    return Container(
      key: const ValueKey('purchase-footer'),
      padding: EdgeInsets.fromLTRB(12, compact ? 6 : 10, 12, compact ? 6 : 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _footerAmount(
                  _t('grandTotal'),
                  _grandTotal,
                  colors.primary,
                  Icons.receipt_long_rounded,
                  const ValueKey('purchase-grand-total'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _footerAmount(
                  _t('remaining'),
                  _remainingPayable,
                  _remainingPayable > 0 ? colors.error : _paidColor,
                  _remainingPayable > 0
                      ? Icons.account_balance_wallet_outlined
                      : Icons.check_circle_outline_rounded,
                  const ValueKey('purchase-remaining'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: _posted
                ? [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _printPostedPurchase,
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(_t('reprint')),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _requestLeave,
                      icon: const Icon(Icons.done_rounded, size: 18),
                      label: Text(_t('done')),
                    ),
                  ]
                : [
                    if (compact)
                      TextButton(
                        style: compactStyle,
                        onPressed: _saving ? null : _saveDraft,
                        child: Text(_t('saveDraft')),
                      )
                    else
                      TextButton.icon(
                        onPressed: _saving ? null : _saveDraft,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: Text(_t('saveDraft')),
                      ),
                    if (compact)
                      OutlinedButton(
                        style: compactStyle,
                        onPressed: _saving
                            ? null
                            : () => _post(printAfter: true),
                        child: Text(_t('confirmAndPrint')),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _post(printAfter: true),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: Text(_t('confirmAndPrint')),
                      ),
                    CommandButton(
                      id: 'action.save',
                      child: FilledButton.icon(
                        style: compactStyle,
                        key: const ValueKey('purchase-confirm'),
                        onPressed: _saving ? null : () => _post(),
                        icon: _posting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                        label: Text(_t('confirmPurchase')),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _footerAmount(
    String label,
    int amount,
    Color color,
    IconData icon,
    Key key,
  ) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
      Text(
        _money(amount),
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );

  Widget _moneyInput(
    TextEditingController controller,
    String label, {
    String? errorText,
    bool enabled = true,
  }) => _fieldLabel(
    label,
    TextField(
      controller: controller,
      enabled: enabled && !_saving,
      textDirection: TextDirection.ltr,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintText: '0',
        suffixText: 'AFN',
        isDense: true,
        errorText: errorText,
        errorMaxLines: 3,
      ),
    ),
  );

  Widget _moneyRow(String label, int value, {Color? color, IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      color ?? Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _money(value),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _showSelectedSupplierLedger() async {
    final supplier = _suppliers
        .where((row) => row['id'] == _supplierId)
        .firstOrNull;
    if (supplier == null) return;
    final rows = await widget.database.supplierLedger(_supplierId!);
    if (!mounted) return;
    await showSupplierLedger(
      context: context,
      supplier: supplier,
      entries: rows,
    );
  }
}

const _purchaseNewWords = <String, Map<String, String>>{
  'en': {
    'newPurchase': 'Purchase Fabric',
    'pageDescription':
        'Select fabric, choose a supplier, and record the invoice.',
    'notAssigned': 'Not assigned',
    'posted': 'Posted',
    'findFabric': 'Find fabric',
    'viewInvoice': 'View invoice',
    'fabricDescription':
        'Search active fabrics and add meters to this purchase.',
    'fabricSearchLabel': 'Search fabric by name, code, or color',
    'fabricSearchHint': 'Type a fabric name, code, or color',
    'allCategories': 'All',
    'clothingFabric': 'Clothing fabric',
    'waistcoatFabric': 'Waistcoat / coat fabric',
    'stock': 'Stock',
    'buyingPrice': 'Buy / meter',
    'sellingPricePerMeter': 'Sell / meter',
    'addToInvoice': 'Add to invoice',
    'purchaseInvoice': 'Purchase invoice',
    'invoiceDescription': 'Supplier, items, and payment',
    'emptyInvoice': 'Select fabric from the left panel.',
    'quantityMeters': 'Quantity (meters)',
    'actualBuyingPrice': 'Actual buying price / meter',
    'invalidQuantity': 'Enter a positive quantity with up to three decimals.',
    'invalidPrice': 'Enter a valid buying price per meter.',
    'invalidDiscount': 'Discount cannot exceed the subtotal.',
    'invalidAmount': 'Enter a valid amount.',
    'invalidAdvance': 'Check the available supplier advance and amount.',
    'reviewPurchase': 'Review purchase',
    'fabricItemCount': 'Fabric items',
    'totalMeters': 'Total meters',
    'purchaseTotal': 'Purchase total',
    'advanceApplied': 'Existing advance applied',
    'cashAdvanceNotice':
        '{amount} extra payment will remain as supplier advance.',
    'confirmPurchase': 'Confirm purchase',
    'confirmAndPrint': 'Confirm & print',
    'saveError': 'Purchase could not be saved',
    'printOpened': 'Purchase invoice opened for printing.',
    'printFailed': 'Could not prepare the printout.',
    'reprint': 'Reprint',
    'done': 'Done',
    'existingPayable': 'Existing payable',
    'availableAdvance': 'Available supplier advance',
    'applyAdvance': 'Apply existing supplier advance',
    'advanceToApply': 'Advance amount to apply',
    'category': 'Category',
    'defaultBuyingPrice': 'Default buying price',
    'clearInvoice': 'Clear invoice',
    'clearInvoiceConfirm':
        'Clear every item and entered amount from this invoice?',
    'addSeparateLine': 'Add separate line',
    'differentPriceSeparateLine':
        'This fabric has a different price. Add it as a separate line?',
    'duplicateFabric': 'Fabric already in invoice',
    'fabricAdded': 'Fabric added to invoice.',
    'quantityIncreased': 'Quantity increased on the existing line.',
    'requiredField': 'This field is required.',
    'optionalDetails': 'Payment reference and notes',
  },
  'ps': {
    'newPurchase': 'د ټوکر پېرود',
    'pageDescription': 'ټوکر وټاکئ، عرضه کوونکی غوره کړئ او بل ثبت کړئ.',
    'notAssigned': 'نه دی ټاکل شوی',
    'posted': 'ثبت شو',
    'findFabric': 'ټوکر ولټوه',
    'viewInvoice': 'بل وګوره',
    'fabricDescription': 'فعال ټوکر ولټوه او په متر یې دې پېرود ته زیات کړه.',
    'fabricSearchLabel': 'د ټوکر نوم، کوډ یا رنګ ولټوه',
    'fabricSearchHint': 'نوم، کوډ یا رنګ ولیکئ',
    'allCategories': 'ټولې کټګورۍ',
    'clothingFabric': 'د جامو ټوکر',
    'waistcoatFabric': 'د واسکټ / کوټ ټوکر',
    'stock': 'موجودي',
    'buyingPrice': 'د پېرود بیه / متر',
    'sellingPricePerMeter': 'د پلور بیه / متر',
    'addToInvoice': 'بل ته زیاتول',
    'purchaseInvoice': 'د پېرود بل',
    'invoiceDescription': 'عرضه کوونکی، توکي او تادیه',
    'emptyInvoice': 'له چپ اړخ څخه ټوکر وټاکئ.',
    'quantityMeters': 'اندازه (متر)',
    'actualBuyingPrice': 'اصلي د پېرود بیه / متر',
    'invalidQuantity': 'مثبته اندازه تر درې اعشاریو ځایونو ولیکئ.',
    'invalidPrice': 'د هر متر سمه بیه ولیکئ.',
    'invalidDiscount': 'تخفیف د فرعي ټول څخه زیات نه شي کېدای.',
    'invalidAmount': 'د پیسو سمه اندازه ولیکئ.',
    'invalidAdvance': 'شته عرضه کوونکی کریډیټ او اندازه وګورئ.',
    'reviewPurchase': 'پېرود بیا وګورئ',
    'fabricItemCount': 'د ټوکر توکي',
    'totalMeters': 'ټول متر',
    'purchaseTotal': 'د پېرود ټول',
    'advanceApplied': 'کارول شوی پخوانی کریډیټ',
    'cashAdvanceNotice':
        'د {amount} اضافي تادیه به د عرضه کوونکي د کریډیټ په توګه پاتې شي.',
    'confirmPurchase': 'پېرود تاییدول',
    'confirmAndPrint': 'تایید او چاپ',
    'saveError': 'پېرود ونه ساتل شو',
    'printOpened': 'د پېرود بل د چاپ لپاره پرانیستل شو.',
    'printFailed': 'د چاپ پاڼه چمتو نه شوه.',
    'reprint': 'بیا چاپ',
    'done': 'بشپړ',
    'existingPayable': 'مخکینی پور',
    'availableAdvance': 'شته عرضه کوونکي کریډیټ',
    'applyAdvance': 'پخوانی عرضه کوونکي کریډیټ وکاروئ',
    'advanceToApply': 'د کارېدونکي کریډیټ اندازه',
    'category': 'کټګوري',
    'defaultBuyingPrice': 'اصلي د پېرود بیه',
    'clearInvoice': 'ټول بل پاکول',
    'clearInvoiceConfirm': 'د دې بل ټول توکي او داخل شوي معلومات پاک شي؟',
    'addSeparateLine': 'جلا کرښه زیاتول',
    'differentPriceSeparateLine':
        'دا ټوکر په بله بیه ثبت شوی. جلا کرښه زیاته کړئ؟',
    'duplicateFabric': 'ټوکر لا دمخه په بل کې شته',
    'fabricAdded': 'ټوکر بل ته زیات شو.',
    'quantityIncreased': 'د موجودې کرښې اندازه زیاته شوه.',
    'requiredField': 'دا برخه اړینه ده.',
    'optionalDetails': 'د تادیې حواله او یادښتونه',
  },
  'fa': {
    'newPurchase': 'خرید پارچه',
    'pageDescription':
        'پارچه را انتخاب کنید، فروشنده را برگزینید و فاکتور را ثبت کنید.',
    'notAssigned': 'تعیین نشده',
    'posted': 'ثبت‌شده',
    'findFabric': 'جستجوی پارچه',
    'viewInvoice': 'مشاهده فاکتور',
    'fabricDescription': 'پارچه‌های فعال را جستجو و به خرید اضافه کنید.',
    'fabricSearchLabel': 'جستجو با نام، کد یا رنگ پارچه',
    'fabricSearchHint': 'نام، کد یا رنگ را وارد کنید',
    'allCategories': 'همه',
    'clothingFabric': 'پارچه لباس',
    'waistcoatFabric': 'پارچه واسکت / کت',
    'stock': 'موجودی',
    'buyingPrice': 'خرید / متر',
    'sellingPricePerMeter': 'فروش / متر',
    'addToInvoice': 'افزودن به فاکتور',
    'purchaseInvoice': 'فاکتور خرید',
    'invoiceDescription': 'فروشنده، اقلام و پرداخت',
    'emptyInvoice': 'پارچه را از پنل سمت چپ انتخاب کنید.',
    'quantityMeters': 'مقدار (متر)',
    'actualBuyingPrice': 'قیمت واقعی خرید / متر',
    'invalidQuantity': 'مقدار مثبت با حداکثر سه رقم اعشار وارد کنید.',
    'invalidPrice': 'قیمت خرید هر متر را بررسی کنید.',
    'invalidDiscount': 'تخفیف نمی‌تواند از جمع جزء بیشتر باشد.',
    'invalidAmount': 'مبلغ معتبر وارد کنید.',
    'invalidAdvance': 'اعتبار موجود فروشنده و مبلغ را بررسی کنید.',
    'reviewPurchase': 'بازبینی خرید',
    'fabricItemCount': 'اقلام پارچه',
    'totalMeters': 'مجموع متر',
    'purchaseTotal': 'مجموع خرید',
    'advanceApplied': 'اعتبار قبلی مصرف‌شده',
    'cashAdvanceNotice':
        'مبلغ اضافی {amount} به‌عنوان اعتبار فروشنده باقی می‌ماند.',
    'confirmPurchase': 'تأیید خرید',
    'confirmAndPrint': 'تأیید و چاپ',
    'saveError': 'خرید ذخیره نشد',
    'printOpened': 'فاکتور خرید برای چاپ باز شد.',
    'printFailed': 'آماده‌سازی چاپ انجام نشد.',
    'reprint': 'چاپ دوباره',
    'done': 'پایان',
    'existingPayable': 'بدهی قبلی',
    'availableAdvance': 'اعتبار موجود فروشنده',
    'applyAdvance': 'مصرف اعتبار قبلی فروشنده',
    'advanceToApply': 'مبلغ اعتبار برای مصرف',
    'category': 'دسته‌بندی',
    'defaultBuyingPrice': 'قیمت خرید پیش‌فرض',
    'clearInvoice': 'پاک کردن فاکتور',
    'clearInvoiceConfirm':
        'همه اقلام و مبلغ‌های واردشده از این فاکتور پاک شود؟',
    'addSeparateLine': 'افزودن ردیف جدا',
    'differentPriceSeparateLine':
        'قیمت این پارچه متفاوت است. آن را در ردیف جدا اضافه می‌کنید؟',
    'duplicateFabric': 'پارچه از قبل در فاکتور است',
    'fabricAdded': 'پارچه به فاکتور افزوده شد.',
    'quantityIncreased': 'مقدار ردیف قبلی افزایش یافت.',
    'requiredField': 'این بخش الزامی است.',
    'optionalDetails': 'مرجع پرداخت و یادداشت',
  },
};

const _purchaseLocaleOverrides = <String, Map<String, String>>{
  'ps': {
    'back': 'شاته',
    'newPurchase': 'د ټوکر نوې پېرودنه',
    'draft': 'مسوده',
    'supplierInvoice': 'عرضه کوونکی او بل',
    'supplier': 'عرضه کوونکی',
    'fabric': 'ټوکر',
    'supplierHint': 'د نوم یا موبایل له لارې لټون',
    'addSupplier': 'عرضه کوونکی زیاتول',
    'mobile': 'موبایل',
    'save': 'ساتل',
    'cancel': 'لغوه',
    'invoiceNumber': 'د عرضه کوونکي د بل شمېره',
    'date': 'د پېرود نېټه',
    'purchaseNumber': 'د پېرود شمېره',
    'notes': 'یادښتونه',
    'notesHint': 'اختیاري یادښتونه',
    'fabricItems': 'د ټوکر توکي',
    'searchAddFabric': 'ټوکر ولټوه او زیات یې کړه',
    'fabricHint': 'د ټوکر نوم، کوډ، رنګ یا بارکوډ ولټوه',
    'unitAndStock': 'واحد · موجودي',
    'addFabric': 'ټوکر زیاتول',
    'color': 'رنګ',
    'unitCost': 'د هر واحد د پېرود بیه',
    'sellingPrice': 'اوسنۍ د پلور بیه',
    'openingStockZero': 'د پیل موجودي صفر ټاکل کېږي.',
    'noFabrics': 'ټوکر ونه موندل شو. د دوام لپاره ټوکر زیات کړئ.',
    'availableStock': 'شته موجودي',
    'availableCredit': 'د عرضه کوونکي شته کریډیټ',
    'previousPayable': 'مخکینی پور',
    'resultingPayable': 'وروستی پور',
    'resultingCredit': 'وروستی کریډیټ',
    'viewLedger': 'د عرضه کوونکي حساب وګورئ',
    'noLedger': 'د عرضه کوونکي په حساب کې ثبت نشته.',
    'charge': 'پېرودونه',
    'payment': 'تادیې / کریډیټونه',
    'quantity': 'اندازه',
    'lineTotal': 'د کرښې ټول',
    'remove': 'لرې کول',
    'confirmRemove': 'دا د ټوکر کرښه لرې شي؟',
    'addLine': 'د ټوکر کرښه زیاتول',
    'totalsPayment': 'ټول او تادیه',
    'subtotal': 'فرعي ټول',
    'discountFixed': 'تخفیف (ثابت AFN)',
    'extraCosts': 'د پېرود اړوند لګښتونه',
    'grandTotal': 'وروستی ټول',
    'paymentMethod': 'د تادیې طریقه',
    'cash': 'نغدې',
    'bankTransfer': 'بانکي لېږد',
    'other': 'نور',
    'paidNow': 'اوس ورکړل شوې',
    'paymentReference': 'د تادیې حواله (اختیاري)',
    'remaining': 'پاتې بیلانس',
    'saveDraft': 'مسوده ساتل',
    'postPurchase': 'پېرود ثبتول',
    'selectSupplier': 'د دوام لپاره عرضه کوونکی وټاکئ.',
    'possibleDuplicate': 'د عرضه کوونکي د بل تکرار کېدای شي',
    'duplicateInvoice': 'د همدې عرضه کوونکي لپاره دا د بل شمېره په ثبت شوي پېرود کې شته. بیا هم دوام کوئ؟',
    'continueAnyway': 'بیا هم دوام',
    'invalidLine': 'د هر توکي سمه اندازه او بیه ولیکئ.',
    'invalidTotals': 'تخفیف، لګښتونه او تادیه وګورئ.',
    'confirmPost': 'پېرود تایید کړئ',
    'total': 'ټول',
    'unsavedChanges': 'نه ساتل شوي بدلونونه',
    'discardChanges': 'د دې پېرود بدلونونه پرېږدئ؟',
    'discard': 'پرېښودل',
    'loadError': 'د پېرود معلومات نه دي لوډ شوي.',
    'retry': 'بیا هڅه',
  },
  'fa': {
    'back': 'بازگشت',
    'newPurchase': 'خرید جدید پارچه',
    'draft': 'پیش‌نویس',
    'supplierInvoice': 'تأمین‌کننده و فاکتور',
    'supplier': 'تأمین‌کننده',
    'fabric': 'پارچه',
    'supplierHint': 'جستجو با نام یا موبایل',
    'addSupplier': 'افزودن تأمین‌کننده',
    'mobile': 'موبایل',
    'save': 'ذخیره',
    'cancel': 'لغو',
    'invoiceNumber': 'شماره فاکتور تأمین‌کننده',
    'date': 'تاریخ خرید',
    'purchaseNumber': 'شماره خرید',
    'notes': 'یادداشت',
    'notesHint': 'یادداشت اختیاری',
    'fabricItems': 'اقلام پارچه',
    'searchAddFabric': 'جستجو و افزودن پارچه',
    'fabricHint': 'جستجو با نام، کد، رنگ یا بارکد پارچه',
    'unitAndStock': 'واحد · موجودی',
    'addFabric': 'افزودن پارچه',
    'color': 'رنگ',
    'unitCost': 'قیمت خرید هر واحد',
    'sellingPrice': 'قیمت فروش فعلی',
    'openingStockZero': 'موجودی آغازین صفر تعیین می‌شود.',
    'noFabrics': 'پارچه پیدا نشد. برای ادامه پارچه اضافه کنید.',
    'availableStock': 'موجودی در دسترس',
    'availableCredit': 'اعتبار موجود تأمین‌کننده',
    'previousPayable': 'بدهی قبلی',
    'resultingPayable': 'بدهی نهایی',
    'resultingCredit': 'اعتبار نهایی',
    'viewLedger': 'مشاهده دفتر تأمین‌کننده',
    'noLedger': 'در دفتر تأمین‌کننده موردی ثبت نشده است.',
    'charge': 'خریدها',
    'payment': 'پرداخت‌ها / اعتبارها',
    'quantity': 'مقدار',
    'lineTotal': 'جمع ردیف',
    'remove': 'حذف',
    'confirmRemove': 'این ردیف پارچه حذف شود؟',
    'addLine': 'افزودن ردیف پارچه',
    'totalsPayment': 'جمع و پرداخت',
    'subtotal': 'جمع جزء',
    'discountFixed': 'تخفیف (مبلغ ثابت AFN)',
    'extraCosts': 'هزینه‌های مربوط به خرید',
    'grandTotal': 'جمع کل',
    'paymentMethod': 'روش پرداخت',
    'cash': 'نقد',
    'bankTransfer': 'انتقال بانکی',
    'other': 'دیگر',
    'paidNow': 'پرداخت فعلی',
    'paymentReference': 'مرجع پرداخت (اختیاری)',
    'remaining': 'مانده این خرید',
    'saveDraft': 'ذخیره پیش‌نویس',
    'postPurchase': 'ثبت خرید',
    'selectSupplier': 'برای ادامه یک تأمین‌کننده انتخاب کنید.',
    'possibleDuplicate': 'احتمال تکراری بودن فاکتور',
    'duplicateInvoice': 'این شماره فاکتور برای همین تأمین‌کننده در خریدی ثبت‌شده وجود دارد. ادامه می‌دهید؟',
    'continueAnyway': 'ادامه',
    'invalidLine': 'مقدار و قیمت هر ردیف را بررسی کنید.',
    'invalidTotals': 'تخفیف، هزینه‌ها و پرداخت را بررسی کنید.',
    'confirmPost': 'تأیید خرید',
    'total': 'مجموع',
    'unsavedChanges': 'تغییرات ذخیره‌نشده',
    'discardChanges': 'تغییرات این خرید کنار گذاشته شود؟',
    'discard': 'کنار گذاشتن',
    'loadError': 'اطلاعات خرید بارگیری نشد.',
    'retry': 'تلاش دوباره',
  },
};

const _words = <String, Map<String, String>>{
  'en': {
    'back': 'Back',
    'newPurchase': 'New Fabric Purchase',
    'draft': 'Draft',
    'supplierInvoice': 'Supplier and Invoice',
    'supplier': 'Supplier',
    'fabric': 'Fabric',
    'supplierHint': 'Search by supplier name or mobile',
    'clearSearch': 'Clear search',
    'noSupplierMatches': 'No suppliers match this search.',
    'noFabricMatches': 'No fabrics match this search.',
    'addSupplier': 'Add supplier',
    'mobile': 'Mobile',
    'save': 'Save',
    'cancel': 'Cancel',
    'invoiceNumber': 'Supplier invoice / bill number',
    'date': 'Purchase date',
    'purchaseNumber': 'Purchase number',
    'notes': 'Notes',
    'notesHint': 'Optional purchase notes',
    'fabricItems': 'Fabric Items',
    'searchAddFabric': 'Search and Add Fabric',
    'fabricHint': 'Search by fabric name, code, color or barcode',
    'unitAndStock': 'Unit · stock',
    'addFabric': 'Add fabric',
    'color': 'Color',
    'unitCost': 'Purchase price per unit',
    'sellingPrice': 'Current selling price',
    'openingStockZero': 'Opening stock is set to zero for this purchase.',
    'noFabrics': 'No fabric found. Add fabric to continue.',
    'availableStock': 'Available stock',
    'availableCredit': 'Available supplier credit',
    'previousPayable': 'Previous amount owed',
    'resultingPayable': 'Resulting amount owed',
    'resultingCredit': 'Resulting supplier credit',
    'viewLedger': 'View supplier ledger',
    'noLedger': 'No supplier ledger entries.',
    'charge': 'Purchases',
    'payment': 'Payments / credits',
    'quantity': 'Quantity',
    'lineTotal': 'Line total',
    'remove': 'Remove',
    'confirmRemove': 'Remove this entered fabric line?',
    'addLine': 'Add fabric line',
    'totalsPayment': 'Totals and Payment',
    'subtotal': 'Subtotal',
    'discountFixed': 'Discount (fixed AFN)',
    'extraCosts': 'Purchase-related costs',
    'grandTotal': 'Grand total',
    'paymentMethod': 'Payment method',
    'cash': 'Cash',
    'bankTransfer': 'Bank transfer',
    'other': 'Other',
    'paidNow': 'Amount paid now',
    'paymentReference': 'Payment reference (optional)',
    'remaining': 'Remaining on this purchase',
    'saveDraft': 'Save Draft',
    'postPurchase': 'Post Purchase',
    'selectSupplier': 'Select a supplier to continue.',
    'possibleDuplicate': 'Possible duplicate supplier invoice',
    'duplicateInvoice': 'A posted purchase already uses this invoice number for this supplier. Continue anyway?',
    'continueAnyway': 'Continue anyway',
    'invalidLine': 'Enter a valid quantity and unit cost for each fabric line.',
    'invalidTotals': 'Check discount, costs, and payment. The discount and payment cannot exceed the purchase total.',
    'confirmPost': 'Confirm purchase',
    'unsavedChanges': 'Unsaved changes',
    'discardChanges': 'Discard changes to this purchase?',
    'discard': 'Discard',
    'total': 'Total',
    'loadError': 'Purchase information could not be loaded.',
    'retry': 'Retry',
  },
  'ps': {
    'back': 'شاته',
    'newPurchase': 'د ټوکر نوې پېرودنه',
    'draft': 'مسوده',
    'supplierInvoice': 'عرضه کوونکی او بل',
    'supplier': 'عرضه کوونکی',
    'supplierHint': 'د نوم یا موبایل له لارې لټون',
    'clearSearch': 'لټون پاکول',
    'noSupplierMatches': 'د لټون له مخې عرضه کوونکی ونه موندل شو.',
    'noFabricMatches': 'د لټون له مخې ټوکر ونه موندل شو.',
    'addSupplier': 'عرضه کوونکی زیاتول',
    'mobile': 'موبایل',
    'save': 'ثبتول',
    'cancel': 'لغوه',
    'invoiceNumber': 'د عرضه کوونکي بل شمېره',
    'date': 'د پېرود نېټه',
    'purchaseNumber': 'د پېرود شمېره',
    'notes': 'یادښتونه',
    'notesHint': 'اختیاري یادښتونه',
    'fabricItems': 'د ټوکر توکي',
    'searchAddFabric': 'ټوکر ولټوه او زیات یې کړه',
    'addFabric': 'ټوکر زیاتول',
    'color': 'رنګ',
    'unitCost': 'د هر واحد د پېرود بیه',
    'sellingPrice': 'اوسنۍ د پلور بیه',
    'openingStockZero': 'د پیل موجودي صفر ټاکل کېږي.',
    'noFabrics': 'ټوکر ونه موندل شو.',
    'availableStock': 'شته موجودي',
    'quantity': 'اندازه',
    'lineTotal': 'د کرښې ټول',
    'remove': 'لرې کول',
    'confirmRemove': 'دا د ټوکر کرښه لرې شي؟',
    'addLine': 'د ټوکر کرښه زیاتول',
    'totalsPayment': 'ټول او تادیه',
    'subtotal': 'فرعي ټول',
    'discountFixed': 'تخفیف (ثابت AFN)',
    'extraCosts': 'د پېرود لګښتونه',
    'grandTotal': 'وروستی ټول',
    'paymentMethod': 'د تادیې طریقه',
    'cash': 'نغدې',
    'bankTransfer': 'بانکي لېږد',
    'other': 'نور',
    'paidNow': 'اوس ورکړل شوې',
    'paymentReference': 'د تادیې حواله',
    'remaining': 'پاتې بیلانس',
    'saveDraft': 'مسوده ساتل',
    'postPurchase': 'پېرود ثبتول',
    'selectSupplier': 'عرضه کوونکی وټاکئ.',
    'invalidLine': 'د هر توکي سمه اندازه او بیه ولیکئ.',
    'invalidTotals': 'تخفیف، لګښتونه او تادیه وګورئ.',
    'saveDraftFirst': 'د ثبتولو مخکې مسوده وساتئ.',
    'confirmPost': 'پېرود تایید کړئ',
    'total': 'ټول',
    'loadError': 'د پېرود معلومات نه دي لوډ شوي.',
    'retry': 'بیا هڅه',
  },
  'fa': {
    'back': 'بازگشت',
    'newPurchase': 'خرید جدید پارچه',
    'draft': 'پیش‌نویس',
    'supplierInvoice': 'تأمین‌کننده و فاکتور',
    'supplier': 'تأمین‌کننده',
    'supplierHint': 'جستجو با نام یا موبایل',
    'clearSearch': 'پاک کردن جستجو',
    'noSupplierMatches': 'تأمین‌کننده‌ای با این جستجو پیدا نشد.',
    'noFabricMatches': 'پارچه‌ای با این جستجو پیدا نشد.',
    'addSupplier': 'افزودن تأمین‌کننده',
    'mobile': 'موبایل',
    'save': 'ذخیره',
    'cancel': 'لغو',
    'invoiceNumber': 'شماره فاکتور تأمین‌کننده',
    'date': 'تاریخ خرید',
    'purchaseNumber': 'شماره خرید',
    'notes': 'یادداشت',
    'notesHint': 'یادداشت اختیاری',
    'fabricItems': 'اقلام پارچه',
    'searchAddFabric': 'جستجو و افزودن پارچه',
    'addFabric': 'افزودن پارچه',
    'color': 'رنگ',
    'unitCost': 'قیمت خرید هر واحد',
    'sellingPrice': 'قیمت فروش فعلی',
    'openingStockZero': 'موجودی آغازین صفر تعیین می‌شود.',
    'noFabrics': 'پارچه پیدا نشد.',
    'availableStock': 'موجودی در دسترس',
    'quantity': 'مقدار',
    'lineTotal': 'جمع ردیف',
    'remove': 'حذف',
    'confirmRemove': 'این ردیف پارچه حذف شود؟',
    'addLine': 'افزودن ردیف پارچه',
    'totalsPayment': 'جمع و پرداخت',
    'subtotal': 'جمع جزء',
    'discountFixed': 'تخفیف (مبلغ ثابت AFN)',
    'extraCosts': 'هزینه‌های خرید',
    'grandTotal': 'جمع کل',
    'paymentMethod': 'روش پرداخت',
    'cash': 'نقد',
    'bankTransfer': 'انتقال بانکی',
    'other': 'دیگر',
    'paidNow': 'پرداخت فعلی',
    'paymentReference': 'مرجع پرداخت',
    'remaining': 'مانده این خرید',
    'saveDraft': 'ذخیره پیش‌نویس',
    'postPurchase': 'ثبت خرید',
    'selectSupplier': 'یک تأمین‌کننده انتخاب کنید.',
    'invalidLine': 'مقدار و قیمت هر ردیف را بررسی کنید.',
    'invalidTotals': 'تخفیف، هزینه و پرداخت را بررسی کنید.',
    'saveDraftFirst': 'پیش از ثبت، خرید را ذخیره کنید.',
    'confirmPost': 'تأیید خرید',
    'total': 'مجموع',
    'loadError': 'اطلاعات خرید بارگیری نشد.',
    'retry': 'تلاش دوباره',
  },
};

const _purchaseRedesignWords = <String, Map<String, String>>{
  'en': {
    'addShort': 'Add',
    'added': 'Added',
    'alreadyAdded': 'Already added. Edit the quantity on the invoice.',
    'chooseSupplier': 'Choose supplier',
    'adjustments': 'Discount and purchase charges',
    'payFull': 'Pay Full Amount',
    'buyCredit': 'Buy on Credit',
    'emptyInvoice':
        'Find fabric, then select Add to start your purchase invoice.',
    'remaining': 'Owed for this purchase',
    'posted': 'Confirmed',
    'saving': 'Saving purchase…',
  },
  'ps': {
    'addShort': 'زیاتول',
    'added': 'زیات شو',
    'alreadyAdded': 'دا ټوکر زیات شوی دی. په بل کې یې اندازه بدله کړئ.',
    'chooseSupplier': 'عرضه کوونکی وټاکئ',
    'adjustments': 'تخفیف او د پېرود لګښتونه',
    'payFull': 'بشپړه تادیه',
    'buyCredit': 'په پور پېرود',
    'emptyInvoice': 'ټوکر ولټوئ او د بل د پیل لپاره د زیاتولو تڼۍ ووهئ.',
    'remaining': 'د دې پېرود پاتې پور',
    'posted': 'تایید شو',
    'saving': 'پېرود ساتل کېږي…',
  },
  'fa': {
    'addShort': 'افزودن',
    'added': 'افزوده شد',
    'alreadyAdded':
        'این پارچه افزوده شده است. مقدار آن را در فاکتور تغییر دهید.',
    'chooseSupplier': 'انتخاب تأمین‌کننده',
    'adjustments': 'تخفیف و هزینه‌های خرید',
    'payFull': 'پرداخت کامل',
    'buyCredit': 'خرید نسیه',
    'emptyInvoice':
        'پارچه را جستجو کرده و برای شروع فاکتور، افزودن را انتخاب کنید.',
    'remaining': 'بدهی این خرید',
    'posted': 'تأیید شد',
    'saving': 'خرید در حال ذخیره شدن است…',
  },
};
