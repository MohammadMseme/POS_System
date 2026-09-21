import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/supplier.dart';
import '../models/debt.dart';
import '../models/note.dart';

class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();

    // تسجيل Adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SaleItemAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SaleAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SupplierPaymentAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(SupplierAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(DebtAdapter());
    
    // 1. إضافة تسجيل الـ NoteAdapter (تأكد أن الرقم 6 غير مستخدم في نموذج آخر، أو حسب رقم الـ TypeId في ملف note.dart)
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(NoteAdapter());

    // فتح الصناديق مع المعالجة الآمنة
    await _openBoxSafely<Product>('products');
    await _openBoxSafely<Sale>('sales');
    await _openBoxSafely<Supplier>('suppliers');
    await _openBoxSafely<Debt>('debts');
    
    // 2. استخدام الفتح الآمن لصندوق الملاحظات أيضاً
    await _openBoxSafely<Note>('notes');
  }

  static Future<void> _openBoxSafely<T>(String boxName) async {
    try {
      await Hive.openBox<T>(boxName);
    } catch (e) {
      // إغلاق الصندوق إذا كان مفتوحاً جزئياً لفك القفل عن الملف
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<T>(boxName).close();
      }
      
      // حذف الصندوق وإعادة إتاحة فتح صندوق جديد نظيف
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {
        // في حال استمرار قفل الملف على Windows
      }
      
      await Hive.openBox<T>(boxName);
    }
  }
}