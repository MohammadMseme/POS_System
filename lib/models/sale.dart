import 'package:hive/hive.dart';

part 'sale.g.dart';

@HiveType(typeId: 1)
class SaleItem {
  @HiveField(0)
  String name;

  @HiveField(1)
  double costPrice;

  @HiveField(2)
  double sellPrice;

  @HiveField(3)
  int quantity;

  @HiveField(4)
  double discount;

  SaleItem({
    required this.name,
    required this.costPrice,
    required this.sellPrice,
    required this.quantity,
    this.discount = 0.0,
  });
}

@HiveType(typeId: 2)
class Sale extends HiveObject {
  @HiveField(0)
  List<SaleItem> items;

  @HiveField(1)
  double totalAmount;

  @HiveField(2)
  double totalProfit;

  @HiveField(3)
  DateTime createdAt;

  Sale({
    required this.items,
    required this.totalAmount,
    required this.totalProfit,
    required this.createdAt,
  });
}