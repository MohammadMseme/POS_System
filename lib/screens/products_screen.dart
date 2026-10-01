import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/debt_supplier_provider.dart';
import '../models/product.dart';
import '../services/Barcode_print_service.dart';
import 'bulk_order_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _searchController = TextEditingController();
  final _categoryController = TextEditingController();
  final _shelfController = TextEditingController();
  final _supplierController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _searchController.dispose();
    _categoryController.dispose();
    _shelfController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  void _showAddOrEditProductDialog({Product? product}) {
    final String? oldBarcode = product?.barcode;

    if (product != null) {
      _barcodeController.text = product.barcode;
      _nameController.text = product.name;
      _costPriceController.text = product.costPrice.toString();
      _sellPriceController.text = product.sellPrice.toString();
      _stockController.text = product.stockQuantity.toString();
      _categoryController.text = product.category ?? '';
      _shelfController.text = product.shelfNumber ?? '';
    } else {
      _barcodeController.clear();
      _nameController.clear();
      _costPriceController.clear();
      _sellPriceController.clear();
      _stockController.clear();
      _categoryController.clear();
      _shelfController.clear();
      _supplierController.clear();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                product == null ? Icons.add_box_outlined : Icons.edit_outlined,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                product == null ? 'إضافة منتج جديد' : 'تعديل المنتج',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'الباركود (اختياري)',
                      prefixIcon: const Icon(Icons.qr_code_2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المنتج',
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _costPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'سعر الشراء (التكلفة)',
                      prefixIcon: const Icon(Icons.shopping_cart_outlined),
                      suffixText: 'شيكل',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null
                            ? 'أدخل رقم صحيح'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sellPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'سعر البيع',
                      prefixIcon: const Icon(Icons.sell_outlined),
                      suffixText: 'شيكل',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null
                            ? 'أدخل رقم صحيح'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'الكمية المتوفرة',
                      prefixIcon: const Icon(Icons.inventory_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) =>
                        int.tryParse(v ?? '') == null
                            ? 'أدخل رقم صحيح'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoryController,
                    decoration: InputDecoration(
                      labelText: 'اسم القسم (اختياري)',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _shelfController,
                    decoration: InputDecoration(
                      labelText: 'رقم الرف (اختياري)',
                      hintText: 'مثال: A-1 أو B#2',
                      prefixIcon: const Icon(Icons.shelves),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (product == null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.withValues(alpha: 0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storefront_outlined, size: 16, color: Colors.indigo.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'ربط قيمة الشراء كدين على تاجر (اختياري)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _supplierController,
                              decoration: InputDecoration(
                                labelText: 'اسم التاجر (اختياري)',
                                hintText: 'اترك الحقل فارغاً لتجاهل هذه الخطوة',
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            icon: Icon(
              product == null ? Icons.add : Icons.save_outlined,
              size: 20,
            ),
            label: Text(
              product == null ? 'إضافة' : 'حفظ التعديلات',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final provider =
                    Provider.of<ProductProvider>(context, listen: false);

                final String? categoryValue =
                    _categoryController.text.trim().isEmpty
                        ? null
                        : _categoryController.text.trim();
                final String? shelfValue =
                    _shelfController.text.trim().isEmpty
                        ? null
                        : _shelfController.text.trim();

                if (product == null) {
                  final newProduct = Product(
                    barcode: _barcodeController.text.trim().isEmpty
                        ? DateTime.now()
                            .millisecondsSinceEpoch
                            .toString()
                        : _barcodeController.text.trim(),
                    name: _nameController.text.trim(),
                    costPrice:
                        double.parse(_costPriceController.text),
                    sellPrice:
                        double.parse(_sellPriceController.text),
                    stockQuantity:
                        int.parse(_stockController.text),
                    category: categoryValue,
                    shelfNumber: shelfValue,
                  );

                  String result =
                      provider.addProductWithRules(newProduct);

                  Navigator.pop(dialogContext);

                  if (result == 'rejected_barcode_conflict') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'خطأ: هذا الباركود مسجل مسبقاً لصنف آخر! تمت ازالة عملية الإضافة.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if (result == 'updated_existing') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'الصنف موجود مسبقاً، تمت إضافة الكمية الجديدة إلى المخزون بنجاح.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تمت إضافة المنتج الجديد بنجاح.',
                        ),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }

                  final String supplierName = _supplierController.text.trim();
                  if (result != 'rejected_barcode_conflict' && supplierName.isNotEmpty) {
                    final double purchaseValue =
                        newProduct.costPrice * newProduct.stockQuantity;
                    if (purchaseValue > 0) {
                      final String note =
                          'تمت إضافة منتج: ${newProduct.name} - '
                          'الكمية: ${newProduct.stockQuantity} - '
                          'سعر الشراء: ${newProduct.costPrice.toStringAsFixed(2)} شيكل '
                          '(أضيف يدوياً من صفحة المنتجات)';

                      await Provider.of<DebtSupplierProvider>(context, listen: false)
                          .addOrUpdateSupplierDebt(
                        supplierName,
                        purchaseValue,
                        note,
                        entryTitle: 'منتج: ${newProduct.name}',
                      );

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم ربط ${purchaseValue.toStringAsFixed(2)} شيكل كدين على التاجر "$supplierName".',
                          ),
                          backgroundColor: Colors.indigo,
                        ),
                      );
                    }
                  }

                  if (!mounted) return;

                  if (result != 'rejected_barcode_conflict') {
                    await _promptPrintBarcodes(newProduct);
                  }
                } else {
                  final result = await provider.updateProduct(
                    product,
                    oldBarcode: oldBarcode ?? product.barcode,
                    barcode: _barcodeController.text.trim(),
                    name: _nameController.text.trim(),
                    costPrice: double.parse(_costPriceController.text),
                    sellPrice: double.parse(_sellPriceController.text),
                    stockQuantity: int.parse(_stockController.text),
                    category: categoryValue,
                    shelfNumber: shelfValue,
                  );

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);

                  if (!context.mounted) return;
                  if (result == 'rejected_barcode_conflict') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'خطأ: هذا الباركود مسجل مسبقاً لصنف آخر! تم إلغاء حفظ التعديل.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حفظ التعديلات بنجاح.'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _promptPrintBarcodes(Product product) async {
    final quantity = product.stockQuantity;

    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.qr_code_2_outlined, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('طباعة الباركود', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'هل تريد طباعة ملصقات الباركود لهذا المنتج؟\n'
          'سيتم طباعة $quantity ملصق (بعدد الكمية المضافة).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا، شكراً'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print_outlined),
            label: const Text('نعم، اطبع'),
          ),
        ],
      ),
    );

    if (shouldPrint != true) return;
    if (!mounted) return;

    await _printLabels(product, quantity);
  }

  Future<void> _printLabels(Product product, int quantity) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    bool success = false;
    Object? error;

    try {
      success = await BarcodePrintService.printProductLabels(
        context: context,
        product: product,
        copies: quantity,
      );
    } catch (e) {
      error = e;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الطباعة: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال ملصقات الباركود إلى الطابعة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إلغاء عملية الطباعة'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    final provider = Provider.of<ProductProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red.shade700),
            const SizedBox(width: 10),
            const Text('حذف المنتج', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف "${product.name}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      provider.deleteProduct(product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف "${product.name}"'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // REDESIGNED: the card is now one Row(mainAxisAlignment: spaceBetween)
  // with an Expanded LEFT side (avatar + name/barcode identity block,
  // which can wrap/ellipsize freely without ever overflowing the card)
  // and a compact, self-sized RIGHT side that groups the sell/cost
  // prices together with the stock badge and the actions menu directly
  // beneath them - a clean, modern "identity on one side, numbers +
  // actions on the other" layout, replacing the previous fixed-width,
  // horizontally-scrollable row.
  Widget _buildProductCard(
    BuildContext context,
    Product product,
  ) {
    final bool lowStock = product.stockQuantity <= 5;
    final bool hasCategory = product.category != null && product.category!.trim().isNotEmpty;
    final bool hasShelf = product.shelfNumber != null && product.shelfNumber!.trim().isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- LEFT: identity block ----------
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: lowStock
                              ? Colors.red.withValues(alpha: 0.08)
                              : Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: lowStock ? Colors.red : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(
                                  Icons.qr_code_2,
                                  size: 15,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    product.barcode.isEmpty
                                        ? 'بدون باركود'
                                        : product.barcode,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ---------- RIGHT: grouped amounts + actions ----------
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'سعر البيع',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${product.sellPrice.toStringAsFixed(2)} ₪',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'التكلفة',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${product.costPrice.toStringAsFixed(2)} ₪',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: lowStock
                                ? Colors.red.withValues(alpha: 0.08)
                                : Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers_outlined,
                                size: 13,
                                color: lowStock ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${product.stockQuantity}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: lowStock ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          tooltip: 'إجراءات',
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showAddOrEditProductDialog(product: product);
                            } else if (value == 'delete') {
                              _confirmDeleteProduct(product);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, color: Colors.blue),
                                  SizedBox(width: 10),
                                  Text('تعديل'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red),
                                  SizedBox(width: 10),
                                  Text('حذف'),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.more_vert, size: 19),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (hasCategory || hasShelf) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (hasCategory)
                    _metaChip(Icons.category_outlined, product.category!.trim(), Colors.deepPurple),
                  if (hasShelf)
                    _metaChip(Icons.shelves, 'الرف: ${product.shelfNumber!.trim()}', Colors.brown),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    final filteredProducts = productProvider.products.where((p) {
      final query = _searchQuery.toLowerCase();

      return p.name.toLowerCase().contains(query) ||
          p.barcode.contains(query);
    }).toList();

    final totalProducts = productProvider.products.length;

    final totalStock = productProvider.products.fold<int>(
      0,
      (sum, product) => sum + product.stockQuantity,
    );

    final lowStockCount = productProvider.products.where(
      (product) => product.stockQuantity <= 5,
    ).length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined),
            SizedBox(width: 10),
            Text('إدارة الأصناف والمنتجات'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.playlist_add_outlined),
                    label: const Text('إضافة طلبية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BulkOrderScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة منتج'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () =>
                        _showAddOrEditProductDialog(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'إجمالي المنتجات',
                    value: '$totalProducts',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.layers_outlined,
                    title: 'إجمالي الكمية',
                    value: '$totalStock',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'مخزون منخفض',
                    value: '$lowStockCount',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.15),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المنتج أو الباركود...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'المنتجات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${filteredProducts.length}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 70,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty
                                ? 'لا توجد منتجات حالياً'
                                : 'لا توجد منتجات مطابقة للبحث',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];

                        return _buildProductCard(
                          context,
                          product,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}