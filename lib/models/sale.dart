import 'package:hive/hive.dart';

part 'sale.g.dart';

@HiveType(typeId: 7)
enum SaleSource {
  @HiveField(0)
  pos,

  /// A cash installment received against a customer debt. Since the
  /// credit-sale rework these records carry NO items - only money
  /// (totalAmount = the amount paid, totalProfit = the part of it that
  /// was profit after the debt's capital was fully recovered). Records
  /// written by older versions may still carry proportional items.
  @HiveField(1)
  debtPayment,

  /// NEW: written once, at the moment a credit sale is FULLY paid off.
  /// Carries the debt's items so they appear in the sales records exactly
  /// like a cash sale. Its totalAmount/totalProfit are always 0 because
  /// the money was already counted by the debtPayment installments -
  /// this record exists for item history only and never double-counts.
  @HiveField(2)
  debtSettlement,
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

  /// NEW: Hive key of the Debt this record belongs to (only for
  /// debtPayment / debtSettlement records created after the credit-sale
  /// rework). Lets the app find every installment of a debt, e.g. to
  /// reverse them all when a settled credit sale is deleted. Null for
  /// cash sales and for records written by older versions.
  @HiveField(5)
  int? debtKey;

  Sale({
    required this.items,
    required this.totalAmount,
    required this.totalProfit,
    required this.createdAt,
    this.source = SaleSource.pos,
    this.debtKey,
  });

  bool get isDebtSettlement => source == SaleSource.debtSettlement;
  bool get isDebtPayment => source == SaleSource.debtPayment;
}
