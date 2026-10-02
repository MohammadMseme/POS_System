import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/debt.dart';
import '../models/supplier.dart';
import '../models/worker.dart';
import '../models/expense.dart';

class InventoryProvider extends ChangeNotifier {
  Box<Sale> get _salesBox => Hive.box<Sale>('sales');
  Box<Product> get _productsBox => Hive.box<Product>('products');
  Box<Debt> get _debtBox => Hive.box<Debt>('debts');
  Box<Supplier> get _supplierBox => Hive.box<Supplier>('suppliers');
  // NEW (Salaries & Expenses <-> Inventory/Jard integration): needed so
  // a worker payment/advance or a general expense is reflected against
  // total sales and net profit - see totalWorkerPayments, totalExpenses,
  // allWorkerPaymentRows and allExpenseRows below.
  Box<Worker> get _workerBox => Hive.box<Worker>('workers');
  Box<Expense> get _expenseBox => Hive.box<Expense>('expenses');

  // Every box this provider reads from is listened to directly, so any
  // write to any of them - regardless of which provider/screen performed
  // it - propagates here automatically as notifyListeners().
  late final ValueListenable<Box<Sale>> _salesListenable;
  late final ValueListenable<Box<Product>> _productsListenable;
  late final ValueListenable<Box<Debt>> _debtListenable;
  late final ValueListenable<Box<Supplier>> _supplierListenable;
  late final ValueListenable<Box<Worker>> _workerListenable;
  late final ValueListenable<Box<Expense>> _expenseListenable;

  InventoryProvider() {
    _salesListenable = _salesBox.listenable();
    _productsListenable = _productsBox.listenable();
    _debtListenable = _debtBox.listenable();
    _supplierListenable = _supplierBox.listenable();
    _workerListenable = _workerBox.listenable();
    _expenseListenable = _expenseBox.listenable();

    _salesListenable.addListener(_handleDataChanged);
    _productsListenable.addListener(_handleDataChanged);
    _debtListenable.addListener(_handleDataChanged);
    _supplierListenable.addListener(_handleDataChanged);
    _workerListenable.addListener(_handleDataChanged);
    _expenseListenable.addListener(_handleDataChanged);
  }

  void _handleDataChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _salesListenable.removeListener(_handleDataChanged);
    _productsListenable.removeListener(_handleDataChanged);
    _debtListenable.removeListener(_handleDataChanged);
    _supplierListenable.removeListener(_handleDataChanged);
    _workerListenable.removeListener(_handleDataChanged);
    _expenseListenable.removeListener(_handleDataChanged);
    super.dispose();
  }

  List<Sale> get allSales => _salesBox.values.toList();

  // المنتجات التي قارب مخزونها على النفاذ (أقل من 5 قطع)
  List<Product> get lowStockProducts {
    return _productsBox.values.where((p) => p.stockQuantity <= 5).toList();
  }

  /// النَقود الراكدة: منتجات موجودة منذ [periodDays] يوماً على الأقل ولم
  /// تظهر في أي عملية بيع خلال تلك الفترة. منتج أُضيف حديثاً (أحدث من
  /// [periodDays]) يُستثنى بدلاً من اعتباره راكداً - فهو لم يحصل بعد على
  /// فرصة عادلة للبيع، فوصفه بالركود مبكراً سيكون مضللاً لا مفيداً.
  List<Product> getStagnantProducts(int periodDays) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: periodDays));

    final soldNamesInPeriod = <String>{};
    for (final sale in _salesBox.values) {
      if (sale.createdAt.isAfter(cutoff)) {
        for (final item in sale.items) {
          soldNamesInPeriod.add(item.name);
        }
      }
    }
    // Items sold on credit leave the shelf immediately even though they
    // only enter the sales records once the debt is fully paid - so they
    // must not be reported as stagnant meanwhile.
    for (final debt in _debtBox.values) {
      if (debt.isPaid) continue;
      for (final item in debt.saleItems) {
        soldNamesInPeriod.add(item.name);
      }
    }

    return _productsBox.values.where((p) {
      if (p.createdAt.isAfter(cutoff)) return false; // too new to judge
      return !soldNamesInPeriod.contains(p.name);
    }).toList();
  }

  /// Raw sales revenue/profit, BEFORE any deduction. Kept available
  /// separately in case the pre-deduction figures are ever needed
  /// elsewhere.
  double get grossSalesRevenue {
    return _salesBox.values.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double get grossSalesProfit {
    return _salesBox.values.fold(0.0, (sum, sale) => sum + sale.totalProfit);
  }

  List<Map<String, dynamic>> get allSupplierPaymentRows {
    final List<Map<String, dynamic>> rows = [];
    for (final supplier in _supplierBox.values) {
      for (final payment in supplier.payments) {
        rows.add({
          'supplierName': supplier.name,
          'amountPaid': payment.amountPaid,
          'date': payment.date,
          'notes': payment.notes,
        });
      }
    }
    return rows;
  }

  double get totalSupplierPayments {
    return _supplierBox.values.fold(0.0, (sum, s) => sum + s.totalPaid);
  }

  /// Every payment/advance ever given to a worker/employee, flattened
  /// across all workers - same row shape as [allSupplierPaymentRows] so
  /// a screen can filter both by period with one shared helper.
  List<Map<String, dynamic>> get allWorkerPaymentRows {
    final List<Map<String, dynamic>> rows = [];
    for (final worker in _workerBox.values) {
      for (final payment in worker.payments) {
        rows.add({
          'workerName': worker.name,
          'amountPaid': payment.amount,
          'date': payment.date,
          'notes': payment.note,
        });
      }
    }
    return rows;
  }

  double get totalWorkerPayments {
    return _workerBox.values.fold(0.0, (sum, w) => sum + w.totalPaid);
  }

  /// Every general expense ever recorded, in the same row shape as
  /// [allWorkerPaymentRows].
  List<Map<String, dynamic>> get allExpenseRows {
    return _expenseBox.values
        .map((e) => {
              'amountPaid': e.amount,
              'date': e.date,
              'notes': e.note,
            })
        .toList();
  }

  double get totalExpenses {
    return _expenseBox.values.fold(0.0, (sum, e) => sum + e.amount);
  }

  // CHANGED (Merchant accounts + Salaries/Expenses <-> Inventory/Jard
  // integration): "إجمالي المبيعات" must reflect money the business
  // actually still holds, so it is net of every supplier payment, every
  // worker payment/advance, and every general expense ever recorded. Use
  // [grossSalesRevenue] above if the pre-deduction figure is ever needed.
  double get totalRevenue {
    return grossSalesRevenue - totalSupplierPayments - totalWorkerPayments - totalExpenses;
  }

  // CHANGED: net profit ("الربح") is now also reduced by worker
  // payments/advances and general expenses. Supplier payments are
  // deliberately NOT subtracted here - they are a cash-flow item against
  // stock already accounted for in cost price, not a further cost of the
  // goods actually sold.
  double get totalProfit {
    return grossSalesProfit - totalWorkerPayments - totalExpenses;
  }

  // إجمالي الديون الحالية للزبائن (تستثني الديون المسددة بالكامل والمؤرشفة)
  double get totalCustomerDebts {
    return _debtBox.values
        .where((d) => !d.isPaid)
        .fold(0.0, (sum, debt) => sum + debt.remainingAmount);
  }

  /// Open (unpaid) debts, newest first - used by the "ديون مستحقة"
  /// details dialog to show items + capital recovery status per debt.
  List<Debt> get openDebts {
    final list = _debtBox.values.where((d) => !d.isPaid).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // صفوف الأصناف المعلقة في الديون الحالية.
  // CHANGED: credit-sale items now stay entirely "pending" until the
  // whole debt is paid (they are no longer released proportionally), so
  // the full quantities are listed, together with the debt's capital
  // recovery status.
  List<Map<String, dynamic>> get pendingDebtInventoryRows {
    final List<Map<String, dynamic>> rows = [];
    for (final debt in openDebts) {
      for (final item in debt.saleItems) {
        final double actualUnitPrice = item.sellPrice - item.discountPerUnit;
        rows.add({
          'debt': debt,
          'customerName': debt.customerName,
          'name': item.name,
          'category': item.category,
          'quantity': item.quantity,
          'actualPrice': actualUnitPrice * item.quantity,
          'capitalRecovered': debt.isCapitalRecovered,
        });
      }
    }
    return rows;
  }

  // الأرباح المتبقية المتوقعة من الديون المعلقة: الجزء من الربح الذي لم
  // يُحتسب بعد في صافي الربح (لأنه يُحتسب فقط بعد استرداد رأس المال).
  double get totalExpectedDebtProfit {
    return _debtBox.values
        .where((d) => !d.isPaid)
        .fold(0.0, (sum, debt) => sum + debt.pendingProfit);
  }

  /// Cost price (رأس المال) still locked inside unpaid debts.
  double get totalPendingDebtCapital {
    return _debtBox.values
        .where((d) => !d.isPaid)
        .fold(0.0, (sum, debt) => sum + debt.capitalRemaining);
  }

  // ---------------------------------------------------------------------
  // NEW: Best-selling items (الأصناف الأكثر مبيعاً)
  // ---------------------------------------------------------------------

  /// Top-selling items within [period], ranked by quantity sold. Based on
  /// the sales records, i.e. cash sales plus credit sales that were fully
  /// paid (exactly what the sales records page shows). Category and shelf
  /// come from the live product when it still exists, falling back to the
  /// category snapshotted on the sale.
  List<BestSellingEntry> getBestSellingItems(BestSellingPeriod period, {int limit = 10}) {
    final now = DateTime.now();
    bool inPeriod(DateTime d) => switch (period) {
          BestSellingPeriod.day =>
            d.year == now.year && d.month == now.month && d.day == now.day,
          BestSellingPeriod.week => !d.isAfter(now) && now.difference(d).inDays < 7,
          BestSellingPeriod.month => d.year == now.year && d.month == now.month,
        };

    final Map<String, _BestSellingAccumulator> byName = {};
    for (final sale in _salesBox.values) {
      if (sale.items.isEmpty || !inPeriod(sale.createdAt)) continue;
      for (final item in sale.items) {
        final key = item.name.trim();
        if (key.isEmpty) continue;
        final acc = byName.putIfAbsent(key, () => _BestSellingAccumulator(key));
        acc.quantity += item.quantity;
        acc.revenue += (item.sellPrice - item.discountPerUnit) * item.quantity;
        if (item.category != null && item.category!.trim().isNotEmpty) {
          acc.snapshotCategory ??= item.category!.trim();
        }
      }
    }

    final products = productsByName;
    final entries = byName.values.map((acc) {
      final product = products[acc.name.toLowerCase()];
      final String? liveCategory =
          (product?.category != null && product!.category!.trim().isNotEmpty)
              ? product.category!.trim()
              : null;
      final String? shelf =
          (product?.shelfNumber != null && product!.shelfNumber!.trim().isNotEmpty)
              ? product.shelfNumber!.trim()
              : null;
      return BestSellingEntry(
        name: acc.name,
        category: liveCategory ?? acc.snapshotCategory,
        shelfNumber: shelf,
        quantity: acc.quantity,
        revenue: acc.revenue,
        product: product,
      );
    }).toList()
      ..sort((a, b) {
        final byQty = b.quantity.compareTo(a.quantity);
        return byQty != 0 ? byQty : b.revenue.compareTo(a.revenue);
      });

    return entries.length > limit ? entries.sublist(0, limit) : entries;
  }

  /// Live products indexed by lower-cased, trimmed name. Used to show the
  /// optional wholesale price / shelf number next to historical rows.
  Map<String, Product> get productsByName {
    final map = <String, Product>{};
    for (final p in _productsBox.values) {
      map[p.name.trim().toLowerCase()] = p;
    }
    return map;
  }

  // ---------------------------------------------------------------------
  // Sale deletion
  // ---------------------------------------------------------------------

  /// Sum of the installments linked to a settled credit sale.
  double linkedDebtPaymentsTotal(Sale settlement) {
    if (!settlement.isDebtSettlement || settlement.debtKey == null) return 0.0;
    return _salesBox.values
        .where((s) => s.isDebtPayment && s.debtKey == settlement.debtKey)
        .fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  /// Deletes a sale record and returns its items to stock. For a settled
  /// credit sale, every installment of that debt is removed as well, so
  /// the money is reversed from total sales / profit exactly like
  /// deleting a cash sale. Returns the names that could not be restocked
  /// (product deleted or renamed).
  Future<List<String>> deleteSaleAndRestock(Sale sale) async {
    final List<String> notRestocked = [];
    final products = productsByName;

    for (final item in sale.items) {
      final product = products[item.name.trim().toLowerCase()];
      if (product != null) {
        product.stockQuantity += item.quantity;
        await product.save();
      } else {
        notRestocked.add(item.name);
      }
    }

    if (sale.isDebtSettlement && sale.debtKey != null) {
      final linked = _salesBox.values
          .where((s) => s.isDebtPayment && s.debtKey == sale.debtKey)
          .toList();
      for (final payment in linked) {
        await payment.delete();
      }
    }

    await sale.delete();
    return notRestocked;
  }
}

enum BestSellingPeriod { day, week, month }

class BestSellingEntry {
  final String name;
  final String? category;
  final String? shelfNumber;
  final int quantity;
  final double revenue;
  final Product? product;

  const BestSellingEntry({
    required this.name,
    required this.category,
    required this.shelfNumber,
    required this.quantity,
    required this.revenue,
    required this.product,
  });
}

class _BestSellingAccumulator {
  final String name;
  int quantity = 0;
  double revenue = 0.0;
  String? snapshotCategory;

  _BestSellingAccumulator(this.name);
}
