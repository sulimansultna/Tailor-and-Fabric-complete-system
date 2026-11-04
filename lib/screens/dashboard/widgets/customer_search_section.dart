import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatters.dart';
import '../../../data/shop_database.dart';
import '../dashboard_strings.dart';

class CustomerSearchSection extends StatefulWidget {
  const CustomerSearchSection({
    super.key,
    required this.database,
    required this.strings,
    required this.onSelect,
    required this.onAddCustomer,
    required this.onViewAll,
    required this.onQueryChanged,
    this.searchFocusNode,
  });

  final ShopDatabase database;
  final DashboardStrings strings;
  final ValueChanged<Map<String, Object?>> onSelect;
  final ValueChanged<String> onAddCustomer;
  final VoidCallback onViewAll;
  final ValueChanged<String> onQueryChanged;
  final FocusNode? searchFocusNode;

  @override
  State<CustomerSearchSection> createState() => _CustomerSearchSectionState();
}

class _CustomerSearchSectionState extends State<CustomerSearchSection> {
  final controller = TextEditingController();
  late final focusNode = widget.searchFocusNode ?? FocusNode();
  Timer? debounce;
  List<Map<String, Object?>> matches = [];
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

  void _submit() {
    if (activeIndex >= 0 && activeIndex < matches.length) {
      widget.onSelect(matches[activeIndex]);
    } else if (matches.length == 1) {
      widget.onSelect(matches.single);
    }
  }

  Future<void> _search() async {
    final id = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.database.searchCustomers(controller.text);
      if (!mounted || id != requestId) return;
      setState(() {
        matches = result;
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
        matches.isNotEmpty) {
      setState(() => activeIndex = (activeIndex + 1) % matches.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && matches.isNotEmpty) {
      setState(
        () => activeIndex = activeIndex <= 0
            ? matches.length - 1
            : activeIndex - 1,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (activeIndex >= 0 && activeIndex < matches.length) {
        widget.onSelect(matches[activeIndex]);
        return KeyEventResult.handled;
      }
      if (matches.length == 1) {
        widget.onSelect(matches.single);
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
                  widget.strings.get('searchCustomers'),
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
                hintText: widget.strings.get('searchHint'),
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
              matches.isEmpty)
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
        ],
      ),
    ),
  );
}
