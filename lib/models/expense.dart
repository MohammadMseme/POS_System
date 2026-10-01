import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 10)
class Expense extends HiveObject {
  @HiveField(0)
  double amount;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String note;

  Expense({
    required this.amount,
    required this.date,
    this.note = '',
  });
}