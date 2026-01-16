
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../models/wifi_entity.dart';
import '../models/bluetooth_entity.dart';
import 'package:permission_handler/permission_handler.dart';

class ExportService {
  
  Future<String?> exportSession(List<WifiEntity> wifiList, List<BluetoothEntity> bleList) async {
    // Check storage permissions if needed (Android 10+ uses scoped storage, accessible via getDownloadsDirectory often requires no extra perm if just writing, but let's see).
    // On Android < 10, needs WRITE_EXTERNAL_STORAGE.
    // For wider compatibility, we'll try to use local application documents or support generic download folder if possible.
    // user asked for "Downloads folder".
    
    // Convert to lists
    List<List<dynamic>> wifiRows = [
      ["SSID", "BSSID", "MANUFACTURER", "RSSI", "FREQ", "CAPS", "TIMESTAMP"]
    ];
    for (var w in wifiList) {
      wifiRows.add([w.ssid, w.bssid, w.manufacturer ?? "Unknown", w.rssi, w.frequency, w.capabilities, w.timestamp.toIso8601String()]);
    }

    List<List<dynamic>> bleRows = [
      ["NAME", "MAC", "MANUFACTURER", "RSSI", "TYPE", "TIMESTAMP"]
    ];
    for (var b in bleList) {
      bleRows.add([b.name, b.mac, b.manufacturer ?? "Unknown", b.rssi, b.type, b.timestamp.toIso8601String()]);
    }

    String csvWifi = const ListToCsvConverter().convert(wifiRows);
    String csvBle = const ListToCsvConverter().convert(bleRows);
    
    try {
      Directory? directory;
      if (Platform.isAndroid) {
         directory = Directory('/storage/emulated/0/Download');
         if (!await directory.exists()) {
            directory = await getExternalStorageDirectory(); // Fallback
         }
      } else {
         directory = await getDownloadsDirectory();
      }
      
      if (directory != null) {
         final now = DateTime.now().toIso8601String().replaceAll(":", "-").split(".").first;
         final fileWifi = File('${directory.path}/ciberradar_wifi_$now.csv');
         final fileBle = File('${directory.path}/ciberradar_ble_$now.csv');
         
         await fileWifi.writeAsString(csvWifi);
         await fileBle.writeAsString(csvBle);

         // Generate KML
         String kmlContent = _generateKml(wifiList);
         final fileKml = File('${directory.path}/ciberradar_heatmap_$now.kml');
         await fileKml.writeAsString(kmlContent);
         
         return directory.path;
      }
    } catch (e) {
      print("Export error: $e");
    }
    return null;
  }

  String _generateKml(List<WifiEntity> networks) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>CiberRadar Wifi Scan</name>');
    
    // Styles
    buffer.writeln('    <Style id="style_open"><IconStyle><scale>1.0</scale><Icon><href>http://maps.google.com/mapfiles/kml/pushpin/red-pushpin.png</href></Icon></IconStyle></Style>');
    buffer.writeln('    <Style id="style_secure"><IconStyle><scale>1.0</scale><Icon><href>http://maps.google.com/mapfiles/kml/pushpin/grn-pushpin.png</href></Icon></IconStyle></Style>');

    for (var net in networks) {
      if (net.latitude != null && net.longitude != null) {
        String style = (net.isOpen || net.isWep) ? "#style_open" : "#style_secure";
        buffer.writeln('    <Placemark>');
        buffer.writeln('      <name><![CDATA[${net.ssid}]]></name>');
        buffer.writeln('      <description><![CDATA[BSSID: ${net.bssid}<br>Sec: ${net.capabilities}<br>Vendor: ${net.manufacturer ?? "Unknown"}]]></description>');
        buffer.writeln('      <styleUrl>$style</styleUrl>');
        buffer.writeln('      <Point>');
        buffer.writeln('        <coordinates>${net.longitude},${net.latitude},0</coordinates>');
        buffer.writeln('      </Point>');
        buffer.writeln('    </Placemark>');
      }
    }

    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');
    return buffer.toString();
  }
}
