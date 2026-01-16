
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class OuiService {
  static Map<String, String> _vendors = {};
  static bool _initialized = false;

  /// Carga la base de datos OUI desde assets/oui.json
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final String jsonString = await rootBundle.loadString('assets/oui.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      
      // Convert dynamic map to <String, String> and normalize keys if needed
      // Assuming keys in JSON could be "XX:XX:XX" or "XX-XX-XX" or "XXXXXX"
      // We will normalize our internal map to "XX:XX:XX" uppercase.
      
      _vendors = {};
      jsonMap.forEach((key, value) {
         String normalizedKey = key.toUpperCase().replaceAll('-', ':').replaceAll('.', ':');
         // If key doesn't have colons (e.g. AABBCC), add them
         if (!normalizedKey.contains(':') && normalizedKey.length == 6) {
            normalizedKey = "${normalizedKey.substring(0,2)}:${normalizedKey.substring(2,4)}:${normalizedKey.substring(4,6)}";
         }
         _vendors[normalizedKey] = value.toString();
      });
      
      _initialized = true;
      print("OUI Database Loaded: ${_vendors.length} entries.");
    } catch (e) {
      print("Error loading OUI Database: $e");
      // Fallback or empty map
    }
  }

  static bool isRandomMac(String mac) {
     if (mac.isEmpty) return false;
     try {
       // Check second hex digit of the first byte (index 1 of the string XX:...)
       // Patterns: x2, x6, xA, xE
       if (mac.length >= 2) {
         final char = mac[1].toUpperCase();
         return ['2', '6', 'A', 'E'].contains(char);
       }
     } catch (_) {}
     return false;
  }

  static String? lookup(String mac, {String? deviceName}) {
    if (mac.length < 8) return null;
    
    // 1. Try DB Lookup
    try {
      String prefix = mac.substring(0, 8).toUpperCase().replaceAll('-', ':');
      String? vendor = _vendors[prefix];
      if (vendor != null) return vendor;
    } catch (e) {
      // ignore
    }

    // 2. Private/Random MAC
    if (isRandomMac(mac)) {
      return "Private/Random";
    }

    // 3. Inference from Name
    if (deviceName != null && deviceName.isNotEmpty) {
       final name = deviceName.toUpperCase();
       // Top heuristics
       if (name.contains("SAMSUNG")) return "Samsung (Inferred)";
       if (name.contains("APPLE") || name.contains("IPHONE") || name.contains("IPAD") || name.contains("MACBOOK") || name.contains("WATCH")) return "Apple (Inferred)";
       if (name.contains("LG")) return "LG (Inferred)";
       if (name.contains("XIAOMI") || name.contains("MI ") || name.contains("POCO")) return "Xiaomi (Inferred)";
       if (name.contains("HUAMI") || name.contains("AMAZFIT")) return "Huami (Inferred)";
       if (name.contains("SONY")) return "Sony (Inferred)";
       if (name.contains("BOSE")) return "Bose (Inferred)";
       if (name.contains("HUAWEI") || name.contains("HONOR")) return "Huawei (Inferred)";
       if (name.contains("JBL")) return "JBL (Inferred)";
       if (name.contains("GARMIN")) return "Garmin (Inferred)";
       if (name.contains("FITBIT")) return "Fitbit (Inferred)";
    }

    return null;
  }
}
