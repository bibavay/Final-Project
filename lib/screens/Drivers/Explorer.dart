import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'Droute.dart';

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
  DateTime? _tripDateFilter;

  // Delivery filter variables
  String _deliveryPickupGovernorateFilter = 'all';
  String _deliveryPickupDistrictFilter = 'all';
  String _deliveryDropoffGovernorateFilter = 'all';
  String _deliveryDropoffDistrictFilter = 'all';
  double _minWeightFilter = 0;
  double _maxWeightFilter = 0;
  double _minDimensionsFilter = 0;
  bool _deliveryRestrictionsFilter = false;
  DateTime? _deliveryDateFilter;

  final Map<String, List<String>> kurdistanCities = {
    'Erbil': [
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

    // Add base query conditions
    baseQuery = baseQuery.where('status', whereIn: ['pending', 'driver_pending', 'confirmed']);

    // Add location filters to the query
    if (_tripPickupGovernorateFilter != 'all') {
      baseQuery = baseQuery.where('routeDetails.pickupCity', isEqualTo: _tripPickupGovernorateFilter);
      if (_tripPickupDistrictFilter != 'all') {
        baseQuery = baseQuery.where('routeDetails.pickupRegion', isEqualTo: _tripPickupDistrictFilter);
      }
    }

    if (_tripDropoffGovernorateFilter != 'all') {
      baseQuery = baseQuery.where('routeDetails.dropoffCity', isEqualTo: _tripDropoffGovernorateFilter);
      if (_tripDropoffDistrictFilter != 'all') {
        baseQuery = baseQuery.where('routeDetails.dropoffRegion', isEqualTo: _tripDropoffDistrictFilter);
      }
    }

    return baseQuery.snapshots().map((snapshot) {
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

      // Apply remaining filters in memory
      if (_minPassengersFilter > 0) {
        allOrders = allOrders.where((order) {
          if (order.details['passengers'] != null) {
            List passengers = order.details['passengers'] as List;
            return passengers.length >= _minPassengersFilter;
          }
          return false;
        }).toList();
      }

      if (_tripRestrictionsFilter) {
        allOrders = allOrders.where((order) => 
          order.details['restrictions'] == true
        ).toList();
      }

      if (_tripDateFilter != null) {
        String filterDate = DateFormat('yyyy-MM-dd').format(_tripDateFilter!);
        allOrders = allOrders.where((order) {
          String orderDate = DateFormat('yyyy-MM-dd').format(order.dateTime);
          return orderDate == filterDate;
        }).toList();
      }

      return allOrders;
    });
  }

  Stream<List<ActiveOrder>> _getActiveDeliveries() {
    Query baseQuery = _firestore.collection('deliveries');
    final driverId = _auth.currentUser?.uid;

    // Add base query conditions
    baseQuery = baseQuery.where('status', whereIn: ['pending', 'driver_pending', 'confirmed']);

    // Add location filters to the query
    if (_deliveryPickupGovernorateFilter != 'all') {
      baseQuery = baseQuery.where('package.locations.source.city', 
          isEqualTo: _deliveryPickupGovernorateFilter);
    }

    if (_deliveryDropoffGovernorateFilter != 'all') {
      baseQuery = baseQuery.where('package.locations.destination.city', 
          isEqualTo: _deliveryDropoffGovernorateFilter);
    }

    return baseQuery.snapshots().map((snapshot) {
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

      // Apply remaining filters in memory
      if (_minWeightFilter > 0 || _maxWeightFilter > 0) {
        allOrders = allOrders.where((order) {
          final weight = order.details['package']?['dimensions']?['weight'] ?? 0;
          return (_minWeightFilter <= 0 || weight >= _minWeightFilter) &&
                 (_maxWeightFilter <= 0 || weight <= _maxWeightFilter);
        }).toList();
      }

      if (_deliveryRestrictionsFilter) {
        allOrders = allOrders.where((order) => 
          order.details['restrictions'] == true
        ).toList();
      }

      if (_deliveryDateFilter != null) {
        String filterDate = DateFormat('yyyy-MM-dd').format(_deliveryDateFilter!);
        allOrders = allOrders.where((order) {
          String orderDate = DateFormat('yyyy-MM-dd').format(order.dateTime);
          return orderDate == filterDate;
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, localSetState) => AlertDialog(
          title: const Text('Filter Trips'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pickup location filter: Governorate
                DropdownButtonFormField<String>(
                  value: _tripPickupGovernorateFilter,
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
                    localSetState(() {
                      _tripPickupGovernorateFilter = value ?? 'all';
                      _tripPickupDistrictFilter = 'all';
                    });
                  },
                ),
                // Pickup location filter: District (only if valid governorate selected)
                if (_tripPickupGovernorateFilter != 'all')
                  DropdownButtonFormField<String>(
                    value: _tripPickupDistrictFilter,
                    decoration: const InputDecoration(
                      labelText: 'Pickup District',
                    ),
                    items: ['all', ...(kurdistanCities[_tripPickupGovernorateFilter] ?? [])]
                        .map((district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district),
                      );
                    }).toList(),
                    onChanged: (value) {
                      localSetState(() {
                        _tripPickupDistrictFilter = value ?? 'all';
                      });
                    },
                  ),
                // Drop-off location filter: Governorate
                DropdownButtonFormField<String>(
                  value: _tripDropoffGovernorateFilter,
                  decoration: const InputDecoration(
                    labelText: 'Drop-off Governorate',
                  ),
                  items: ['all', ...kurdistanCities.keys].map((city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    localSetState(() {
                      _tripDropoffGovernorateFilter = value ?? 'all';
                      _tripDropoffDistrictFilter = 'all';
                    });
                  },
                ),
                // Drop-off District (only if a valid governorate is selected)
                if (_tripDropoffGovernorateFilter != 'all')
                  DropdownButtonFormField<String>(
                    value: _tripDropoffDistrictFilter,
                    decoration: const InputDecoration(
                      labelText: 'Drop-off District',
                    ),
                    items: ['all', ...(kurdistanCities[_tripDropoffGovernorateFilter] ?? [])]
                        .map((district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district),
                      );
                    }).toList(),
                    onChanged: (value) {
                      localSetState(() {
                        _tripDropoffDistrictFilter = value ?? 'all';
                      });
                    },
                  ),
                // Date filter
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter Date: ${_tripDateFilter != null ? DateFormat('MMM dd, yyyy').format(_tripDateFilter!) : 'Any'}',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _tripDateFilter ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          localSetState(() {
                            _tripDateFilter = picked;
                          });
                        }
                      },
                    ),
                    if (_tripDateFilter != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          localSetState(() {
                            _tripDateFilter = null;
                          });
                        },
                      ),
                  ],
                ),
                // Minimum Passengers field with validation
                TextField(
                  controller: TextEditingController(
                    text: _minPassengersFilter > 0 ? _minPassengersFilter.toString() : '',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Minimum Passengers',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    localSetState(() {
                      _minPassengersFilter = int.tryParse(val) ?? 0;
                    });
                  },
                ),
                CheckboxListTile(
                  value: _tripRestrictionsFilter,
                  title: const Text('Only trips with restrictions'),
                  onChanged: (value) {
                    localSetState(() {
                      _tripRestrictionsFilter = value ?? false;
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
                Navigator.pop(context, {
                  'pickupGovernorate': _tripPickupGovernorateFilter,
                  'pickupDistrict': _tripPickupDistrictFilter,
                  'dropoffGovernorate': _tripDropoffGovernorateFilter,
                  'dropoffDistrict': _tripDropoffDistrictFilter,
                  'minPassengers': _minPassengersFilter,
                  'restrictions': _tripRestrictionsFilter,
                  'date': _tripDateFilter,
                });
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _tripPickupGovernorateFilter = result['pickupGovernorate'] as String;
        _tripPickupDistrictFilter = result['pickupDistrict'] as String;
        _tripDropoffGovernorateFilter = result['dropoffGovernorate'] as String;
        _tripDropoffDistrictFilter = result['dropoffDistrict'] as String;
        _minPassengersFilter = result['minPassengers'] as int;
        _tripRestrictionsFilter = result['restrictions'] as bool;
        _tripDateFilter = result['date'] as DateTime?;
      });
    }
  }

  Future<void> _showDeliveryFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, localSetState) => AlertDialog(
          title: const Text('Filter Deliveries'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pickup location filter: Governorate
                DropdownButtonFormField<String>(
                  value: _deliveryPickupGovernorateFilter,
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
                    localSetState(() {
                      _deliveryPickupGovernorateFilter = value ?? 'all';
                      _deliveryPickupDistrictFilter = 'all';
                    });
                  },
                ),
                // Pickup location filter: District (only if valid governorate selected)
                if (_deliveryPickupGovernorateFilter != 'all')
                  DropdownButtonFormField<String>(
                    value: _deliveryPickupDistrictFilter,
                    decoration: const InputDecoration(
                      labelText: 'Pickup District',
                    ),
                    items: ['all', ...(kurdistanCities[_deliveryPickupGovernorateFilter] ?? [])]
                        .map((district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district),
                      );
                    }).toList(),
                    onChanged: (value) {
                      localSetState(() {
                        _deliveryPickupDistrictFilter = value ?? 'all';
                      });
                    },
                  ),
                // Drop-off location filter: Governorate
                DropdownButtonFormField<String>(
                  value: _deliveryDropoffGovernorateFilter,
                  decoration: const InputDecoration(
                    labelText: 'Drop-off Governorate',
                  ),
                  items: ['all', ...kurdistanCities.keys].map((city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    localSetState(() {
                      _deliveryDropoffGovernorateFilter = value ?? 'all';
                      _deliveryDropoffDistrictFilter = 'all';
                    });
                  },
                ),
                // Drop-off location filter: District (only if valid governorate selected)
                if (_deliveryDropoffGovernorateFilter != 'all')
                  DropdownButtonFormField<String>(
                    value: _deliveryDropoffDistrictFilter,
                    decoration: const InputDecoration(
                      labelText: 'Drop-off District',
                    ),
                    items: ['all', ...(kurdistanCities[_deliveryDropoffGovernorateFilter] ?? [])]
                        .map((district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district),
                      );
                    }).toList(),
                    onChanged: (value) {
                      localSetState(() {
                        _deliveryDropoffDistrictFilter = value ?? 'all';
                      });
                    },
                  ),
                // Date filter for deliveries
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter Date: ${_deliveryDateFilter != null ? DateFormat('MMM dd, yyyy').format(_deliveryDateFilter!) : 'Any'}',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _deliveryDateFilter ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          localSetState(() {
                            _deliveryDateFilter = picked;
                          });
                        }
                      },
                    ),
                    if (_deliveryDateFilter != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          localSetState(() {
                            _deliveryDateFilter = null;
                          });
                        },
                      ),
                  ],
                ),
                // Minimum Weight field with validation
                TextField(
                  controller: TextEditingController(
                    text: _minWeightFilter > 0 ? _minWeightFilter.toString() : '',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Minimum Weight (kg)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                CheckboxListTile(
                  value: _deliveryRestrictionsFilter,
                  title: const Text('Only deliveries with restrictions'),
                  onChanged: (value) {
                    localSetState(() {
                      _deliveryRestrictionsFilter = value ?? false;
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
                Navigator.pop(context, {
                  'pickupGovernorate': _deliveryPickupGovernorateFilter,
                  'pickupDistrict': _deliveryPickupDistrictFilter,
                  'dropoffGovernorate': _deliveryDropoffGovernorateFilter,
                  'dropoffDistrict': _deliveryDropoffDistrictFilter,
                  'minWeight': double.tryParse(
                          (_minWeightFilter > 0 ? _minWeightFilter.toString() : '0').trim()) ??
                      0,
                  'maxWeight': double.tryParse(
                          (_maxWeightFilter > 0 ? _maxWeightFilter.toString() : '0').trim()) ??
                      0,
                  'minDimensions': double.tryParse(
                          (_minDimensionsFilter > 0 ? _minDimensionsFilter.toString() : '0').trim()) ??
                      0,
                  'restrictions': _deliveryRestrictionsFilter,
                  'date': _deliveryDateFilter,
                });
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _deliveryPickupGovernorateFilter = result['pickupGovernorate'] as String;
        _deliveryPickupDistrictFilter = result['pickupDistrict'] as String;
        _deliveryDropoffGovernorateFilter = result['dropoffGovernorate'] as String;
        _deliveryDropoffDistrictFilter = result['dropoffDistrict'] as String;
        _minWeightFilter = result['minWeight'] as double;
        _maxWeightFilter = result['maxWeight'] as double;
        _minDimensionsFilter = result['minDimensions'] as double;
        _deliveryRestrictionsFilter = result['restrictions'] as bool;
        _deliveryDateFilter = result['date'] as DateTime?;
      });
    }
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
          _buildInfoRow('Customer Phone', details['customerPhone'] ?? 'Not provided'),
          
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

          Text('Price Information:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Price:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${NumberFormat("#,##0").format(details['estimatedPrice'] ?? 0)} IQD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 3, 76, 83),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                ],
              ),
            ),
          ),

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
          _buildInfoRow('Customer Phone', details['customerPhone'] ?? 'Not provided'),

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

          const Divider(height: 24),

          Text('Price Information:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Price:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${NumberFormat("#,##0").format(details['estimatedPrice'] ?? 0)} IQD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 3, 76, 83),
                        ),
                      ),
                    ],
                  ),
                  
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
              onPressed: () => _navigateToMap(details, details['type']),
              icon: const Icon(Icons.map),
              label: const Text('View Route'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToMap(Map<String, dynamic> details, String type) {
    List<Location> pickupLocations = [];
    List<Location> dropoffLocations = [];

    try {
      print('Full details: $details'); // Debug log

      if (type == 'Trip') {
        // 1. Main route locations
        final routeDetails = details['routeDetails'];
        if (routeDetails != null) {
          if (routeDetails['pickupLocation'] != null) {
            final pickup = routeDetails['pickupLocation'];
            print('Main pickup location: $pickup');
            
            try {
              pickupLocations.add(Location(
                latLng: LatLng(
                  double.parse(pickup['latitude'].toString()),
                  double.parse(pickup['longitude'].toString())
                ),
                name: 'Main Pickup: ${routeDetails['pickupCity'] ?? 'Unknown'}, ${routeDetails['pickupRegion'] ?? 'Unknown'}',
              ));
            } catch (e) {
              print('Error parsing main pickup location: $e');
            }
          }

          if (routeDetails['dropoffLocation'] != null) {
            final dropoff = routeDetails['dropoffLocation'];
            print('Main dropoff location: $dropoff');
            
            try {
              dropoffLocations.add(Location(
                latLng: LatLng(
                  double.parse(dropoff['latitude'].toString()),
                  double.parse(dropoff['longitude'].toString())
                ),
                name: 'Main Dropoff: ${routeDetails['dropoffCity'] ?? 'Unknown'}, ${routeDetails['dropoffRegion'] ?? 'Unknown'}',
              ));
            } catch (e) {
              print('Error parsing main dropoff location: $e');
            }
          }
        }

        // 2. Passenger locations
        final passengers = details['passengers'] as List<dynamic>?;
        if (passengers != null) {
          for (var passenger in passengers) {
            try {
              // Get passenger pickup location
              if (passenger['locations']?['source']?['coordinates'] != null) {
                final source = passenger['locations']['source']['coordinates'];
                print('Passenger pickup location: $source');
                
                pickupLocations.add(Location(
                  latLng: LatLng(
                    double.parse(source['latitude'].toString()),
                    double.parse(source['longitude'].toString())
                  ),
                  name: 'Passenger Pickup: ${passenger['locations']['source']['city'] ?? 'Unknown'}, ${passenger['locations']['source']['region'] ?? 'Unknown'}',
                ));
              }

              // Get passenger dropoff location
              if (passenger['locations']?['destination']?['coordinates'] != null) {
                final destination = passenger['locations']['destination']['coordinates'];
                print('Passenger dropoff location: $destination');
                
                dropoffLocations.add(Location(
                  latLng: LatLng(
                    double.parse(destination['latitude'].toString()),
                    double.parse(destination['longitude'].toString())
                  ),
                  name: 'Passenger Dropoff: ${passenger['locations']['destination']['city'] ?? 'Unknown'}, ${passenger['locations']['destination']['region'] ?? 'Unknown'}',
                ));
              }
            } catch (e) {
              print('Error processing passenger locations: $e');
            }
          }
        }

      } else if (type == 'Delivery') {
        // ... existing delivery location handling code ...
      }

      print('Found ${pickupLocations.length} pickup locations');
      print('Found ${dropoffLocations.length} dropoff locations');

      if (pickupLocations.isEmpty && dropoffLocations.isEmpty) {
        throw Exception('No valid locations found in the data structure');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapView(
            pickupLocations: pickupLocations,
            dropoffLocations: dropoffLocations,
          ),
        ),
      );
    } catch (e) {
      print('Error processing location data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location data not available: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
  
  DateTime orderDateTime;
  String type;
  Map<String, dynamic> details;
  
  try {
    if (data['tripDate'] != null) {
      orderDateTime = (data['tripDate'] as Timestamp).toDate();
      type = 'Trip';
      
      // Process passengers data to include their locations
      List<Map<String, dynamic>> processedPassengers = [];
      if (data['passengers'] != null) {
        processedPassengers = (data['passengers'] as List).map((passenger) {
          return {
            'gender': passenger['gender'],
            'age': passenger['age'],
            'pickupCity': passenger['locations']?['source']?['city'],
            'pickupRegion': passenger['locations']?['source']?['region'],
            'dropoffCity': passenger['locations']?['destination']?['city'],
            'dropoffRegion': passenger['locations']?['destination']?['region'],
          };
        }).toList();
      }
      
      details = {
        ...data,
        'customerPhone': data['userPhone'],
        'pickupCity': data['routeDetails']?['pickupCity'],
        'pickupRegion': data['routeDetails']?['pickupRegion'],
        'dropoffCity': data['routeDetails']?['dropoffCity'],
        'dropoffRegion': data['routeDetails']?['dropoffRegion'],
        'passengers': processedPassengers,
        'tripTime': data['tripTime'],
      };
    } else if (data['deliveryDate'] != null) {
      orderDateTime = (data['deliveryDate'] as Timestamp).toDate();
      type = 'Delivery';
      details = {
        ...data,
        'customerPhone': data['userPhone'],
      };
    } else {
      orderDateTime = DateTime.now();
      type = 'Unknown';
      details = data;
    }

    print('Processed route details: ${details['pickupCity']}, ${details['pickupRegion']} -> ${details['dropoffCity']}, ${details['dropoffRegion']}'); // Debug log

    return ActiveOrder(
      id: doc.id,
      type: type,
      dateTime: orderDateTime,
      status: data['status'] ?? 'pending',
      details: details,
    );
  } catch (e) {
    print('Error processing document ${doc.id}: $e'); // Debug log
    rethrow;
  }
}

Future<void> _saveTrip() async {
  // Get the current user's phone number
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser?.uid)
      .get();
  
  final userData = userDoc.data();
  final userPhone = userData?['phone'];

  await FirebaseFirestore.instance.collection('trips').add({
    'userId': FirebaseAuth.instance.currentUser?.uid,
    'userPhone': userPhone,
    // ... rest of the trip data ...
  });
}

Future<void> _saveDelivery() async {
  // Get the current user's phone number
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser?.uid)
      .get();
  
  final userData = userDoc.data();
  final userPhone = userData?['phone'];

  await FirebaseFirestore.instance.collection('deliveries').add({
    'userId': FirebaseAuth.instance.currentUser?.uid,
    'userPhone': userPhone,
    // ... rest of the delivery data ...
  });
}
}