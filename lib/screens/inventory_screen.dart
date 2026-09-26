import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/debt_supplier_provider.dart';
import '../providers/product_provider.dart';
import '../models/sale.dart';
import '../models/product.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedPeriod = 'يومي';

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

  // دالة النسخ الاحتياطي الذكي الشامل لكل بيانات البرنامج (منطق دون تغيير)
  Future<void> _smartBackupToExternalDrive(BuildContext context) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dbDirectory = Directory(appDir.path);

      if (!dbDirectory.existsSync()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مجلد البيانات غير موجود!'), backgroundColor: Colors.red),
        );
        return;
      }

      Directory? externalDrive;
      for (var letter in ['D', 'G', 'H', 'I', 'J']) {
        final dir = Directory('$letter:\\');
        if (dir.existsSync()) {
          externalDrive = dir;
          break;
        }
      }

      if (!mounted) return;
      if (externalDrive == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء التأكد من توصيل الفلاشة أو الهارد الخارجي أولاً!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final backupDir = Directory('${externalDrive.path}SamaBackup');
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      final files = dbDirectory.listSync();
      int copiedCount = 0;

      for (var file in files) {
        if (file is File) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          final targetPath = '${backupDir.path}${Platform.pathSeparator}$fileName';
          final targetFile = File(targetPath);

          bool shouldCopy = false;

          if (!targetFile.existsSync()) {
            shouldCopy = true;
          } else {
            final sourceModified = file.lastModifiedSync();
            final targetModified = targetFile.lastModifiedSync();
            if (sourceModified.isAfter(targetModified)) {
              shouldCopy = true;
            }
          }

          if (shouldCopy) {
            file.copySync(targetPath);
            copiedCount++;
          }
        }
      }

      if (!mounted) return;
      if (copiedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم بنجاح: نسخ وتحديث ($copiedCount) من الملفات الشاملة على الهارد الخارجي.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جميع البيانات منسوخة مسبقاً ولا توجد بيانات جديدة لتحديثها!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء النسخ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
                              subtitle: Text('الكمية: ${product.stockQuantity} | سعر الجملة: ${product.costPrice} شيكل'),
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

  void _showDebtInventoryDialog(BuildContext context, InventoryProvider inventory) {
    final pendingRows = inventory.pendingDebtInventoryRows;
    final expectedProfit = inventory.totalExpectedDebtProfit;
    final totalDebts = inventory.totalCustomerDebts;

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
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('إجمالي الديون: ${totalDebts.toStringAsFixed(2)} شيكل', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('الأرباح المتوقعة: ${expectedProfit.toStringAsFixed(2)} شيكل', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('الأصناف المباعة بالدين ولم تُسدد بعد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Expanded(
                child: pendingRows.isEmpty
                    ? const Center(child: Text('لا توجد أصناف معلقة في الديون حالياً!'))
                    : ListView.builder(
                        itemCount: pendingRows.length,
                        itemBuilder: (context, index) {
                          final row = pendingRows[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(row['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('الزبون: ${row['customerName']} | الكمية: ${row['quantity']}'),
                              trailing: Text('${row['actualPrice'].toStringAsFixed(2)} شيكل', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
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

  Future<void> _confirmDeleteSale(BuildContext context, Sale saleObj) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف وإرجاع الكميات'),
        content: const Text('هل أنت متأكد من حذف حركة البيع؟ سيتم إعادة الكميات المباعة تلقائياً إلى المخزون.'),
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
    // FIX (use_build_context_synchronously): guard immediately after the
    // async gap above, before any further use of `context`.
    if (!context.mounted) return;

    final productBox = Hive.box<Product>('products');

    // 1. إعادة الكميات المباعة إلى مخزون المنتجات
    for (var item in saleObj.items) {
      for (var product in productBox.values) {
        if (product.name == item.name) {
          product.stockQuantity += item.quantity;
          product.save();
          break;
        }
      }
    }

    // 2. حذف سجل البيع نفسه - يكفي وحده الآن لتحديث كل من صفحتي الجرد
    // والمنتجات فوراً، لأن InventoryProvider و ProductProvider يستمعان
    // مباشرة لصناديق Hive المعنية.
    await saleObj.delete();

    // FIX (use_build_context_synchronously): another async gap
    // (saleObj.delete()) just happened - re-check before using context.
    if (!context.mounted) return;
    Provider.of<ProductProvider>(context, listen: false).refreshProducts();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف حركة البيع وإعادة الكميات إلى المخزون بنجاح'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context);
    final debtProvider = Provider.of<DebtSupplierProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    double totalCustomerDebts = debtProvider.activeDebts.fold(0.0, (sum, debt) => sum + debt.remainingAmount);

    final filteredSales = _getFilteredSales(inventory.allSales);
    final filteredPurchases = _getFilteredPurchases(productProvider.products);

    double totalPurchasesCost = filteredPurchases.fold(0.0, (sum, p) => sum + (p.costPrice * p.stockQuantity));

    double totalRevenue = 0.0;
    double grossProfit = 0.0;

    List<Map<String, dynamic>> individualSaleRows = [];

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
          'quantity': item.quantity,
          'costPrice': item.costPrice,
          'sellPrice': item.sellPrice,
          'discount': item.discountPerUnit,
          'actualSellPrice': actualSellPrice,
          'profit': itemProfit,
        });
      }
    }

    // الأحدث أولاً
    individualSaleRows.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    double realizedProfitFromSales = grossProfit;

    return Scaffold(
      backgroundColor: const Color(0xfff4f7fb),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.analytics_outlined),
            SizedBox(width: 10),
            Text('الجرد والتقارير المالية', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
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
              tooltip: 'نسخ احتياطي شامل للهارد الخارجي',
              onPressed: () => _smartBackupToExternalDrive(context),
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

            // ---------- Quick stats ----------
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.trending_up_rounded,
                    title: 'إجمالي المبيعات',
                    value: '${totalRevenue.toStringAsFixed(2)} ₪',
                    color: const Color(0xFF1565C0),
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
                    icon: realizedProfitFromSales >= 0 ? Icons.savings_outlined : Icons.trending_down_rounded,
                    title: 'الربح المحقق',
                    value: '${realizedProfitFromSales.toStringAsFixed(2)} ₪',
                    color: realizedProfitFromSales >= 0 ? Colors.green.shade700 : Colors.red.shade700,
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

            const SizedBox(height: 18),

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
                              // FIX (deprecated_member_use): MaterialStateProperty
                              // is deprecated in favor of WidgetStateProperty.
                              headingRowColor: WidgetStateProperty.all(const Color(0xFF1565C0).withValues(alpha: 0.06)),
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 13),
                              dataRowColor: WidgetStateProperty.resolveWith((states) => Colors.transparent),
                              columnSpacing: 22,
                              horizontalMargin: 16,
                              columns: const [
                                DataColumn(label: Text('الوقت')),
                                DataColumn(label: Text('اسم الصنف')),
                                DataColumn(label: Text('الكمية')),
                                DataColumn(label: Text('سعر الجملة')),
                                DataColumn(label: Text('السعر الأصلي')),
                                DataColumn(label: Text('الخصم')),
                                DataColumn(label: Text('سعر البيع الفعلي')),
                                DataColumn(label: Text('إجمالي الربح')),
                                DataColumn(label: Text('')),
                              ],
                              rows: List<DataRow>.generate(individualSaleRows.length, (i) {
                                final row = individualSaleRows[i];
                                final DateTime date = row['date'];
                                final timeFormatted =
                                    '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                final Sale saleObj = row['saleObject'];
                                final double profit = row['profit'];

                                return DataRow(
                                  color: WidgetStateProperty.all(i.isEven ? Colors.white : Colors.grey.shade50),
                                  cells: [
                                    DataCell(Text(timeFormatted, style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5))),
                                    DataCell(Text(row['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text('${row['quantity']}')),
                                    DataCell(Text('${row['costPrice']} ₪')),
                                    DataCell(Text('${row['sellPrice']} ₪')),
                                    DataCell(Text(
                                      '${row['discount']} ₪',
                                      style: TextStyle(color: (row['discount'] as num) > 0 ? Colors.red.shade600 : Colors.grey.shade400),
                                    )),
                                    DataCell(Text(
                                      '${row['actualSellPrice'].toStringAsFixed(2)} ₪',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                                    )),
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

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
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
            ],
          ),
        ),
      ),
    );
  }
}