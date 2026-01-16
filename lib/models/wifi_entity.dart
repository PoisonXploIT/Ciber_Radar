
class WifiEntity {
  final String ssid;
  final String bssid;
  final int rssi; // Signal Strength
  final int frequency;
  final String capabilities;
  final String? manufacturer;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;

  WifiEntity({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
    required this.capabilities,
    this.manufacturer,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  bool get isOpen => capabilities.toUpperCase().contains("ESS") && !capabilities.toUpperCase().contains("WPA") && !capabilities.toUpperCase().contains("WEP");
  bool get isWep => capabilities.toUpperCase().contains("WEP");
  bool get isWpa3 => capabilities.toUpperCase().contains("WPA3") || capabilities.toUpperCase().contains("SAE");
  
  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'bssid': bssid,
      'rssi': rssi,
      'frequency': frequency,
      'capabilities': capabilities,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
