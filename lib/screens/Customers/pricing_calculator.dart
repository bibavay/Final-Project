import 'dart:math' as math;

class PricingCalculator {
  // Base prices for different cities (in IQD)
  static const Map<String, Map<String, int>> cityPrices = {
    'Erbil': {
      'Sulaymaniyah': 25000,
      'Duhok': 20000,
      'Halabja': 30000,
    },
    'Sulaymaniyah': {
      'Erbil': 25000,
      'Duhok': 35000,
      'Halabja': 15000,
    },
    'Duhok': {
      'Erbil': 20000,
      'Sulaymaniyah': 35000,
      'Halabja': 40000,
    },
    'Halabja': {
      'Erbil': 30000,
      'Sulaymaniyah': 15000,
      'Duhok': 40000,
    },
  };

  // Delivery pricing factors
  static const double pricePerKg = 1000.0;  // IQD per kg
  static const double pricePerVolume = 500.0;  // IQD per 1000 cm³

  // Trip pricing factors
  static const double basePassengerPrice = 15000.0;  // Base price per passenger
  static const double additionalPassengerDiscount = 0.15;  // 15% discount for each additional passenger

  static double calculateDeliveryPrice({
    required String sourceCity,
    required String destinationCity,
    required double weight,
    required double height,
    required double width,
    required double depth,
  }) {
    // Get base price for city combination
    double basePrice = _getCityBasePrice(sourceCity, destinationCity).toDouble();
    
    // Calculate volume in cm³
    double volume = height * width * depth;
    
    // Calculate weight-based price
    double weightPrice = weight * pricePerKg;
    
    // Calculate volume-based price
    double volumePrice = (volume / 1000) * pricePerVolume;
    
    // Total price is base price plus the higher of weight or volume price
    double totalPrice = basePrice + math.max(weightPrice, volumePrice);
    
    return totalPrice;
  }

  static double calculateTripPrice({
    required String sourceCity,
    required String destinationCity,
    required int passengerCount,
  }) {
    // Get base price for city combination
    double basePrice = _getCityBasePrice(sourceCity, destinationCity).toDouble();
    
    // Calculate price per passenger with progressive discount
    double passengerPrice = 0;
    for (int i = 0; i < passengerCount; i++) {
      double discount = i * additionalPassengerDiscount;
      // Cap discount at 45%
      discount = math.min(discount, 0.45);
      passengerPrice += basePassengerPrice * (1 - discount);
    }
    
    return basePrice + passengerPrice;
  }

  static int _getCityBasePrice(String sourceCity, String destinationCity) {
    if (sourceCity == destinationCity) return 10000;  // Local trip base price
    return cityPrices[sourceCity]?[destinationCity] ?? 50000;  // Default price if not found
  }
}