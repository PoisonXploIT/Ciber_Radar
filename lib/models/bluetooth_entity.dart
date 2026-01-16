
class BluetoothEntity {
  final String name;
  final String mac; // Device Id
  final int rssi;
  final String type; // e.g. LE, Classic
  final String? manufacturer;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;

  BluetoothEntity({
    required this.name,
    required this.mac,
    required this.rssi,
    required this.type,
    this.manufacturer,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mac': mac,
      'rssi': rssi,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
