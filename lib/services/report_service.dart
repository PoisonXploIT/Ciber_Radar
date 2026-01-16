
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'scanner_service.dart';
import 'lan_service.dart';
import 'cell_service.dart';
import 'sensor_service.dart';
import '../models/wifi_entity.dart';
import '../models/bluetooth_entity.dart';
import '../models/host_model.dart';

class ReportService {
  final ScannerService _scannerService = ScannerService();
  final LanService _lanService = LanService();
  final CellService _cellService = CellService();
  final SensorService _sensorService = SensorService();

  Future<void> generateAndShareReport(Function(String) onStatus) async {
    // 1. WiFi Audit
    onStatus("AUDITING WIFI SPECTRUM...");
    _scannerService.clearSession(); 
    await _scannerService.startWifiScan();
    await Future.delayed(const Duration(seconds: 3));
    final wifiList = _scannerService.sessionWifiList;

    // 2. BLE Audit
    onStatus("SCANNING BLUETOOTH DEVICES...");
    await _scannerService.startBleScan();
    await Future.delayed(const Duration(seconds: 3));
    await _scannerService.stopBleScan();
    final bleList = _scannerService.sessionBleList;

    // 3. Sensor Audit
    onStatus("READING MAGNETIC SENSORS...");
    double magValue = 0.0;
    try {
       magValue = await _sensorService.magneticField.first.timeout(const Duration(seconds: 1));
    } catch (e) {
       magValue = 0.0;
    }

    // 4. Cellular Audit
    onStatus("INTERCEPTING CELLULAR TOWERS...");
    List<CellTowerModel> cellList = [];
    try {
       cellList = await _cellService.getCells();
    } catch (e) {
       cellList = [];
    }

    // 5. LAN Audit
    onStatus("PINGING LAN SUBNET...");
    List<HostModel> lanHosts = [];
    try {
      String? ip = await _lanService.getIp();
      if (ip != null) {
         String? subnet = _lanService.getSubnet(ip);
         if (subnet != null) {
             final stream = _lanService.scan(subnet);
             final List<HostModel> tempHosts = [];
             final sub = stream.listen((host) => tempHosts.add(host));
             await Future.delayed(const Duration(seconds: 3));
             await sub.cancel();
             lanHosts = tempHosts;
         }
      }
    } catch(e) { /* ignore */ }

    // 6. PDF Generation
    onStatus("COMPILING PDF REPORT...");
    
    // Load Unicode Fonts
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(),
            pw.Divider(thickness: 2),
            _buildSectionTitle("1. WIRELESS SPECTRUM (WiFi)"),
            _buildWifiTable(wifiList),
            pw.SizedBox(height: 15),
            _buildSectionTitle("2. BLUETOOTH DEVICES"),
            _buildBleTable(bleList),
            pw.SizedBox(height: 15),
            _buildSectionTitle("3. CELLULAR INTERCEPTOR"),
            _buildCellTable(cellList),
            pw.SizedBox(height: 15),
            _buildSectionTitle("4. PHYSICAL SENSORS"),
            _buildSensorRow(magValue),
            pw.SizedBox(height: 15),
            _buildSectionTitle("5. LOCAL NETWORK (LAN)"),
            _buildLanTable(lanHosts),
            pw.Divider(thickness: 1, color: PdfColors.grey),
            _buildFooter(),
          ];
        },
      ),
    );

    // 7. Share
    onStatus("EXPORTING DOCUMENT...");
    await Printing.sharePdf(
      bytes: await doc.save(), 
      filename: 'CiberRadar_Audit_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf'
    );
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
             pw.Text("CIBER-RADAR", style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
             pw.Text("SECURITY AUDIT REPORT", style: pw.TextStyle(fontSize: 14, color: PdfColors.redAccent, fontWeight: pw.FontWeight.bold)),
          ]
        ),
        pw.SizedBox(height: 5),
        pw.Text("Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
      ]
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8, top: 8),
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: PdfColors.blueGrey800,
      child: pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
       margin: const pw.EdgeInsets.only(top: 20),
       child: pw.Row(
         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
         children: [
            pw.Text("CONFIDENTIAL", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            pw.Text("Generated by Ciber-Radar v3.1", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey))
         ]
       )
    );
  }

  pw.Widget _buildWifiTable(List<WifiEntity> list) {
    if (list.isEmpty) return pw.Paragraph(text: "No WiFi Networks Detected");
    
    // Sort: Vulnerable first
    list.sort((a,b) {
       final aVuln = (a.isOpen || a.isWep) ? 1 : 0;
       final bVuln = (b.isOpen || b.isWep) ? 1 : 0;
       return bVuln.compareTo(aVuln);
    });

    final data = list.take(15).map((e) {
      final isVuln = e.isOpen || e.isWep;
      return [
        e.ssid.isEmpty ? "<HIDDEN>" : e.ssid,
        e.bssid,
        "${e.rssi} dBm",
        pw.Text(
          isVuln ? "VULNERABLE (${e.capabilities})" : "SECURE", 
          style: pw.TextStyle(color: isVuln ? PdfColors.red : PdfColors.green, fontWeight: pw.FontWeight.bold)
        )
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: ['SSID', 'BSSID', 'SIGNAL', 'SECURITY'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  pw.Widget _buildBleTable(List<BluetoothEntity> list) {
    if (list.isEmpty) return pw.Paragraph(text: "No Bluetooth Devices");

    final data = list.take(10).map((e) {
      return [
        e.name.isEmpty ? "N/A" : e.name,
        e.mac,
        "${e.rssi} dBm",
        "BLE Generic"
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: ['DEVICE NAME', 'MAC ADDRESS', 'RSSI', 'TYPE'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellStyle: const pw.TextStyle(fontSize: 10),
    );
  }

  pw.Widget _buildCellTable(List<CellTowerModel> list) {
     if (list.isEmpty) return pw.Paragraph(text: "No Cellular Data Available");

     final data = list.map((e) {
       final isRisk = e.threatLevel == ThreatLevel.HIGH;
       return [
         e.type,
         e.cid.toString(),
         "${e.dbm} dBm",
         pw.Text(
           isRisk ? "THREAT (Downgrade)" : (e.threatLevel == ThreatLevel.WARN ? "WARNING (3G)" : "SECURE"),
           style: pw.TextStyle(color: isRisk ? PdfColors.red : (e.threatLevel == ThreatLevel.WARN ? PdfColors.orange : PdfColors.green), fontWeight: pw.FontWeight.bold)
         )
       ];
     }).toList();

     return pw.Table.fromTextArray(
      headers: ['NETWORK', 'CELL ID', 'SIGNAL', 'ANALYSIS'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellStyle: const pw.TextStyle(fontSize: 10),
    );
  }

  pw.Widget _buildLanTable(List<HostModel> list) {
    if (list.isEmpty) return pw.Paragraph(text: "No LAN Hosts Discovered");

    return pw.Table.fromTextArray(
      headers: ['IP ADDRESS', 'HOSTNAME', 'DISCOVERY SOURCE'],
      data: list.map((e) => [
        e.ip,
        e.name ?? "Unknown",
        e.source
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellStyle: const pw.TextStyle(fontSize: 10),
    );
  }

  pw.Widget _buildSensorRow(double mag) {
     final isHigh = mag > 60.0;
     return pw.Container(
       padding: const pw.EdgeInsets.all(10),
       decoration: pw.BoxDecoration(
         border: pw.Border.all(color: isHigh ? PdfColors.red : PdfColors.green),
         color: isHigh ? PdfColors.red50 : PdfColors.green50
       ),
       child: pw.Row(
         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
         children: [
           pw.Text("MAGNETOMETER READING (EMF)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
           pw.Text("$mag µT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
           pw.Text(isHigh ? "ANOMALY DETECTED" : "NORMAL", style: pw.TextStyle(color: isHigh ? PdfColors.red : PdfColors.green, fontWeight: pw.FontWeight.bold)),
         ]
       )
     );
  }
}
