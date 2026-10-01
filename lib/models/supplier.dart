import 'package:hive/hive.dart';
import 'supplier_entry.dart';

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

  // Mirrors Debt.isPaid. A fully-paid supplier account used to be
  // deleted outright the moment remainingAmount hit zero, which silently
  // destroyed the supplier's identity and entire payment history. Now it
  // is archived instead - hidden from the active list, but never lost.
  @HiveField(4)
  bool isPaid;

  // NEW: every distinct debt addition (a whole bulk order, or a single
  // product/manual debt) is recorded here as its own entry, instead of
  // being flattened into the single free-text `notes` string above.
  // This is what lets the UI show "طلبية رقم 1", "طلبية رقم 2", etc.,
  // each independently expandable to its own item table. Appended as a
  // new Hive field index (5) AFTER all existing ones, so supplier
  // records written before this change simply lack this key in their
  // on-disk field map and deserialize safely to an empty list - no
  // migration step needed, no risk to existing data.
  @HiveField(5)
  List<SupplierEntry> entries;

  Supplier({
    required this.name,
    this.notes = '',
    List<SupplierPayment>? payments,
    this.remainingAmount = 0.0,
    this.isPaid = false,
    List<SupplierEntry>? entries,
  })  : payments = payments ?? [],
        entries = entries ?? [];

  // Derived, non-persisted stats for the supplier detail view. Nothing
  // here is written to Hive - they're computed on read from the
  // `payments` list and current `remainingAmount`, so they stay correct
  // automatically as payments are added, with no extra field to keep in
  // sync.
  double get totalPaid =>
      payments.fold(0.0, (sum, p) => sum + p.amountPaid);

  double get totalEverOwed => totalPaid + remainingAmount;
}