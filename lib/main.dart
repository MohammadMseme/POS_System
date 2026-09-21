import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. استيراد الخدمات
import 'services/hive_service.dart';

// 2. استيراد كافة الـ Providers المعرفة في مشروعك
import 'providers/product_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/debt_supplier_provider.dart';

// 3. استيراد الشاشة الرئيسية
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة قاعدة البيانات المحلية Hive وفتح جميع الصناديق
  await HiveService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => DebtSupplierProvider()),
      ],
      child: const HouseholdStoreApp(),
    ),
  );
}

class HouseholdStoreApp extends StatelessWidget {
  const HouseholdStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة معرض الأدوات المنزلية',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', ''),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        fontFamily: 'Segoe UI',
      ),
      home: const MainNavigationScreen(),
    );
  }
}