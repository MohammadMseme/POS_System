import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/debt_supplier_provider.dart';
import '../models/supplier.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPaymentDialog(
    BuildContext context,
    Supplier supplier,
  ) {
    final payController = TextEditingController();
    final noteController = TextEditingController();

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
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.payments_outlined,
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'تسديد دفعة للتاجر',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 470,
          child: SingleChildScrollView(
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
                      Text(
                        supplier.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'المبلغ المتبقي للتاجر',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${supplier.remainingAmount.toStringAsFixed(2)} شيكل',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
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
                    labelText: 'مبلغ الدفعة المدفوعة (شيكل)',
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_outlined,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات الدفعة (اختياري)',
                    prefixIcon: const Icon(
                      Icons.notes_outlined,
                    ),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 19,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'سجل الدفعات السابقة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                supplier.payments.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'لا توجد دفعات مسجلة بعد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 150,
                        width: double.maxFinite,
                        child: ListView.builder(
                          itemCount: supplier.payments.length,
                          itemBuilder: (context, pIndex) {
                            final payment =
                                supplier.payments[pIndex];

                            final dateStr =
                                '${payment.date.year}-'
                                '${payment.date.month.toString().padLeft(2, '0')}-'
                                '${payment.date.day.toString().padLeft(2, '0')}';

                            return Container(
                              margin: const EdgeInsets.only(
                                bottom: 6,
                              ),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${payment.amountPaid.toStringAsFixed(2)} شيكل',
                                          style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            color:
                                                Colors.green.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                Colors.grey.shade600,
                                          ),
                                        ),
                                        if (payment.notes.isNotEmpty)
                                          Text(
                                            payment.notes,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  Colors.grey.shade700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
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
            label: const Text('تسجيل الدفعة'),
            onPressed: () {
              double pay =
                  double.tryParse(payController.text) ?? 0.0;

              if (pay > 0) {
                final payment = SupplierPayment(
                  amountPaid: pay,
                  date: DateTime.now(),
                  notes: noteController.text.trim(),
                );

                Provider.of<DebtSupplierProvider>(
                  context,
                  listen: false,
                ).addSupplierPayment(
                  supplier,
                  payment,
                );

                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context) {
    final nameController = TextEditingController();
    final remainingController = TextEditingController();
    final noteController = TextEditingController();

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
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'إضافة / تحديث دين',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم التاجر / الشركة',
                    prefixIcon:
                        const Icon(Icons.business_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remainingController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المستحق إضافته (شيكل)',
                    prefixIcon:
                        const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات الحساب / الدين (اختياري)',
                    prefixIcon:
                        const Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
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
            label: const Text('حفظ'),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Provider.of<DebtSupplierProvider>(
                  context,
                  listen: false,
                ).addOrUpdateSupplierDebt(
                  nameController.text.trim(),
                  double.tryParse(
                        remainingController.text,
                      ) ??
                      0.0,
                  noteController.text.trim(),
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
        padding: const EdgeInsets.all(15),
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
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    final supplierProvider =
        Provider.of<DebtSupplierProvider>(context);

    final filteredSuppliers =
        supplierProvider.suppliers.where((s) {
      return s.name
          .toLowerCase()
          .contains(
            _searchQuery.trim().toLowerCase(),
          );
    }).toList();

    final totalRemaining =
        supplierProvider.suppliers.fold<double>(
      0.0,
      (sum, supplier) =>
          sum + supplier.remainingAmount,
    );

    final totalSuppliers =
        supplierProvider.suppliers.length;

    final totalPayments =
        supplierProvider.suppliers.fold<int>(
      0,
      (sum, supplier) =>
          sum + supplier.payments.length,
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
              Icons.local_shipping_outlined,
              color: Colors.indigo,
            ),
            SizedBox(width: 10),
            Text(
              'حسابات الموردين والتجار',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                _buildSummaryCard(
                  icon: Icons.business_outlined,
                  title: 'عدد الموردين',
                  value: '$totalSuppliers',
                  color: Colors.indigo,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  icon:
                      Icons.account_balance_wallet_outlined,
                  title: 'إجمالي المستحق',
                  value:
                      '${totalRemaining.toStringAsFixed(2)} ₪',
                  color: Colors.red,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  icon: Icons.payments_outlined,
                  title: 'عدد الدفعات',
                  value: '$totalPayments',
                  color: Colors.teal,
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                decoration: InputDecoration(
                  labelText: 'بحث باسم التاجر أو الشركة',
                  hintText: 'اكتب اسم المورد...',
                  prefixIcon:
                      const Icon(Icons.search),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'مسح البحث',
                              icon:
                                  const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
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
              child: filteredSuppliers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _searchQuery.isEmpty
                                  ? Icons
                                      .local_shipping_outlined
                                  : Icons.search_off,
                              size: 48,
                              color: Colors.indigo.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'لا توجد حسابات موردين حالياً'
                                : 'لا يوجد مورد مطابق لـ "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        bottom: 20,
                      ),
                      itemCount:
                          filteredSuppliers.length,
                      itemBuilder:
                          (context, index) {
                        final s =
                            filteredSuppliers[index];

                        return Container(
                          margin: const EdgeInsets.only(
                            bottom: 10,
                          ),
                          padding:
                              const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(15),
                            border: Border.all(
                              color:
                                  Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(
                                  alpha: 0.025,
                                ),
                                blurRadius: 8,
                                offset:
                                    const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.indigo.shade50,
                                  borderRadius:
                                      BorderRadius.circular(
                                    12,
                                  ),
                                ),
                                child: Icon(
                                  Icons
                                      .local_shipping_outlined,
                                  color:
                                      Colors.indigo.shade700,
                                  size: 28,
                                ),
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      s.name,
                                      style:
                                          const TextStyle(
                                        fontSize: 17,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(
                                        height: 5),
                                    Text(
                                      'عدد الدفعات: ${s.payments.length}',
                                      style: TextStyle(
                                        color: Colors
                                            .grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (s.notes.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets
                                                .only(
                                          top: 3,
                                        ),
                                        child: Text(
                                          s.notes,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style: TextStyle(
                                            color: Colors
                                                .blueGrey
                                                .shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 15),

                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${s.remainingAmount.toStringAsFixed(2)} شيكل',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          s.remainingAmount >
                                                  0
                                              ? Colors.red
                                                  .shade700
                                              : Colors
                                                  .green
                                                  .shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    style:
                                        ElevatedButton
                                            .styleFrom(
                                      backgroundColor:
                                          Colors.teal,
                                      foregroundColor:
                                          Colors.white,
                                      elevation: 0,
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          9,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.payment,
                                      size: 17,
                                    ),
                                    onPressed: () =>
                                        _showPaymentDialog(
                                      context,
                                      s,
                                    ),
                                    label: const Text(
                                      'دفع دفعة',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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

