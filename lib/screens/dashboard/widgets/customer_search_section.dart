import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatters.dart';
import '../../../data/shop_database.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../dashboard_strings.dart';
import 'dashboard_panel.dart';

class CustomerSearchSection extends StatefulWidget {
  const CustomerSearchSection({
    super.key,
    required this.database,
    required this.strings,
    required this.onSelect,
    required this.onAddCustomer,
    required this.onViewAll,
    required this.onQueryChanged,
    required this.onOpenBill,
    this.searchFocusNode,
  });

  final ShopDatabase database;
  final DashboardStrings strings;
  final ValueChanged<Map<String, Object?>> onSelect;
  final ValueChanged<String> onAddCustomer;
  final VoidCallback onViewAll;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Map<String, Object?>> onOpenBill;
  final FocusNode? searchFocusNode;

  @override
  State<CustomerSearchSection> createState() => _CustomerSearchSectionState();
}

class _CustomerSearchSectionState extends State<CustomerSearchSection> {
  final controller = TextEditingController();
  late final focusNode = widget.searchFocusNode ?? FocusNode();
  Timer? debounce;
  List<Map<String, Object?>> matches = [];
  List<Map<String, Object?>> bills = [];
  int activeIndex = -1;
  bool loading = false;
  String? error;
  int requestId = 0;

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    if (widget.searchFocusNode == null) focusNode.dispose();
    super.dispose();
  }

  void _changed(String value) {
    widget.onQueryChanged(value);
    debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        matches = [];
        bills = [];
        loading = false;
        error = null;
        activeIndex = -1;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    debounce = Timer(const Duration(milliseconds: 220), _search);
  }

  int get _resultCount => matches.length + bills.length;

  void _submit() {
    if (activeIndex >= 0 && activeIndex < matches.length) {
      widget.onSelect(matches[activeIndex]);
    } else if (activeIndex >= matches.length && activeIndex < _resultCount) {
      widget.onOpenBill(bills[activeIndex - matches.length]);
    } else if (matches.length == 1 && bills.isEmpty) {
      widget.onSelect(matches.single);
    } else if (bills.length == 1 && matches.isEmpty) {
      widget.onOpenBill(bills.single);
    }
  }

  Future<void> _search() async {
    final id = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.database.searchCustomers(controller.text),
        widget.database.searchOrders(query: controller.text),
      ]);
      if (!mounted || id != requestId) return;
      setState(() {
        matches = results[0];
        bills = results[1].take(6).toList();
        loading = false;
        activeIndex = -1;
      });
    } catch (_) {
      if (!mounted || id != requestId) return;
      setState(() {
        loading = false;
        error = widget.strings.l10n.searchError;
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        _resultCount > 0) {
      setState(() => activeIndex = (activeIndex + 1) % _resultCount);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && _resultCount > 0) {
      setState(
        () => activeIndex = activeIndex <= 0
            ? _resultCount - 1
            : activeIndex - 1,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (activeIndex >= 0 && activeIndex < matches.length) {
        widget.onSelect(matches[activeIndex]);
        return KeyEventResult.handled;
      }
      if (activeIndex >= matches.length && activeIndex < _resultCount) {
        widget.onOpenBill(bills[activeIndex - matches.length]);
        return KeyEventResult.handled;
      }
      if (matches.length == 1 && bills.isEmpty) {
        widget.onSelect(matches.single);
        return KeyEventResult.handled;
      }
      if (bills.length == 1 && matches.isEmpty) {
        widget.onOpenBill(bills.single);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.dashSearchCustomersOrBills,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onViewAll,
                icon: const Icon(Icons.people_outline, size: 18),
                label: Text(widget.strings.get('viewAll')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Focus(
            onKeyEvent: _onKey,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onChanged: _changed,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 44,
                ),
                hintText: context.l10n.dashSearchCustomersOrBillsHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: widget.strings.l10n.clearSearch,
                        onPressed: () {
                          controller.clear();
                          _changed('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
          if (loading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (error != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(error!),
              trailing: TextButton(
                onPressed: _search,
                child: Text(widget.strings.l10n.retry),
              ),
            ),
          if (!loading &&
              error == null &&
              controller.text.trim().isNotEmpty &&
              matches.isEmpty &&
              bills.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(child: Text(widget.strings.get('noResults'))),
                  TextButton.icon(
                    onPressed: () => widget.onAddCustomer(controller.text),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(widget.strings.get('addCustomer')),
                  ),
                ],
              ),
            ),
          if (matches.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: matches.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final customer = matches[index];
                  final balance = (customer['balance'] as int?) ?? 0;
                  return Semantics(
                    button: true,
                    selected: index == activeIndex,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: index == activeIndex,
                      selectedTileColor: Theme.of(context).colorScheme.primary
                          .withValues(alpha: .10),
                      onTap: () => widget.onSelect(customer),
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        '${customer['name']}  ·  ${customer['phone']}',
                        textDirection: TextDirection.ltr,
                      ),
                      subtitle: Text(
                        '${widget.strings.get('customerId')}: ${customer['code'] ?? customer['id']}   ·   ${widget.strings.get('outstanding')}: ${formatMoney(balance, locale: Localizations.localeOf(context).toLanguageTag())}',
                        textDirection: TextDirection.ltr,
                      ),
                      trailing: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                      ),
                    ),
                  );
                },
              ),
            ),
          if (bills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.dashBills,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            for (var index = 0; index < bills.length; index++)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                selected: activeIndex == matches.length + index,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .10),
                onTap: () => widget.onOpenBill(bills[index]),
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(
                  '${bills[index]['bill_number'] ?? bills[index]['number'] ?? ''} · ${bills[index]['customer_name'] ?? bills[index]['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(widget.strings.get('${bills[index]['status']}')),
                trailing: StatusChip(
                  label: widget.strings.get('${bills[index]['status']}'),
                  tone: toneForStatus('${bills[index]['status']}'),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
