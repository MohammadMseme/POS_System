import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/debt_supplier_provider.dart';
import '../providers/auth_provider.dart';
import '../models/debt.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const int _employeeMinQueryLength = 3;
  static const int _employeeMaxResults = 5;

  /// Debt keys with a payment currently being written - blocks a second
  /// payment on the same debt until the first one has finished.
  final Set<dynamic> _paymentsInProgress = {};

  // FIXED (lifecycle): the dialogs below are now self-contained
  // StatefulWidgets (_AddDebtDialog / _DebtPaymentDialog at the bottom of
  // this file). They own and dispose their own TextEditingControllers and
  // perform NO async work - they only validate input and pop() with the
  // result. All Hive/provider work then happens here, in the screen's
  // State, using the State's own `context` guarded by `mounted`.
  //
  // Previously the controllers were disposed in showDialog(...).then(...),
  // which runs as soon as pop() is called while the dialog is still on
  // screen for its closing animation; the payment dialog also rebuilt
  // itself (setState) around an await. Rebuilding with a disposed
  // controller broke the element tree and crashed with
  // "'_dependents.isEmpty' is not true".

  Future<void> _showAddDebtDialog() async {
    final Debt? newDebt = await showDialog<Debt>(
      context: context,
      builder: (_) => const _AddDebtDialog(),
    );
    if (newDebt == null || !mounted) return;

    final provider = Provider.of<DebtSupplierProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.addDebt(newDebt);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم تسجيل الدين على "${newDebt.customerName}"'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر حفظ الدين: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showPaymentDialog(Debt debt) async {
    if (_paymentsInProgress.contains(debt.key)) return;

    final double? amount = await showDialog<double>(
      context: context,
      builder: (_) => _DebtPaymentDialog(
        debt: debt,
        // Cost / profit figures are Admin-only.
        showCapital: Provider.of<AuthProvider>(context, listen: false).isAdmin,
      ),
    );
    if (amount == null || amount <= 0 || !mounted) return;

    await _registerPayment(debt, amount);
  }

  Future<void> _registerPayment(Debt debt, double amount) async {
    if (_paymentsInProgress.contains(debt.key)) return;

    // Everything that needs the context is captured BEFORE the await.
    final provider = Provider.of<DebtSupplierProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    _paymentsInProgress.add(debt.key);
    try {
      final result = await provider.payCustomerDebt(debt, amount);
      if (!mounted || result.isNone) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<AuthProvider>(context, listen: false).isAdmin
                ? _describePayment(debt, result)
                // Employee: no capital/profit/sales breakdown.
                : 'تم تسجيل سداد ${result.amountApplied.toStringAsFixed(2)} شيكل من ${debt.customerName}'
                    '${result.settled ? ' - تم سداد الدين بالكامل' : ' - المتبقي: ${debt.remainingAmount.toStringAsFixed(2)} شيكل'}',
          ),
          backgroundColor:
              result.settled ? Colors.green.shade700 : Colors.blue.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('تعذر تسجيل السداد: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _paymentsInProgress.remove(debt.key);
    }
  }

  /// Human-readable summary of how a payment was booked.
  String _describePayment(Debt debt, DebtPaymentResult r) {
    final paid = r.amountApplied.toStringAsFixed(2);
    if (debt.saleItems.isEmpty) {
      return r.settled
          ? 'تم سداد $paid شيكل وإغلاق دين ${debt.customerName} بالكامل'
          : 'تم تسجيل سداد $paid شيكل';
    }
    final parts = <String>['تم تسجيل $paid شيكل في إجمالي المبيعات'];
    if (r.toCapital > 0.005) {
      parts.add('${r.toCapital.toStringAsFixed(2)} لاسترداد رأس المال');
    }
    if (r.toProfit.abs() > 0.005) {
      parts.add('${r.toProfit.toStringAsFixed(2)} ربح صافي');
    }
    String text = parts.join(' • ');
    if (r.settled) {
      text += '\nتم سداد الدين بالكامل ونقل الأصناف إلى سجل المبيعات';
    } else if (r.capitalJustRecovered) {
      text += '\nتم استرداد رأس المال بالكامل - الدفعات القادمة تُحتسب ربحاً';
    }
    return text;
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    alignment: Alignment.centerRight,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [restricted] = Employee view: no capital/profit figures.
  Widget _buildDebtCard(
    BuildContext context,
    Debt debt, {
    bool restricted = false,
  }) {
    final double progress = debt.totalAmount > 0
        ? (debt.paidAmount / debt.totalAmount)
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      // Stable identity per debt: when a debt is fully paid and leaves the
      // list, the remaining cards keep their own expanded/collapsed state.
      key: ValueKey(debt.key),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        childrenPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.person_outline,
            color: Colors.blue.shade700,
            size: 27,
          ),
        ),
        title: Text(
          debt.customerName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                restricted
                    ? 'دين مفتوح - المبلغ المطلوب تحصيله'
                    : 'إجمالي ${debt.totalAmount.toStringAsFixed(2)} • '
                        'مسدد ${debt.paidAmount.toStringAsFixed(2)} شيكل',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              // NEW: capital recovery status (only for debts that came
              // from real POS items, where the cost price is known).
              if (!restricted && debt.saleItems.isNotEmpty)
                CapitalStatusBadge(recovered: debt.isCapitalRecovered),
            ],
          ),
        ),
        trailing: SizedBox(
          width: 220,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${debt.remainingAmount.toStringAsFixed(2)} شيكل',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                ),
                onPressed: () => _showPaymentDialog(debt),
                child: const Text('سداد'),
              ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              18,
              0,
              18,
              18,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),

                if (!restricted) ...[
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'نسبة السداد',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor:
                        Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(
                      Colors.green.shade500,
                    ),
                  ),
                ),
                ],

                if (!restricted && debt.saleItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _CapitalStatusPanel(debt: debt),
                ],

                const SizedBox(height: 18),

                const Text(
                  'المنتجات / الملاحظات',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 8),

                if (debt.itemsTaken.isEmpty)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'لا يوجد تسجيل تفصيلي للمنتجات',
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: debt.itemsTaken
                          .map(
                            (item) => Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 5,
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Icon(
                                    Icons
                                        .fiber_manual_record,
                                    size: 8,
                                    color: Colors.blue
                                        .shade600,
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  Expanded(
                                    child: Text(item),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debtProvider =
        Provider.of<DebtSupplierProvider>(context);
    // NEW (roles): the Employee can collect payments, but never sees the
    // totals, the paid amounts, or the full debtor list.
    final bool isAdmin = Provider.of<AuthProvider>(context).isAdmin;
    final String query = _searchQuery.trim().toLowerCase();

    final matchingDebts =
        debtProvider.activeDebts.where((debt) {
      return debt.customerName
          .toLowerCase()
          .contains(query);
    }).toList();

    // Employee: results only after typing at least
    // [_employeeMinQueryLength] letters, and at most
    // [_employeeMaxResults] cards - enough to find one customer, never
    // enough to browse the list.
    final bool employeeQueryTooShort =
        !isAdmin && query.length < _employeeMinQueryLength;
    final bool employeeTooManyMatches =
        !isAdmin && !employeeQueryTooShort && matchingDebts.length > _employeeMaxResults;
    final List<Debt> filteredDebts = isAdmin
        ? matchingDebts
        : (employeeQueryTooShort || employeeTooManyMatches)
            ? const <Debt>[]
            : matchingDebts;

    final totalDebt = debtProvider.activeDebts.fold<double>(
      0.0,
      (sum, debt) => sum + debt.remainingAmount,
    );

    final totalCustomers =
        debtProvider.activeDebts.length;

    final totalPaid = debtProvider.activeDebts.fold<double>(
      0.0,
      (sum, debt) => sum + debt.paidAmount,
    );

    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.blue,
            ),
            SizedBox(width: 10),
            Text(
              'إدارة ديون الزبائن',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      // Manual debts are Admin-only (credit sales still go through POS).
      floatingActionButton: !isAdmin
          ? null
          : FloatingActionButton.extended(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: _showAddDebtDialog,
        icon: const Icon(Icons.add),
        label: const Text(
          'إضافة دين',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            if (isAdmin) ...[
            Row(
              children: [
                _buildSummaryCard(
                  icon: Icons.people_outline,
                  title: 'الزبائن المدينون',
                  value: '$totalCustomers',
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'إجمالي المتبقي',
                  value:
                      '${totalDebt.toStringAsFixed(2)} ₪',
                  color: Colors.red,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  icon: Icons.payments_outlined,
                  title: 'إجمالي المسدد',
                  value:
                      '${totalPaid.toStringAsFixed(2)} ₪',
                  color: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 16),
            ] else ...[
              _EmployeeDebtsNotice(minLetters: _employeeMinQueryLength),
              const SizedBox(height: 16),
            ],

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: 0.035),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'بحث باسم الزبون',
                  hintText: isAdmin
                      ? 'اكتب اسم الزبون...'
                      : 'اكتب $_employeeMinQueryLength أحرف على الأقل من اسم الزبون...',
                  prefixIcon: const Icon(
                    Icons.search,
                  ),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'مسح البحث',
                              icon: const Icon(
                                Icons.clear,
                              ),
                              onPressed: () {
                                _searchController
                                    .clear();

                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 14,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: filteredDebts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              (_searchQuery.isEmpty || employeeQueryTooShort)
                                  ? Icons
                                      .account_balance_wallet_outlined
                                  : Icons.search_off,
                              size: 48,
                              color: Colors.blue.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            employeeQueryTooShort
                                ? 'ابحث عن الزبون بالاسم لتسجيل دفعة'
                                : employeeTooManyMatches
                                    ? 'يوجد أكثر من زبون مطابق، اكتب الاسم بشكل أدق'
                                    : _searchQuery.isEmpty
                                        ? 'لا يوجد أي ديون مسجلة حالياً'
                                        : 'لا يوجد زبون مطابق لـ "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isAdmin && _searchQuery.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                top: 8,
                              ),
                              child: Text(
                                'يمكنك إضافة دين جديد باستخدام الزر بالأسفل',
                                style: TextStyle(
                                  color:
                                      Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredDebts.length,
                      padding: const EdgeInsets.only(
                        bottom: 90,
                      ),
                      itemBuilder: (context, index) {
                        final debt =
                            filteredDebts[index];

                        return _buildDebtCard(
                          context,
                          debt,
                          restricted: !isAdmin,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill telling whether a credit sale's cost price (رأس المال) has
/// been fully recovered by the payments received so far. Public so the
/// Inventory screen's debt details can reuse it.
class CapitalStatusBadge extends StatelessWidget {
  final bool recovered;
  final bool compact;

  const CapitalStatusBadge({
    super.key,
    required this.recovered,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = recovered ? Colors.green.shade700 : Colors.orange.shade800;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            recovered ? Icons.verified_outlined : Icons.hourglass_top_rounded,
            size: compact ? 11 : 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            recovered ? 'تم استرداد رأس المال' : 'لم يُسترد رأس المال بعد',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Capital-recovery breakdown of a credit sale: how much of the cost has
/// been recovered, and how much profit is realized vs still pending.
class _CapitalStatusPanel extends StatelessWidget {
  final Debt debt;

  const _CapitalStatusPanel({required this.debt});

  @override
  Widget build(BuildContext context) {
    final double cost = debt.totalCost;
    final double recovered = debt.capitalRecovered.clamp(0.0, cost);
    final double progress = cost > 0 ? (recovered / cost).clamp(0.0, 1.0) : 1.0;
    final bool done = debt.isCapitalRecovered;
    final Color color = done ? Colors.green.shade600 : Colors.orange.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'استرداد رأس المال',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              CapitalStatusBadge(recovered: done, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'رأس المال المسترد: ${recovered.toStringAsFixed(2)} / ${cost.toStringAsFixed(2)} شيكل',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 2),
          Text(
            'ربح محتسب: ${debt.profitRealized.toStringAsFixed(2)} شيكل • '
            'ربح متبقٍ في الدين: ${debt.pendingProfit.toStringAsFixed(2)} شيكل',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

/// "إضافة دين جديد" dialog. Owns its controllers (disposed in dispose(),
/// i.e. only after the dialog has fully left the screen) and returns the
/// new [Debt] via Navigator.pop - it never touches providers itself.
class _AddDebtDialog extends StatefulWidget {
  const _AddDebtDialog();

  @override
  State<_AddDebtDialog> createState() => _AddDebtDialogState();
}

class _AddDebtDialogState extends State<_AddDebtDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  String? _nameError;
  String? _amountError;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final item = _itemController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'أدخل اسم الزبون' : null;
      _amountError = amount <= 0 ? 'أدخل مبلغاً صحيحاً' : null;
    });
    if (_nameError != null || _amountError != null) return;

    Navigator.pop(
      context,
      Debt(
        customerName: name,
        totalAmount: amount,
        paidAmount: 0.0,
        remainingAmount: amount,
        itemsTaken: item.isNotEmpty ? [item] : ['إضافة يدوية'],
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_add_alt_1_outlined,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'إضافة دين جديد',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'اسم الزبون',
                errorText: _nameError,
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'إجمالي مبلغ الدين (شيكل)',
                errorText: _amountError,
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _itemController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'ملاحظة / الأصناف المأخوذة',
                prefixIcon: const Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ الدين'),
          onPressed: _save,
        ),
      ],
    );
  }
}

/// "تسديد دين" dialog. Only collects and validates the amount, then pops
/// with it (double). The actual payment is executed afterwards by the
/// screen (see _DebtsScreenState._registerPayment), so there is no await,
/// no setState around async work and no context use after the dialog
/// closes inside this widget.
class _DebtPaymentDialog extends StatefulWidget {
  final Debt debt;
  final bool showCapital;

  const _DebtPaymentDialog({required this.debt, this.showCapital = true});

  @override
  State<_DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends State<_DebtPaymentDialog> {
  final TextEditingController _payController = TextEditingController();
  String? _errorText;
  bool _closing = false;

  @override
  void dispose() {
    _payController.dispose();
    super.dispose();
  }

  void _fillFullAmount() {
    _payController.text = widget.debt.remainingAmount.toStringAsFixed(2);
    if (_errorText != null) setState(() => _errorText = null);
  }

  void _submit() {
    if (_closing) return; // ignore double taps while the dialog closes

    final debt = widget.debt;
    final double pay = double.tryParse(_payController.text.trim()) ?? 0.0;

    String? error;
    if (pay <= 0) {
      error = 'أدخل مبلغاً صحيحاً';
    } else if (pay > debt.remainingAmount + 0.005) {
      // small tolerance for rounding (e.g. 33.333 shown as 33.33)
      error = 'المبلغ أكبر من المتبقي (${debt.remainingAmount.toStringAsFixed(2)} شيكل)';
    }

    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    _closing = true;
    // Never more than the remaining balance.
    final double amount = pay > debt.remainingAmount ? debt.remainingAmount : pay;
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.payments_outlined,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'تسديد دين: ${debt.customerName}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'المبلغ المتبقي حالياً',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${debt.remainingAmount.toStringAsFixed(2)} شيكل',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showCapital && debt.saleItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CapitalStatusPanel(debt: debt),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _payController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'المبلغ المدفوع (شيكل)',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                suffixIcon: TextButton(
                  onPressed: _fillFullAmount,
                  child: const Text('كامل المبلغ'),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('تسجيل السداد'),
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Shown to the Employee instead of the totals row.
class _EmployeeDebtsNotice extends StatelessWidget {
  final int minLetters;

  const _EmployeeDebtsNotice({required this.minLetters});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.badge_outlined, color: Colors.teal.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تحصيل الديون: اكتب $minLetters أحرف على الأقل من اسم الزبون ثم اضغط "سداد" لتسجيل الدفعة.',
              style: TextStyle(fontSize: 13, color: Colors.teal.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
