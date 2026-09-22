import 'package:flutter/material.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'inventory_screen.dart';
import 'debts_screen.dart';
import 'suppliers_screen.dart';
import 'notes_screen.dart'; // 1. استيراد ملف صفحة الملاحظات الجديد

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // 2. إضافة NotesScreen إلى قائمة الشاشات
  final List<Widget> _screens = const [
    PosScreen(),
    ProductsScreen(),
    InventoryScreen(),
    DebtsScreen(),
    SuppliersScreen(),
    NotesScreen(), // شاشة الملاحظات الجديدة
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // استخدام IndexedStack يحافظ على حال البيانات في كل شاشة عند التنقل بينها ولا يعيد تحميلها من الصفر
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          // تخصيص الألوان والتصميم العصري الموحد
          backgroundColor: Colors.white,
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          elevation: 0,
          height: 65,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFF1565C0)),
              label: 'نقطة البيع',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF1565C0)),
              label: 'المنتجات',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics, color: Color(0xFF1565C0)),
              label: 'الجرد',
            ),
            NavigationDestination(
              icon: Icon(Icons.money_off_outlined),
              selectedIcon: Icon(Icons.money_off, color: Color(0xFF1565C0)),
              label: 'الديون',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping, color: Color(0xFF1565C0)),
              label: 'التجار',
            ),
            NavigationDestination(
              icon: Icon(Icons.book_outlined),
              selectedIcon: Icon(Icons.book, color: Color(0xFF1565C0)),
              label: 'الملاحظات',
            ),
          ],
        ),
      ),
    );
  }
}