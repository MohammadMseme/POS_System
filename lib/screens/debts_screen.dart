import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/debt_supplier_provider.dart';
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

  void _showAddDebtDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final itemController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الزبون',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'إجمالي مبلغ الدين (شيكل)',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemController,
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ الدين'),
            onPressed: () {
              final name = nameController.text.trim();
              final amount =
                  double.tryParse(amountController.text) ?? 0.0;
              final item = itemController.text.trim();

              if (name.isNotEmpty && amount > 0) {
                final newDebt = Debt(
                  customerName: name,
                  totalAmount: amount,
                  paidAmount: 0.0,
                  remainingAmount: amount,
                  itemsTaken: item.isNotEmpty
                      ? [item]
                      : ['إضافة يدوية'],
                  createdAt: DateTime.now(),
                );

                Provider.of<DebtSupplierProvider>(
                  context,
                  listen: false,
                ).addDebt(newDebt);

                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, Debt debt) {
    final payController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                      style: TextStyle(
                        color: Colors.black54,
                      ),
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
              const SizedBox(height: 16),
              TextField(
                controller: payController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع (شيكل)',
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('تسجيل السداد'),
            onPressed: () {
              double pay =
                  double.tryParse(payController.text) ?? 0.0;

              if (pay > 0) {
                Provider.of<DebtSupplierProvider>(
                  context,
                  listen: false,
                ).payCustomerDebt(
                  debt,
                  pay,
                );

                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
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

  Widget _buildDebtCard(
    BuildContext context,
    Debt debt,
  ) {
    final double progress = debt.totalAmount > 0
        ? (debt.paidAmount / debt.totalAmount)
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
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
          child: Text(
            'إجمالي ${debt.totalAmount.toStringAsFixed(2)} • '
            'مسدد ${debt.paidAmount.toStringAsFixed(2)} شيكل',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
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
                onPressed: () =>
                    _showPaymentDialog(
                  context,
                  debt,
                ),
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

    final filteredDebts =
        debtProvider.activeDebts.where((debt) {
      return debt.customerName
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
    }).toList();

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

      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: () =>
            _showAddDebtDialog(context),
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
                  hintText: 'اكتب اسم الزبون...',
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
                              _searchQuery.isEmpty
                                  ? Icons
                                      .account_balance_wallet_outlined
                                  : Icons.search_off,
                              size: 48,
                              color: Colors.blue.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'لا يوجد أي ديون مسجلة حالياً'
                                : 'لا يوجد زبون مطابق لـ "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_searchQuery.isEmpty)
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
