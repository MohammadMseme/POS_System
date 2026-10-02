import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/debt.dart';
import '../models/supplier.dart';
import '../models/supplier_entry.dart';
import '../models/sale.dart';

class DebtSupplierProvider extends ChangeNotifier {
  Box<Debt>? _debtBox;
  Box<Supplier>? _supplierBox;

  List<Debt> debts = [];
  List<Supplier> suppliers = [];

  /// Debts that are still outstanding. Paid-off debts are no longer
  /// deleted (see payCustomerDebt below) - they are archived via
  /// `isPaid = true` so history is preserved - so screens that only care
  /// about debts a customer still owes should read this instead of the
  /// raw `debts` list.
  List<Debt> get activeDebts => debts.where((d) => !d.isPaid).toList();

  /// Suppliers whose balance is still outstanding. Mirrors [activeDebts]:
  /// a supplier that has been fully paid is archived (isPaid = true)
  /// instead of removed from the box, so their record and full payment
  /// history stay recoverable.
  List<Supplier> get activeSuppliers =>
      suppliers.where((s) => !s.isPaid).toList();

  /// Fully-paid, archived supplier accounts. Exposed so the UI can offer
  /// a "show archived" view instead of that data being invisible forever.
  List<Supplier> get archivedSuppliers =>
      suppliers.where((s) => s.isPaid).toList();

  /// NEW: every debtor name ever registered (open accounts first), used by
  /// the POS autocomplete so a credit sale can be linked to an existing
  /// debtor account instead of accidentally creating a near-duplicate.
  List<DebtorSuggestion> searchDebtors(String query, {int limit = 8}) {
    final q = query.trim().toLowerCase();
    final Map<String, DebtorSuggestion> byName = {};

    for (final d in debts) {
      final display = d.customerName.trim();
      final norm = display.toLowerCase();
      if (norm.isEmpty) continue;
      if (q.isNotEmpty && !norm.contains(q)) continue;

      final current = byName[norm];
      final open = !d.isPaid;
      if (current == null) {
        byName[norm] = DebtorSuggestion(
          name: display,
          remaining: open ? d.remainingAmount : 0.0,
          hasOpenAccount: open,
        );
      } else {
        byName[norm] = DebtorSuggestion(
          // prefer the spelling of the open account
          name: open ? display : current.name,
          remaining: current.remaining + (open ? d.remainingAmount : 0.0),
          hasOpenAccount: current.hasOpenAccount || open,
        );
      }
    }

    final list = byName.values.toList()
      ..sort((a, b) {
        if (a.hasOpenAccount != b.hasOpenAccount) {
          return a.hasOpenAccount ? -1 : 1;
        }
        if (q.isNotEmpty) {
          final aStarts = a.name.toLowerCase().startsWith(q);
          final bStarts = b.name.toLowerCase().startsWith(q);
          if (aStarts != bStarts) return aStarts ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });

    return list.length > limit ? list.sublist(0, limit) : list;
  }

  /// Returns the open (unpaid) debt account for [name], if any.
  Debt? findOpenDebtByName(String name) {
    final norm = name.trim().toLowerCase();
    if (norm.isEmpty) return null;
    for (final d in debts) {
      if (!d.isPaid && d.customerName.trim().toLowerCase() == norm) return d;
    }
    return null;
  }

  DebtSupplierProvider() {
    _init();
  }

  Future<void> _init() async {
    _debtBox = Hive.isBoxOpen('debts')
        ? Hive.box<Debt>('debts')
        : await Hive.openBox<Debt>('debts');

    _supplierBox = Hive.isBoxOpen('suppliers')
        ? Hive.box<Supplier>('suppliers')
        : await Hive.openBox<Supplier>('suppliers');

    await _migrateDebtTracking();

    loadDebts();
    loadSuppliers();
  }

  /// Safety net for the start-up migration in HiveService.init (see
  /// [Debt.ensureTracking]). Only touches debts that still lack the
  /// capital-recovery counters, so normally it does nothing.
  Future<void> _migrateDebtTracking() async {
    if (_debtBox == null || !_debtBox!.isOpen) return;
    for (final debt in _debtBox!.values.toList()) {
      try {
        if (debt.ensureTracking()) await debt.save();
      } catch (e, stack) {
        debugPrint('[DebtSupplierProvider] Debt migration skipped: $e');
        debugPrint('$stack');
      }
    }
  }

  void loadDebts() {
    if (_debtBox != null && _debtBox!.isOpen) {
      debts = _debtBox!.values.toList();
      notifyListeners();
    }
  }

  void loadSuppliers() {
    if (_supplierBox != null && _supplierBox!.isOpen) {
      suppliers = _supplierBox!.values.toList();
      notifyListeners();
    }
  }

  // إضافة دين مع دمج الأصناف والأرباح في حال وجود نفس الزبون مسبقاً
  Future<void> addDebt(Debt newDebt) async {
    if (_debtBox != null && _debtBox!.isOpen) {
      Debt? existingDebt;
      try {
        // Only merge into an existing debt that is still outstanding.
        // A customer who fully paid off a previous debt (now archived
        // with isPaid = true) should get a fresh debt record, not have
        // their new purchase silently merged into old, closed history.
        existingDebt = _debtBox!.values.firstWhere(
          (d) =>
              !d.isPaid &&
              d.customerName.trim().toLowerCase() ==
                  newDebt.customerName.trim().toLowerCase(),
        );
      } catch (_) {
        existingDebt = null;
      }

      if (existingDebt != null) {
        existingDebt.ensureTracking();
        existingDebt.totalAmount += newDebt.totalAmount;
        existingDebt.remainingAmount += newDebt.remainingAmount;
        existingDebt.itemsTaken.addAll(newDebt.itemsTaken);
        // The newly merged items carry new cost: the account goes back to
        // "capital not recovered" until payments cover that cost too.
        existingDebt.saleItems.addAll(newDebt.saleItems);
        existingDebt.totalProfit += newDebt.totalProfit;
        await existingDebt.save();
      } else {
        newDebt.recoveredCapital ??= 0.0;
        newDebt.realizedProfit ??= 0.0;
        await _debtBox!.add(newDebt);
      }

      loadDebts();
    }
  }

  /// Registers a customer payment against [debt].
  ///
  /// NEW financial rules (credit sales / البيع بالدين):
  ///  * The paid amount is added to Total Sales (إجمالي المبيعات)
  ///    immediately, as an item-less `SaleSource.debtPayment` record.
  ///  * The money first recovers the cost price (رأس المال) of the items
  ///    sold on credit. Only after the full cost is recovered do further
  ///    payments count towards Net Profit.
  ///  * The items do NOT appear in the sales records while the debt is
  ///    open. When the balance is fully paid, ONE `debtSettlement` record
  ///    is written with all the items (amount/profit = 0, since the money
  ///    was already counted), so they appear just like a cash sale.
  ///  * A payment larger than the remaining balance is capped to it.
  ///
  /// Example: cost 100, price 200. Pay 50 -> sales +50, profit +0
  /// (capital 50/100). Pay 70 -> sales +70, profit +20 (capital
  /// recovered). Pay 80 -> sales +80, profit +80, debt settled.
  Future<DebtPaymentResult> payCustomerDebt(Debt debt, double amount) async {
    if (amount <= 0 || debt.isPaid || debt.remainingAmount <= 0) {
      return const DebtPaymentResult.none();
    }

    debt.ensureTracking();

    const double eps = 0.005;
    final double remainingBefore = debt.remainingAmount;
    final double applied = amount > remainingBefore ? remainingBefore : amount;
    final bool settles = (remainingBefore - applied) <= eps;
    final bool capitalWasRecovered = debt.isCapitalRecovered;

    // Only the part of the debt backed by real POS items is counted as
    // sales (a pure manual debt has no items and keeps old behavior).
    final double countedSoFar = debt.capitalRecovered + debt.profitRealized;
    double countable = debt.itemsSaleValue - countedSoFar;
    if (countable < 0) countable = 0;
    if (countable > applied) countable = applied;

    double toCapital;
    double toProfit;
    if (settles && debt.saleItems.isNotEmpty) {
      // Final payment: close the books exactly, including the (rare) case
      // of items sold below cost where the total profit is negative.
      toProfit = debt.totalProfit - debt.profitRealized;
      toCapital = countable - toProfit;
    } else {
      final double capitalNeeded = debt.capitalRemaining;
      toCapital = countable < capitalNeeded ? countable : capitalNeeded;
      toProfit = countable - toCapital;
    }

    final int? debtKey = debt.key is int ? debt.key as int : null;
    final salesBox = Hive.box<Sale>('sales');

    try {
      if (countable > 0 || toProfit.abs() > eps) {
        await salesBox.add(Sale(
          items: <SaleItem>[],
          totalAmount: countable,
          totalProfit: toProfit,
          createdAt: DateTime.now(),
          source: SaleSource.debtPayment,
          debtKey: debtKey,
        ));
      }

      if (settles) {
        final settledItems = _itemsForSettlement(debt);
        if (settledItems.isNotEmpty) {
          await salesBox.add(Sale(
            items: settledItems,
            totalAmount: 0.0,
            totalProfit: 0.0,
            createdAt: DateTime.now(),
            source: SaleSource.debtSettlement,
            debtKey: debtKey,
          ));
        }
      }
    } catch (e, stack) {
      debugPrint('[DebtSupplierProvider] Failed to record debt payment: $e');
      debugPrint('$stack');
      rethrow;
    }

    debt.recoveredCapital = debt.capitalRecovered + toCapital;
    debt.realizedProfit = debt.profitRealized + toProfit;
    debt.paidAmount += applied;
    debt.remainingAmount = debt.totalAmount - debt.paidAmount;

    if (settles || debt.remainingAmount <= eps) {
      // Archive instead of delete: preserve debt/customer history.
      debt.remainingAmount = 0;
      debt.isPaid = true;
    }
    await debt.save();

    loadDebts();

    return DebtPaymentResult(
      amountApplied: applied,
      countedAsSales: countable,
      toCapital: toCapital,
      toProfit: toProfit,
      capitalJustRecovered: !capitalWasRecovered && debt.isCapitalRecovered,
      settled: debt.isPaid,
    );
  }

  /// Items to release into the sales records when a debt is fully paid.
  /// For debts that older versions already partly released (see
  /// [Debt.legacyReleasedRatio]) only the not-yet-shown quantity is used.
  List<SaleItem> _itemsForSettlement(Debt debt) {
    final List<SaleItem> result = [];
    for (int i = 0; i < debt.saleItems.length; i++) {
      final item = debt.saleItems[i];
      int qty = item.quantity;
      if (i < debt.legacyItemCount && debt.legacyReleasedRatio > 0) {
        qty -= (item.quantity * debt.legacyReleasedRatio).round();
      }
      if (qty <= 0) continue;
      result.add(SaleItem(
        name: item.name,
        costPrice: item.costPrice,
        sellPrice: item.sellPrice,
        quantity: qty,
        discountPerUnit: item.discountPerUnit,
        category: item.category,
      ));
    }
    return result;
  }

  /// Adds a debt to (or updates the debt of) a supplier/merchant, named
  /// [supplierName]. Only merges into an existing supplier if that
  /// supplier is still ACTIVE (not fully paid/archived) - a supplier
  /// previously paid off in full gets a fresh record instead of silently
  /// reviving and mutating their old, closed history.
  ///
  /// [amount] is always added to the supplier's [Supplier.remainingAmount]
  /// (the cumulative balance shown on their card), regardless of whether
  /// this call created a new supplier or merged into an existing one.
  ///
  /// Every call also appends one distinct, independently-viewable
  /// [SupplierEntry] to the supplier's history (never overwriting a
  /// previous one), so a bulk order and a single product addition each
  /// stay cleanly separated and individually expandable in the UI:
  /// - If [entryTitle] is given, it's used as-is (e.g. "منتج: اسم المنتج"
  ///   for a single-product addition from the Products page).
  /// - Otherwise, when [items] is provided (a bulk order), the entry is
  ///   auto-titled "طلبية رقم N", where N increments per supplier based
  ///   on how many order-type entries (entries with a non-null item
  ///   list) that supplier already has.
  /// - Otherwise (a plain manual debt with no items), it defaults to
  ///   "دين إضافي".
  ///
  /// [note] is ALSO still appended to the legacy free-text [Supplier.notes]
  /// field (unchanged behavior), so anything relying on that summary
  /// keeps working exactly as before.
  Future<void> addOrUpdateSupplierDebt(
    String supplierName,
    double amount,
    String note, {
    String? entryTitle,
    List<SupplierOrderItem>? items,
  }) async {
    if (_supplierBox == null || !_supplierBox!.isOpen) return;

    Supplier? existingSupplier;
    try {
      existingSupplier = _supplierBox!.values.firstWhere(
        (s) =>
            !s.isPaid &&
            s.name.trim().toLowerCase() == supplierName.trim().toLowerCase(),
      );
    } catch (_) {
      existingSupplier = null;
    }

    final Supplier target;
    if (existingSupplier != null) {
      target = existingSupplier;
      target.remainingAmount += amount;
      if (note.trim().isNotEmpty) {
        target.notes = target.notes.isEmpty
            ? note
            : '${target.notes} | $note';
      }
    } else {
      target = Supplier(
        name: supplierName.trim(),
        remainingAmount: amount,
        notes: note.trim(),
      );
      await _supplierBox!.add(target);
    }

    final String resolvedTitle = entryTitle ??
        (items != null
            ? 'طلبية رقم ${target.entries.where((e) => e.items != null).length + 1}'
            : 'دين إضافي');

    target.entries.add(SupplierEntry(
      title: resolvedTitle,
      amount: amount,
      date: DateTime.now(),
      note: note.trim(),
      items: items,
    ));

    await target.save();
    loadSuppliers();
  }

  Future<void> addSupplier(Supplier supplier) async {
    if (_supplierBox != null && _supplierBox!.isOpen) {
      await _supplierBox!.add(supplier);
      loadSuppliers();
    }
  }

  // CHANGED: now takes the Supplier object directly instead of a raw list
  // index. Indexing into `suppliers` was fragile - if the cached list is
  // reloaded or reordered between when the UI captured the index and when
  // this method runs, the wrong supplier could be paid. HiveObjects carry
  // their own box reference, so operating on the object directly is both
  // simpler and safe regardless of list ordering.
  Future<void> addSupplierPayment(Supplier supplier, SupplierPayment payment) async {
    supplier.payments.add(payment);
    supplier.remainingAmount -= payment.amountPaid;

    if (supplier.remainingAmount <= 0) {
      supplier.remainingAmount = 0; // avoid a meaningless negative balance
      // CHANGED: previously called `await supplier.delete()` here, which
      // permanently erased the supplier's name, notes and entire payment
      // history the instant the balance reached zero. Archive instead,
      // matching the Debt pattern above - the record stays recoverable
      // and its history stays intact, it just moves out of the active
      // suppliers list.
      supplier.isPaid = true;
    }
    await supplier.save();
    loadSuppliers();
  }
}

/// Outcome of [DebtSupplierProvider.payCustomerDebt], so the UI can tell
/// the user exactly how the payment was booked.
class DebtPaymentResult {
  final double amountApplied;
  final double countedAsSales;
  final double toCapital;
  final double toProfit;
  final bool capitalJustRecovered;
  final bool settled;

  const DebtPaymentResult({
    required this.amountApplied,
    required this.countedAsSales,
    required this.toCapital,
    required this.toProfit,
    required this.capitalJustRecovered,
    required this.settled,
  });

  const DebtPaymentResult.none()
      : amountApplied = 0,
        countedAsSales = 0,
        toCapital = 0,
        toProfit = 0,
        capitalJustRecovered = false,
        settled = false;

  bool get isNone => amountApplied <= 0;
}

/// One debtor entry for the POS autocomplete.
class DebtorSuggestion {
  final String name;
  final double remaining;
  final bool hasOpenAccount;

  const DebtorSuggestion({
    required this.name,
    required this.remaining,
    required this.hasOpenAccount,
  });
}
