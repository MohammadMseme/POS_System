import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/debt.dart';
import '../models/supplier.dart';
import '../models/sale.dart';

class DebtSupplierProvider extends ChangeNotifier {
  Box<Debt>? _debtBox;
  Box<Supplier>? _supplierBox;

  List<Debt> debts = [];
  List<Supplier> suppliers = [];

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

    loadDebts();
    loadSuppliers();
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
        existingDebt = _debtBox!.values.firstWhere(
          (d) => d.customerName.trim().toLowerCase() == newDebt.customerName.trim().toLowerCase(),
        );
      } catch (_) {
        existingDebt = null;
      }

      if (existingDebt != null) {
        existingDebt.totalAmount += newDebt.totalAmount;
        existingDebt.remainingAmount += newDebt.remainingAmount;
        existingDebt.itemsTaken.addAll(newDebt.itemsTaken);
        existingDebt.saleItems.addAll(newDebt.saleItems);
        existingDebt.totalProfit += newDebt.totalProfit;
        await existingDebt.save();
      } else {
        await _debtBox!.add(newDebt);
      }
      
      loadDebts();
    }
  }

  // عند سداد الدين: يتم تسجيل الجزء المسدد كعملية بيع حقيقية في الجرد والأرباح
  Future<void> payCustomerDebt(Debt debt, double amount) async {
    if (amount <= 0 || debt.totalAmount <= 0) return;

    // حساب نسبة المبلغ المسدد من إجمالي الدين
    double paymentRatio = amount / debt.totalAmount;
    if (paymentRatio > 1.0) paymentRatio = 1.0;

    // استخراج الأصناف والأرباح الخاصة بالدفعة المسددة
    List<SaleItem> paidSaleItems = debt.saleItems.map((item) {
      int proportionalQty = (item.quantity * paymentRatio).round();
      if (proportionalQty < 1 && item.quantity > 0 && paymentRatio > 0) {
        proportionalQty = 1;
      }
      if (proportionalQty > item.quantity) proportionalQty = item.quantity;

      return SaleItem(
        name: item.name,
        costPrice: item.costPrice,
        sellPrice: item.sellPrice,
        quantity: proportionalQty,
        discount: item.discount,
      );
    }).where((item) => item.quantity > 0).toList();

    double paidProfit = debt.totalProfit * paymentRatio;
    double paidTotalAmount = debt.totalAmount * paymentRatio;

    // إرسال هذه الدفعة لصندوق المبيعات لتظهر في الأرباح والجرد بشكل طبيعي
    if (paidSaleItems.isNotEmpty) {
      final salesBox = Hive.box<Sale>('sales');
      await salesBox.add(Sale(
        items: paidSaleItems,
        totalAmount: paidTotalAmount,
        totalProfit: paidProfit,
        createdAt: DateTime.now(),
      ));
    }

    debt.paidAmount += amount;
    debt.remainingAmount = debt.totalAmount - debt.paidAmount;

    if (debt.remainingAmount <= 0) {
      await debt.delete();
    } else {
      await debt.save();
    }

    loadDebts();
  }

  Future<void> addOrUpdateSupplierDebt(String supplierName, double amount, String note) async {
    if (_supplierBox != null && _supplierBox!.isOpen) {
      Supplier? existingSupplier;
      try {
        existingSupplier = _supplierBox!.values.firstWhere(
          (s) => s.name.trim().toLowerCase() == supplierName.trim().toLowerCase(),
        );
      } catch (_) {
        existingSupplier = null;
      }

      if (existingSupplier != null) {
        existingSupplier.remainingAmount += amount;
        if (note.trim().isNotEmpty) {
          existingSupplier.notes = existingSupplier.notes.isEmpty 
              ? note 
              : '${existingSupplier.notes} | $note';
        }
        await existingSupplier.save();
      } else {
        final newSupplier = Supplier(
          name: supplierName.trim(),
          remainingAmount: amount,
          notes: note.trim(),
        );
        await _supplierBox!.add(newSupplier);
      }
      loadSuppliers();
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    if (_supplierBox != null && _supplierBox!.isOpen) {
      _supplierBox!.add(supplier);
      loadSuppliers();
    }
  }

  Future<void> addSupplierPayment(int supplierIndex, SupplierPayment payment) async {
    if (supplierIndex >= 0 && supplierIndex < suppliers.length) {
      final supplier = suppliers[supplierIndex];
      supplier.payments.add(payment);
      supplier.remainingAmount -= payment.amountPaid;

      if (supplier.remainingAmount <= 0) {
        await supplier.delete();
      } else {
        await supplier.save();
      }
      loadSuppliers();
    }
  }
}