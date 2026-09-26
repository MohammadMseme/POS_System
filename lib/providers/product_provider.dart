import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';

class ProductProvider extends ChangeNotifier {
  Box<Product> get _productBox => Hive.box<Product>('products');

  // FIX (instant real-time updates): previously this provider only ever
  // called notifyListeners() from its own methods (addProductWithRules,
  // updateProduct, deleteProduct). A POS cash sale decrements stock via
  // `item.product.save()` directly on the HiveObject in PosProvider,
  // completely bypassing this provider - so ProductsScreen never learned
  // anything changed until something unrelated forced a rebuild.
  //
  // Listening directly to the 'products' Hive box (same pattern as
  // InventoryProvider) decouples this from whichever provider performs
  // the write: any save/put/delete on the box - stock decrement, a new
  // product, an edit, a debt-payment restocking a return, anything added
  // later - now propagates here automatically.
  late final ValueListenable<Box<Product>> _productListenable;

  ProductProvider() {
    _productListenable = _productBox.listenable();
    _productListenable.addListener(_handleDataChanged);
  }

  void _handleDataChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _productListenable.removeListener(_handleDataChanged);
    super.dispose();
  }

  List<Product> get products => _productBox.values.toList();

  // إضافة منتج مع التحقق من شروط الاسم والباركود
  String addProductWithRules(Product newProduct) {
    String trimmedNewName = newProduct.name.trim().toLowerCase();
    String trimmedNewBarcode = newProduct.barcode.trim();

    // 1. البحث عما إذا كان الباركود موجوداً مسبقاً لصنف آخر
    Product? existingByBarcode;
    try {
      existingByBarcode = _productBox.values.firstWhere(
        (p) => p.barcode.trim() == trimmedNewBarcode,
      );
    } catch (_) {
      existingByBarcode = null;
    }

    // 2. البحث عما إذا كان اسم المنتج موجوداً مسبقاً
    Product? existingByName;
    try {
      existingByName = _productBox.values.firstWhere(
        (p) => p.name.trim().toLowerCase() == trimmedNewName,
      );
    } catch (_) {
      existingByName = null;
    }

    // الحالة الأولى: الباركود موجود مسبقاً ولكن لصنف آخر (اسم مختلف) -> رفض الإضافة
    if (existingByBarcode != null && existingByBarcode.name.trim().toLowerCase() != trimmedNewName) {
      return 'rejected_barcode_conflict';
    }

    // الحالة الثانية: تطابق الاسم والباركود معاً، أو تطابق الاسم فقط لصنف موجود -> زيادة الكمية
    if (existingByName != null) {
      existingByName.stockQuantity += newProduct.stockQuantity;
      existingByName.save();
      return 'updated_existing';
    }

    // الحالة الثالثة: الباركود موجود مسبقاً (لنفس الصنف تماماً لأن الاسم متطابق وتم فحصه بالاعلى)
    if (existingByBarcode != null) {
      existingByBarcode.stockQuantity += newProduct.stockQuantity;
      existingByBarcode.save();
      return 'updated_existing';
    }

    // إذا كان صنفاً جديداً كلياً -> إضافته بشكل طبيعي، مفتاحاً بالباركود
    _productBox.put(trimmedNewBarcode, newProduct);
    return 'added_new';
  }

  /// Updates an existing product's fields.
  ///
  /// Products are stored in the Hive box keyed by their barcode (see
  /// [addProductWithRules]). If the barcode itself is edited, the box
  /// entry is re-keyed atomically so the box key never drifts out of
  /// sync with `product.barcode` (which would silently break
  /// [getByBarcode] for that product).
  ///
  /// Returns 'rejected_barcode_conflict' if the new barcode already
  /// belongs to a different product, or 'ok' on success.
  Future<String> updateProduct(
    Product product, {
    required String oldBarcode,
    required String barcode,
    required String name,
    required double costPrice,
    required double sellPrice,
    required int stockQuantity,
  }) async {
    final trimmedOldKey = oldBarcode.trim();
    final trimmedNewKey = barcode.trim();
    final barcodeChanged = trimmedNewKey != trimmedOldKey;

    if (barcodeChanged) {
      final conflict = _productBox.get(trimmedNewKey);
      if (conflict != null && conflict.key != product.key) {
        return 'rejected_barcode_conflict';
      }
    }

    product.barcode = barcode;
    product.name = name;
    product.costPrice = costPrice;
    product.sellPrice = sellPrice;
    product.stockQuantity = stockQuantity;

    if (barcodeChanged) {
      await product.delete();
      await _productBox.put(trimmedNewKey, product);
    } else {
      await product.save();
    }

    return 'ok';
  }

  void deleteProduct(Product product) {
    product.delete();
  }

  void refreshProducts() {
    notifyListeners();
  }

  Product? getByBarcode(String barcode) {
    return _productBox.get(barcode.trim());
  }
}