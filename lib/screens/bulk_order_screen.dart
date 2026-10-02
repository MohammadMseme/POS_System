import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/debt_supplier_provider.dart';
import '../models/product.dart';
import '../models/supplier_entry.dart';
import '../services/Barcode_print_service.dart';

class _DecimalTextInputFormatter extends TextInputFormatter {
  static final RegExp _pattern = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    if (_pattern.hasMatch(newValue.text)) return newValue;
    return oldValue;
  }
}

/// One row of the bulk-order grid: a full set of controllers mirroring
/// the fields on a single Product, so the row can be turned directly
/// into a Product (and a matching SupplierOrderItem) on save.
class _OrderRow {
  final TextEditingController barcodeCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController costCtrl = TextEditingController();
  final TextEditingController sellCtrl = TextEditingController();
  // NEW: optional wholesale price (سعر البيع بالجملة) for this row only -
  // saved on the Product exactly like the single "Add Product" form.
  final TextEditingController wholesaleCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController categoryCtrl = TextEditingController();
  final TextEditingController shelfCtrl = TextEditingController();

  void dispose() {
    barcodeCtrl.dispose();
    nameCtrl.dispose();
    costCtrl.dispose();
    sellCtrl.dispose();
    wholesaleCtrl.dispose();
    qtyCtrl.dispose();
    categoryCtrl.dispose();
    shelfCtrl.dispose();
  }
}

class BulkOrderScreen extends StatefulWidget {
  const BulkOrderScreen({super.key});

  @override
  State<BulkOrderScreen> createState() => _BulkOrderScreenState();
}

class _BulkOrderScreenState extends State<BulkOrderScreen> {
  final TextEditingController _supplierController = TextEditingController();
  final List<_OrderRow> _rows = [];

  static const double _wBarcode = 130;
  static const double _wName = 220;
  static const double _wCost = 110;
  static const double _wSell = 110;
  static const double _wWholesale = 120;
  static const double _wQty = 90;
  static const double _wCategory = 150;
  static const double _wShelf = 120;
  static const double _wDelete = 56;
  static const double _cellGap = 8;

  static double get _tableWidth =>
      _wBarcode + _wName + _wCost + _wSell + _wWholesale + _wQty + _wCategory + _wShelf + _wDelete +
      (_cellGap * 9);

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _rows.add(_OrderRow());
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_OrderRow()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  double get _totalCost {
    double sum = 0;
    for (final row in _rows) {
      if (row.nameCtrl.text.trim().isEmpty) continue;
      final cost = double.tryParse(row.costCtrl.text) ?? 0;
      final qty = int.tryParse(row.qtyCtrl.text) ?? 0;
      sum += cost * qty;
    }
    return sum;
  }

  Future<void> _save() async {
    final nonEmptyRows = _rows.where((r) => r.nameCtrl.text.trim().isNotEmpty).toList();

    if (nonEmptyRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم تقم بإدخال أي منتج بعد. أدخل اسم منتج واحد على الأقل.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate every non-empty row BEFORE writing anything, so a single
    // bad row can never leave the batch half-committed. سعر البيع is now
    // a MANDATORY field for every row, exactly like سعر الشراء and
    // الكمية - a row missing it is treated as invalid and blocks saving.
    final List<String> invalidRowLabels = [];
    for (final row in nonEmptyRows) {
      final cost = double.tryParse(row.costCtrl.text);
      final sell = double.tryParse(row.sellCtrl.text);
      final qty = int.tryParse(row.qtyCtrl.text);
      final rowName = row.nameCtrl.text.trim();

      if (cost == null || cost < 0) {
        invalidRowLabels.add('$rowName (سعر شراء غير صالح)');
      } else if (sell == null || sell < 0) {
        invalidRowLabels.add('$rowName (سعر البيع مطلوب وغير صالح)');
      } else if (qty == null || qty <= 0) {
        invalidRowLabels.add('$rowName (كمية غير صالحة)');
      } else if (row.wholesaleCtrl.text.trim().isNotEmpty &&
          (double.tryParse(row.wholesaleCtrl.text.trim()) ?? -1) < 0) {
        // Optional column: only validated when something was typed.
        invalidRowLabels.add('$rowName (سعر الجملة غير صالح)');
      }
    }

    if (invalidRowLabels.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تحقق من هذه الصفوف قبل الحفظ: ${invalidRowLabels.join('، ')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final debtProvider = Provider.of<DebtSupplierProvider>(context, listen: false);

    int addedCount = 0;
    int mergedCount = 0;
    int rejectedCount = 0;
    final List<SupplierOrderItem> linkedItems = [];
    // NEW: every product that actually went through (added or merged),
    // kept as a plain Product carrying THIS order's quantity, so it can
    // be handed to the print-confirmation flow afterward - exactly the
    // same object shape/print call the single-product "Add Product"
    // flow already uses.
    final List<Product> productsForPrinting = [];
    double linkedTotal = 0;

    for (final row in nonEmptyRows) {
      final double cost = double.parse(row.costCtrl.text);
      // سعر البيع is now guaranteed present and valid by the validation
      // pass above - no more "falls back to cost price" default.
      final double sell = double.parse(row.sellCtrl.text);
      final int qty = int.parse(row.qtyCtrl.text);
      final String name = row.nameCtrl.text.trim();
      final String? category =
          row.categoryCtrl.text.trim().isEmpty ? null : row.categoryCtrl.text.trim();
      final String? shelf =
          row.shelfCtrl.text.trim().isEmpty ? null : row.shelfCtrl.text.trim();
      // Optional, informational only (never used in any calculation).
      final double? parsedWholesale = double.tryParse(row.wholesaleCtrl.text.trim());
      final double? wholesale =
          (parsedWholesale != null && parsedWholesale > 0) ? parsedWholesale : null;

      final product = Product(
        barcode: row.barcodeCtrl.text.trim().isEmpty
            ? DateTime.now().millisecondsSinceEpoch.toString() + name.hashCode.toString()
            : row.barcodeCtrl.text.trim(),
        name: name,
        costPrice: cost,
        sellPrice: sell,
        stockQuantity: qty,
        category: category,
        shelfNumber: shelf,
        wholesalePrice: wholesale,
      );

      final result = productProvider.addProductWithRules(product);

      if (result == 'rejected_barcode_conflict') {
        rejectedCount++;
        continue; // never link a rejected row's cost/print its labels
      }

      if (result == 'updated_existing') {
        mergedCount++;
      } else {
        addedCount++;
      }

      final double lineTotal = cost * qty;
      linkedTotal += lineTotal;
      linkedItems.add(SupplierOrderItem(
        name: name,
        costPrice: cost,
        sellPrice: sell,
        quantity: qty,
      ));
      // `product.stockQuantity` here is exactly this order's quantity
      // for this row - the right number of copies to print, regardless
      // of whether the row created a new product or merged into an
      // existing one's total stock.
      productsForPrinting.add(product);
    }

    final String supplierName = _supplierController.text.trim();
    if (supplierName.isNotEmpty && linkedItems.isNotEmpty) {
      final note =
          'طلبية جديدة تضم ${linkedItems.length} صنف بإجمالي ${linkedTotal.toStringAsFixed(2)} شيكل';
      await debtProvider.addOrUpdateSupplierDebt(
        supplierName,
        linkedTotal,
        note,
        items: linkedItems,
      );
    }

    if (!mounted) return;

    // NEW: offer to print barcode labels for every product in this
    // order, each with its own quantity as copies - same confirmation
    // pattern and same underlying print call as the single-product "Add
    // Product" flow, just looped across the whole batch. Shown BEFORE
    // leaving this screen, so the person can review the summary snackbar
    // afterward without losing context.
    if (productsForPrinting.isNotEmpty) {
      await _promptPrintOrderBarcodes(productsForPrinting);
      if (!mounted) return;
    }

    final summaryParts = <String>[
      if (addedCount > 0) 'تمت إضافة $addedCount منتج جديد',
      if (mergedCount > 0) 'تم دمج $mergedCount منتج مع مخزون موجود',
      if (rejectedCount > 0) 'تم تجاهل $rejectedCount منتج بسبب تعارض الباركود',
      if (supplierName.isNotEmpty && linkedItems.isNotEmpty)
        'وتم ربط ${linkedTotal.toStringAsFixed(2)} شيكل كدين على "$supplierName"',
    ];

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summaryParts.join(' - ')),
        backgroundColor: rejectedCount > 0 ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // NEW: confirmation dialog asking whether to print barcodes for every
  // product just added in this order, with their respective quantities.
  Future<void> _promptPrintOrderBarcodes(List<Product> products) async {
    final int totalLabels = products.fold<int>(0, (sum, p) => sum + p.stockQuantity);

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
          'هل تريد طباعة باركود لجميع المنتجات المضافة بكمياتها؟\n'
          'سيتم طباعة $totalLabels ملصق لعدد ${products.length} صنف.',
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

    await _printOrderLabels(products);
  }

  // NEW: prints labels for every product in the order, one at a time,
  // each with copies == that product's quantity in this order - the
  // exact same BarcodePrintService.printProductLabels call the
  // single-product "Add Product" flow uses, just looped across the
  // whole batch under one shared progress indicator.
  Future<void> _printOrderLabels(List<Product> products) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    bool anyFailure = false;
    Object? error;

    try {
      for (final product in products) {
        final ok = await BarcodePrintService.printProductLabels(
          context: context,
          product: product,
          copies: product.stockQuantity,
        );
        if (!ok) anyFailure = true;
      }
    } catch (e) {
      error = e;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close the progress dialog

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الطباعة: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (anyFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إلغاء أو فشل جزء من عملية الطباعة لبعض المنتجات'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال جميع ملصقات الباركود إلى الطابعة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _headerCell(String label, double width, {bool required = false}) {
    return SizedBox(
      width: width,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.black87),
          children: [
            TextSpan(text: label),
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _textCell(
    TextEditingController controller,
    double width, {
    String? hint,
    bool numeric = false,
    bool decimal = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: numeric
            ? (decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number)
            : TextInputType.text,
        inputFormatters: numeric
            ? (decimal
                ? [_DecimalTextInputFormatter()]
                : [FilteringTextInputFormatter.digitsOnly])
            : null,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.playlist_add_outlined),
            SizedBox(width: 10),
            Text('إضافة طلبية جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront_outlined, size: 18, color: Colors.indigo.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'ربط الطلبية بتاجر/مورد (اختياري)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _supplierController,
                    decoration: InputDecoration(
                      labelText: 'اسم التاجر',
                      hintText: 'اترك الحقل فارغاً لتجاهل ربط الدين',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('أصناف الطلبية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة صف'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _tableWidth,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _headerCell('الباركود (اختياري)', _wBarcode),
                          const SizedBox(width: _cellGap),
                          _headerCell('اسم المنتج', _wName, required: true),
                          const SizedBox(width: _cellGap),
                          _headerCell('سعر الشراء', _wCost, required: true),
                          const SizedBox(width: _cellGap),
                          // CHANGED: سعر البيع is now a required column,
                          // marked with a red asterisk like the other
                          // mandatory columns.
                          _headerCell('سعر البيع', _wSell, required: true),
                          const SizedBox(width: _cellGap),
                          // NEW: optional per-row wholesale price.
                          _headerCell('سعر الجملة (اختياري)', _wWholesale),
                          const SizedBox(width: _cellGap),
                          _headerCell('الكمية', _wQty, required: true),
                          const SizedBox(width: _cellGap),
                          _headerCell('القسم (اختياري)', _wCategory),
                          const SizedBox(width: _cellGap),
                          _headerCell('الرف (اختياري)', _wShelf),
                          const SizedBox(width: _cellGap),
                          SizedBox(width: _wDelete),
                        ],
                      ),
                      const Divider(height: 20),
                      ...List.generate(_rows.length, (index) {
                        final row = _rows[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              _textCell(row.barcodeCtrl, _wBarcode, hint: 'اختياري'),
                              const SizedBox(width: _cellGap),
                              _textCell(row.nameCtrl, _wName, hint: 'اسم المنتج'),
                              const SizedBox(width: _cellGap),
                              _textCell(row.costCtrl, _wCost, numeric: true, decimal: true, hint: '0.00'),
                              const SizedBox(width: _cellGap),
                              // CHANGED: hint now reads "مطلوب" instead
                              // of "اختياري" - the field is validated as
                              // mandatory in _save() above.
                              _textCell(row.sellCtrl, _wSell, numeric: true, decimal: true, hint: 'مطلوب'),
                              const SizedBox(width: _cellGap),
                              _textCell(row.wholesaleCtrl, _wWholesale, numeric: true, decimal: true, hint: 'اختياري'),
                              const SizedBox(width: _cellGap),
                              _textCell(row.qtyCtrl, _wQty, numeric: true, hint: '0'),
                              const SizedBox(width: _cellGap),
                              _textCell(row.categoryCtrl, _wCategory, hint: 'اختياري'),
                              const SizedBox(width: _cellGap),
                              _textCell(row.shelfCtrl, _wShelf, hint: 'اختياري'),
                              const SizedBox(width: _cellGap),
                              SizedBox(
                                width: _wDelete,
                                child: IconButton(
                                  tooltip: 'حذف الصف',
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'إجمالي تكلفة الطلبية',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_totalCost.toStringAsFixed(2)} شيكل',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ الطلبية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}