import '../data/shop_database.dart';
import 'profit_report_builder.dart';

/// Builds one immutable, database-consistent report snapshot for display/export.
class ReportService {
  const ReportService(this.database);
  final ShopDatabase database;

  Future<Map<String, Object?>> generate({
    required String fromDate,
    required String throughDate,
  }) async {
    if (fromDate.compareTo(throughDate) > 0) {
      throw ArgumentError('Start date must be on or before end date.');
    }
    return database.db.transaction((txn) async {
      final orders = await txn.rawQuery(
        '''
        SELECT o.id,o.order_date,o.bill_number,o.number,c.name AS customer,c.phone,
          o.due_date,o.status,o.total,o.discount,o.extra,o.stitching_total,
          COALESCE((SELECT GROUP_CONCAT(ol.garment || ' × ' || ol.quantity, ', ')
            FROM order_lines ol WHERE ol.order_id=o.id AND ol.record_state='Active'),'') AS garments
        FROM orders o JOIN customers c ON c.id=o.customer_id
        WHERE substr(o.order_date,1,10)>=? AND substr(o.order_date,1,10)<=?
        ORDER BY o.order_date,o.id''',
        [fromDate, throughDate],
      );
      final deliveries = await txn.rawQuery(
        '''
        SELECT h.changed_at AS date,o.bill_number,o.number,c.name AS customer,h.status,h.note
        FROM order_status_history h JOIN orders o ON o.id=h.order_id
        JOIN customers c ON c.id=o.customer_id
        WHERE substr(h.changed_at,1,10)>=? AND substr(h.changed_at,1,10)<=?
          AND (h.status LIKE '%Deliver%' OR h.status='Cancelled')
        ORDER BY h.changed_at,h.id''',
        [fromDate, throughDate],
      );
      final sales = await txn.rawQuery(
        '''
        SELECT o.order_date AS date,o.bill_number,o.number,c.name AS customer,
          o.stitching_total,o.extra,o.discount,
          COALESCE(ca.original_total,o.total) AS total,
          'Stitching order' AS source
        FROM orders o JOIN customers c ON c.id=o.customer_id
        LEFT JOIN order_cancellations ca ON ca.order_id=o.id
        WHERE substr(o.order_date,1,10)>=? AND substr(o.order_date,1,10)<=?
        UNION ALL
        SELECT r.date,o.bill_number,o.number,c.name,0,0,0,-r.amount,'Order return'
        FROM order_returns r JOIN orders o ON o.id=r.order_id
        JOIN customers c ON c.id=o.customer_id
        WHERE substr(r.date,1,10)>=? AND substr(r.date,1,10)<=?
        UNION ALL
        SELECT ca.cancelled_at,o.bill_number,o.number,c.name,0,0,0,
          ca.retained_charge-ca.original_total,'Order cancellation adjustment'
        FROM order_cancellations ca JOIN orders o ON o.id=ca.order_id
        JOIN customers c ON c.id=o.customer_id
        WHERE substr(ca.cancelled_at,1,10)>=? AND substr(ca.cancelled_at,1,10)<=?
        UNION ALL
        SELECT f.date,COALESCE(f.bill_number,f.number),f.number,COALESCE(c.name,'Walk-in'),0,0,0,f.total,'Direct fabric sale'
        FROM fabric_sales f LEFT JOIN customers c ON c.id=f.customer_id
        WHERE substr(f.date,1,10)>=? AND substr(f.date,1,10)<=? AND f.status='Posted'
        ORDER BY date''',
        [
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
        ],
      );
      final receipts = await txn.rawQuery(
        '''
        SELECT p.date,p.receipt AS receipt,c.name AS customer,p.method,p.amount,p.status,
          COALESCE((SELECT GROUP_CONCAT(o.bill_number, ', ') FROM payment_allocations a JOIN orders o ON o.id=a.order_id WHERE a.payment_id=p.id),'') AS bills
        FROM payments p JOIN customers c ON c.id=p.customer_id
        WHERE substr(p.date,1,10)>=? AND substr(p.date,1,10)<=?
        UNION ALL
        SELECT f.date,f.number AS receipt,COALESCE(c.name,'Walk-in'),'Cash',f.paid,
          f.status,'' AS bills
        FROM fabric_sales f LEFT JOIN customers c ON c.id=f.customer_id
        WHERE substr(f.date,1,10)>=? AND substr(f.date,1,10)<=?
          AND f.status='Posted' AND f.paid>0
        ORDER BY date,receipt''',
        [fromDate, throughDate, fromDate, throughDate],
      );
      final refunds = await txn.rawQuery(
        '''
        SELECT r.date,r.reference,c.name AS customer,r.method,r.amount,r.reason,'Refund' AS status
        FROM customer_refunds r JOIN customers c ON c.id=r.customer_id
        WHERE substr(r.date,1,10)>=? AND substr(r.date,1,10)<=? ORDER BY r.date,r.id''',
        [fromDate, throughDate],
      );
      final customerBalances = await txn.rawQuery(
        '''
        SELECT c.id,c.name,c.phone,COALESCE(SUM(l.charge-l.payment),0) AS balance
        FROM customers c LEFT JOIN ledger l ON l.customer_id=c.id AND substr(l.date,1,10)<=?
        WHERE c.archived=0 GROUP BY c.id ORDER BY c.name COLLATE NOCASE''',
        [throughDate],
      );
      final fabric = await txn.rawQuery(
        '''
        SELECT f.id,f.code,f.name,f.unit,f.average_cost,
          COALESCE(SUM(CASE WHEN substr(m.date,1,10)<? THEN COALESCE(m.quantity_milli,CAST(ROUND(m.quantity*1000) AS INTEGER)) ELSE 0 END),0)/1000.0 AS opening_meters,
          COALESCE(SUM(CASE WHEN substr(m.date,1,10)>=? AND substr(m.date,1,10)<=? THEN COALESCE(m.quantity_milli,CAST(ROUND(m.quantity*1000) AS INTEGER)) ELSE 0 END),0)/1000.0 AS movement_meters,
          COALESCE(SUM(CASE WHEN substr(m.date,1,10)<=? THEN COALESCE(m.quantity_milli,CAST(ROUND(m.quantity*1000) AS INTEGER)) ELSE 0 END),0)/1000.0 AS closing_meters
        FROM fabrics f LEFT JOIN stock_movements m ON m.fabric_id=f.id
        WHERE f.archived=0 GROUP BY f.id ORDER BY f.name COLLATE NOCASE''',
        [fromDate, fromDate, throughDate, throughDate],
      );
      final fabricPriceProfitRows = await txn.rawQuery(
        '''SELECT f.code,f.name AS fabric,COALESCE(f.category,'') AS category,
          f.purchase_cost AS buying_price_per_meter,
          f.selling_price AS selling_price_per_meter,
          COALESCE(f.selling_price,0)-COALESCE(f.purchase_cost,0) AS profit_per_meter
        FROM fabrics f
        WHERE f.archived=0 AND LOWER(COALESCE(f.unit,'meter'))='meter'
        ORDER BY f.name COLLATE NOCASE''',
      );
      final fabricMovements = await txn.rawQuery(
        '''
        SELECT m.date,f.code,f.name AS fabric,f.unit,m.kind,m.source_type,
          COALESCE(m.quantity_milli,CAST(ROUND(m.quantity*1000) AS INTEGER))/1000.0 AS quantity_meters,
          m.unit_cost,m.cost_total,m.reference,m.reason,
          p.number AS purchase_number,p.invoice_reference AS supplier_bill,
          s.name AS supplier
        FROM stock_movements m JOIN fabrics f ON f.id=m.fabric_id
        LEFT JOIN fabric_purchases p ON m.source_type='purchase' AND p.id=m.source_id
        LEFT JOIN suppliers s ON s.id=p.supplier_id
        WHERE substr(m.date,1,10)>=? AND substr(m.date,1,10)<=? ORDER BY m.date,m.id''',
        [fromDate, throughDate],
      );
      // Count shop fabric on confirmed active orders as sold once it is
      // reserved, even before the cloth is cut and stock is issued.
      final fabricProfitRows = await txn.rawQuery(
        '''SELECT f.id,f.code,f.name,f.category,
          COALESCE((SELECT SUM(l.quantity_milli) FROM fabric_sale_lines l
            JOIN fabric_sales s ON s.id=l.sale_id
            WHERE l.fabric_id=f.id AND s.status='Posted'
              AND substr(s.date,1,10)>=? AND substr(s.date,1,10)<=?),0) AS direct_qty,
          COALESCE((SELECT SUM(l.line_total) FROM fabric_sale_lines l
            JOIN fabric_sales s ON s.id=l.sale_id
            WHERE l.fabric_id=f.id AND s.status='Posted'
              AND substr(s.date,1,10)>=? AND substr(s.date,1,10)<=?),0) AS direct_revenue,
          COALESCE((SELECT SUM(ROUND(l.quantity_milli*COALESCE(l.unit_cost,0)/1000.0)) FROM fabric_sale_lines l
            JOIN fabric_sales s ON s.id=l.sale_id
            WHERE l.fabric_id=f.id AND s.status='Posted'
              AND substr(s.date,1,10)>=? AND substr(s.date,1,10)<=?),0) AS direct_cost,
          COALESCE((SELECT SUM(rl.quantity_milli) FROM fabric_return_lines rl
            JOIN fabric_returns r ON r.id=rl.return_id
            WHERE rl.fabric_id=f.id AND r.kind='sale'
              AND substr(r.date,1,10)>=? AND substr(r.date,1,10)<=?),0) AS returned_qty,
          COALESCE((SELECT SUM(ROUND(rl.quantity_milli*rl.unit_price/1000.0)) FROM fabric_return_lines rl
            JOIN fabric_returns r ON r.id=rl.return_id
            WHERE rl.fabric_id=f.id AND r.kind='sale'
              AND substr(r.date,1,10)>=? AND substr(r.date,1,10)<=?),0) AS returned_revenue,
          COALESCE((SELECT SUM(CASE WHEN rl.restock=1 THEN ROUND(rl.quantity_milli*rl.unit_cost/1000.0) ELSE 0 END)
            FROM fabric_return_lines rl JOIN fabric_returns r ON r.id=rl.return_id
            WHERE rl.fabric_id=f.id AND r.kind='sale'
              AND substr(r.date,1,10)>=? AND substr(r.date,1,10)<=?),0) AS returned_cost,
          COALESCE((SELECT SUM(foi.quantity_milli) FROM fabric_order_items foi
            JOIN orders o ON o.id=foi.order_id
            WHERE foi.fabric_id=f.id AND foi.ownership='shop' AND foi.unit_price>0
              AND foi.record_state='Active' AND (o.cancellation_status='Cancelled' OR foi.state IN ('reserved','issued','used'))
              AND substr(o.order_date,1,10)>=? AND substr(o.order_date,1,10)<=?),0) AS order_qty,
          COALESCE((SELECT SUM((foi.quantity_milli*foi.unit_price+500)/1000 -
            CASE WHEN (COALESCE((SELECT SUM(x.quantity_milli*x.unit_price) FROM fabric_order_items x
              WHERE x.order_id=o.id AND x.ownership='shop'),0)/1000.0)+o.stitching_total+o.extra>0
            THEN ROUND(o.discount * ((foi.quantity_milli*foi.unit_price+500)/1000.0) /
              ((COALESCE((SELECT SUM(x.quantity_milli*x.unit_price) FROM fabric_order_items x
                WHERE x.order_id=o.id AND x.ownership='shop'),0)/1000.0)+o.stitching_total+o.extra))
            ELSE 0 END) FROM fabric_order_items foi
            JOIN orders o ON o.id=foi.order_id
            WHERE foi.fabric_id=f.id AND foi.ownership='shop' AND foi.unit_price>0
              AND foi.record_state='Active' AND (o.cancellation_status='Cancelled' OR foi.state IN ('reserved','issued','used'))
              AND substr(o.order_date,1,10)>=? AND substr(o.order_date,1,10)<=?),0) AS order_revenue,
          COALESCE((SELECT SUM(ROUND(foi.quantity_milli*foi.unit_cost/1000.0))
            FROM fabric_order_items foi JOIN orders o ON o.id=foi.order_id
            WHERE foi.fabric_id=f.id AND foi.ownership='shop' AND foi.unit_price>0
              AND foi.record_state='Active' AND (o.cancellation_status='Cancelled' OR foi.state IN ('reserved','issued','used'))
              AND substr(o.order_date,1,10)>=? AND substr(o.order_date,1,10)<=?),0) AS order_cost,
          COALESCE((SELECT COUNT(*) FROM fabric_order_items foi JOIN orders o ON o.id=foi.order_id
            WHERE foi.fabric_id=f.id AND foi.ownership='shop' AND foi.unit_price<=0
              AND foi.record_state='Active' AND (o.cancellation_status='Cancelled' OR foi.state IN ('reserved','issued','used'))
              AND substr(o.order_date,1,10)>=? AND substr(o.order_date,1,10)<=?),0) AS unpriced_orders
          ,(COALESCE((SELECT COUNT(*) FROM fabric_sale_lines l JOIN fabric_sales s ON s.id=l.sale_id
            WHERE l.fabric_id=f.id AND s.status='Posted'
              AND (COALESCE(l.unit_cost,0)<=0 OR COALESCE(s.cost_total,0)<=0)
              AND substr(s.date,1,10)>=? AND substr(s.date,1,10)<=?),0)
          +COALESCE((SELECT COUNT(*) FROM fabric_order_items foi JOIN orders o ON o.id=foi.order_id
            WHERE foi.fabric_id=f.id AND foi.ownership='shop' AND foi.unit_price>0
              AND COALESCE(foi.unit_cost,0)<=0
              AND foi.record_state='Active' AND (o.cancellation_status='Cancelled' OR foi.state IN ('reserved','issued','used')) AND substr(o.order_date,1,10)>=? AND substr(o.order_date,1,10)<=?),0)) AS missing_cost_lines
        FROM fabrics f ORDER BY f.name COLLATE NOCASE''',
        [
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
          fromDate,
          throughDate,
        ],
      );
      final fabricCancellationAdjustments = await txn.rawQuery(
        '''SELECT ca.id AS transaction_id,ca.cancelled_at AS date,
          COALESCE(NULLIF(o.bill_number,''),o.number) AS bill_number,
          c.name AS customer,f.id AS fabric_id,f.code,f.name AS fabric,
          COALESCE(f.category,'') AS category,
          a.original_quantity_milli,a.retained_quantity_milli,
          a.original_revenue,a.retained_revenue,a.original_cost,a.retained_cost,
          CASE WHEN foi.unit_cost<=0 AND a.original_quantity_milli>0 THEN 1 ELSE 0 END AS missing_cost
        FROM order_cancellation_fabric_allocations a
        JOIN order_cancellations ca ON ca.id=a.cancellation_id
        JOIN fabric_order_items foi ON foi.id=a.fabric_order_item_id
        JOIN orders o ON o.id=ca.order_id
        JOIN customers c ON c.id=o.customer_id
        JOIN fabrics f ON f.id=foi.fabric_id
        WHERE substr(ca.cancelled_at,1,10)>=? AND substr(ca.cancelled_at,1,10)<=?
        ORDER BY ca.cancelled_at,ca.id,a.id''',
        [fromDate, throughDate],
      );
      final fabricProfitByItem = <Map<String, Object?>>[];
      for (final row in fabricProfitRows) {
        final directQty = (row['direct_qty'] as num).toDouble();
        final returnQty = (row['returned_qty'] as num).toDouble();
        final orderQty = (row['order_qty'] as num).toDouble();
        final netMeters = (directQty - returnQty + orderQty) / 1000.0;
        final revenue =
            (row['direct_revenue'] as num).toDouble() -
            (row['returned_revenue'] as num).toDouble() +
            (row['order_revenue'] as num).toDouble();
        final cost =
            (row['direct_cost'] as num).toDouble() -
            (row['returned_cost'] as num).toDouble() +
            (row['order_cost'] as num).toDouble();
        final missingCosts = (row['missing_cost_lines'] as num).toInt();
        fabricProfitByItem.add({
          'id': row['id'],
          'fabric': row['name'],
          'code': row['code'],
          'category': row['category'] ?? '',
          'net_meters': netMeters,
          'net_revenue': revenue.round(),
          'recorded_cost': cost.round(),
          'gross_profit': missingCosts > 0 ? null : (revenue - cost).round(),
          'profit_per_meter': missingCosts > 0 || netMeters == 0
              ? null
              : ((revenue - cost) / netMeters).round(),
          'average_revenue_per_meter': netMeters == 0
              ? 0
              : (revenue / netMeters).round(),
          'average_cost_per_meter': netMeters == 0
              ? 0
              : (cost / netMeters).round(),
          'returned_meters': returnQty / 1000.0,
          'unpriced_stitching_lines': row['unpriced_orders'],
          'missing_cost_lines': missingCosts,
          'cost_available': missingCosts == 0,
        });
      }
      final fabricProfitById = {
        for (final row in fabricProfitByItem) (row['id'] as num).toInt(): row,
      };
      for (final adjustment in fabricCancellationAdjustments) {
        final key = (adjustment['fabric_id'] as num).toInt();
        final row = fabricProfitById[key];
        if (row == null) continue;
        final quantityDelta =
            ((adjustment['retained_quantity_milli'] as num).toInt() -
                (adjustment['original_quantity_milli'] as num).toInt()) /
            1000.0;
        final revenueDelta =
            (adjustment['retained_revenue'] as num).toInt() -
            (adjustment['original_revenue'] as num).toInt();
        final costDelta =
            (adjustment['retained_cost'] as num).toInt() -
            (adjustment['original_cost'] as num).toInt();
        final meters = (row['net_meters'] as num).toDouble() + quantityDelta;
        final revenue = (row['net_revenue'] as num).toInt() + revenueDelta;
        final cost = (row['recorded_cost'] as num).toInt() + costDelta;
        final missing = (adjustment['missing_cost'] as num).toInt();
        final missingTotal =
            (row['missing_cost_lines'] as num).toInt() + missing;
        row['net_meters'] = meters;
        row['net_revenue'] = revenue;
        row['recorded_cost'] = cost;
        row['gross_profit'] = missingTotal > 0 ? null : revenue - cost;
        row['profit_per_meter'] = missingTotal > 0 || meters == 0
            ? null
            : ((revenue - cost) / meters).round();
        row['average_revenue_per_meter'] = meters == 0
            ? 0
            : (revenue / meters).round();
        row['average_cost_per_meter'] = meters == 0
            ? 0
            : (cost / meters).round();
        row['missing_cost_lines'] = missingTotal;
        row['cost_available'] = missingTotal == 0;
      }
      final fabricCategoryTotals = <String, Map<String, Object?>>{};
      for (final row in fabricProfitByItem) {
        final key = '${row['category']}'.isEmpty
            ? 'Uncategorized'
            : '${row['category']}';
        final totals = fabricCategoryTotals.putIfAbsent(
          key,
          () => {
            'net_meters': 0,
            'net_revenue': 0,
            'recorded_cost': 0,
            'gross_profit': 0,
            'returned_meters': 0,
            'missing_cost_lines': 0,
          },
        );
        for (final field in totals.keys) {
          // This is a derived category average, not a value to sum from each
          // fabric row. Calculate it from the category totals below.
          if (field == 'profit_per_meter') continue;
          if (field == 'gross_profit' && row[field] == null) {
            totals[field] = null;
          } else if (totals[field] != null) {
            totals[field] = (totals[field] as num) + (row[field] as num);
          }
        }
        final meters = totals['net_meters'] as num;
        final grossProfit = totals['gross_profit'];
        totals['profit_per_meter'] = grossProfit is num && meters > 0
            ? (grossProfit / meters).round()
            : null;
      }
      final fabricProfitSubtotals = fabricCategoryTotals.entries
          .map(
            (entry) => <String, Object?>{'category': entry.key, ...entry.value},
          )
          .toList();
      final fabricProfitTotals = <String, Object?>{
        'net_meters': 0,
        'net_revenue': 0,
        'recorded_cost': 0,
        'gross_profit': 0,
        'returned_meters': 0,
        'missing_cost_lines': 0,
      };
      for (final row in fabricProfitByItem) {
        for (final field in fabricProfitTotals.keys) {
          if (field == 'gross_profit' && row['gross_profit'] == null) continue;
          if (fabricProfitTotals[field] != null) {
            fabricProfitTotals[field] =
                (fabricProfitTotals[field] as num) + (row[field] as num);
          }
        }
      }
      final missingCostLines = fabricProfitByItem.fold<int>(
        0,
        (total, row) => total + (row['missing_cost_lines'] as int),
      );
      final anyMissingCosts = missingCostLines > 0;
      if (anyMissingCosts) {
        fabricProfitTotals['gross_profit'] = null;
        for (final subtotal in fabricProfitSubtotals) {
          final category = '${subtotal['category']}';
          if (fabricProfitByItem.any(
            (row) =>
                ('${row['category']}'.isEmpty
                        ? 'Uncategorized'
                        : '${row['category']}') ==
                    category &&
                row['gross_profit'] == null,
          )) {
            subtotal['gross_profit'] = null;
          }
        }
      }
      final totalMeters = fabricProfitTotals['net_meters'] as num;
      final totalGrossProfit = fabricProfitTotals['gross_profit'];
      fabricProfitTotals['profit_per_meter'] =
          totalGrossProfit is num && totalMeters > 0
          ? (totalGrossProfit / totalMeters).round()
          : null;
      final unpricedStitchingLines = fabricProfitRows.fold<int>(
        0,
        (total, row) =>
            total + ((row['unpriced_orders'] as num?)?.toInt() ?? 0),
      );
      final stitchingLines = await txn.rawQuery(
        '''SELECT o.id AS order_id,o.order_date AS date,
          COALESCE(NULLIF(o.bill_number,''),o.number) AS bill_number,
          c.name AS customer,o.status,o.stitching_total,o.extra,o.discount,
          o.total,ol.id AS line_id,ol.garment,ol.quantity,ol.price_each,
          o.cancellation_status,COALESCE(ca.work_started,0) AS work_started,
          COALESCE(e.labor_cost,0) AS labor_cost,
          COALESCE(e.earning_count,0) AS earning_count
        FROM orders o JOIN customers c ON c.id=o.customer_id
        JOIN order_lines ol ON ol.order_id=o.id
        LEFT JOIN order_cancellations ca ON ca.order_id=o.id
        LEFT JOIN (
          SELECT a.order_line_id,
            SUM(CASE WHEN e.reversal_of IS NULL THEN e.amount ELSE -e.amount END) AS labor_cost,
            COUNT(e.id) AS earning_count
          FROM worker_assignments a JOIN worker_earnings e ON e.assignment_id=a.id
          GROUP BY a.order_line_id
        ) e ON e.order_line_id=ol.id
        WHERE substr(o.order_date,1,10)>=? AND substr(o.order_date,1,10)<=?
          AND ol.record_state='Active'
        ORDER BY o.order_date,o.id,ol.id''',
        [fromDate, throughDate],
      );
      final orderCancellations = await txn.rawQuery(
        '''SELECT ca.cancelled_at AS date,
          COALESCE(NULLIF(o.bill_number,''),o.number) AS bill_number,
          c.name AS customer,ca.original_stitching,ca.retained_stitching,ca.reason
        FROM order_cancellations ca JOIN orders o ON o.id=ca.order_id
        JOIN customers c ON c.id=o.customer_id
        WHERE substr(ca.cancelled_at,1,10)>=? AND substr(ca.cancelled_at,1,10)<=?
        ORDER BY ca.cancelled_at,ca.id''',
        [fromDate, throughDate],
      );
      final directFabricSaleLines = await txn.rawQuery(
        '''SELECT s.id AS transaction_id,s.date,
          COALESCE(NULLIF(s.bill_number,''),s.number) AS bill_number,
          COALESCE(c.name,'Walk-in') AS customer,f.id AS fabric_id,
          f.code,f.name AS fabric,COALESCE(f.category,'') AS category,
          SUM(COALESCE(l.quantity_milli,CAST(ROUND(l.quantity*1000) AS INTEGER))) AS quantity_milli,
          SUM(l.line_total) AS net_revenue,
          SUM(ROUND(COALESCE(l.quantity_milli,CAST(ROUND(l.quantity*1000) AS INTEGER))*COALESCE(l.unit_cost,0)/1000.0)) AS line_recorded_cost,
          SUM(COALESCE(l.quantity_milli,CAST(ROUND(l.quantity*1000) AS INTEGER))*l.unit_price) AS selling_weight,
          SUM(COALESCE(l.quantity_milli,CAST(ROUND(l.quantity*1000) AS INTEGER))*COALESCE(l.unit_cost,0)) AS cost_weight,
          SUM(CASE WHEN COALESCE(l.unit_cost,0)<=0 THEN 1 ELSE 0 END) AS missing_line_cost_count,
          COUNT(*) AS line_count,COALESCE(m.recorded_cost,NULL) AS movement_cost,
          COALESCE(m.movement_count,0) AS movement_count,
          COALESCE(m.missing_cost_count,0) AS missing_movement_cost_count
        FROM fabric_sales s JOIN fabric_sale_lines l ON l.sale_id=s.id
        JOIN fabrics f ON f.id=l.fabric_id
        LEFT JOIN customers c ON c.id=s.customer_id
        LEFT JOIN (
          SELECT source_id,fabric_id,-SUM(cost_total) AS recorded_cost,
            COUNT(*) AS movement_count,
            SUM(CASE WHEN cost_total IS NULL OR cost_total=0 THEN 1 ELSE 0 END) AS missing_cost_count
          FROM stock_movements
          WHERE source_type='sale' AND kind='Sale'
          GROUP BY source_id,fabric_id
        ) m ON m.source_id=s.id AND m.fabric_id=f.id
        WHERE s.status='Posted' AND substr(s.date,1,10)>=? AND substr(s.date,1,10)<=?
        GROUP BY s.id,f.id ORDER BY s.date,s.id,f.name COLLATE NOCASE''',
        [fromDate, throughDate],
      );
      final directFabricReturns = await txn.rawQuery(
        '''SELECT r.id AS transaction_id,r.date,r.number AS return_number,
          COALESCE(NULLIF(s.bill_number,''),s.number,r.number) AS bill_number,
          COALESCE(c.name,'Walk-in') AS customer,f.id AS fabric_id,
          f.code,f.name AS fabric,COALESCE(f.category,'') AS category,
          SUM(rl.quantity_milli) AS quantity_milli,
          SUM(ROUND(rl.quantity_milli*rl.unit_price/1000.0)) AS revenue,
          SUM(CASE WHEN rl.restock=1 THEN ROUND(rl.quantity_milli*rl.unit_cost/1000.0) ELSE 0 END) AS recorded_cost,
          SUM(rl.quantity_milli*rl.unit_price) AS selling_weight,
          SUM(CASE WHEN rl.restock=1 THEN rl.quantity_milli*rl.unit_cost ELSE 0 END) AS cost_weight,
          SUM(CASE WHEN rl.restock=1 AND COALESCE(rl.unit_cost,0)<=0 THEN 1 ELSE 0 END) AS missing_cost_count,
          SUM(CASE WHEN rl.restock=1 THEN rl.quantity_milli ELSE 0 END) AS restocked_quantity_milli
        FROM fabric_returns r JOIN fabric_return_lines rl ON rl.return_id=r.id
        JOIN fabrics f ON f.id=rl.fabric_id
        LEFT JOIN fabric_sales s ON s.id=r.source_id
        LEFT JOIN customers c ON c.id=r.customer_id
        WHERE r.kind='sale' AND substr(r.date,1,10)>=? AND substr(r.date,1,10)<=?
        GROUP BY r.id,f.id ORDER BY r.date,r.id,f.name COLLATE NOCASE''',
        [fromDate, throughDate],
      );
      final stitchingFabricRows = await txn.rawQuery(
        '''SELECT o.id AS order_id,o.order_date AS date,
          COALESCE(NULLIF(o.bill_number,''),o.number) AS bill_number,
          c.name AS customer,o.stitching_total,o.extra,o.discount,
          foi.fabric_id,f.code,f.name AS fabric,COALESCE(f.category,'') AS category,
          SUM(foi.quantity_milli) AS quantity_milli,
          SUM(CASE WHEN foi.unit_price>0 THEN (foi.quantity_milli*foi.unit_price+500)/1000 ELSE 0 END) AS gross_revenue,
          SUM(foi.net_amount) AS saved_net_revenue,
          SUM(CASE WHEN foi.net_amount IS NULL THEN 1 ELSE 0 END) AS missing_saved_net_count,
          SUM(foi.quantity_milli*foi.unit_price) AS selling_weight,
          SUM(ROUND(foi.quantity_milli*foi.unit_cost/1000.0)) AS line_recorded_cost,
          SUM(foi.quantity_milli*foi.unit_cost) AS cost_weight,
          SUM(CASE WHEN foi.unit_price>0 AND foi.unit_cost<=0 THEN 1 ELSE 0 END) AS missing_line_cost_count,
          SUM(CASE WHEN foi.unit_price>0 THEN foi.quantity_milli ELSE 0 END) AS priced_quantity_milli,
          SUM(CASE WHEN foi.unit_price<=0 THEN foi.quantity_milli ELSE 0 END) AS unpriced_quantity_milli
        FROM fabric_order_items foi
        JOIN orders o ON o.id=foi.order_id
        JOIN customers c ON c.id=o.customer_id
        LEFT JOIN fabrics f ON f.id=foi.fabric_id
        WHERE foi.ownership='shop' AND
          (o.cancellation_status='Cancelled' OR foi.state IN ('reserved','issued','used'))
          AND substr(o.order_date,1,10)>=? AND substr(o.order_date,1,10)<=?
          AND foi.record_state='Active'
        GROUP BY o.id,foi.fabric_id
        ORDER BY o.order_date,o.id,f.name COLLATE NOCASE''',
        [fromDate, throughDate],
      );
      final stitchingReturns = await txn.rawQuery(
        '''SELECT rl.id AS return_line_id,r.id AS transaction_id,r.date,
          r.number AS return_number,COALESCE(NULLIF(o.bill_number,''),o.number) AS bill_number,
          c.name AS customer,ol.garment,rl.quantity,rl.revenue
        FROM order_return_lines rl
        JOIN order_returns r ON r.id=rl.return_id
        JOIN orders o ON o.id=r.order_id
        JOIN customers c ON c.id=o.customer_id
        JOIN order_lines ol ON ol.id=rl.order_line_id
        WHERE rl.kind='garment' AND o.cancellation_status!='Cancelled'
          AND substr(r.date,1,10)>=? AND substr(r.date,1,10)<=?
        ORDER BY r.date,r.id,rl.id''',
        [fromDate, throughDate],
      );
      final stitchingFabricReturns = await txn.rawQuery(
        '''SELECT rl.id AS transaction_id,r.date,r.number AS return_number,
          COALESCE(NULLIF(o.bill_number,''),o.number) AS bill_number,
          c.name AS customer,f.id AS fabric_id,f.code,f.name AS fabric,
          COALESCE(f.category,'') AS category,rl.quantity_milli,rl.revenue,
          rl.unit_cost,rl.restock,
          CASE WHEN rl.restock=1
            THEN ROUND(rl.quantity_milli*rl.unit_cost/1000.0) ELSE 0 END AS recorded_cost,
          CASE WHEN rl.restock=1 AND COALESCE(rl.unit_cost,0)<=0 THEN 1 ELSE 0 END AS missing_cost_count
        FROM order_return_lines rl
        JOIN order_returns r ON r.id=rl.return_id
        JOIN orders o ON o.id=r.order_id
        JOIN customers c ON c.id=o.customer_id
        JOIN fabric_order_items foi ON foi.id=rl.fabric_order_item_id
        JOIN fabrics f ON f.id=foi.fabric_id
        WHERE rl.kind='fabric' AND o.cancellation_status!='Cancelled'
          AND substr(r.date,1,10)>=? AND substr(r.date,1,10)<=?
        ORDER BY r.date,r.id,rl.id''',
        [fromDate, throughDate],
      );
      final orderCancellationFabricRows = await txn.rawQuery(
        '''SELECT ca.id AS transaction_id,ca.cancelled_at AS date,
          COALESCE(NULLIF(o.bill_number,''),o.number) AS bill_number,
          c.name AS customer,f.id AS fabric_id,f.code,f.name AS fabric,
          COALESCE(f.category,'') AS category,
          a.original_quantity_milli,a.retained_quantity_milli,
          a.original_revenue,a.retained_revenue,a.original_cost,a.retained_cost,
          CASE WHEN foi.unit_cost<=0 AND a.original_quantity_milli>0 THEN 1 ELSE 0 END AS missing_cost
        FROM order_cancellation_fabric_allocations a
        JOIN order_cancellations ca ON ca.id=a.cancellation_id
        JOIN fabric_order_items foi ON foi.id=a.fabric_order_item_id
        JOIN orders o ON o.id=ca.order_id
        JOIN customers c ON c.id=o.customer_id
        JOIN fabrics f ON f.id=foi.fabric_id
        WHERE substr(ca.cancelled_at,1,10)>=? AND substr(ca.cancelled_at,1,10)<=?
        ORDER BY ca.cancelled_at,ca.id,a.id''',
        [fromDate, throughDate],
      );
      final stitchingReport = buildStitchingProfitReport(
        stitchingLines: stitchingLines,
        shopFabricLines: stitchingFabricRows,
        returns: stitchingReturns,
        cancellations: orderCancellations,
      );
      final fabricReport = buildFabricProfitReport(
        directSales: directFabricSaleLines,
        directReturns: directFabricReturns,
        stitchingLines: stitchingLines,
        shopFabricLines: stitchingFabricRows,
        stitchingReturns: stitchingFabricReturns,
        orderCancellations: orderCancellationFabricRows,
      );
      final purchases = await txn.rawQuery(
        '''
        SELECT p.date,p.number,p.invoice_reference,s.name AS supplier,p.total,p.paid,p.status
        FROM fabric_purchases p JOIN suppliers s ON s.id=p.supplier_id
        WHERE substr(p.date,1,10)>=? AND substr(p.date,1,10)<=? ORDER BY p.date,p.id''',
        [fromDate, throughDate],
      );
      final supplierBalances = await txn.rawQuery(
        '''
        SELECT s.id,s.name,s.phone,COALESCE(SUM(l.charge-l.payment),CASE WHEN substr(s.created_at,1,10)<=? THEN s.opening_balance ELSE 0 END) AS balance
        FROM suppliers s LEFT JOIN supplier_ledger l ON l.supplier_id=s.id AND substr(l.date,1,10)<=?
        WHERE s.archived=0 GROUP BY s.id ORDER BY s.name COLLATE NOCASE''',
        [throughDate, throughDate],
      );
      final supplierPayments = await txn.rawQuery(
        '''
        SELECT p.date,p.receipt AS reference,s.name AS supplier,p.method,p.amount,p.status
        FROM supplier_payments p JOIN suppliers s ON s.id=p.supplier_id
        WHERE substr(p.date,1,10)>=? AND substr(p.date,1,10)<=?
        ORDER BY p.date,p.id''',
        [fromDate, throughDate],
      );
      final supplierReturns = await txn.rawQuery(
        '''
        SELECT r.date,r.number,s.name AS supplier,r.amount,r.refund_amount,r.reason,r.kind
        FROM fabric_returns r JOIN suppliers s ON s.id=r.supplier_id
        WHERE r.kind='supplier' AND substr(r.date,1,10)>=? AND substr(r.date,1,10)<=?
        ORDER BY r.date,r.id''',
        [fromDate, throughDate],
      );
      final earnings = await txn.rawQuery(
        '''
        SELECT e.date,e.reference,w.name AS worker,a.task,a.accepted_quantity,e.rate,e.amount
        FROM worker_earnings e JOIN workers w ON w.id=e.worker_id JOIN worker_assignments a ON a.id=e.assignment_id
        WHERE substr(e.date,1,10)>=? AND substr(e.date,1,10)<=? ORDER BY e.date,e.id''',
        [fromDate, throughDate],
      );
      final salaries = await txn.rawQuery(
        '''
        SELECT substr(COALESCE(e.posted_at,e.created_at),1,10) AS date,
          w.name AS worker,e.amount,e.status,'Monthly salary' AS source
        FROM worker_salary_entries e JOIN workers w ON w.id=e.worker_id
        WHERE e.status='Posted'
          AND substr(COALESCE(e.posted_at,e.created_at),1,10)>=?
          AND substr(COALESCE(e.posted_at,e.created_at),1,10)<=?
        ORDER BY e.posted_at,e.created_at,w.name''',
        [fromDate, throughDate],
      );
      final workerPayments = await txn.rawQuery(
        '''
        SELECT p.date,p.voucher AS reference,w.name AS worker,p.kind,p.amount,p.method,p.status
        FROM worker_payments p JOIN workers w ON w.id=p.worker_id
        WHERE substr(p.date,1,10)>=? AND substr(p.date,1,10)<=? ORDER BY p.date,p.id''',
        [fromDate, throughDate],
      );
      final workerBalances = await txn.rawQuery(
        '''
        SELECT w.id,w.name,w.phone,
          COALESCE((SELECT SUM(e.amount) FROM worker_earnings e WHERE e.worker_id=w.id AND substr(e.date,1,10)<=?),0)
          + COALESCE((SELECT SUM(e.amount) FROM worker_salary_entries e WHERE e.worker_id=w.id AND e.status='Posted' AND e.period<=? AND substr(COALESCE(e.posted_at,e.created_at),1,10)<=?),0)
          - COALESCE((SELECT SUM(p.amount) FROM worker_payments p WHERE p.worker_id=w.id AND p.status='Posted' AND p.kind='Pay Earnings' AND substr(p.date,1,10)<=?),0)
          - COALESCE((SELECT SUM(p.amount) FROM worker_salary_payments p JOIN worker_salary_entries e ON e.id=p.entry_id WHERE e.worker_id=w.id AND substr(p.date,1,10)<=?),0) AS payable
        FROM workers w WHERE w.active=1 ORDER BY w.name COLLATE NOCASE''',
        [
          throughDate,
          throughDate.substring(0, 7),
          throughDate,
          throughDate,
          throughDate,
        ],
      );
      final expenses = await txn.rawQuery(
        '''
        SELECT date,expense_no AS reference,category,description,payee,method,
          amount,status,reversal_reason,
          CASE WHEN status IN ('Posted','Reversed') THEN amount
            WHEN status='Reversal' THEN -amount ELSE 0 END AS report_amount
        FROM expenses WHERE substr(date,1,10)>=? AND substr(date,1,10)<=? AND status IN ('Posted','Reversed','Reversal') ORDER BY date,id''',
        [fromDate, throughDate],
      );
      final recognizedExpenses = <Map<String, Object?>>[
        ...expenses,
        for (final salary in salaries)
          {
            'date': salary['date'],
            'reference': '',
            'category': 'Worker salaries',
            'description': 'Monthly salary',
            'payee': salary['worker'],
            'method': '',
            'amount': salary['amount'],
            'status': 'Posted',
            'reversal_reason': null,
            'report_amount': salary['amount'],
            'source': 'worker_salary',
          },
      ];

      int sum(
        List<Map<String, Object?>> rows,
        String field, {
        String? status,
      }) => rows
          .where((r) => status == null || r['status'] == status)
          .fold<int>(
            0,
            (total, row) => total + ((row[field] as num?)?.toInt() ?? 0),
          );
      final invoiced = sales
          .where((r) => r['source'] == 'Stitching order')
          .fold<int>(0, (v, r) => v + ((r['total'] as num?)?.toInt() ?? 0));
      final directFabricSales = sales
          .where((r) => r['source'] == 'Direct fabric sale')
          .fold<int>(0, (v, r) => v + ((r['total'] as num?)?.toInt() ?? 0));
      final received = sum(receipts, 'amount', status: 'Posted');
      final refundsTotal = sum(refunds, 'amount');
      final canonicalFabricProfit =
          (fabricReport['totals'] as Map)['gross_profit'];
      final int? fabricProfit = canonicalFabricProfit is num
          ? canonicalFabricProfit.toInt()
          : null;
      final stitchingTotals = stitchingReport['totals'] as Map;
      final stitchingProfitValue = stitchingTotals['gross_profit'];
      final int? stitchingProfit = stitchingProfitValue is num
          ? stitchingProfitValue.toInt()
          : null;
      final netStitchingRevenueValue = stitchingTotals['net_stitching_revenue'];
      final int? netStitchingRevenue = netStitchingRevenueValue is num
          ? netStitchingRevenueValue.toInt()
          : null;
      final workerSalaryTotal = sum(salaries, 'amount');
      final expenseTotal = recognizedExpenses.fold<int>(
        0,
        (total, row) => total + ((row['report_amount'] as num?)?.toInt() ?? 0),
      );
      final int? grossProfit =
          fabricProfit == null || netStitchingRevenue == null
          ? null
          : fabricProfit + netStitchingRevenue;
      final int? netProfit = grossProfit == null
          ? null
          : grossProfit - expenseTotal;
      final supplierPayable = supplierBalances.fold<int>(
        0,
        (v, r) =>
            v + (((r['balance'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60)),
      );
      final workerPayable = workerBalances.fold<int>(
        0,
        (v, r) =>
            v + (((r['payable'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60)),
      );
      final debt = customerBalances.fold<int>(
        0,
        (v, r) =>
            v + (((r['balance'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60)),
      );
      final credit = customerBalances.fold<int>(
        0,
        (v, r) =>
            v + (-((r['balance'] as num?)?.toInt() ?? 0)).clamp(0, 1 << 60),
      );
      final categories = <String, int>{};
      for (final row in recognizedExpenses.where(
        (r) => (r['report_amount'] as num?)?.toInt() != 0,
      )) {
        final key = '${row['category']}';
        categories[key] =
            (categories[key] ?? 0) +
            ((row['report_amount'] as num?)?.toInt() ?? 0);
      }
      final categoryRows = categories.entries
          .map((entry) => {'category': entry.key, 'amount': entry.value})
          .toList();
      final sectionData = <String, Object?>{
        'orders': {
          'created': orders,
          'delivery_events': deliveries,
          'total': orders
              .where((r) => r['status'] != 'Cancelled')
              .fold<int>(0, (v, r) => v + ((r['total'] as num?)?.toInt() ?? 0)),
        },
        'sales': {
          'records': sales,
          'total': invoiced + directFabricSales,
          'invoiced': invoiced,
          'direct_fabric': directFabricSales,
        },
        'collections': {
          'receipts': receipts,
          'refunds': refunds,
          'received': received,
          'refund_total': refundsTotal,
          'net': received - refundsTotal,
        },
        'customer_balances': {
          'rows': customerBalances,
          'debt': debt,
          'credit': credit,
        },
        'fabric': {'rows': fabric, 'movements': fabricMovements},
        'fabric_price_profit': {'rows': fabricPriceProfitRows},
        'fabric_profit': {
          'rows': fabricProfitByItem,
          'category_subtotals': fabricProfitSubtotals,
          'totals': [
            {
              'category': 'Grand total',
              ...fabricProfitTotals,
              'missing_cost_lines': missingCostLines,
            },
          ],
          'unpriced_stitching_lines': unpricedStitchingLines,
          'missing_cost_lines': missingCostLines,
        },
        'stitching_report': stitchingReport,
        'fabric_report': fabricReport,
        'purchases': {
          'purchases': purchases,
          'supplier_payments': supplierPayments,
          'returns_and_credits': supplierReturns,
          'suppliers': supplierBalances,
          'payable': supplierPayable,
        },
        'workers': {
          'earnings': earnings,
          'salaries': salaries,
          'payments': workerPayments,
          'balances': workerBalances,
          'earnings_total': sum(earnings, 'amount') + workerSalaryTotal,
          'paid_total': sum(workerPayments, 'amount', status: 'Posted'),
        },
        'expenses': {
          'rows': recognizedExpenses,
          'categories': categories,
          'category_subtotals': categoryRows,
          'total': expenseTotal,
        },
        'profit': {
          'available': grossProfit != null,
          'fabric_profit': fabricProfit,
          'stitching_profit': stitchingProfit,
          'net_stitching_revenue': netStitchingRevenue,
          'gross_profit': grossProfit,
          'expenses': expenseTotal,
          'net_profit': netProfit,
        },
      };
      final settings = await txn.query('settings');
      final settingMap = {
        for (final row in settings) '${row['key']}': row['value'],
      };
      return <String, Object?>{
        'from': fromDate,
        'through': throughDate,
        'generated_at': DateTime.now().toIso8601String(),
        'shop_name': settingMap['shop_name'] ?? '',
        'shop_address': settingMap['address'] ?? '',
        'shop_phone': settingMap['phone'] ?? '',
        'shop_logo_path': settingMap['shop_logo_path'] ?? '',
        'overview': {
          'orders': orders.length,
          'sales': invoiced + directFabricSales,
          'receipts': received,
          'refunds': refundsTotal,
          'net_collections': received - refundsTotal,
          'expenses': expenseTotal,
          'customer_debt': debt,
          'customer_credit': credit,
          'worker_payable': workerPayable,
          'supplier_payable': supplierPayable,
          'gross_profit': grossProfit,
          'monthly_profit': netProfit,
        },
        'sections': sectionData,
        'notes': [
          'Date filters include both selected calendar dates and use canonical ISO dates.',
          'Order status is current except delivery and cancellation events, which come from status history.',
          'Customer and supplier balances are derived from dated ledger entries through the selected end date.',
          'Worker payable combines dated earnings, posted monthly salary, and posted payments. Advances may not reconcile to this simplified report balance.',
          'Fabric reserved quantity is current; reservation history is not stored by effective date.',
          'Net profit is total fabric profit plus net stitching revenue, minus posted operating expenses. Stitching profit remains a separate estimate after linked worker earnings. Missing fabric costs leave net profit unavailable.',
          'Stitching profit subtracts recorded worker earnings linked to order lines from net stitching charges. It is an estimate when additional direct sewing costs are not allocated; missing labor costs are marked unavailable.',
          'Fabric profit includes posted direct sales and shop fabric billed on stitching orders. Customer-owned fabric and stitching charges are excluded. Sale returns reverse revenue, and only restocked returns reverse inventory cost. Unpriced fabric and missing inventory costs are identified.',
          'Posted worker salaries are recognized as operating expenses on their posting date. Reversals reduce expenses on their own posting date, and settlements of previously recorded earnings are excluded.',
        ],
      };
    });
  }
}
