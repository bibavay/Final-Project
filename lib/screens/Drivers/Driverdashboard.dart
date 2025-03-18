import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/Explorer.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/DHistory.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/DriverProfile.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const Explorer(),      // Explorer
    const DHistory(),     // Order History
    const DriverProfile() // Profile
  ];

  final List<String> _titles = [
    'Explorer',
    'Order History',
    'Profile'
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
              _buildNavItem(Icons.explore_outlined, Icons.explore, 'Explorer'),
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