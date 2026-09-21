import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/debt.dart';
import 'debt_supplier_provider.dart';

class CartItem {
  final Product product;
  String name;
  double costPrice;
  double sellPrice;
  int quantity;
  double discount;

  CartItem({
    required this.product,
    required this.name,
    required this.costPrice,
    required this.sellPrice,
    required this.quantity,
    this.discount = 0.0,
  });

  double get totalWithDiscount => (sellPrice * quantity) - discount;
  double get discountPerUnit => quantity > 0 ? (discount / quantity) : 0.0;
}

class PosProvider extends ChangeNotifier {
  List<CartItem> cart = [];

  double get totalAmount =>
      cart.fold(0.0, (sum, item) => sum + item.totalWithDiscount);

  String? addToCart(Product product) {
    int index = cart.indexWhere((item) => item.product.key == product.key);
    if (index != -1) {
      if (cart[index].quantity + 1 > product.stockQuantity) {
        return 'الكمية المطلوبة تتجاوز المخزون المتاح!';
      }
      cart[index].quantity += 1;
    } else {
      if (product.stockQuantity < 1) {
        return 'المنتج غير متوفر في المخزون!';
      }
      cart.add(CartItem(
        product: product,
        name: product.name,
        costPrice: product.costPrice,
        sellPrice: product.sellPrice,
        quantity: 1,
      ));
    }
    notifyListeners();
    return null;
  }

  void updateQuantity(int index, int newQty) {
    if (newQty > 0 && newQty <= cart[index].product.stockQuantity) {
      cart[index].quantity = newQty;
      notifyListeners();
    }
  }

  void updateDiscount(int index, double newDiscount) {
    cart[index].discount = newDiscount;
    notifyListeners();
  }

  void removeItem(int index) {
    cart.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  // إتمام البيع كاش
  Future<bool> completeSale() async {
    if (cart.isEmpty) return false;

    for (var item in cart) {
      item.product.stockQuantity -= item.quantity;
      await item.product.save();
    }

    final salesBox = Hive.box<Sale>('sales');
    final List<SaleItem> saleItems = cart
        .map((e) => SaleItem(
              name: e.name,
              costPrice: e.costPrice,
              sellPrice: e.sellPrice,
              quantity: e.quantity,
              discount: e.discountPerUnit,
            ))
        .toList();

    double totalProfit = cart.fold(
        0.0, (sum, e) => sum + (e.totalWithDiscount - (e.costPrice * e.quantity)));

    await salesBox.add(Sale(
      items: saleItems,
      totalAmount: totalAmount,
      totalProfit: totalProfit,
      createdAt: DateTime.now(),
    ));

    clearCart();
    return true;
  }

  // إتمام البيع بالدين مع تمرير تفاصيل الأصناف والأرباح لكائن الدين الجديد
  Future<bool> completeSaleAsDebt(String customerName, DebtSupplierProvider debtProvider) async {
    if (cart.isEmpty || customerName.trim().isEmpty) return false;

    for (var item in cart) {
      item.product.stockQuantity -= item.quantity;
      await item.product.save();
    }

    List<String> itemsTakenList = cart
        .map((item) => '${item.name} (${item.quantity} قطعة)')
        .toList();

    final List<SaleItem> saleItems = cart
        .map((e) => SaleItem(
              name: e.name,
              costPrice: e.costPrice,
              sellPrice: e.sellPrice,
              quantity: e.quantity,
              discount: e.discountPerUnit,
            ))
        .toList();

    double totalProfit = cart.fold(
        0.0, (sum, e) => sum + (e.totalWithDiscount - (e.costPrice * e.quantity)));

    final newDebt = Debt(
      customerName: customerName.trim(),
      totalAmount: totalAmount,
      paidAmount: 0.0,
      remainingAmount: totalAmount,
      itemsTaken: itemsTakenList,
      createdAt: DateTime.now(),
      saleItems: saleItems,
      totalProfit: totalProfit,
    );

    await debtProvider.addDebt(newDebt);

    clearCart();
    return true;
  }
}