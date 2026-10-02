import 'package:hive/hive.dart';
import 'sale.dart';

part 'debt.g.dart';

@HiveType(typeId: 5)
class Debt extends HiveObject {
  @HiveField(0)
  String customerName;

  @HiveField(1)
  double totalAmount;

  @HiveField(2)
  double paidAmount;

  @HiveField(3)
  double remainingAmount;

  @HiveField(4)
  List<String> itemsTaken;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  List<SaleItem> saleItems;

  @HiveField(7)
  double totalProfit;

  @HiveField(8)
  bool isPaid;

  // ---------------------------------------------------------------------
  // NEW: capital-first repayment tracking (استرداد رأس المال).
  //
  // Every installment is split in two parts:
  //   1. capital  -> recovers the cost price of the items sold on credit
  //   2. profit   -> only once the full cost has been recovered
  // Both counters are cumulative across all installments of this debt.
  //
  // They are nullable on purpose: debts written by older app versions do
  // not have them; HiveService.init migrates those once at startup (see
  // ensureTracking below).
  // ---------------------------------------------------------------------

  /// Cost of goods already recovered from this debt's payments.
  @HiveField(9)
  double? recoveredCapital;

  /// Profit already realized (counted in net profit) from this debt.
  @HiveField(10)
  double? realizedProfit;

  /// Migration only: share (0..1) of the ORIGINAL items that older app
  /// versions already released into the sales records proportionally
  /// before this rework. Used so the final settlement record only lists
  /// the quantities that were not already shown. 0 for all new debts.
  @HiveField(11)
  double legacyReleasedRatio;

  /// Migration only: how many entries of [saleItems] existed when the
  /// legacy ratio above was captured. Items appended later (a new credit
  /// purchase merged into the same account) are never affected by it.
  @HiveField(12)
  int legacyItemCount;

  Debt({
    required this.customerName,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.itemsTaken,
    required this.createdAt,
    List<SaleItem>? saleItems,
    this.totalProfit = 0.0,
    this.isPaid = false,
    this.recoveredCapital,
    this.realizedProfit,
    this.legacyReleasedRatio = 0.0,
    this.legacyItemCount = 0,
  }) : saleItems = saleItems ?? <SaleItem>[]; // growable - merges append to it

  /// Total cost price (رأس المال) of all items taken on this debt.
  double get totalCost => saleItems.fold(
      0.0, (sum, item) => sum + (item.costPrice * item.quantity));

  /// Value of this debt that is backed by real POS items (cost + profit).
  /// Only this part of a payment is ever counted as sales. Any extra
  /// amount (a manual debt typed in on the Debts page, without items)
  /// keeps its previous behavior and is not counted as sales.
  double get itemsSaleValue => totalCost + totalProfit;

  double get capitalRecovered => recoveredCapital ?? 0.0;
  double get profitRealized => realizedProfit ?? 0.0;

  /// Cost that still has to be recovered before payments become profit.
  double get capitalRemaining {
    final r = totalCost - capitalRecovered;
    return r > 0 ? r : 0.0;
  }

  /// True when the payments received so far fully cover the cost price.
  bool get isCapitalRecovered =>
      saleItems.isNotEmpty && capitalRemaining <= 0.005;

  /// Profit that is still "inside" the unpaid balance.
  double get pendingProfit {
    final p = totalProfit - profitRealized;
    return p > 0 ? p : 0.0;
  }

  /// Initializes [recoveredCapital] / [realizedProfit] when they
  /// are missing. Returns true if the debt was changed (caller saves).
  ///
  /// Older versions recorded every partial payment as a proportional
  /// sale (proportional items, proportional profit). For such debts the
  /// already-booked amounts are reconstructed with that same proportion,
  /// so nothing is counted twice when the remaining balance is paid
  /// under the new capital-first rules.
  bool ensureTracking() {
    if (recoveredCapital != null && realizedProfit != null) {
      return false;
    }

    if (saleItems.isEmpty) {
      recoveredCapital = 0.0;
      realizedProfit = 0.0;
      return true;
    }

    if (isPaid) {
      // Fully paid under the old system - everything was already booked
      // and every item was already released into the sales records.
      recoveredCapital = totalCost;
      realizedProfit = totalProfit;
      legacyReleasedRatio = 1.0;
      legacyItemCount = saleItems.length;
      return true;
    }

    if (paidAmount > 0 && totalAmount > 0) {
      final double ratio = (paidAmount / totalAmount).clamp(0.0, 1.0);
      double bookedRevenue = totalAmount * ratio;
      if (bookedRevenue > itemsSaleValue) bookedRevenue = itemsSaleValue;
      final double bookedProfit = totalProfit * ratio;
      double capital = bookedRevenue - bookedProfit;
      if (capital < 0) capital = 0;
      if (capital > totalCost) capital = totalCost;

      recoveredCapital = capital;
      realizedProfit = bookedProfit;
      legacyReleasedRatio = ratio;
      legacyItemCount = saleItems.length;
      return true;
    }

    recoveredCapital = 0.0;
    realizedProfit = 0.0;
    return true;
  }
}
