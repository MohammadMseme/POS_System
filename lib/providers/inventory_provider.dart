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

  // صفوف الأصناف المعلقة في الديون الحالية (مع حساب السعر الفعلي بعد الخصم)
  List<Map<String, dynamic>> get pendingDebtInventoryRows {
    List<Map<String, dynamic>> rows = [];
    for (var debt in _debtBox.values) {
      if (debt.isPaid) continue;

      double ratio = debt.totalAmount > 0 ? (debt.remainingAmount / debt.totalAmount) : 0.0;
      for (var item in debt.saleItems) {
        int remainingQty = (item.quantity * ratio).round();
        if (remainingQty > 0 || debt.saleItems.length == 1) {
          int finalQty = remainingQty > 0 ? remainingQty : item.quantity;

          double actualUnitPrice = item.sellPrice - item.discountPerUnit;
          double totalActualPrice = actualUnitPrice * finalQty;

          rows.add({
            'customerName': debt.customerName,
            'name': item.name,
            'quantity': finalQty,
            'actualPrice': totalActualPrice,
          });
        }
      }
    }
    return rows;
  }

  // إجمالي الأرباح المتوقعة من الديون المعلقة (غير المسددة فقط)
  double get totalExpectedDebtProfit {
    return _debtBox.values
        .where((d) => !d.isPaid)
        .fold(0.0, (sum, debt) => sum + debt.totalProfit);
  }
}