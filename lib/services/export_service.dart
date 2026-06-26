import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../models/wifi_entity.dart';
import '../models/bluetooth_entity.dart';
import '../models/host_model.dart';

class ExportService {

  /// Export WiFi + BLE to CSV + KML (existing functionality)
  Future<String?> exportSession(List<WifiEntity> wifiList, List<BluetoothEntity> bleList) async {
    List<List<dynamic>> wifiRows = [
      ["SSID", "BSSID", "MANUFACTURER", "SECURITY", "RSSI", "FREQ", "CHANNEL", "BAND", "CAPS", "LAT", "LON", "TIMESTAMP"]
    ];
    for (var w in wifiList) {
      wifiRows.add([w.ssid, w.bssid, w.manufacturer ?? "Unknown", w.securityType, w.rssi, w.frequency,
        w.channel, w.band, w.capabilities, w.latitude ?? "", w.longitude ?? "", w.timestamp.toIso8601String()]);
    }

    List<List<dynamic>> bleRows = [
      ["NAME", "MAC", "MANUFACTURER", "RSSI", "TYPE", "LAT", "LON", "TIMESTAMP"]
    ];
    for (var b in bleList) {
      bleRows.add([b.name, b.mac, b.manufacturer ?? "Unknown", b.rssi, b.type,
        b.latitude ?? "", b.longitude ?? "", b.timestamp.toIso8601String()]);
    }

    String csvWifi = const ListToCsvConverter().convert(wifiRows);
    String csvBle = const ListToCsvConverter().convert(bleRows);

    try {
      Directory? directory;
      if (Platform.isAndroid) {
         directory = await getExternalStorageDirectory();
      } else {
         directory = await getDownloadsDirectory();
      }

      if (directory != null) {
         final now = DateTime.now().toIso8601String().replaceAll(":", "-").split(".").first;
         final fileWifi = File('${directory.path}/ciberradar_wifi_$now.csv');
         final fileBle = File('${directory.path}/ciberradar_ble_$now.csv');

         await fileWifi.writeAsString(csvWifi);
         await fileBle.writeAsString(csvBle);

         String kmlContent = _generateKml(wifiList);
         final fileKml = File('${directory.path}/ciberradar_heatmap_$now.kml');
         await fileKml.writeAsString(kmlContent);

         return directory.path;
      }
    } catch (e) {
      // Export error
    }
    return null;
  }

  /// Export comprehensive JSON report compatible with sec-dashboard
  /// Can be imported into sec-dashboard or any SIEM
  Future<String?> exportJsonReport({
    required List<WifiEntity> wifiList,
    required List<BluetoothEntity> bleList,
    List<HostModel> lanHosts = const [],
    Map<String, dynamic>? cellData,
    double? magneticReading,
  }) async {
    final report = {
      "source": "ciber_radar",
      "version": "2.0.0",
      "exported_at": DateTime.now().toIso8601String(),
      "device_info": {
        "platform": Platform.operatingSystem,
        "os_version": Platform.operatingSystemVersion,
      },
      "summary": {
        "wifi_networks": wifiList.length,
        "wifi_vulnerable": wifiList.where((w) => w.isVulnerable).length,
        "wifi_open": wifiList.where((w) => w.isOpen).length,
        "wifi_wep": wifiList.where((w) => w.isWep).length,
        "ble_devices": bleList.length,
        "lan_hosts": lanHosts.length,
        "lan_high_risk": lanHosts.where((h) => h.riskLevel == "HIGH").length,
      },
      "events": <Map<String, dynamic>>[],
    };

    // WiFi events
    for (var w in wifiList) {
      report["events"]!.add({
        "event": "wifi_scan",
        "timestamp": w.timestamp.toIso8601String(),
        "ssid": w.ssid,
        "bssid": w.bssid,
        "security": w.securityType,
        "vulnerable": w.isVulnerable,
        "rssi": w.rssi,
        "frequency": w.frequency,
        "channel": w.channel,
        "band": w.band,
        "manufacturer": w.manufacturer,
        "latitude": w.latitude,
        "longitude": w.longitude,
      });
    }

    // BLE events
    for (var b in bleList) {
      report["events"]!.add({
        "event": "ble_scan",
        "timestamp": b.timestamp.toIso8601String(),
        "name": b.name,
        "mac": b.mac,
        "rssi": b.rssi,
        "type": b.type,
        "manufacturer": b.manufacturer,
        "latitude": b.latitude,
        "longitude": b.longitude,
      });
    }

    // LAN host events
    for (var h in lanHosts) {
      report["events"]!.add({
        "event": "lan_host",
        "timestamp": DateTime.now().toIso8601String(),
        "ip": h.ip,
        "hostname": h.name,
        "source": h.source,
        "open_ports": h.openPorts,
        "port_services": h.portServices,
        "risk_level": h.riskLevel,
      });
    }

    // Cell data
    if (cellData != null) {
      report["events"]!.add({
        "event": "cell_scan",
        "timestamp": DateTime.now().toIso8601String(),
        ...cellData,
      });
    }

    // Sensor data
    if (magneticReading != null) {
      report["events"]!.add({
        "event": "emf_reading",
        "timestamp": DateTime.now().toIso8601String(),
        "magnetic_field_ut": magneticReading,
        "anomaly": magneticReading > 100.0,
      });
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(report);

    try {
      Directory? directory;
      if (Platform.isAndroid) {
         directory = await getExternalStorageDirectory();
      } else {
         directory = await getDownloadsDirectory();
      }

      if (directory != null) {
         final now = DateTime.now().toIso8601String().replaceAll(":", "-").split(".").first;
         final file = File('${directory.path}/ciberradar_report_$now.json');
         await file.writeAsString(jsonString);
         return file.path;
      }
    } catch (e) {
      // Export error
    }
    return null;
  }

  /// Share JSON report via Android share sheet
  Future<void> shareJsonReport({
    required List<WifiEntity> wifiList,
    required List<BluetoothEntity> bleList,
    List<HostModel> lanHosts = const [],
    Map<String, dynamic>? cellData,
    double? magneticReading,
  }) async {
    final path = await exportJsonReport(
      wifiList: wifiList,
      bleList: bleList,
      lanHosts: lanHosts,
      cellData: cellData,
      magneticReading: magneticReading,
    );

    if (path != null) {
      await Share.shareXFiles([XFile(path)], text: 'CiberRadar Security Report');
    }
  }

  String _generateKml(List<WifiEntity> networks) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>CiberRadar Wifi Scan</name>');

    buffer.writeln('    <Style id="style_open"><IconStyle><scale>1.0</scale><Icon><href>http://maps.google.com/mapfiles/kml/pushpin/red-pushpin.png</href></Icon></IconStyle></Style>');
    buffer.writeln('    <Style id="style_secure"><IconStyle><scale>1.0</scale><Icon><href>http://maps.google.com/mapfiles/kml/pushpin/grn-pushpin.png</href></Icon></IconStyle></Style>');

    for (var net in networks) {
      if (net.latitude != null && net.longitude != null) {
        String style = net.isVulnerable ? "#style_open" : "#style_secure";
        buffer.writeln('    <Placemark>');
        buffer.writeln('      <name><![CDATA[${net.ssid}]]></name>');
        buffer.writeln('      <description><![CDATA[BSSID: ${net.bssid}<br>Security: ${net.securityType}<br>Vendor: ${net.manufacturer ?? "Unknown"}<br>Signal: ${net.rssi} dBm]]></description>');
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