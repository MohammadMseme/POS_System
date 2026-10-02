import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/backup_dialog.dart';
import '../providers/inventory_provider.dart';
import '../providers/debt_supplier_provider.dart';
import '../providers/product_provider.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/debt.dart';
import '../widgets/wholesale_price_reveal.dart';
import 'debts_screen.dart' show CapitalStatusBadge;

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedPeriod = 'يومي';

  // NEW (Stagnant items): independent from the sales-period selector
  // above - this is its own toggle just for the "الأصناف الراكدة" panel.
  int _stagnationDays = 7;
  static const List<int> _stagnationOptions = [7, 15, 30, 60];

  // NEW (Best-selling items): its own period toggle + expand state,
  // independent from the page-wide period selector above.
  BestSellingPeriod _bestSellingPeriod = BestSellingPeriod.day;
  bool _bestSellingExpanded = false;

  static const _periods = [
    {'value': 'يومي', 'label': 'اليوم', 'icon': Icons.today_outlined},
    {'value': 'أسبوعي', 'label': 'الأسبوع', 'icon': Icons.view_week_outlined},
    {'value': 'شهري', 'label': 'الشهر', 'icon': Icons.calendar_view_month_outlined},
    {'value': 'سنوي', 'label': 'السنة', 'icon': Icons.calendar_today_outlined},
    {'value': 'الكل', 'label': 'الكل', 'icon': Icons.all_inclusive},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DebtSupplierProvider>(context, listen: false).loadDebts();
    });
  }

  // CHANGED: the old backup copied EVERY file in the Windows Documents
  // folder (Hive used to store the database there, mixed with the user's
  // own files) to the first of D/G/H/I/J that existed - often an internal
  // disk. The new smart backup (BackupService + backup dialog) lets the
  // user pick the flash drive / external disk, copies only the database
  // folder, and on later runs only appends the new records.
  Future<void> _openSmartBackup() => showSmartBackupDialog(context);

  List<Sale> _getFilteredSales(List<Sale> sales) {
    if (_selectedPeriod == 'الكل') {
      return sales;
    }
    final now = DateTime.now();
    return sales.where((sale) {
      if (_selectedPeriod == 'يومي') {
        return sale.createdAt.day == now.day &&
            sale.createdAt.month == now.month &&
            sale.createdAt.year == now.year;
      } else if (_selectedPeriod == 'أسبوعي') {
        return now.difference(sale.createdAt).inDays <= 7;
      } else if (_selectedPeriod == 'شهري') {
        return sale.createdAt.month == now.month && sale.createdAt.year == now.year;
      } else {
        return sale.createdAt.year == now.year;
      }
    }).toList();
  }

  List<Product> _getFilteredPurchases(List<Product> products) {
    if (_selectedPeriod == 'الكل') {
      return products;
    }
    final now = DateTime.now();
    return products.where((product) {
      if (_selectedPeriod == 'يومي') {
        return product.createdAt.day == now.day &&
            product.createdAt.month == now.month &&
            product.createdAt.year == now.year;
      } else if (_selectedPeriod == 'أسبوعي') {
        return now.difference(product.createdAt).inDays <= 7;
      } else if (_selectedPeriod == 'شهري') {
        return product.createdAt.month == now.month && product.createdAt.year == now.year;
      } else {
        return product.createdAt.year == now.year;
      }
    }).toList();
  }

  // NEW: shared period filter for any flattened "row" list that carries
  // a 'date' key - used for supplier payments, worker payments, and
  // general expenses alike, following the exact same period definitions
  // as sales/purchases above.
  List<Map<String, dynamic>> _filterRowsByPeriod(List<Map<String, dynamic>> rows) {
    if (_selectedPeriod == 'الكل') {
      return rows;
    }
    final now = DateTime.now();
    return rows.where((row) {
      final DateTime date = row['date'] as DateTime;
      if (_selectedPeriod == 'يومي') {
        return date.day == now.day && date.month == now.month && date.year == now.year;
      } else if (_selectedPeriod == 'أسبوعي') {
        return now.difference(date).inDays <= 7;
      } else if (_selectedPeriod == 'شهري') {
        return date.month == now.month && date.year == now.year;
      } else {
        return date.year == now.year;
      }
    }).toList();
  }

  void _showPurchasesDialog(BuildContext context, List<Product> purchases) {
    double totalPurchasesCost = purchases.fold(0.0, (sum, p) => sum + (p.costPrice * p.stockQuantity));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.orange),
            SizedBox(width: 8),
            Text('تفاصيل المشتريات خلال الفترة'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('إجمالي التكلفة: ${totalPurchasesCost.toStringAsFixed(2)} شيكل', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('عدد الأصناف: ${purchases.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('قائمة الأصناف التي تم شراؤها أو إضافتها:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Expanded(
                child: purchases.isEmpty
                    ? const Center(child: Text('لا توجد مشتريات جديدة مسجلة في هذه الفترة!'))
                    : ListView.builder(
                        itemCount: purchases.length,
                        itemBuilder: (context, index) {
                          final product = purchases[index];
                          double totalItemCost = product.costPrice * product.stockQuantity;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              // "سعر الشراء" (cost) - renamed so it is not
                              // confused with the new, informational-only
                              // wholesale price field (سعر الجملة).
                              subtitle: Text('الكمية: ${product.stockQuantity} | سعر الشراء: ${product.costPrice} شيكل'),
                              trailing: Text('${totalItemCost.toStringAsFixed(2)} شيكل', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showLowStockDialog(BuildContext context, List lowStockList) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('قائمة نواقص المخزون'),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 350,
          child: lowStockList.isEmpty
              ? const Center(child: Text('لا توجد أصناف منتهية حالياً!'))
              : ListView.builder(
                  itemCount: lowStockList.length,
                  itemBuilder: (context, index) {
                    final product = lowStockList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('الباركود: ${product.barcode}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'المتبقي: ${product.stockQuantity}',
                            style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // CHANGED: credit-sale items now stay pending (and out of the sales
  // records) until the whole debt is paid. This dialog lists them per
  // debt, with the capital recovery status (تم استرداد رأس المال) next to
  // each item.
  void _showDebtInventoryDialog(BuildContext context, InventoryProvider inventory) {
    final List<Debt> debts = inventory.openDebts;
    final expectedProfit = inventory.totalExpectedDebtProfit;
    final pendingCapital = inventory.totalPendingDebtCapital;
    final totalDebts = inventory.totalCustomerDebts;

    Widget summaryValue(String label, double value, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
          const SizedBox(height: 2),
          Text(
            '${value.toStringAsFixed(2)} شيكل',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.purple),
            SizedBox(width: 8),
            Text('جرد ومرابح الديون المعلقة'),
          ],
        ),
        content: SizedBox(
          width: 580,
          height: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    summaryValue('إجمالي الديون المتبقية', totalDebts, Colors.purple.shade700),
                    summaryValue('رأس مال لم يُسترد بعد', pendingCapital, Colors.orange.shade800),
                    summaryValue('أرباح متوقعة (غير محتسبة بعد)', expectedProfit, Colors.green.shade700),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الدفعات تُضاف لإجمالي المبيعات فوراً، وتسترد رأس المال أولاً ثم تُحتسب ربحاً. '
                'تظهر الأصناف في سجل المبيعات بعد سداد الدين بالكامل.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: debts.isEmpty
                    ? const Center(child: Text('لا توجد ديون معلقة حالياً!'))
                    : ListView.builder(
                        itemCount: debts.length,
                        itemBuilder: (context, index) {
                          final debt = debts[index];
                          final bool hasItems = debt.saleItems.isNotEmpty;
                          final bool recovered = debt.isCapitalRecovered;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 18, color: Colors.purple.shade400),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          debt.customerName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      Text(
                                        'المتبقي: ${debt.remainingAmount.toStringAsFixed(2)} شيكل',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (hasItems) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'رأس المال المسترد: ${debt.capitalRecovered.clamp(0.0, debt.totalCost).toStringAsFixed(2)}'
                                      ' / ${debt.totalCost.toStringAsFixed(2)} شيكل'
                                      ' • ربح محتسب: ${debt.profitRealized.toStringAsFixed(2)}'
                                      ' • ربح متبقٍ: ${debt.pendingProfit.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                    ),
                                    const Divider(height: 16),
                                    ...debt.saleItems.map((item) {
                                      final double lineTotal =
                                          (item.sellPrice - item.discountPerUnit) * item.quantity;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Icon(Icons.circle, size: 7, color: Colors.purple.shade200),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${item.name}  ×${item.quantity}',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                            ),
                                            CapitalStatusBadge(recovered: recovered, compact: true),
                                            const SizedBox(width: 10),
                                            Text(
                                              '${lineTotal.toStringAsFixed(2)} شيكل',
                                              style: const TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ] else
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'دين مسجل يدوياً بدون أصناف: ${debt.itemsTaken.join('، ')}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // NEW (Merchant accounts + Salaries/Expenses <-> Inventory/Jard
  // integration): a single transparency dialog showing exactly what was
  // subtracted from "إجمالي المبيعات" and "الربح المحقق" for the
  // selected period, broken down by source.
  void _showDeductionsDialog(
    BuildContext context, {
    required List<Map<String, dynamic>> supplierPayments,
    required List<Map<String, dynamic>> workerPayments,
    required List<Map<String, dynamic>> expenseRows,
  }) {
    double supplierTotal = supplierPayments.fold(0.0, (s, r) => s + (r['amountPaid'] as double));
    double workerTotal = workerPayments.fold(0.0, (s, r) => s + (r['amountPaid'] as double));
    double expenseTotal = expenseRows.fold(0.0, (s, r) => s + (r['amountPaid'] as double));

    Widget buildSection(String title, List<Map<String, dynamic>> rows, String? nameKey, double total, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Text('${total.toStringAsFixed(2)} ₪', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('لا يوجد شيء خلال هذه الفترة', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            )
          else
            ...rows.map((row) {
              final DateTime date = row['date'] as DateTime;
              final dateStr = '${date.day}/${date.month}/${date.year}';
              final String? name = nameKey != null ? row[nameKey] as String? : null;
              final String notes = (row['notes'] as String?) ?? '';
              final label = [
                if (name != null && name.isNotEmpty) name,
                if (notes.isNotEmpty) notes,
                dateStr,
              ].join(' - ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
                    Text(
                      '${(row['amountPaid'] as double).toStringAsFixed(2)} ₪',
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 10),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.remove_circle_outline, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('تفاصيل الخصومات من المبيعات والربح', style: TextStyle(fontSize: 15))),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSection('مدفوعات للتجار والموردين (تُخصم من المبيعات فقط)', supplierPayments, 'supplierName', supplierTotal, Colors.teal),
                const Divider(),
                buildSection('رواتب وسلف العمال (تُخصم من المبيعات والربح)', workerPayments, 'workerName', workerTotal, Colors.indigo),
                const Divider(),
                buildSection('مصاريف عامة (تُخصم من المبيعات والربح)', expenseRows, null, expenseTotal, Colors.red),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSale(BuildContext context, Sale saleObj) async {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    final bool isSettlement = saleObj.isDebtSettlement;
    final double linkedPayments =
        isSettlement ? inventory.linkedDebtPaymentsTotal(saleObj) : 0.0;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف وإرجاع الكميات'),
        content: Text(
          isSettlement
              ? 'هذه الحركة لبيع بالدين تم سداده بالكامل. سيتم إعادة الكميات المباعة إلى المخزون، '
                  'وإلغاء دفعات السداد المرتبطة بها '
                  '(${linkedPayments.toStringAsFixed(2)} شيكل) من إجمالي المبيعات والربح. هل أنت متأكد؟'
              : 'هل أنت متأكد من حذف حركة البيع؟ سيتم إعادة الكميات المباعة تلقائياً إلى المخزون.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف وإرجاع'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final List<String> notRestocked = await inventory.deleteSaleAndRestock(saleObj);

    productProvider.refreshProducts();

    if (!context.mounted) return;
    if (notRestocked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف حركة البيع وإعادة الكميات إلى المخزون بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حذف الحركة، لكن تعذر إيجاد بعض الأصناف لإعادة كميتها للمخزون '
            '(ربما تم حذفها أو تغيير اسمها): ${notRestocked.join('، ')}',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context);
    // NEW (roles): the Employee only gets the sales log (to handle
    // returns) - no financial cards, no analysis panels, no cost/profit
    // columns, no backup.
    final bool isAdmin = Provider.of<AuthProvider>(context).isAdmin;
    final debtProvider = Provider.of<DebtSupplierProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    double totalCustomerDebts = debtProvider.activeDebts.fold(0.0, (sum, debt) => sum + debt.remainingAmount);

    final filteredSales = _getFilteredSales(inventory.allSales);
    final filteredPurchases = _getFilteredPurchases(productProvider.products);

    // Money leaving the till within the selected period, from every
    // source that now feeds into "إجمالي المبيعات" / "الربح المحقق".
    final filteredSupplierPayments = _filterRowsByPeriod(inventory.allSupplierPaymentRows);
    final filteredWorkerPayments = _filterRowsByPeriod(inventory.allWorkerPaymentRows);
    final filteredExpenseRows = _filterRowsByPeriod(inventory.allExpenseRows);

    final double totalSupplierPaymentsInPeriod =
        filteredSupplierPayments.fold(0.0, (sum, r) => sum + (r['amountPaid'] as double));
    final double totalWorkerPaymentsInPeriod =
        filteredWorkerPayments.fold(0.0, (sum, r) => sum + (r['amountPaid'] as double));
    final double totalExpensesInPeriod =
        filteredExpenseRows.fold(0.0, (sum, r) => sum + (r['amountPaid'] as double));

    final double totalSalesDeductionsInPeriod =
        totalSupplierPaymentsInPeriod + totalWorkerPaymentsInPeriod + totalExpensesInPeriod;
    final double totalProfitDeductionsInPeriod = totalWorkerPaymentsInPeriod + totalExpensesInPeriod;

    double totalPurchasesCost = filteredPurchases.fold(0.0, (sum, p) => sum + (p.costPrice * p.stockQuantity));

    double totalRevenue = 0.0;
    double grossProfit = 0.0;

    List<Map<String, dynamic>> individualSaleRows = [];
    // Live products by name - used only to reveal the optional,
    // informational wholesale price next to the selling price.
    final productsByName = inventory.productsByName;

    for (var sale in filteredSales) {
      totalRevenue += sale.totalAmount;
      grossProfit += sale.totalProfit;

      for (var item in sale.items) {
        double actualSellPrice = item.sellPrice - item.discountPerUnit;
        double itemProfit = (actualSellPrice - item.costPrice) * item.quantity;

        individualSaleRows.add({
          'saleObject': sale,
          'date': sale.createdAt,
          'name': item.name,
          // NEW: category snapshotted on the SaleItem at sale time, so
          // this row always shows the category as it was then - never
          // displayed at all when the item had no category set.
          'category': item.category,
          'quantity': item.quantity,
          'costPrice': item.costPrice,
          'sellPrice': item.sellPrice,
          'discount': item.discountPerUnit,
          'actualSellPrice': actualSellPrice,
          'profit': itemProfit,
          // NEW: credit sale that was fully paid - shown like a cash sale,
          // with a small badge. Its money was already counted through the
          // debt installments, so it adds nothing to the totals above.
          'isDebtSettlement': sale.isDebtSettlement,
          'wholesalePrice': productsByName[item.name.trim().toLowerCase()]?.wholesalePrice,
        });
      }
    }

    // الأحدث أولاً
    individualSaleRows.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    // CHANGED (Merchant accounts + Salaries/Expenses <-> Inventory/Jard
    // integration): every merchant payment, worker payment/advance, and
    // general expense within the selected period is money leaving the
    // till, so both figures below are shown net of them. Profit is NOT
    // reduced by supplier payments (see totalProfitDeductionsInPeriod).
    final double netRevenue = totalRevenue - totalSalesDeductionsInPeriod;
    final double netProfit = grossProfit - totalProfitDeductionsInPeriod;

    final stagnantProducts = inventory.getStagnantProducts(_stagnationDays);
    final bestSellingItems = inventory.getBestSellingItems(_bestSellingPeriod);

    return Scaffold(
      backgroundColor: const Color(0xfff4f7fb),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined),
            const SizedBox(width: 10),
            Text(
              isAdmin ? 'الجرد والتقارير المالية' : 'سجل حركات البيع والمرتجعات',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sd_storage_outlined),
              ),
              tooltip: 'نسخ احتياطي ذكي للفلاشة / الهارد الخارجي',
              onPressed: _openSmartBackup,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- Period selector ----------
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: _periods.map((p) {
                  final selected = _selectedPeriod == p['value'];
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedPeriod = p['value'] as String),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF1565C0) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              p['icon'] as IconData,
                              size: 18,
                              color: selected ? Colors.white : Colors.grey.shade500,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              p['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: selected ? Colors.white : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Financial overview + analysis panels: Admin only.
            if (isAdmin) ...[
            // ---------- Quick stats ----------
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.trending_up_rounded,
                    title: 'إجمالي المبيعات',
                    value: '${netRevenue.toStringAsFixed(2)} ₪',
                    color: const Color(0xFF1565C0),
                    subtitle: totalSalesDeductionsInPeriod > 0
                        ? '(بعد خصم ${totalSalesDeductionsInPeriod.toStringAsFixed(2)} ₪)'
                        : null,
                    onTap: (filteredSupplierPayments.isNotEmpty ||
                            filteredWorkerPayments.isNotEmpty ||
                            filteredExpenseRows.isNotEmpty)
                        ? () => _showDeductionsDialog(
                              context,
                              supplierPayments: filteredSupplierPayments,
                              workerPayments: filteredWorkerPayments,
                              expenseRows: filteredExpenseRows,
                            )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.shopping_cart_outlined,
                    title: 'قيمة المشتريات',
                    value: '${totalPurchasesCost.toStringAsFixed(2)} ₪',
                    color: Colors.orange.shade700,
                    onTap: () => _showPurchasesDialog(context, filteredPurchases),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: netProfit >= 0 ? Icons.savings_outlined : Icons.trending_down_rounded,
                    title: 'الربح المحقق',
                    value: '${netProfit.toStringAsFixed(2)} ₪',
                    color: netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    subtitle: totalProfitDeductionsInPeriod > 0
                        ? '(بعد خصم ${totalProfitDeductionsInPeriod.toStringAsFixed(2)} ₪ رواتب/مصاريف)'
                        : null,
                    onTap: (filteredWorkerPayments.isNotEmpty || filteredExpenseRows.isNotEmpty)
                        ? () => _showDeductionsDialog(
                              context,
                              supplierPayments: filteredSupplierPayments,
                              workerPayments: filteredWorkerPayments,
                              expenseRows: filteredExpenseRows,
                            )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'ديون مستحقة',
                    value: '${totalCustomerDebts.toStringAsFixed(2)} ₪',
                    color: Colors.purple.shade700,
                    onTap: () => _showDebtInventoryDialog(context, inventory),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'نواقص المخزون',
                    value: '${inventory.lowStockProducts.length} منتج',
                    color: Colors.red.shade700,
                    onTap: () => _showLowStockDialog(context, inventory.lowStockProducts),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ---------- Best-selling + stagnant items panels ----------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BestSellingSection(
                    items: bestSellingItems,
                    period: _bestSellingPeriod,
                    expanded: _bestSellingExpanded,
                    onPeriodChanged: (p) => setState(() {
                      _bestSellingPeriod = p;
                      _bestSellingExpanded = true;
                    }),
                    onToggle: () => setState(() => _bestSellingExpanded = !_bestSellingExpanded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StagnantItemsSection(
                    stagnantProducts: stagnantProducts,
                    selectedDays: _stagnationDays,
                    options: _stagnationOptions,
                    onDaysChanged: (d) => setState(() => _stagnationDays = d),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            ],

            // ---------- Detailed sales table ----------
            Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 19, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text('سجل حركات البيع المفصلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${individualSaleRows.length}',
                    style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الأصناف المباعة بالدين تظهر هنا بعد سداد الدين بالكامل',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Expanded(
              child: individualSaleRows.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                              child: Icon(Icons.point_of_sale_outlined, size: 44, color: Colors.blue.shade300),
                            ),
                            const SizedBox(height: 14),
                            const Text('لا توجد حركات بيع خلال هذه الفترة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('جرّب اختيار فترة زمنية أوسع من الأعلى', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFF1565C0).withValues(alpha: 0.06)),
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 13),
                              dataRowColor: WidgetStateProperty.resolveWith((states) => Colors.transparent),
                              columnSpacing: 22,
                              horizontalMargin: 16,
                              // Cost and profit columns are Admin-only
                              // (cells below use the same conditions).
                              columns: [
                                const DataColumn(label: Text('الوقت')),
                                const DataColumn(label: Text('اسم الصنف')),
                                const DataColumn(label: Text('الكمية')),
                                if (isAdmin) const DataColumn(label: Text('سعر التكلفة للحبة')),
                                const DataColumn(label: Text('السعر الأصلي للحبة')),
                                const DataColumn(label: Text('الخصم للحبة')),
                                const DataColumn(label: Text('سعر البيع الفعلي للحبة')),
                                if (isAdmin) const DataColumn(label: Text('إجمالي الربح للكل')),
                                const DataColumn(label: Text('')),
                              ],
                              rows: List<DataRow>.generate(individualSaleRows.length, (i) {
                                final row = individualSaleRows[i];
                                final DateTime date = row['date'];
                                final timeFormatted =
                                    '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                final Sale saleObj = row['saleObject'];
                                final double profit = row['profit'];
                                final String? category = row['category'] as String?;
                                final bool hasCategory = category != null && category.trim().isNotEmpty;
                                final bool isDebtSettlement = row['isDebtSettlement'] == true;

                                return DataRow(
                                  color: WidgetStateProperty.all(i.isEven ? Colors.white : Colors.grey.shade50),
                                  cells: [
                                    DataCell(Text(timeFormatted, style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5))),
                                    // NEW: product name + category badge
                                    // right next to it, shown ONLY when
                                    // the sale item actually carries a
                                    // (snapshotted) category.
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              row['name'],
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (hasCategory) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.deepPurple.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
                                              ),
                                              child: Text(
                                                category.trim(),
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.deepPurple,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (isDebtSettlement) ...[
                                            const SizedBox(width: 6),
                                            Tooltip(
                                              message: 'بيع بالدين تم سداده بالكامل',
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  'دين مسدد',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange.shade800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    DataCell(Text('${row['quantity']}')),
                                    if (isAdmin) DataCell(Text('${row['costPrice']} ₪')),
                                    // NEW: tap to reveal the optional wholesale price.
                                    DataCell(WholesalePriceReveal(
                                      priceText: '${row['sellPrice']} ₪',
                                      wholesalePrice: row['wholesalePrice'] as double?,
                                    )),
                                    DataCell(Text(
                                      '${row['discount']} ₪',
                                      style: TextStyle(color: (row['discount'] as num) > 0 ? Colors.red.shade600 : Colors.grey.shade400),
                                    )),
                                    DataCell(Text(
                                      '${row['actualSellPrice'].toStringAsFixed(2)} ₪',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                                    )),
                                    if (isAdmin)
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (profit >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${profit.toStringAsFixed(2)} ₪',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        tooltip: 'حذف هذه الحركة وإعادة الكميات للمخزون',
                                        onPressed: () => _confirmDeleteSale(context, saleObj),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact, tappable quick-stat card used across the top of the Inventory
/// screen. Purely presentational - all figures are computed in build().
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final String? subtitle;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  if (onTap != null) Icon(Icons.arrow_drop_down_circle, size: 15, color: color.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: Colors.red.shade400, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "الأصناف الراكدة" panel. Shows the count and names of products with
/// zero sales within the selected stagnation window, with a dynamic
/// 7/15/30/60-day toggle.
class _StagnantItemsSection extends StatelessWidget {
  final List<Product> stagnantProducts;
  final int selectedDays;
  final List<int> options;
  final ValueChanged<int> onDaysChanged;

  const _StagnantItemsSection({
    required this.stagnantProducts,
    required this.selectedDays,
    required this.options,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hourglass_bottom_outlined, color: Colors.deepPurple, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Text('الأصناف الراكدة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${stagnantProducts.length}',
                      style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: options.map((d) {
                  final selected = d == selectedDays;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      onTap: () => onDaysChanged(d),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? Colors.deepPurple : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$d يوم',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (stagnantProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'لا توجد أصناف راكدة خلال آخر $selectedDays يوم 🎉',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                itemCount: stagnantProducts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = stagnantProducts[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.circle, size: 8, color: Colors.deepPurple.shade300),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                      'الكمية المتوفرة: ${p.stockQuantity}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
/// NEW: "الأصناف الأكثر مبيعاً" panel. Collapsible card with its own
/// Day / Week / Month toggle. When expanded it lists the top-selling
/// items of the chosen period with category (اسم القسم) and shelf number
/// (رقم الرف). The selling price can be tapped to reveal the optional
/// wholesale price.
class _BestSellingSection extends StatelessWidget {
  final List<BestSellingEntry> items;
  final BestSellingPeriod period;
  final bool expanded;
  final ValueChanged<BestSellingPeriod> onPeriodChanged;
  final VoidCallback onToggle;

  const _BestSellingSection({
    required this.items,
    required this.period,
    required this.expanded,
    required this.onPeriodChanged,
    required this.onToggle,
  });

  static const Map<BestSellingPeriod, String> _labels = {
    BestSellingPeriod.day: 'يوم',
    BestSellingPeriod.week: 'أسبوع',
    BestSellingPeriod.month: 'شهر',
  };

  static const Map<BestSellingPeriod, String> _emptyLabels = {
    BestSellingPeriod.day: 'اليوم',
    BestSellingPeriod.week: 'آخر 7 أيام',
    BestSellingPeriod.month: 'هذا الشهر',
  };

  static const Color _accent = Color(0xFF00897B);

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_fire_department_outlined, color: _accent, size: 19),
                    ),
                    const SizedBox(width: 10),
                    const Text('الأصناف الأكثر مبيعاً', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: BestSellingPeriod.values.map((p) {
                  final selected = p == period;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      onTap: () => onPeriodChanged(p),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? _accent : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _labels[p]!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'لا توجد مبيعات مسجلة خلال ${_emptyLabels[period]}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
            )
          else if (!expanded)
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'الأعلى مبيعاً: ${items.first.name} (${items.first.quantity} قطعة) - اضغط لعرض القائمة',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = items[index];
                  final bool hasCategory = e.category != null && e.category!.isNotEmpty;
                  final bool hasShelf = e.shelfNumber != null && e.shelfNumber!.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: index < 3 ? Colors.amber.shade100 : Colors.grey.shade100,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: index < 3 ? Colors.amber.shade900 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                e.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 3,
                                children: [
                                  _chip(
                                    Icons.category_outlined,
                                    hasCategory ? e.category! : 'بدون قسم',
                                    hasCategory ? Colors.deepPurple : Colors.grey,
                                  ),
                                  _chip(
                                    Icons.shelves,
                                    hasShelf ? 'الرف: ${e.shelfNumber!}' : 'بدون رف',
                                    hasShelf ? Colors.brown : Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${e.quantity} قطعة',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: _accent, fontSize: 13),
                            ),
                            if (e.product != null)
                              WholesalePriceReveal(
                                priceText: '${e.product!.sellPrice.toStringAsFixed(2)} ₪',
                                wholesalePrice: e.product!.wholesalePrice,
                                priceStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
