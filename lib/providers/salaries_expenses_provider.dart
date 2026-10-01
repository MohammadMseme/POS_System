import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/worker.dart';
import '../models/expense.dart';

/// Manages the "رواتب ومفرقات" (Salaries & Expenses) data: workers and
/// their payments/advances, plus general business expenses.
///
/// Both boxes are opened by HiveService.init() before this provider is
/// ever constructed (see main.dart), so `Hive.box<T>(...)` below is safe
/// to call directly - same pattern as DebtSupplierProvider.
class SalariesExpensesProvider extends ChangeNotifier {
  Box<Worker>? _workerBox;
  Box<Expense>? _expenseBox;

  List<Worker> workers = [];
  List<Expense> expenses = [];

  SalariesExpensesProvider() {
    _init();
  }

  Future<void> _init() async {
    _workerBox = Hive.isBoxOpen('workers')
        ? Hive.box<Worker>('workers')
        : await Hive.openBox<Worker>('workers');

    _expenseBox = Hive.isBoxOpen('expenses')
        ? Hive.box<Expense>('expenses')
        : await Hive.openBox<Expense>('expenses');

    loadWorkers();
    loadExpenses();
  }

  void loadWorkers() {
    if (_workerBox != null && _workerBox!.isOpen) {
      workers = _workerBox!.values.toList();
      notifyListeners();
    }
  }

  void loadExpenses() {
    if (_expenseBox != null && _expenseBox!.isOpen) {
      expenses = _expenseBox!.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }
  }

  /// Adds a new worker/employee. `addedAt` is stamped automatically at
  /// creation time and is never mutated afterwards, so it always
  /// reflects the true date the worker was added.
  Future<void> addWorker(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_workerBox != null && _workerBox!.isOpen) {
      final worker = Worker(name: trimmed, addedAt: DateTime.now());
      await _workerBox!.add(worker);
      loadWorkers();
    }
  }

  /// Records a payment/advance for a specific [worker], with an optional
  /// note. Operates on the HiveObject directly (like
  /// DebtSupplierProvider.addSupplierPayment) so it is always correct
  /// regardless of list ordering or reloads.
  Future<void> addWorkerPayment(Worker worker, double amount, String note) async {
    if (amount <= 0) return;
    worker.payments.add(
      WorkerPayment(amount: amount, date: DateTime.now(), note: note.trim()),
    );
    await worker.save();
    loadWorkers();
  }

  /// Records a general business expense, with an optional note.
  Future<void> addExpense(double amount, String note) async {
    if (amount <= 0) return;
    if (_expenseBox != null && _expenseBox!.isOpen) {
      final expense = Expense(amount: amount, date: DateTime.now(), note: note.trim());
      await _expenseBox!.add(expense);
      loadExpenses();
    }
  }

  double get totalWorkerPayments =>
      workers.fold(0.0, (sum, w) => sum + w.totalPaid);

  double get totalExpenses =>
      expenses.fold(0.0, (sum, e) => sum + e.amount);
}