import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/debt.dart';

class InventoryProvider extends ChangeNotifier {
  Box<Sale> get _salesBox => Hive.box<Sale>('sales');
  Box<Product> get _productsBox => Hive.box<Product>('products');
  Box<Debt> get _debtBox => Hive.box<Debt>('debts');

  // FIX (real-time inventory refresh): every getter below already reads
  // straight from the live Hive box, so the *data* was never stale - the
  // bug was that this provider never called notifyListeners(), so
  // nothing ever told InventoryScreen to rebuild after a cash sale wrote
  // directly to the sales/products boxes via PosProvider (which has no
  // reference to this provider at all). Previously the screen only
  // appeared to refresh because an unrelated setState - e.g. toggling
  // the date filter - happened to rebuild it and pick up fresh data in
  // the process.
  //
  // The fix: listen directly to the underlying Hive boxes and forward
  // every change as notifyListeners(). This is decoupled from whichever
  // provider/screen performs the write, so it stays correct for cash
  // sales, debt-payment sales, stock edits, or anything added later that
  // touches these boxes - not just today's one call site.
  late final ValueListenable<Box<Sale>> _salesListenable;
  late final ValueListenable<Box<Product>> _productsListenable;
  late final ValueListenable<Box<Debt>> _debtListenable;

  InventoryProvider() {
    _salesListenable = _salesBox.listenable();
    _productsListenable = _productsBox.listenable();
    _debtListenable = _debtBox.listenable();

    _salesListenable.addListener(_handleDataChanged);
    _productsListenable.addListener(_handleDataChanged);
    _debtListenable.addListener(_handleDataChanged);
  }

  void _handleDataChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _salesListenable.removeListener(_handleDataChanged);
    _productsListenable.removeListener(_handleDataChanged);
    _debtListenable.removeListener(_handleDataChanged);
    super.dispose();
  }

  List<Sale> get allSales => _salesBox.values.toList();

  // المنتجات التي قارب مخزونها على النفاذ (أقل من 5 قطع)
  List<Product> get lowStockProducts {
    return _productsBox.values.where((p) => p.stockQuantity <= 5).toList();
  }

  double get totalRevenue {
    return _salesBox.values.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double get totalProfit {
    return _salesBox.values.fold(0.0, (sum, sale) => sum + sale.totalProfit);
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