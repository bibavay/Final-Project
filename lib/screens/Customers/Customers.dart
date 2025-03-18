import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/CActive.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/CHistory.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/CustomerProfile.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/Order.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const OrderScreen(),
    const CActive(),
    const CHistory(),
    const CustomerProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            backgroundColor: const Color.fromARGB(255, 3, 76, 83),
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.5),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: [
              _buildNavItem(Icons.add_box_outlined, Icons.add_box, 'Order'),
              _buildNavItem(Icons.pending_actions_outlined, Icons.pending_actions, 'Active'),
              _buildNavItem(Icons.history_outlined, Icons.history, 'History'),
              _buildNavItem(Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Icon(icon),
      ),
      activeIcon: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white,
              width: 2,
            ),
          ),
        ),
        child: Icon(activeIcon),
      ),
      label: label,
    );
  }
}