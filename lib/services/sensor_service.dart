
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  /// Stream that emits the magnitude of the magnetic field in microteslas (µT).
  /// Magnitude = sqrt(x^2 + y^2 + z^2)
  Stream<double> get magneticField {
    return magnetometerEvents.map((event) {
      double magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      // Round to 1 decimal place to reduce UI jitter
      return double.parse(magnitude.toStringAsFixed(1));
    });
  }
}
