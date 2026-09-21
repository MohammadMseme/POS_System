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
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale),
            label: 'نقطة البيع',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2),
            label: 'المنتجات',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'الجرد والتنبيهات',
          ),
          NavigationDestination(
            icon: Icon(Icons.money_off),
            label: 'الديون',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping),
            label: 'حسابات التجار',
          ),
          // 3. إضافة زر الملاحظات في شريط التنقل السفلي
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'الملاحظات',
          ),
        ],
      ),
    );
  }
}