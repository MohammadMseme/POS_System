import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'inventory_screen.dart';
import 'debts_screen.dart';
import 'suppliers_screen.dart';
import 'salaries_expenses_screen.dart'; // رواتب ومفرقات
import 'calculator_screen.dart'; // NEW: حاسبة
import 'notes_screen.dart';
import 'setting_screen.dart'; // settings tab (change password / lock app)

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

/// One tab of the bottom navigation bar.
class _NavTab {
  final Widget screen;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// true -> also shown to the Employee role.
  final bool employeeAllowed;

  const _NavTab({
    required this.screen,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.employeeAllowed = false,
  });
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // NEW (roles): every tab declares whether the Employee may see it.
  // Employee: POS, Inventory (sales log only), Debts (repayments only),
  // Calculator and Settings (lock app only). Admin: everything.
  static const List<_NavTab> _allTabs = [
    _NavTab(
      screen: PosScreen(),
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      label: 'نقطة البيع',
      employeeAllowed: true,
    ),
    _NavTab(
      screen: ProductsScreen(),
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'المنتجات',
    ),
    _NavTab(
      screen: InventoryScreen(),
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'الجرد',
      employeeAllowed: true,
    ),
    _NavTab(
      screen: DebtsScreen(),
      icon: Icons.money_off_outlined,
      selectedIcon: Icons.money_off,
      label: 'الديون',
      employeeAllowed: true,
    ),
    _NavTab(
      screen: SuppliersScreen(),
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping,
      label: 'التجار',
    ),
    _NavTab(
      screen: SalariesExpensesScreen(),
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'رواتب',
    ),
    _NavTab(
      screen: CalculatorScreen(),
      icon: Icons.calculate_outlined,
      selectedIcon: Icons.calculate,
      label: 'حاسبة',
      employeeAllowed: true,
    ),
    _NavTab(
      screen: NotesScreen(),
      icon: Icons.book_outlined,
      selectedIcon: Icons.book,
      label: 'الملاحظات',
    ),
    _NavTab(
      screen: SettingsScreen(),
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'الإعدادات',
      employeeAllowed: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isAdmin = context.watch<AuthProvider>().isAdmin;

    // Restricted pages are not just hidden from the bar - they are never
    // built at all for the Employee, so their data can't leak.
    final tabs = isAdmin
        ? _allTabs
        : _allTabs.where((t) => t.employeeAllowed).toList();
    final int index = _selectedIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      // استخدام IndexedStack يحافظ على حال البيانات في كل شاشة عند التنقل بينها ولا يعيد تحميلها من الصفر
      body: IndexedStack(
        index: index,
        children: tabs.map((t) => t.screen).toList(),
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
          selectedIndex: index,
          onDestinationSelected: (i) {
            setState(() {
              _selectedIndex = i;
            });
          },
          // تخصيص الألوان والتصميم العصري الموحد
          backgroundColor: Colors.white,
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          elevation: 0,
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: tabs
              .map((t) => NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon, color: const Color(0xFF1565C0)),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
