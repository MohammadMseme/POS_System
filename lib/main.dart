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
      // الثيم العام المطور والموحد لكل التطبيق باللون الأزرق العصري
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: const Color(0xFF1565C0), // أزرق غامق احترافي وبارز
          secondary: const Color(0xFF42A5F5), // أزرق فاتح مكمل
          surface: Colors.grey.shade50,     // خلفية عامة مريحة للعين
        ),
        fontFamily: 'Segoe UI',
        
        // 1. توحيد شكل شريط العنوان (AppBar) في كافة الواجهات
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),

        // 2. توحيد شكل البطاقات (Cards) لتكون بحواف دائرية ناعمة وحدود نظيفة
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),

        // 3. توحيد شكل حقول الإدخال (TextFormFields) في كل الشاشات
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
          ),
        ),

        // 4. توحيد شكل الأزرار البارزة (ElevatedButtons)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}