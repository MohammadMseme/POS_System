import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/salaries_expenses_provider.dart';
import '../models/worker.dart';
import '../models/expense.dart';
import '../widgets/dispose_on_unmount.dart';

class SalariesExpensesScreen extends StatefulWidget {
  const SalariesExpensesScreen({super.key});

  @override
  State<SalariesExpensesScreen> createState() => _SalariesExpensesScreenState();
}

class _SalariesExpensesScreenState extends State<SalariesExpensesScreen> {
  void _showAddWorkerDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        // Controllers are disposed when the dialog is really unmounted
        // (after its closing animation), not when pop() completes.
        disposables: [nameController],
        child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.person_add_alt_1_outlined, color: Colors.indigo.shade700),
            ),
            const SizedBox(width: 12),
            const Text('إضافة عامل جديد', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'اسم العامل / الموظف',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ'),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Provider.of<SalariesExpensesProvider>(context, listen: false).addWorker(name);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
      ),
    );
  }

  void _showPayWorkerDialog(BuildContext context, Worker worker) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        // Controllers are disposed when the dialog is really unmounted
        // (after its closing animation), not when pop() completes.
        disposables: [amountController, noteController],
        child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.payments_outlined, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('دفع مبلغ لـ ${worker.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'المبلغ (شيكل)',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'ملاحظة (مثال: سلفة، راتب الشهر)',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('تسجيل الدفعة'),
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0) return;
              Provider.of<SalariesExpensesProvider>(context, listen: false)
                  .addWorkerPayment(worker, amount, noteController.text);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        // Controllers are disposed when the dialog is really unmounted
        // (after its closing animation), not when pop() completes.
        disposables: [amountController, noteController],
        child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.receipt_long_outlined, color: Colors.red.shade700),
            ),
            const SizedBox(width: 12),
            const Text('إضافة مصروف عام', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'قيمة المصروف (شيكل)',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'ملاحظة (مثال: فاتورة كهرباء، صيانة)',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('حفظ المصروف'),
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0) return;
              Provider.of<SalariesExpensesProvider>(context, listen: false)
                  .addExpense(amount, noteController.text);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSummaryCard({required IconData icon, required String title, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 4),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(BuildContext context, Worker worker) {
    final sortedPayments = [...worker.payments]..sort((a, b) => b.date.compareTo(a.date));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        childrenPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.badge_outlined, color: Colors.indigo.shade700),
        ),
        title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            'أُضيف في ${worker.addedAt.year}-${worker.addedAt.month.toString().padLeft(2, '0')}-${worker.addedAt.day.toString().padLeft(2, '0')} '
            '• إجمالي المدفوع: ${worker.totalPaid.toStringAsFixed(2)} ₪',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
        trailing: SizedBox(
          width: 90,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            icon: const Icon(Icons.payment, size: 15),
            label: const Text('دفع', style: TextStyle(fontSize: 12.5)),
            onPressed: () => _showPayWorkerDialog(context, worker),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 6),
                const Text('سجل الدفعات والسلف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (sortedPayments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                    child: const Text('لا توجد دفعات مسجلة بعد', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...sortedPayments.map((p) {
                    final dateStr =
                        '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p.amount.toStringAsFixed(2)} ₪',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                const SizedBox(height: 2),
                                Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                if (p.note.isNotEmpty)
                                  Text(p.note, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    final dateStr =
        '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}-${expense.date.day.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.receipt_long_outlined, size: 18, color: Colors.red.shade700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.note.isEmpty ? 'مصروف عام' : expense.note,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text('${expense.amount.toStringAsFixed(2)} ₪', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SalariesExpensesProvider>(context);
    final sortedExpenses = [...provider.expenses]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.groups_outlined, color: Colors.indigo),
            SizedBox(width: 10),
            Text('رواتب ومفرقات', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              _buildSummaryCard(
                icon: Icons.groups_outlined,
                title: 'عدد العمال',
                value: '${provider.workers.length}',
                color: Colors.indigo,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                icon: Icons.payments_outlined,
                title: 'رواتب وسلف مدفوعة',
                value: '${provider.totalWorkerPayments.toStringAsFixed(2)} ₪',
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                icon: Icons.receipt_long_outlined,
                title: 'إجمالي المصاريف',
                value: '${provider.totalExpenses.toStringAsFixed(2)} ₪',
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 19, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text('العمال والموظفون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddWorkerDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة عامل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (provider.workers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Icon(Icons.badge_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text('لا يوجد عمال مسجلون بعد', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          else
            ...provider.workers.map((w) => _buildWorkerCard(context, w)),

          const SizedBox(height: 24),

          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 19, color: Colors.red),
              const SizedBox(width: 8),
              const Text('المصاريف العامة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddExpenseDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة مصروف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (sortedExpenses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text('لا توجد مصاريف مسجلة بعد', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          else
            ...sortedExpenses.map(_buildExpenseTile),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'يتم خصم كل دفعة للعمال وكل مصروف تلقائياً من إجمالي المبيعات والربح في صفحة الجرد.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}