/// Pure report calculations shared by the stitching and fabric report views.
/// Monetary amounts use the database's fixed two-decimal minor units and
/// quantities use thousandths of a meter.
int _reportInt(Object? value) => (value as num?)?.toInt() ?? 0;

int? _rateFromAmount(int amount, int quantityMilli) =>
    quantityMilli == 0 ? null : (amount * 1000 / quantityMilli).round();

List<int> allocateReportAmount(int amount, List<int> rawWeights) =>
    _allocateAmount(amount, rawWeights);

List<int> _allocateAmount(int amount, List<int> rawWeights) {
  if (rawWeights.isEmpty) return const [];
  final weights = rawWeights.map((value) => value < 0 ? 0 : value).toList();
  final totalWeight = weights.fold<int>(0, (total, value) => total + value);
  if (totalWeight == 0) {
    final sign = amount.isNegative ? -1 : 1;
    final magnitude = amount.abs();
    final base = magnitude ~/ weights.length;
    var remainder = magnitude - base * weights.length;
    return [
      for (var i = 0; i < weights.length; i++)
        (base + (remainder-- > 0 ? 1 : 0)) * sign,
    ];
  }
  final sign = amount.isNegative ? -1 : 1;
  final magnitude = amount.abs();
  final allocations = <(int, int)>[];
  var allocated = 0;
  for (var i = 0; i < weights.length; i++) {
    final numerator = magnitude * weights[i];
    final base = numerator ~/ totalWeight;
    allocations.add((base, numerator % totalWeight));
    allocated += base;
  }
  final remainder = magnitude - allocated;
  final priority = List<int>.generate(weights.length, (index) => index)
    ..sort((a, b) {
      final byRemainder = allocations[b].$2.compareTo(allocations[a].$2);
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  final results = [for (final item in allocations) item.$1];
  for (var index = 0; index < remainder; index++) {
    results[priority[index]]++;
  }
  return [for (final value in results) value * sign];
}

({Map<int, int> stitchingRevenue, Map<String, int> fabricRevenue})
_allocateOrderDiscounts(
  List<Map<String, Object?>> stitchingLines,
  List<Map<String, Object?>> fabricLines,
) {
  final lineGroups = <int, List<Map<String, Object?>>>{};
  for (final line in stitchingLines) {
    lineGroups.putIfAbsent(_reportInt(line['order_id']), () => []).add(line);
  }
  final fabricGroups = <int, List<Map<String, Object?>>>{};
  for (final line in fabricLines) {
    fabricGroups.putIfAbsent(_reportInt(line['order_id']), () => []).add(line);
  }

  final stitchingRevenue = <int, int>{};
  final fabricRevenue = <String, int>{};
  final orderIds = <int>{...lineGroups.keys, ...fabricGroups.keys};
  for (final orderId in orderIds) {
    final orderLines = lineGroups[orderId] ?? const [];
    final shopFabricLines = fabricGroups[orderId] ?? const [];
    final first = orderLines.isNotEmpty
        ? orderLines.first
        : shopFabricLines.first;
    final rawLineWeights = orderLines
        .map(
          (line) =>
              _reportInt(line['quantity']) * _reportInt(line['price_each']),
        )
        .toList();
    final lineAmount = rawLineWeights.fold<int>(
      0,
      (total, value) => total + value,
    );
    final storedStitching = _reportInt(first['stitching_total']);
    final stitchingGross =
        (storedStitching == 0 && lineAmount > 0
            ? lineAmount
            : storedStitching) +
        _reportInt(first['extra']);
    final fabricGross = shopFabricLines
        .map((line) => _reportInt(line['gross_revenue']))
        .toList();
    final discount = _reportInt(first['discount']);
    final discountShares = allocateReportAmount(discount, [
      stitchingGross,
      ...fabricGross,
    ]);
    if (orderLines.isNotEmpty) {
      final netStitching = stitchingGross - discountShares.first;
      final lineShares = allocateReportAmount(netStitching, rawLineWeights);
      for (var index = 0; index < orderLines.length; index++) {
        stitchingRevenue[_reportInt(orderLines[index]['line_id'])] =
            lineShares[index];
      }
    }
    for (var index = 0; index < shopFabricLines.length; index++) {
      final row = shopFabricLines[index];
      fabricRevenue['$orderId:${row['fabric_id'] ?? 'unknown'}'] =
          fabricGross[index] - discountShares[index + 1];
    }
  }
  return (stitchingRevenue: stitchingRevenue, fabricRevenue: fabricRevenue);
}

Map<String, Object?> buildStitchingProfitReport({
  required List<Map<String, Object?>> stitchingLines,
  required List<Map<String, Object?>> shopFabricLines,
  List<Map<String, Object?>> returns = const [],
  List<Map<String, Object?>> cancellations = const [],
}) {
  final allocations = _allocateOrderDiscounts(stitchingLines, shopFabricLines);
  final rows = <Map<String, Object?>>[];
  for (final line in stitchingLines) {
    final earningCount = _reportInt(line['earning_count']);
    final laborCost = _reportInt(line['labor_cost']);
    final revenue =
        allocations.stitchingRevenue[_reportInt(line['line_id'])] ?? 0;
    final cancelledWithoutWork =
        line['cancellation_status'] == 'Cancelled' &&
        _reportInt(line['work_started']) == 0;
    final costKnown = earningCount > 0 || cancelledWithoutWork;
    final status = '${line['status']}';
    final costStatus = !costKnown
        ? 'unavailable'
        : status == 'Ready' || status == 'Delivered'
        ? 'estimated'
        : 'incomplete';
    rows.add({
      'date': line['date'],
      'bill_number': line['bill_number'],
      'customer': line['customer'],
      'garment': line['garment'],
      'quantity': _reportInt(line['quantity']),
      'stitching_revenue': revenue,
      'direct_cost': costKnown ? laborCost : null,
      'gross_profit': costKnown ? revenue - laborCost : null,
      'cost_status': costStatus,
    });
  }
  for (final returned in returns) {
    final revenue = _reportInt(returned['revenue']);
    rows.add({
      'date': returned['date'],
      'bill_number': returned['bill_number'],
      'customer': returned['customer'],
      'garment': returned['garment'],
      'quantity': -_reportInt(returned['quantity']),
      'stitching_revenue': -revenue,
      'direct_cost': 0,
      'gross_profit': -revenue,
      'cost_status': 'not_applicable',
      'transaction_type': 'stitching_return',
      'return_reference': returned['return_number'],
    });
  }
  for (final cancellation in cancellations) {
    final revenue =
        _reportInt(cancellation['retained_stitching']) -
        _reportInt(cancellation['original_stitching']);
    rows.add({
      'date': cancellation['date'],
      'bill_number': cancellation['bill_number'],
      'customer': cancellation['customer'],
      'garment': 'Order cancellation adjustment',
      'quantity': 0,
      'stitching_revenue': revenue,
      'direct_cost': 0,
      'gross_profit': revenue,
      'cost_status': 'not_applicable',
      'transaction_type': 'order_cancellation',
      'cancellation_reason': cancellation['reason'],
    });
  }

  final missingCostLines = rows
      .where((row) => row['gross_profit'] == null)
      .length;
  final grossProfit = missingCostLines == 0
      ? rows.fold<int>(
          0,
          (total, row) => total + _reportInt(row['gross_profit']),
        )
      : null;
  final totals = <String, Object?>{
    'net_stitching_revenue': rows.fold<int>(
      0,
      (total, row) => total + _reportInt(row['stitching_revenue']),
    ),
    'direct_stitching_costs': rows.fold<int>(
      0,
      (total, row) => total + _reportInt(row['direct_cost']),
    ),
    'gross_profit': grossProfit,
    'garment_quantity': rows.fold<int>(
      0,
      (total, row) => total + _reportInt(row['quantity']),
    ),
    'missing_cost_lines': missingCostLines,
    'incomplete_lines': rows
        .where((row) => row['cost_status'] == 'incomplete')
        .length,
    'profit_status': missingCostLines > 0
        ? (missingCostLines == rows.length ? 'unavailable' : 'incomplete')
        : rows.any((row) => row['cost_status'] == 'incomplete')
        ? 'incomplete'
        : rows.isEmpty
        ? 'complete'
        : 'estimated',
  };
  return {'rows': rows, 'totals': totals};
}

Map<String, Object?> buildFabricProfitReport({
  required List<Map<String, Object?>> directSales,
  required List<Map<String, Object?>> directReturns,
  required List<Map<String, Object?>> stitchingLines,
  required List<Map<String, Object?>> shopFabricLines,
  List<Map<String, Object?>> stitchingReturns = const [],
  List<Map<String, Object?>> orderCancellations = const [],
}) {
  final allocations = _allocateOrderDiscounts(stitchingLines, shopFabricLines);
  final rows = <Map<String, Object?>>[];

  for (final sale in directSales) {
    final quantity = _reportInt(sale['quantity_milli']);
    final movementCount = _reportInt(sale['movement_count']);
    final missingMovementCosts = _reportInt(
      sale['missing_movement_cost_count'],
    );
    final missingLineCosts = _reportInt(sale['missing_line_cost_count']);
    final hasMovementCost = movementCount > 0;
    final recordedCost = hasMovementCost
        ? _reportInt(sale['movement_cost'])
        : _reportInt(sale['line_recorded_cost']);
    final costAvailable = hasMovementCost
        ? missingMovementCosts == 0 && recordedCost > 0
        : missingLineCosts == 0 && recordedCost > 0;
    final revenue = _reportInt(sale['net_revenue']);
    final grossProfit = costAvailable ? revenue - recordedCost : null;
    rows.add({
      'transaction_id': sale['transaction_id'],
      'transaction_type': 'direct_fabric_sale',
      'fabric_source': 'shop',
      'date': sale['date'],
      'bill_number': sale['bill_number'],
      'customer': sale['customer'],
      'source': 'Direct Sale',
      'fabric': sale['fabric'],
      'code': sale['code'],
      'category': sale['category'],
      'quantity_meters': quantity / 1000,
      'cost_rate': costAvailable
          ? _rateFromAmount(recordedCost, quantity)
          : null,
      'selling_rate': _rateFromAmount(revenue, quantity),
      'net_revenue': revenue,
      'recorded_cost': costAvailable ? recordedCost : null,
      'gross_profit': grossProfit,
      'profit_per_meter': grossProfit == null
          ? null
          : _rateFromAmount(grossProfit, quantity),
      'cost_status': costAvailable ? 'recorded' : 'unavailable',
    });
  }

  for (final returned in directReturns) {
    final quantity = _reportInt(returned['quantity_milli']);
    final missing = _reportInt(returned['missing_cost_count']);
    final restockedQuantity = _reportInt(returned['restocked_quantity_milli']);
    final costAvailable =
        missing == 0 &&
        (restockedQuantity == 0 || _reportInt(returned['cost_weight']) > 0);
    final revenue = _reportInt(returned['revenue']);
    final cost = _reportInt(returned['recorded_cost']);
    final grossProfit = costAvailable ? -revenue + cost : null;
    rows.add({
      'transaction_id': returned['transaction_id'],
      'transaction_type': 'direct_fabric_return',
      'fabric_source': 'shop',
      'date': returned['date'],
      'bill_number': returned['bill_number'],
      'reference': returned['return_number'],
      'customer': returned['customer'],
      'source': returned['source'] ?? 'Direct Sale',
      'fabric': returned['fabric'],
      'code': returned['code'],
      'category': returned['category'],
      'quantity_meters': -quantity / 1000,
      'cost_rate': costAvailable && restockedQuantity > 0
          ? _rateFromAmount(
              _reportInt(returned['cost_weight']),
              restockedQuantity,
            )
          : null,
      'selling_rate': _rateFromAmount(revenue, quantity),
      'net_revenue': -revenue,
      'recorded_cost': costAvailable ? -cost : null,
      'gross_profit': grossProfit,
      'profit_per_meter': grossProfit == null
          ? null
          : _rateFromAmount(grossProfit, quantity),
      'cost_status': costAvailable ? 'recorded' : 'unavailable',
    });
  }

  for (final returned in stitchingReturns) {
    final quantity = _reportInt(returned['quantity_milli']);
    final revenue = _reportInt(returned['revenue']);
    final cost = _reportInt(returned['recorded_cost']);
    final restocked = _reportInt(returned['restock']);
    final missingCost = _reportInt(returned['missing_cost_count']);
    final costAvailable = restocked == 0 || missingCost == 0;
    final reversedCost = restocked == 1 ? cost : 0;
    rows.add({
      'transaction_id': returned['transaction_id'],
      'transaction_type': 'stitching_fabric_return',
      'fabric_source': 'shop',
      'date': returned['date'],
      'bill_number': returned['bill_number'],
      'reference': returned['return_number'],
      'customer': returned['customer'],
      'source': 'Stitching Order',
      'fabric': returned['fabric'],
      'code': returned['code'],
      'category': returned['category'],
      'quantity_meters': -quantity / 1000,
      'cost_rate': costAvailable && restocked == 1
          ? _rateFromAmount(reversedCost, quantity)
          : null,
      'selling_rate': _rateFromAmount(revenue, quantity),
      'net_revenue': -revenue,
      'recorded_cost': costAvailable && restocked == 1
          ? -reversedCost
          : (costAvailable ? 0 : null),
      'gross_profit': costAvailable ? -revenue + reversedCost : null,
      'profit_per_meter': costAvailable
          ? _rateFromAmount(-revenue + reversedCost, quantity)
          : null,
      'cost_status': costAvailable ? 'recorded' : 'unavailable',
    });
  }

  for (final cancellation in orderCancellations) {
    final quantity =
        _reportInt(cancellation['retained_quantity_milli']) -
        _reportInt(cancellation['original_quantity_milli']);
    final revenue =
        _reportInt(cancellation['retained_revenue']) -
        _reportInt(cancellation['original_revenue']);
    final cost =
        _reportInt(cancellation['retained_cost']) -
        _reportInt(cancellation['original_cost']);
    final costAvailable = _reportInt(cancellation['missing_cost']) == 0;
    rows.add({
      'transaction_id': cancellation['transaction_id'],
      'transaction_type': 'order_cancellation_adjustment',
      'fabric_source': 'shop',
      'date': cancellation['date'],
      'bill_number': cancellation['bill_number'],
      'reference': cancellation['bill_number'],
      'customer': cancellation['customer'],
      'source': 'Order Cancellation',
      'fabric': cancellation['fabric'],
      'code': cancellation['code'],
      'category': cancellation['category'],
      'quantity_meters': quantity / 1000,
      'cost_rate': null,
      'selling_rate': null,
      'net_revenue': revenue,
      'recorded_cost': costAvailable ? cost : null,
      'gross_profit': costAvailable ? revenue - cost : null,
      'profit_per_meter': null,
      'cost_status': costAvailable ? 'recorded' : 'unavailable',
    });
  }

  for (final supplied in shopFabricLines) {
    final quantity = _reportInt(supplied['quantity_milli']);
    final recordedCost = _reportInt(supplied['line_recorded_cost']);
    final missingLineCosts = _reportInt(supplied['missing_line_cost_count']);
    final unpricedQuantity = _reportInt(supplied['unpriced_quantity_milli']);
    final hasPrice = unpricedQuantity == 0;
    final costAvailable = quantity > 0 && missingLineCosts == 0;
    final orderId = _reportInt(supplied['order_id']);
    final fabricKey = '$orderId:${supplied['fabric_id'] ?? 'unknown'}';
    final savedNet = _reportInt(supplied['missing_saved_net_count']) == 0;
    final allocatedRevenue = savedNet
        ? _reportInt(supplied['saved_net_revenue'])
        : allocations.fabricRevenue[fabricKey] ??
              _reportInt(supplied['gross_revenue']);
    final revenue = hasPrice ? allocatedRevenue : null;
    final grossProfit = costAvailable && revenue != null
        ? revenue - recordedCost
        : null;
    rows.add({
      'transaction_id': orderId,
      'transaction_type': 'stitching_order_fabric',
      'fabric_source': 'shop',
      'date': supplied['date'],
      'bill_number': supplied['bill_number'],
      'customer': supplied['customer'],
      'source': 'Stitching Order',
      'fabric': supplied['fabric'] ?? 'Unidentified fabric',
      'code': supplied['code'],
      'category': supplied['category'],
      'quantity_meters': quantity / 1000,
      'cost_rate': costAvailable
          ? _rateFromAmount(recordedCost, quantity)
          : null,
      'selling_rate': hasPrice
          ? _rateFromAmount(_reportInt(supplied['gross_revenue']), quantity)
          : null,
      'net_revenue': revenue,
      'recorded_cost': costAvailable ? recordedCost : null,
      'gross_profit': grossProfit,
      'profit_per_meter': grossProfit == null
          ? null
          : _rateFromAmount(grossProfit, quantity),
      'cost_status': !hasPrice
          ? 'unavailable'
          : costAvailable
          ? 'recorded'
          : 'unavailable',
    });
  }

  rows.sort((a, b) {
    final date = '${a['date']}'.compareTo('${b['date']}');
    if (date != 0) return date;
    return '${a['bill_number']}'.compareTo('${b['bill_number']}');
  });

  Map<String, Object?> subtotal(
    String category,
    List<Map<String, Object?>> records,
  ) {
    num sum(String field) => records.fold<num>(
      0,
      (total, row) => total + ((row[field] as num?) ?? 0),
    );
    bool unknown(String field) => records.any((row) => row[field] == null);
    return {
      'category': category,
      'net_meters': sum('quantity_meters'),
      'net_revenue': unknown('net_revenue') ? null : sum('net_revenue').toInt(),
      'recorded_cost': unknown('recorded_cost')
          ? null
          : sum('recorded_cost').toInt(),
      'gross_profit': unknown('gross_profit')
          ? null
          : sum('gross_profit').toInt(),
      'missing_cost_lines': records
          .where((row) => row['recorded_cost'] == null)
          .length,
      'unpriced_lines': records
          .where((row) => row['net_revenue'] == null)
          .length,
    };
  }

  final categoryGroups = <String, List<Map<String, Object?>>>{};
  for (final row in rows) {
    final category = '${row['category']}'.trim().isEmpty
        ? 'Uncategorized'
        : '${row['category']}';
    categoryGroups.putIfAbsent(category, () => []).add(row);
  }
  final categorySubtotals = categoryGroups.entries
      .map((entry) => subtotal(entry.key, entry.value))
      .toList();
  final totals = subtotal('Grand total', rows);
  return {
    'rows': rows,
    'category_subtotals': categorySubtotals,
    'totals': totals,
    'categories': const ['Clothing Fabric', 'Waistcoat / Coat Fabric'],
  };
}
