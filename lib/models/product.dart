import 'package:hive/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
class Product extends HiveObject {
  @HiveField(0)
  String barcode; // قد يكون فارغاً إذا لم يحوي باركود

  @HiveField(1)
  String name;

  @HiveField(2)
  double costPrice;

  @HiveField(3)
  double sellPrice;

  @HiveField(4)
  int stockQuantity;

  @HiveField(5)
  DateTime createdAt; // <-- أضفنا حقل التاريخ لمعرفة متى تم شراؤه وإضافته

  // NEW (optional fields): both are completely optional. If left empty
  // when adding/editing a product, they are stored as null and simply
  // never rendered anywhere in the UI - no placeholder text, no empty
  // chips. Appended as new Hive field indices (6, 7) AFTER all existing
  // ones, so records written before this change simply lack these keys
  // in their on-disk field map and deserialize safely to null - no
  // migration step needed, no risk to existing data.
  @HiveField(6)
  String? category; // اسم القسم

  @HiveField(7)
  String? shelfNumber; // رقم الرف - نص حر (أرقام/حروف/رموز مثل A-1, B#2)

  // NEW: optional wholesale price (سعر الجملة). STRICTLY an informational
  // reference for the seller (to help decide a manual discount). It is
  // never read by any financial calculation - totals, profit, cost of
  // goods and debt capital recovery all keep using costPrice/sellPrice
  // only. Appended as a new field index, so older records read it as
  // null (= not set, never displayed).
  @HiveField(8)
  double? wholesalePrice;

  Product({
    this.barcode = '',
    required this.name,
    required this.costPrice,
    required this.sellPrice,
    required this.stockQuantity,
    DateTime? createdAt,
    this.category,
    this.shelfNumber,
    this.wholesalePrice,
  }) : createdAt = createdAt ?? DateTime.now();

  /// True only when a usable wholesale price has been entered.
  bool get hasWholesalePrice => wholesalePrice != null && wholesalePrice! > 0;
}
