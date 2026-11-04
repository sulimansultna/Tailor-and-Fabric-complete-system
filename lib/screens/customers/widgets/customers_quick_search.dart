import 'package:flutter/material.dart';

import '../../../data/shop_database.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../../../widgets/section_title.dart';
import 'customer_tile.dart';

class CustomersQuickSearch extends StatefulWidget {
  const CustomersQuickSearch({
    super.key,
    required this.database,
    required this.query,
    required this.onChanged,
  });
  final ShopDatabase database;
  final String query;
  final VoidCallback onChanged;
  @override
  State<CustomersQuickSearch> createState() => _CustomersQuickSearchState();
}

class _CustomersQuickSearchState extends State<CustomersQuickSearch> {
  List<Map<String, Object?>> rows = [];
  @override
  void didUpdateWidget(covariant CustomersQuickSearch old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    rows = await widget.database.searchCustomers(widget.query);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionTitle(
        context,
        context.l10n.recentCustomers,
        trailing: TextButton(
          onPressed: widget.onChanged,
          child: Text(context.l10n.viewAll),
        ),
      ),
      Expanded(
        child: rows.isEmpty
            ? Center(child: Text(context.l10n.noCustomersYet))
            : ListView.separated(
                itemCount: rows.length,
                itemBuilder: (context, i) => CustomerTile(
                  customer: rows[i],
                  database: widget.database,
                  onChanged: () async => _load(),
                ),
                separatorBuilder: (_, _) => const Divider(height: 1),
              ),
      ),
    ],
  );
}
