import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_4th_year_project/screens/Drivers/Droute.dart';
import 'package:intl/intl.dart';

class Explorer extends StatefulWidget {
  const Explorer({super.key});

  @override
  State<Explorer> createState() => _ExplorerState();
}

class _ExplorerState extends State<Explorer> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _tripStatusFilter = 'all';
  String _deliveryStatusFilter = 'all';
  
  final List<String> _statusFilters = ['all', 'pending', 'accepted', 'in_progress'];

  // Trip filter variables
  String _tripPickupGovernorateFilter = 'all';
  String _tripPickupDistrictFilter = 'all';
  String _tripDropoffGovernorateFilter = 'all';
  String _tripDropoffDistrictFilter = 'all';
  int _minPassengersFilter = 0;
  bool _tripRestrictionsFilter = false;

  // Delivery filter variables
  String _deliveryPickupGovernorateFilter = 'all';
  String _deliveryPickupDistrictFilter = 'all';
  String _deliveryDropoffGovernorateFilter = 'all';
  String _deliveryDropoffDistrictFilter = 'all';
  double _minWeightFilter = 0;
  double _maxWeightFilter = 0;
  double _minDimensionsFilter = 0;
  bool _deliveryRestrictionsFilter = false;

  final Map<String, List<String>> kurdistanCities = {
    'Erbil': [
      'Erbil City',
      'Shaqlawa',
      'Soran',
      'Koya',
      'Mergasur', 
      'Choman',
      'Makhmur',
    ],
    'Sulaymaniyah': [
      'Sulaymaniyah City',
      'Halabja',
      'Ranya',
      'Penjwin',
      'Dukan',
      'Chamchamal',
      'Kalar',
    ],
    'Duhok': [
      'Duhok City',
      'Zakho',
      'Amedi',
      'Akre',
      'Bardarash',
      'Shekhan',
      'Semel',
    ],
    'Halabja': [
      'Halabja City',
      'Shahrizor',
      'Khurmal',
      'Sirwan',
    ],
  };

  Stream<List<ActiveOrder>> _getActiveTrips() {
    Query baseQuery = _firestore.collection('trips');
    final driverId = _auth.currentUser?.uid;
    
    return baseQuery
        .where('status', whereIn: ['pending', 'driver_pending', 'confirmed'])
        .orderBy('tripDate', descending: true)
        .snapshots()
        .map((snapshot) {
            List<ActiveOrder> allOrders = snapshot.docs
                .map((doc) => ActiveOrder.fromFirestore(doc))
                .where((order) {
                  if (order.status == 'confirmed') {
                    return order.details['driverId'] == driverId;
                  }
                  return order.status == 'pending' ||
                         (order.status == 'driver_pending' &&
                          order.details['pendingDriverId'] == driverId);
                })
                .toList();
            
            allOrders.sort((a, b) {
              int getPriority(String status) {
                switch (status) {
                  case 'confirmed': return 2;
                  case 'driver_pending': return 1;
                  case 'pending': return 0;
                  default: return -1;
                }
              }
              int priorityA = getPriority(a.status);
              int priorityB = getPriority(b.status);
              if (priorityA != priorityB) {
                return priorityB.compareTo(priorityA);
              }
              return b.dateTime.compareTo(a.dateTime);
            });

            // Apply pickup governorate filter on pickupCity if set
            if (_tripPickupGovernorateFilter != 'all') {
              allOrders = allOrders.where((order) {
                bool pickupGovernorateMatch = (order.details['pickupCity'] ?? '').toString().toLowerCase() ==
                       _tripPickupGovernorateFilter.toLowerCase();
                if (_tripPickupDistrictFilter != 'all') {
                  return pickupGovernorateMatch && 
                         (order.details['pickupRegion'] ?? '').toString().toLowerCase() ==
                         _tripPickupDistrictFilter.toLowerCase();
                }
                return pickupGovernorateMatch;
              }).toList();
            }
            // Apply dropoff governorate filter on dropoffCity if set
            if (_tripDropoffGovernorateFilter != 'all') {
              allOrders = allOrders.where((order) {
                bool dropoffGovernorateMatch = (order.details['dropoffCity'] ?? '').toString().toLowerCase() ==
                       _tripDropoffGovernorateFilter.toLowerCase();
                if (_tripDropoffDistrictFilter != 'all') {
                  return dropoffGovernorateMatch && 
                         (order.details['dropoffRegion'] ?? '').toString().toLowerCase() ==
                         _tripDropoffDistrictFilter.toLowerCase();
                }
                return dropoffGovernorateMatch;
              }).toList();
            }
            // Apply restrictions filter if enabled
            if (_tripRestrictionsFilter) {
              allOrders = allOrders.where((order) {
                return order.details['restrictions'] == true;
              }).toList();
            }
            // Apply minimum passengers filter for Trip orders
            if (_minPassengersFilter > 0) {
              allOrders = allOrders.where((order) {
                if (order.type == 'Trip' && order.details['passengers'] != null) {
                  List passengers = order.details['passengers'] as List;
                  return passengers.length >= _minPassengersFilter;
                }
                return true;
              }).toList();
            }
            
            return allOrders;
        });
  }

  Stream<List<ActiveOrder>> _getActiveDeliveries() {
    Query baseQuery = _firestore.collection('deliveries');
    final driverId = _auth.currentUser?.uid;
    
    return baseQuery
        .where('status', whereIn: ['pending', 'driver_pending', 'confirmed'])
        .orderBy('deliveryDate', descending: true)
        .snapshots()
        .map((snapshot) {
            List<ActiveOrder> allOrders = snapshot.docs
                .map((doc) => ActiveOrder.fromFirestore(doc))
                .where((order) {
                  if (order.status == 'confirmed') {
                    return order.details['driverId'] == driverId;
                  }
                  return order.status == 'pending' ||
                         (order.status == 'driver_pending' &&
                          order.details['pendingDriverId'] == driverId);
                })
                .toList();
            
            allOrders.sort((a, b) {
              int getPriority(String status) {
                switch (status) {
                  case 'confirmed': return 2;
                  case 'driver_pending': return 1;
                  case 'pending': return 0;
                  default: return -1;
                }
              }
              int priorityA = getPriority(a.status);
              int priorityB = getPriority(b.status);
              if (priorityA != priorityB) {
                return priorityB.compareTo(priorityA);
              }
              return b.dateTime.compareTo(a.dateTime);
            });

            // Apply pickup governorate filter on pickupRegion if set
            if (_deliveryPickupGovernorateFilter != 'all') {
              allOrders = allOrders.where((order) {
                bool pickupGovernorateMatch = (order.details['pickupRegion'] ?? '').toString().toLowerCase() ==
                       _deliveryPickupGovernorateFilter.toLowerCase();
                if (_deliveryPickupDistrictFilter != 'all') {
                  return pickupGovernorateMatch && 
                         (order.details['pickupCity'] ?? '').toString().toLowerCase() ==
                         _deliveryPickupDistrictFilter.toLowerCase();
                }
                return pickupGovernorateMatch;
              }).toList();
            }
            // Apply dropoff governorate filter on dropoffRegion if set
            if (_deliveryDropoffGovernorateFilter != 'all') {
              allOrders = allOrders.where((order) {
                bool dropoffGovernorateMatch = (order.details['dropoffRegion'] ?? '').toString().toLowerCase() ==
                       _deliveryDropoffGovernorateFilter.toLowerCase();
                if (_deliveryDropoffDistrictFilter != 'all') {
                  return dropoffGovernorateMatch && 
                         (order.details['dropoffCity'] ?? '').toString().toLowerCase() ==
                         _deliveryDropoffDistrictFilter.toLowerCase();
                }
                return dropoffGovernorateMatch;
              }).toList();
            }
            // Apply restrictions filter if enabled
            if (_deliveryRestrictionsFilter) {
              allOrders = allOrders.where((order) {
                return order.details['restrictions'] == true;
              }).toList();
            }
            // Apply weight and dimensions filters for Delivery orders
            if (_minWeightFilter > 0 || _maxWeightFilter > 0 || _minDimensionsFilter > 0) {
              allOrders = allOrders.where((order) {
                if (order.type == 'Delivery' && order.details['package'] != null) {
                  final package = order.details['package'] as Map<String, dynamic>;
                  final weight = package['weight'] ?? 0.0;
                  final dimensions = package['dimensions'] ?? 0.0;
                  return (weight >= _minWeightFilter && weight <= _maxWeightFilter) &&
                         dimensions >= _minDimensionsFilter;
                }
                return true;
              }).toList();
            }
            
            return allOrders;
        });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 3, 76, 83),
          foregroundColor: Colors.white,
          title: const Text('Explorer'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: Icon(Icons.directions_car),
                text: "Trips",
              ),
              Tab(
                icon: Icon(Icons.local_shipping),
                text: "Deliveries",
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTripsTab(),
            _buildDeliveriesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(String currentFilter, Function(String) onFilterChanged) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: _statusFilters.map((status) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(status.toUpperCase()),
              selected: currentFilter == status,
              onSelected: (_) => onFilterChanged(status),
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: currentFilter == status
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterButton(bool isTripsTab) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        onPressed: () => isTripsTab ? _showTripFilterDialog() : _showDeliveryFilterDialog(),
        icon: const Icon(Icons.filter_list),
        label: Text('Filter ${isTripsTab ? 'Trips' : 'Deliveries'}'),
      ),
    );
  }

  Future<void> _showTripFilterDialog() async {
    String selectedPickupGovernorate = _tripPickupGovernorateFilter;
    String selectedPickupDistrict = _tripPickupDistrictFilter;
    String selectedDropoffGovernorate = _tripDropoffGovernorateFilter;
    String selectedDropoffDistrict = _tripDropoffDistrictFilter;
    TextEditingController passengersController = TextEditingController(
      text: _minPassengersFilter > 0 ? _minPassengersFilter.toString() : '',
    );
    bool restrictions = _tripRestrictionsFilter;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Trips'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pickup Location', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedPickupGovernorate,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Governorate',
                  ),
                  items: ['all', ...kurdistanCities.keys].map((city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPickupGovernorate = value ?? 'all';
                      selectedPickupDistrict = 'all';
                    });
                  },
                ),
                if (selectedPickupGovernorate != 'all') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedPickupDistrict,
                    decoration: const InputDecoration(
                      labelText: 'Pickup District',
                    ),
                    items: ['all', ...(kurdistanCities[selectedPickupGovernorate] ?? [])].map((district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPickupDistrict = value ?? 'all';
                      });
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Text('Dropoff Location', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedDropoffGovernorate,
                  decoration: const InputDecoration(
                    labelText: 'Dropoff Governorate',
                  ),
                  items: ['all', ...kurdistanCities.keys].map((city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDropoffGovernorate = value ?? 'all';
                      selectedDropoffDistrict = 'all';
                    });
                  },
                ),
                if (selectedDropoffGovernorate != 'all') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDropoffDistrict,
                    decoration: const InputDecoration(
                      labelText: 'Dropoff District',
                    ),
                    items: ['all', ...(kurdistanCities[selectedDropoffGovernorate] ?? [])].map((district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDropoffDistrict = value ?? 'all';
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: passengersController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Passengers',
                  ),
                  keyboardType: TextInputType.number,
                ),
                CheckboxListTile(
                  value: restrictions,
                  title: const Text('Only trips with restrictions'),
                  onChanged: (value) {
                    setState(() {
                      restrictions = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _tripPickupGovernorateFilter = selectedPickupGovernorate;
                  _tripPickupDistrictFilter = selectedPickupDistrict;
                  _tripDropoffGovernorateFilter = selectedDropoffGovernorate;
                  _tripDropoffDistrictFilter = selectedDropoffDistrict;
                  _minPassengersFilter = int.tryParse(passengersController.text.trim()) ?? 0;
                  _tripRestrictionsFilter = restrictions;
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeliveryFilterDialog() async {
    String selectedPickupGovernorate = _deliveryPickupGovernorateFilter;
    String selectedPickupDistrict = _deliveryPickupDistrictFilter;
    String selectedDropoffGovernorate = _deliveryDropoffGovernorateFilter;
    String selectedDropoffDistrict = _deliveryDropoffDistrictFilter;
    TextEditingController minWeightController = TextEditingController(
      text: _minWeightFilter > 0 ? _minWeightFilter.toString() : '',
    );
    TextEditingController maxWeightController = TextEditingController(
      text: _maxWeightFilter > 0 ? _maxWeightFilter.toString() : '',
    );
    TextEditingController minDimensionsController = TextEditingController(
      text: _minDimensionsFilter > 0 ? _minDimensionsFilter.toString() : '',
    );
    bool restrictions = _deliveryRestrictionsFilter;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Deliveries'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pickup Location', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedPickupGovernorate,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Governorate',
                  ),
                  items: ['all', ...kurdistanCities.keys].map((city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPickupGovernorate = value ?? 'all';
                      selectedPickupDistrict = 'all';
                    });
                  },
                ),
                if (selectedPickupGovernorate != 'all') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedPickupDistrict,
                    decoration: const InputDecoration(
                      labelText: 'Pickup District',
                    ),
                    items: ['all', ...(kurdistanCities[selectedPickupGovernorate] ?? [])].map((district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPickupDistrict = value ?? 'all';
                      });
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Text('Dropoff Location', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedDropoffGovernorate,
                  decoration: const InputDecoration(
                    labelText: 'Dropoff Governorate',
                  ),
                  items: ['all', ...kurdistanCities.keys].map((city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDropoffGovernorate = value ?? 'all';
                      selectedDropoffDistrict = 'all';
                    });
                  },
                ),
                if (selectedDropoffGovernorate != 'all') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDropoffDistrict,
                    decoration: const InputDecoration(
                      labelText: 'Dropoff District',
                    ),
                    items: ['all', ...(kurdistanCities[selectedDropoffGovernorate] ?? [])].map((district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDropoffDistrict = value ?? 'all';
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: minWeightController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Weight (kg)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: maxWeightController,
                  decoration: const InputDecoration(
                    labelText: 'Maximum Weight (kg)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: minDimensionsController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Dimensions (cm³)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                CheckboxListTile(
                  value: restrictions,
                  title: const Text('Only deliveries with restrictions'),
                  onChanged: (value) {
                    setState(() {
                      restrictions = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _deliveryPickupGovernorateFilter = selectedPickupGovernorate;
                  _deliveryPickupDistrictFilter = selectedPickupDistrict;
                  _deliveryDropoffGovernorateFilter = selectedDropoffGovernorate;
                  _deliveryDropoffDistrictFilter = selectedDropoffDistrict;
                  _minWeightFilter = double.tryParse(minWeightController.text.trim()) ?? 0;
                  _maxWeightFilter = double.tryParse(maxWeightController.text.trim()) ?? 0;
                  _minDimensionsFilter = double.tryParse(minDimensionsController.text.trim()) ?? 0;
                  _deliveryRestrictionsFilter = restrictions;
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsTab() {
    return StreamBuilder<List<ActiveOrder>>(
       stream: _getActiveTrips(),
       builder: (context, snapshot) {
         print('Trip Stream State: ${snapshot.connectionState}'); // Debug log
         print('Trip Error: ${snapshot.error}'); // Debug log
         print('Trip Data Length: ${snapshot.data?.length}'); // Debug log

         if (snapshot.hasError) {
           return Center(child: Text('Error: ${snapshot.error}'));
         }

         if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
         }

         final trips = snapshot.data ?? [];

         return Column(
           children: [
             _buildFilterButton(true),
             Expanded(
               child: trips.isEmpty
                   ? const Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
                           SizedBox(height: 16),
                           Text('No active trips available',
                               style: TextStyle(fontSize: 16, color: Colors.grey)),
                         ],
                       ),
                     )
                   : ListView.builder(
                       itemCount: trips.length,
                       padding: const EdgeInsets.all(8),
                       itemBuilder: (context, index) {
                         final order = trips[index];
                         return _buildOrderCard(order);
                       },
                     ),
             ),
           ],
         );
       },
    );
  }

  Widget _buildTripDetails(ActiveOrder order) {
    final details = order.details;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trip Information:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(order.dateTime)),
          _buildInfoRow('Time', details['tripTime'] ?? 'Not specified'),
          _buildInfoRow('Status', order.status.toUpperCase()),
          
          const Divider(height: 24),
          
          Text('Route Details:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From:', style: TextStyle(color: Colors.grey[600])),
                            Text('${details['pickupCity']}, ${details['pickupRegion']}',
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To:', style: TextStyle(color: Colors.grey[600])),
                            Text('${details['dropoffCity']}, ${details['dropoffRegion']}',
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 24),

          if (details['passengers'] != null) ...[
            Text('Passenger Information:', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List<Map<String, dynamic>>.from(details['passengers'])
                .map((passenger) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Gender', passenger['gender'] ?? 'N/A'),
                            _buildInfoRow('Age', passenger['age']?.toString() ?? 'N/A'),
                            const Divider(height: 16),
                            _buildInfoRow('Pickup', '${passenger['pickupCity']}, ${passenger['pickupRegion']}'),
                            _buildInfoRow('Drop-off', '${passenger['dropoffCity']}, ${passenger['dropoffRegion']}'),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDeliveriesTab() {
    return StreamBuilder<List<ActiveOrder>>(
      stream: _getActiveDeliveries(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('failed-precondition')) {
            return const Center(
              child: Text('Database index is being created. Please wait a few minutes and try again.'),
            );
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final deliveries = snapshot.data ?? [];
        
        return Column(
          children: [
            _buildFilterButton(false),
            Expanded(
              child: deliveries.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 64, color: Color.fromARGB(255, 3, 76, 83)),
                          SizedBox(height: 16),
                          Text('No active deliveries available',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: deliveries.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final order = deliveries[index];
                        return _buildOrderCard(order);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeliveryDetails(Map<String, dynamic> details) {
    final package = details['package'] as Map<String, dynamic>? ?? {};
    final locations = package['locations'] as Map<String, dynamic>? ?? {};
    final source = locations['source'] as Map<String, dynamic>? ?? {};
    final destination = locations['destination'] as Map<String, dynamic>? ?? {};
    final dimensions = package['dimensions'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Date', details['deliveryDate'] != null 
              ? DateFormat('MMM dd, yyyy').format((details['deliveryDate'] as Timestamp).toDate())
              : 'N/A'),
          _buildInfoRow('Time', details['deliveryTime'] ?? 'N/A'),
          _buildInfoRow('Status', details['status']?.toUpperCase() ?? 'PENDING'),

          const Divider(height: 24),

          Text('Route Details:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationRow(
                    'Pickup Location',
                    '${source['city'] ?? 'N/A'}, ${source['region'] ?? 'N/A'}',
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildLocationRow(
                    'Drop-off Location',
                    '${destination['city'] ?? 'N/A'}, ${destination['region'] ?? 'N/A'}',
                    Colors.green,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 24),

          Text('Package Details:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Dimensions',
                      '${dimensions['height'] ?? 'N/A'}x${dimensions['width'] ?? 'N/A'}x${dimensions['depth'] ?? 'N/A'} cm'),
                  _buildInfoRow('Weight', '${dimensions['weight'] ?? 'N/A'} kg'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', 
            style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _acceptOrder(String orderId, String type) async {
    try {
      final driverId = _auth.currentUser?.uid;
      if (driverId == null) throw Exception('Not logged in');

      final collection = type == 'Trip' ? 'trips' : 'deliveries';
      final orderRef = _firestore.collection(collection).doc(orderId);

      final docSnap = await orderRef.get();
      if (!docSnap.exists) {
        throw Exception('Order no longer exists');
      }

      final orderData = docSnap.data() as Map<String, dynamic>;
      if (orderData['pendingDriverId'] != null || orderData['driverId'] != null) {
        throw Exception('Order has already been requested by another driver');
      }

      await _notifyCustomer(orderId, type, driverId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent to customer. Waiting for confirmation...'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error accepting ${type.toLowerCase()}: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _notifyCustomer(String orderId, String type, String driverId) async {
    try {
      final collection = type == 'Trip' ? 'trips' : 'deliveries';
      final orderRef = _firestore.collection(collection).doc(orderId);
      
      final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
      final driverData = driverDoc.data() as Map<String, dynamic>;
      final driverRating = driverData['averageRating'] ?? 0.0;
      final totalRatings = driverData['totalRatings'] ?? 0;

      final orderDoc = await orderRef.get();
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final userId = orderData['userId'];

      await orderRef.update({
        'pendingDriverId': driverId,
        'driverRating': driverRating,
        'driverTotalRatings': totalRatings,
        'driverRequestTime': FieldValue.serverTimestamp(),
        'status': 'driver_pending',
      });

      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'driver_request',
        'orderId': orderId,
        'orderType': type,
        'driverId': driverId,
        'driverRating': driverRating,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false
      });
    } catch (e) {
      print('Error notifying customer: $e');
      throw e;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color.fromARGB(255, 235, 141, 0);
      case 'driver_pending':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOrderCard(ActiveOrder order) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: Icon(
          order.type == 'Trip' ? Icons.directions_car : Icons.local_shipping,
          color: order.status == 'driver_pending' ? Colors.blue :  Color(0xFF007074),
          
        ),
        title: Text('${order.type} #${order.id.substring(0, 8)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd, yyyy HH:mm').format(order.dateTime),
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Status: ${order.status.toUpperCase()}',
              style: TextStyle(
                color: _getStatusColor(order.status),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        children: [
          order.type == 'Trip' 
              ? _buildTripDetails(order)
              : _buildDeliveryDetails(order.details),
          if (order.status == 'confirmed' || order.status == 'driver_pending') ...[
            _buildDriverRequest({
              ...order.details,
              'status': order.status,
              'type': order.type,
            }),
            const SizedBox(height: 16),
          ],
          if (order.status == 'pending')
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _acceptOrder(order.id, order.type),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: Text(
                  'Accept ${order.type}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(Icons.location_on, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverRating(double rating, int totalRatings) {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 20),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} ($totalRatings reviews)',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverRequest(Map<String, dynamic> details) {
    final bool isConfirmed = details['status'] == 'confirmed';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConfirmed 
            ? Colors.green.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConfirmed
              ? Colors.green.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3)
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConfirmed ? Icons.check_circle : Icons.pending_actions,
                color: isConfirmed ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                isConfirmed ? 'Request Confirmed' : 'Request Pending',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isConfirmed ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isConfirmed 
                ? 'Customer has accepted your request'
                : 'Waiting for customer confirmation...',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          if (details['driverRequestTime'] != null) ...[
            Text(
              'Requested: ${DateFormat('MMM dd, yyyy HH:mm')
                  .format((details['driverRequestTime'] as Timestamp).toDate())}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
          if (isConfirmed && details['confirmedAt'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Confirmed: ${DateFormat('MMM dd, yyyy HH:mm')
                  .format((details['confirmedAt'] as Timestamp).toDate())}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                print('Debug: ${details['type']}'); // Add this debug print
                print('Debug - Order Details: ${details.toString()}');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Droute(
                     // orderDetails: details,
                      //orderType: details['type'] ?? 'Order',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('View Route'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement start trip/delivery
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: Text('Start ${details['type'] ?? 'Order'}'),
            ),
          ],
        ],
      ),
    );
  }
}

class ActiveOrder {
  final String id;
  final String type;
  final DateTime dateTime;
  final String status;
  final Map<String, dynamic> details;
  
  ActiveOrder({
    required this.id,
    required this.type,
    required this.dateTime,
    required this.status,
    required this.details,
  });
  
factory ActiveOrder.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  print('Processing document: ${doc.id}'); // Debug log
  print('Document data: $data'); // Debug log
  
  DateTime orderDateTime;
  String type;
  
  try {
    if (data['tripDate'] != null) {
      orderDateTime = (data['tripDate'] as Timestamp).toDate();
      type = 'Trip';
    } else if (data['deliveryDate'] != null) {
      orderDateTime = (data['deliveryDate'] as Timestamp).toDate();
      type = 'Delivery';
    } else {
      print('Warning: No date found for order ${doc.id}'); // Debug log
      orderDateTime = DateTime.now();
      type = 'Unknown';
    }

    data['type'] = type;

    return ActiveOrder(
      id: doc.id,
      type: type,
      dateTime: orderDateTime,
      status: data['status'] ?? 'pending',
      details: data,
    );
  } catch (e) {
    print('Error processing document ${doc.id}: $e'); // Debug log
    rethrow;
  }
}
}