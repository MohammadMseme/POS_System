import 'package:hive/hive.dart';

part 'sale.g.dart';

@HiveType(typeId: 7)
enum SaleSource {
  @HiveField(0)
  pos,

  @HiveField(1)
  debtPayment,
}

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
  double discountPerUnit;

  // NEW: a SNAPSHOT of the product's category name at the moment this
  // sale was made - not a live reference to the Product. This is
  // deliberate: a historical sales record (shown in the Inventory/الجرد
  // page) must always reflect what was true when the sale happened, even
  // if the product's category is edited or the product itself is later
  // deleted. Optional - stays null and is never rendered when the
  // product had no category set at sale time.
  @HiveField(5)
  String? category;

  SaleItem({
    required this.name,
    required this.costPrice,
    required this.sellPrice,
    required this.quantity,
    this.discountPerUnit = 0.0,
    this.category,
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

  @HiveField(4)
  SaleSource source;

  Sale({
    required this.items,
    required this.totalAmount,
    required this.totalProfit,
    required this.createdAt,
    this.source = SaleSource.pos,
  });
}