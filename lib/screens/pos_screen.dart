import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../providers/product_provider.dart';
import '../providers/debt_supplier_provider.dart';

/// Restricts a text field to a non-negative decimal number with at most
/// two decimal places (e.g. "5", "5.5", "10.25"), rejecting anything
/// else - including a second decimal point, letters, or a 3rd decimal
/// digit - as the user types, instead of accepting bad input and
/// failing silently on parse.
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

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _processSearchOrBarcode(
    String value,
    ProductProvider productProvider,
    PosProvider posProvider,
  ) {
    final query = value.trim();
    if (query.isEmpty) return;

    try {
      final exactBarcodeMatch = productProvider.products.firstWhere(
        (p) => p.barcode.toLowerCase() == query.toLowerCase(),
      );

      _addToCartAndReset(exactBarcodeMatch, posProvider);
      return;
    } catch (_) {}

    final matchingProducts = productProvider.products
        .where(
          (p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.barcode.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    if (matchingProducts.length == 1) {
      _addToCartAndReset(matchingProducts.first, posProvider);
    } else if (matchingProducts.length > 1) {
      _showProductOptionsDialog(
        context,
        matchingProducts,
        posProvider,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على أي منتج بهذا الاسم أو الرمز'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addToCartAndReset(product, PosProvider posProvider) {
    String? warning = posProvider.addToCart(product);

    if (warning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }

    _searchController.clear();
    _searchFocusNode.requestFocus();
  }

  void _showProductOptionsDialog(
    BuildContext context,
    List products,
    PosProvider posProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'اختر المنتج المطابق',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 420,
          height: 300,
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: Colors.grey.shade100,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'الباركود: ${p.barcode}  •  السعر: ${p.sellPrice} شيكل',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addToCartAndReset(p, posProvider);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _showDebtDialog(
    BuildContext context,
    PosProvider posProvider,
  ) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Row(
          children: [
            Icon(
              Icons.assignment_ind_outlined,
              color: Colors.orange.shade800,
            ),
            const SizedBox(width: 10),
            const Text(
              'تسجيل فاتورة دين / آجل',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'المبلغ الإجمالي للدين',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${posProvider.totalAmount.toStringAsFixed(2)} شيكل',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'اسم الزبون المدين',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
            ),
            icon: const Icon(Icons.check),
            label: const Text('تأكيد الدين'),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              // Captured before the async gap, while both contexts are
              // still guaranteed valid.
              final debtProvider = Provider.of<DebtSupplierProvider>(
                context,
                listen: false,
              );
              final customerName = nameController.text.trim();

              bool success = false;
              Object? error;

              try {
                success = await posProvider.completeSaleAsDebt(
                  customerName,
                  debtProvider,
                );
              } catch (e) {
                error = e;
              }

              // FIX (use_build_context_synchronously): after the await
              // above, TWO different BuildContexts are used below - the
              // dialog's own `ctx` (to pop it) and the screen's `context`
              // (to show a SnackBar on the screen underneath). Each one
              // needs its OWN `.mounted` check immediately before use;
              // checking only `ctx.mounted` does not guarantee `context`
              // is still safe to use, and vice-versa.
              if (!ctx.mounted) return;

              if (success) {
                Navigator.pop(ctx);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تم تسجيل الدين بنجاح وتحويل الفاتورة لصفحة الديون',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (error != null) {
                Navigator.pop(ctx);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم تسجيل الدين، لكن حدث خطأ أثناء تحديث المخزون: $error',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                // Insufficient stock: keep the dialog open so the user
                // can adjust the cart, exactly as before - just surface
                // the message.
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تعذر إتمام العملية: الكمية المطلوبة لم تعد متوفرة بالكامل في المخزون',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    ).then((_) => nameController.dispose());
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 45,
            child: Center(
              child: Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.grey,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              'الإجمالي الصافي',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              'الخصم الإجمالي',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              'الكمية',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              'سعر القطعة ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'اسم المنتج            ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW (inventory stock validation): centralizes every place quantity
  // can change (+ button, - button, manual typing) so all three paths
  // get the exact same real-time stock check and the exact same
  // user-facing warning, instead of the increment button silently doing
  // nothing when stock ran out.
  void _applyQuantityChange(PosProvider posProvider, int index, int newQty) {
    final warning = posProvider.updateQuantity(index, newQty);
    if (warning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildCartItem(
    BuildContext context,
    int index,
    CartItem item,
    PosProvider posProvider,
  ) {
    final double grossTotal = item.sellPrice * item.quantity;
    final double totalDiscountForThisItem = item.lineDiscountTotal;
    final double itemTotal = grossTotal - totalDiscountForThisItem;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: IconButton(
              tooltip: 'حذف المنتج',
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              onPressed: () {
                posProvider.removeItem(index);
              },
            ),
          ),

          SizedBox(
            width: 110,
            child: Text(
              '${itemTotal.toStringAsFixed(2)} شيكل',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SizedBox(
            width: 105,
            child: TextFormField(
              key: ValueKey('discount_${item.product.key}'),
              initialValue: totalDiscountForThisItem > 0
                  ? totalDiscountForThisItem.toStringAsFixed(2)
                  : '',
              // FIX (decimal discount input): the discount is a currency
              // amount, so it must accept fractional shekel values (e.g.
              // 5.5, 10.25). `TextInputType.number` alone shows an
              // integer-only keypad on many devices, and without an
              // input formatter the field would also happily accept
              // garbage like "5..5" that `double.tryParse` silently
              // turns into 0.0 further down. `numberWithOptions(decimal:
              // true)` gives the user a decimal-point key, and
              // `_DecimalTextInputFormatter` keeps what they type always
              // parseable, capped at 2 decimal places to match the
              // `toStringAsFixed(2)` display everywhere else in the app.
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_DecimalTextInputFormatter()],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'الخصم',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) {
                double totalDiscountInput =
                    double.tryParse(val) ?? 0.0;

                double discountPerUnit =
                    item.quantity > 0
                        ? (totalDiscountInput / item.quantity)
                        : 0.0;

                if ((item.sellPrice - discountPerUnit) <
                    item.product.costPrice) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تنبيه: سعر البيع بعد توزيع الخصم أقل من سعر التكلفة (البيع بخسارة)!',
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                posProvider.updateDiscount(
                  index,
                  totalDiscountInput,
                );
              },
            ),
          ),

          SizedBox(
            width: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'تقليل الكمية',
                  icon: const Icon(
                    Icons.remove_circle_outline,
                  ),
                  onPressed: () {
                    if (item.quantity > 1) {
                      // Decreasing can never exceed stock, but we still
                      // route through the same validated call for
                      // consistency - it will simply return null here.
                      _applyQuantityChange(
                        posProvider,
                        index,
                        item.quantity - 1,
                      );
                    }
                  },
                ),
                SizedBox(
                  width: 45,
                  child: TextFormField(
                    key: ValueKey(
                      'qty_${item.product.key}_${item.quantity}',
                    ),
                    initialValue: '${item.quantity}',
                    keyboardType: TextInputType.number,
                    // Quantity is always a whole number of units - block
                    // anything but digits at the input level rather than
                    // relying solely on int.tryParse() after the fact.
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 2,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) {
                      int? q = int.tryParse(val);

                      if (q != null && q > 0) {
                        _applyQuantityChange(posProvider, index, q);
                      }
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'زيادة الكمية',
                  icon: const Icon(
                    Icons.add_circle_outline,
                  ),
                  onPressed: () {
                    _applyQuantityChange(
                      posProvider,
                      index,
                      item.quantity + 1,
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(
            width: 105,
            child: Text(
              '${item.sellPrice.toStringAsFixed(2)} شيكل',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final productProvider =
        Provider.of<ProductProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(
              Icons.point_of_sale,
              color: Colors.blue,
            ),
            SizedBox(width: 10),
            Text(
              'نقطة البيع',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (posProvider.cart.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(
                vertical: 9,
                horizontal: 8,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '${posProvider.cart.length} منتج',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'تفريغ السلة',
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.red,
            ),
            onPressed: () => posProvider.clearCart(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText:
                            'امسح الباركود أو اكتب اسم المنتج',
                        hintText:
                            'الباركود / اسم المنتج',
                        prefixIcon: const Icon(
                          Icons.qr_code_scanner,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchFocusNode.requestFocus();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 14,
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                      onSubmitted: (value) {
                        _processSearchOrBarcode(
                          value,
                          productProvider,
                          posProvider,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withValues(alpha: 0.035),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildCartHeader(),
                          const SizedBox(height: 10),

                          Expanded(
                            child: posProvider.cart.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.blue.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons
                                                .shopping_cart_outlined,
                                            size: 48,
                                            color:
                                                Colors.blue.shade400,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'السلة فارغة',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'امسح الباركود أو ابحث عن منتج لإضافته',
                                          style: TextStyle(
                                            color:
                                                Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount:
                                        posProvider.cart.length,
                                    itemBuilder:
                                        (context, index) {
                                      final item =
                                          posProvider.cart[index];

                                      return _buildCartItem(
                                        context,
                                        index,
                                        item,
                                        posProvider,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            width: 320,
            margin: const EdgeInsets.only(
              top: 18,
              right: 18,
              bottom: 18,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ملخص الفاتورة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                const Spacer(),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'المبلغ الإجمالي',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        child: Text(
                          '${posProvider.totalAmount.toStringAsFixed(2)} شيكل',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'عدد المنتجات',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        '${posProvider.cart.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 24,
                  ),
                  label: const Text(
                    'إتمام البيع (كاش)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: posProvider.cart.isEmpty
                      ? null
                      : () async {
                          bool success = false;
                          Object? error;

                          try {
                            success =
                                await posProvider.completeSale();
                          } catch (e) {
                            error = e;
                          }

                          // FIX (use_build_context_synchronously):
                          // `mounted` (this State's flag) guards every
                          // use of `context` below, immediately after
                          // the async gap.
                          if (!mounted) return;

                          if (success) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تمت عملية البيع كاش بنجاح',
                                ),
                                backgroundColor:
                                    Colors.green,
                              ),
                            );
                          } else if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تم تسجيل البيع، لكن حدث خطأ أثناء تحديث المخزون: $error',
                                ),
                                backgroundColor:
                                    Colors.orange,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تعذر إتمام العملية: الكمية المطلوبة لم تعد متوفرة بالكامل في المخزون',
                                ),
                                backgroundColor:
                                    Colors.red,
                              ),
                            );
                          }
                        },
                ),

                const SizedBox(height: 10),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.assignment_ind_outlined,
                    size: 24,
                  ),
                  label: const Text(
                    'تسجيل بالدين (آجل)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: posProvider.cart.isEmpty
                      ? null
                      : () => _showDebtDialog(
                            context,
                            posProvider,
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}