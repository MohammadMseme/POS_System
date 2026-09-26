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

  // Suppliers are archived (not deleted) once fully paid, so we need a
  // way to see them again instead of them vanishing from the UI.
  bool _showArchived = false;

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

  // NEW: full payment-history detail view. Works for both active and
  // archived suppliers - tapping an archived (fully-paid) supplier is
  // now the only way to see their history again, since they no longer
  // appear in the active list or the summary totals.
  void _showSupplierDetail(BuildContext context, Supplier supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SupplierDetailSheet(supplier: supplier),
    );
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
    ).then((_) {
      payController.dispose();
      noteController.dispose();
    });
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
    ).then((_) {
      nameController.dispose();
      remainingController.dispose();
      noteController.dispose();
    });
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

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.grey.shade700,
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

    final baseList = _showArchived
        ? supplierProvider.archivedSuppliers
        : supplierProvider.activeSuppliers;

    final filteredSuppliers = baseList.where((s) {
      return s.name
          .toLowerCase()
          .contains(
            _searchQuery.trim().toLowerCase(),
          );
    }).toList();

    final totalRemaining =
        supplierProvider.activeSuppliers.fold<double>(
      0.0,
      (sum, supplier) =>
          sum + supplier.remainingAmount,
    );

    final totalSuppliers =
        supplierProvider.activeSuppliers.length;

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showAddSupplierDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة / تحديث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                _buildSummaryCard(
                  icon: Icons.business_outlined,
                  title: 'الموردون النشطون',
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

            // Active / Archived segmented toggle. Archived suppliers are
            // the ones that were paid off in full - tap any card (in
            // either tab) to open the full payment-history detail sheet.
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      label: 'نشطون',
                      icon: Icons.local_shipping_outlined,
                      selected: !_showArchived,
                      onTap: () => setState(() => _showArchived = false),
                    ),
                  ),
                  Expanded(
                    child: _buildToggleButton(
                      label: 'مؤرشفون (تم السداد)',
                      icon: Icons.archive_outlined,
                      selected: _showArchived,
                      onTap: () => setState(() => _showArchived = true),
                    ),
                  ),
                ],
              ),
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

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'اضغط على أي بطاقة لعرض كامل سجل الدفعات',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

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
                            _searchQuery.isNotEmpty
                                ? 'لا يوجد مورد مطابق لـ "$_searchQuery"'
                                : _showArchived
                                    ? 'لا يوجد موردون مؤرشفون حالياً'
                                    : 'لا توجد حسابات موردين نشطة حالياً',
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
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(15),
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
                          child: Material(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(15),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(15),
                              // NEW: tap anywhere on the card to open the
                              // full payment-history detail sheet.
                              onTap: () =>
                                  _showSupplierDetail(context, s),
                              child: Container(
                                padding:
                                    const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(15),
                                  border: Border.all(
                                    color:
                                        Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: s.isPaid
                                            ? Colors.green.shade50
                                            : Colors.indigo.shade50,
                                        borderRadius:
                                            BorderRadius.circular(
                                          12,
                                        ),
                                      ),
                                      child: Icon(
                                        s.isPaid
                                            ? Icons.check_circle_outline
                                            : Icons.local_shipping_outlined,
                                        color: s.isPaid
                                            ? Colors.green.shade700
                                            : Colors.indigo.shade700,
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
                                          s.isPaid
                                              ? 'تم السداد بالكامل'
                                              : '${s.remainingAmount.toStringAsFixed(2)} شيكل',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight:
                                                FontWeight.bold,
                                            color: s.isPaid
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (!s.isPaid)
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
                                          )
                                        else
                                          Icon(
                                            Icons.chevron_left,
                                            color: Colors.grey.shade400,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

/// Full payment-history detail sheet for a single supplier. Opened by
/// tapping any supplier card - active or archived. Read-only: payments
/// are still recorded through the existing "دفع دفعة" dialog so this
/// sheet never has to worry about keeping itself in sync mid-payment.
class _SupplierDetailSheet extends StatelessWidget {
  final Supplier supplier;

  const _SupplierDetailSheet({required this.supplier});

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedPayments = [...supplier.payments]
      ..sort((a, b) => b.date.compareTo(a.date));

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: supplier.isPaid ? Colors.green.shade50 : Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        supplier.isPaid ? Icons.check_circle_outline : Icons.local_shipping_outlined,
                        color: supplier.isPaid ? Colors.green.shade700 : Colors.indigo.shade700,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: supplier.isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              supplier.isPaid ? 'مؤرشف - تم السداد بالكامل' : 'حساب نشط',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: supplier.isPaid ? Colors.green.shade700 : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if (supplier.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      supplier.notes,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _statTile('إجمالي التعامل', '${supplier.totalEverOwed.toStringAsFixed(2)} ₪', Colors.indigo),
                    const SizedBox(width: 10),
                    _statTile('إجمالي المسدد', '${supplier.totalPaid.toStringAsFixed(2)} ₪', Colors.green),
                    const SizedBox(width: 10),
                    _statTile(
                      'المتبقي',
                      '${supplier.remainingAmount.toStringAsFixed(2)} ₪',
                      supplier.remainingAmount > 0 ? Colors.red : Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'سجل الدفعات (${sortedPayments.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: sortedPayments.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد دفعات مسجلة لهذا المورد',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: sortedPayments.length,
                        itemBuilder: (context, index) {
                          final p = sortedPayments[index];
                          final dateStr = '${p.date.year}-'
                              '${p.date.month.toString().padLeft(2, '0')}-'
                              '${p.date.day.toString().padLeft(2, '0')}  '
                              '${p.date.hour.toString().padLeft(2, '0')}:'
                              '${p.date.minute.toString().padLeft(2, '0')}';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green.shade700,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${p.amountPaid.toStringAsFixed(2)} شيكل',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateStr,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      if (p.notes.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            p.notes,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '#${sortedPayments.length - index}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}