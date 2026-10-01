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

  Product({
    this.barcode = '',
    required this.name,
    required this.costPrice,
    required this.sellPrice,
    required this.stockQuantity,
    DateTime? createdAt,
    this.category,
    this.shelfNumber,
  }) : createdAt = createdAt ?? DateTime.now();
}