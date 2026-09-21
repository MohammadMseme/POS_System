import 'package:hive/hive.dart';

part 'supplier.g.dart';

@HiveType(typeId: 3)
class SupplierPayment {
  @HiveField(0)
  double amountPaid;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String notes;

  SupplierPayment({
    required this.amountPaid,
    required this.date,
    this.notes = '',
  });
}

@HiveType(typeId: 4)
class Supplier extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String notes;

  @HiveField(2)
  List<SupplierPayment> payments;

  @HiveField(3)
  double remainingAmount;

  Supplier({
    required this.name,
    this.notes = '',
    List<SupplierPayment>? payments,
    this.remainingAmount = 0.0,
  }) : payments = payments ?? [];
}