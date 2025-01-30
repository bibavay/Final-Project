import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/DActive.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/DHistory.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/Filters.dart';
import 'package:flutter_application_4th_year_project/screens/authenticaion/signin_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _selectedIndex = 0;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        automaticallyImplyLeading: false,
        leading: _selectedIndex != 0 ? IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _selectedIndex = 0; // Return to main dashboard
          });
        },
      ) : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SigninScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home Screen with Cards
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildDashboardCard(
                'Active Orders',
                'View and manage current orders',
                Icons.local_shipping,
                Colors.green,
                () => setState(() => _selectedIndex = 3),
              ),
              const SizedBox(height: 16),
              _buildDashboardCard(
                'Order History',
                'View completed deliveries',
                Icons.history,
                Colors.blue,
                () => setState(() => _selectedIndex = 2),
              ),
               const SizedBox(height: 16),
              _buildDashboardCard(
                'Filter',
                'View all order to filter it',
                Icons.filter_list,
                Colors.blue,
                () => setState(() => _selectedIndex = 1),
              ),
            ],
          ),
          // Filters Screen
          const Filters(),
          // History Screen
          const DHistory(),
          const Dactive(),
        ],
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: _selectedIndex,
      //   onTap: (index) => setState(() => _selectedIndex = index),
      //   items: const [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.dashboard),
      //       label: 'Dashboard',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.filter_list),
      //       label: 'Filters',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.history),
      //       label: 'History',
      //     ),
      //   ],
      // ),
    );
  }

  Widget _buildDashboardCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    size: 35,
                    color: color,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}