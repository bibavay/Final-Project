import 'package:flutter/material.dart';

class Filters extends StatefulWidget {
  const Filters({super.key});

  @override
  State<Filters> createState() => _FiltersState();
}

class _FiltersState extends State<Filters> {
  String? selectedLocation;
  DateTimeRange? dateRange;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  RangeValues passengerRange = const RangeValues(1, 4);

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.filter_list, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Filter Orders'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedLocation,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: ['Duhok', 'Erbil', 'Sulaymaniyah'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedLocation = value),
                ),
                const SizedBox(height: 16),
                
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(dateRange == null 
                    ? 'Select Date Range'
                    : '${dateRange!.start.toLocal().toString().split(' ')[0]} - ${dateRange!.end.toLocal().toString().split(' ')[0]}'),
                  onTap: () async {
                    final result = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (result != null) {
                      setState(() => dateRange = result);
                    }
                  },
                ),
                
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(startTime == null || endTime == null
                    ? 'Select Time Range'
                    : '${startTime!.format(context)} - ${endTime!.format(context)}'),
                  onTap: () async {
                    final start = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (start != null) {
                      final end = await showTimePicker(
                        context: context,
                        initialTime: start,
                      );
                      if (end != null) {
                        setState(() {
                          startTime = start;
                          endTime = end;
                        });
                      }
                    }
                  },
                ),
                
                const Text('Passenger Count'),
                RangeSlider(
                  values: passengerRange,
                  min: 1,
                  max: 24,
                  divisions: 3,
                  labels: RangeLabels(
                    passengerRange.start.round().toString(),
                    passengerRange.end.round().toString(),
                  ),
                  onChanged: (values) => setState(() => passengerRange = values),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  selectedLocation = null;
                  dateRange = null;
                  startTime = null;
                  endTime = null;
                  passengerRange = const RangeValues(1, 4);
                });
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilters() {
    // Implement filter logic here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Results"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Center(
        child: Text("Results"),
      ),
    );
  }
}