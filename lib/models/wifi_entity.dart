class WifiEntity {
  final String ssid;
  final String bssid;
  final int rssi;
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

  /// Normalized capabilities string for security checks
  String get _caps => capabilities.toUpperCase();

  /// True only if NO security protocol is present (open network)
  /// ESS is present in virtually all beacons including secured ones -- not an indicator of open
  bool get isOpen {
    // A network is open if it has no WPA, no WEP, no RSN, no SAE
    return !_caps.contains("WPA") &&
           !_caps.contains("WEP") &&
           !_caps.contains("RSN") &&
           !_caps.contains("SAE") &&
           !_caps.contains("WAPI");
  }

  bool get isWep => _caps.contains("WEP");
  bool get isWpa3 => _caps.contains("WPA3") || _caps.contains("SAE");
  bool get isWpa2 => _caps.contains("WPA2") || (_caps.contains("WPA") && !isWpa3);
  bool get isWps => _caps.contains("WPS");

  /// Security level: "OPEN", "WEP", "WPA", "WPA2", "WPA3"
  String get securityType {
    if (isOpen) return "OPEN";
    if (isWep) return "WEP";
    if (isWpa3) return "WPA3";
    if (isWpa2) return "WPA2";
    if (_caps.contains("WPA")) return "WPA";
    return "UNKNOWN";
  }

  /// True if the network uses vulnerable security
  bool get isVulnerable => isOpen || isWep;

  /// Channel number derived from frequency
  int get channel {
    if (frequency >= 2412 && frequency <= 2484) {
      return frequency <= 2472 ? (frequency - 2407) ~/ 5 : 14;
    }
    if (frequency >= 5160 && frequency <= 5885) {
      return (frequency - 5000) ~/ 5;
    }
    return 0;
  }

  /// Band: "2.4 GHz" or "5 GHz"
  String get band => frequency >= 5000 ? "5 GHz" : "2.4 GHz";

  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'bssid': bssid,
      'rssi': rssi,
      'frequency': frequency,
      'capabilities': capabilities,
      'security_type': securityType,
      'manufacturer': manufacturer,
      'latitude': latitude,
      'longitude': longitude,
      'channel': channel,
      'band': band,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WifiEntity && bssid == other.bssid;

  @override
  int get hashCode => bssid.hashCode;
}