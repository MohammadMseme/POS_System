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
  //
  // FIX (data integrity): an empty barcode used to be treated as a real,
  // matchable barcode value. That meant:
  //   1. Two unrelated products both left "without a barcode" could
  //      falsely collide as a "barcode conflict" against each other.
  //   2. If ever written to the box under an empty key, a second
  //      no-barcode product would silently overwrite the first one in
  //      Hive (same key == same record).
  // Barcode matching now only runs when a barcode is actually present,
  // and the Hive box key always falls back to a unique value instead of
  // an empty string.
  String addProductWithRules(Product newProduct) {
    String trimmedNewName = newProduct.name.trim().toLowerCase();
    String trimmedNewBarcode = newProduct.barcode.trim();

    // 1. البحث عما إذا كان الباركود موجوداً مسبقاً لصنف آخر (فقط إن كان
    // هناك باركود فعلي - "بدون باركود" لا يجب أن تُعتبر قيمة مطابقة).
    Product? existingByBarcode;
    if (trimmedNewBarcode.isNotEmpty) {
      try {
        existingByBarcode = _productBox.values.firstWhere(
          (p) => p.barcode.trim() == trimmedNewBarcode,
        );
      } catch (_) {
        existingByBarcode = null;
      }
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
      // NEW: if a category/shelf number is supplied on this merge, keep
      // the existing record up to date with it. If left empty on this
      // particular add, the existing product's previously-saved
      // category/shelf (if any) is left untouched - never wiped out by
      // a later stock top-up that didn't mention them.
      if (newProduct.category != null && newProduct.category!.trim().isNotEmpty) {
        existingByName.category = newProduct.category!.trim();
      }
      if (newProduct.shelfNumber != null && newProduct.shelfNumber!.trim().isNotEmpty) {
        existingByName.shelfNumber = newProduct.shelfNumber!.trim();
      }
      existingByName.save();
      return 'updated_existing';
    }

    // الحالة الثالثة: الباركود موجود مسبقاً (لنفس الصنف تماماً لأن الاسم متطابق وتم فحصه بالاعلى)
    if (existingByBarcode != null) {
      existingByBarcode.stockQuantity += newProduct.stockQuantity;
      if (newProduct.category != null && newProduct.category!.trim().isNotEmpty) {
        existingByBarcode.category = newProduct.category!.trim();
      }
      if (newProduct.shelfNumber != null && newProduct.shelfNumber!.trim().isNotEmpty) {
        existingByBarcode.shelfNumber = newProduct.shelfNumber!.trim();
      }
      existingByBarcode.save();
      return 'updated_existing';
    }

    // إذا كان صنفاً جديداً كلياً -> إضافته بشكل طبيعي، مفتاحاً بالباركود.
    // FIX: never key the box entry with an empty string - fall back to a
    // unique key so a future "no barcode" product can never silently
    // overwrite this one.
    final String boxKey = trimmedNewBarcode.isNotEmpty
        ? trimmedNewBarcode
        : DateTime.now().millisecondsSinceEpoch.toString();
    _productBox.put(boxKey, newProduct);
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
  /// [category] and [shelfNumber] are optional (اسم القسم / رقم الرف).
  /// Pass null (or an empty/whitespace string, which the caller
  /// normalizes to null before calling this) to clear a previously-set
  /// value; pass a non-empty string to set/replace it.
  ///
  /// FIX (data integrity): the Edit dialog, unlike the Add dialog, does
  /// not substitute a placeholder when the barcode field is cleared - it
  /// used to pass an empty string straight through, which re-keyed the
  /// product's box entry to '' and risked a second edited product
  /// silently overwriting it later under the same empty key. The new
  /// barcode is now guaranteed non-empty (falls back to a unique
  /// timestamp, exactly like the Add flow), and the stored `barcode`
  /// field and the box key are always kept identical (trimmed).
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
    String? category,
    String? shelfNumber,
  }) async {
    final trimmedOldKey = oldBarcode.trim();
    final rawNewBarcode = barcode.trim();
    final trimmedNewKey = rawNewBarcode.isNotEmpty
        ? rawNewBarcode
        : DateTime.now().millisecondsSinceEpoch.toString();
    final barcodeChanged = trimmedNewKey != trimmedOldKey;

    if (barcodeChanged) {
      final conflict = _productBox.get(trimmedNewKey);
      if (conflict != null && conflict.key != product.key) {
        return 'rejected_barcode_conflict';
      }
    }

    product.barcode = trimmedNewKey;
    product.name = name;
    product.costPrice = costPrice;
    product.sellPrice = sellPrice;
    product.stockQuantity = stockQuantity;
    product.category = category;
    product.shelfNumber = shelfNumber;

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