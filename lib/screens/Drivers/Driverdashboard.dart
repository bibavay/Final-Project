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

  // PreferredSizeWidget _buildAppBar() {
  //   switch (_selectedIndex) {
  //     case 0: // Explorer
  //       return AppBar(
  //         backgroundColor: Color.fromARGB(255, 3, 76, 83),
  //         foregroundColor: Colors.white,
  //         title: Text(_titles[_selectedIndex]),
  //         automaticallyImplyLeading: false,
  //       );
      
  //     case 1: // History
  //       return AppBar(
  //         backgroundColor: Color.fromARGB(255, 3, 76, 83),
  //         foregroundColor: Colors.white,
  //         title: Text(_titles[_selectedIndex]),
  //         automaticallyImplyLeading: false,
  //       );
      
  //     case 2: // Profile
  //       return AppBar(
  //         backgroundColor: Color.fromARGB(255, 3, 76, 83),
  //         foregroundColor: Colors.white,
  //         title: Text(_titles[_selectedIndex]),
  //         automaticallyImplyLeading: false,
  //         elevation: 0,
  //       );
      
  //     default:
  //       return AppBar(
  //         backgroundColor: Color.fromARGB(255, 3, 76, 83),
  //         foregroundColor: Colors.white,
  //         title: Text(_titles[_selectedIndex]),
  //         automaticallyImplyLeading: false,
  //       );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     // appBar: _buildAppBar(),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Color.fromARGB(255, 3, 76, 83),
          selectedItemColor: const Color.fromARGB(255, 255, 255, 255),
          unselectedItemColor: const Color.fromARGB(255, 204, 204, 204),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explorer',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}