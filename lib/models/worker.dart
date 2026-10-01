import 'package:hive/hive.dart';

part 'worker.g.dart';

@HiveType(typeId: 8)
class WorkerPayment {
  @HiveField(0)
  double amount;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String note;

  WorkerPayment({
    required this.amount,
    required this.date,
    this.note = '',
  });
}

@HiveType(typeId: 9)
class Worker extends HiveObject {
  @HiveField(0)
  String name;

  // Recorded automatically when the worker is added - never edited
  // afterwards, so it always reflects the true addition date.
  @HiveField(1)
  DateTime addedAt;

  @HiveField(2)
  List<WorkerPayment> payments;

  Worker({
    required this.name,
    required this.addedAt,
    List<WorkerPayment>? payments,
  }) : payments = payments ?? [];

  /// Derived, non-persisted total. Computed on read from [payments], so
  /// it stays correct automatically as payments are added - nothing here
  /// needs to be kept manually in sync.
  double get totalPaid => payments.fold(0.0, (sum, p) => sum + p.amount);
}