import 'package:flutter/material.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/NewDelivery.dart';
import 'package:flutter_application_4th_year_project/screens/Customers/NewTrip.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Place Your Order',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 3, 76, 83),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            _buildOrderButton(
              
              context,
              'New Delivery',
              'Request a new delivery service',
              Icons.local_shipping,
              const Color.fromARGB(255, 5, 110, 120), // Updated color
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewDelivery()),
              ),
            ),
            const SizedBox(height: 20),
            _buildOrderButton(
              context,
              'New Trip',
              'Book a new trip',
              Icons.directions_car,
              const Color.fromARGB(255, 6, 109, 118), // Updated color
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Newtrip()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
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
    );
  }
}