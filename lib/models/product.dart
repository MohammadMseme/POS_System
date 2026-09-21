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

  Product({
    this.barcode = '',
    required this.name,
    required this.costPrice,
    required this.sellPrice,
    required this.stockQuantity,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}