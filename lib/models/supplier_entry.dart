import 'package:hive/hive.dart';

part 'supplier_entry.g.dart';

/// One line item inside a bulk order (see [SupplierEntry.items]).
@HiveType(typeId: 11)
class SupplierOrderItem {
  @HiveField(0)
  String name;

  @HiveField(1)
  double costPrice;

  @HiveField(2)
  double sellPrice;

  @HiveField(3)
  int quantity;

  SupplierOrderItem({
    required this.name,
    required this.costPrice,
    required this.sellPrice,
    required this.quantity,
  });

  double get total => costPrice * quantity;
}

/// A single, distinct history record against a supplier: either a whole
/// bulk order (with [items] populated) or a plain single debt/product
/// addition (with [items] left null). Kept separate from [Supplier.notes]
/// (a legacy free-text field) so each addition stays cleanly organized
/// and individually expandable in the UI, instead of being flattened
/// into one long string.
@HiveType(typeId: 12)
class SupplierEntry {
  @HiveField(0)
  String title; // e.g. "طلبية رقم 1" أو "منتج: اسم المنتج" أو "دين إضافي"

  @HiveField(1)
  double amount;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  String note;

  // Present (non-null) for a bulk order so its table can be expanded and
  // reviewed later; left null for a plain single debt/product addition.
  @HiveField(4)
  List<SupplierOrderItem>? items;

  SupplierEntry({
    required this.title,
    required this.amount,
    required this.date,
    this.note = '',
    this.items,
  });
}