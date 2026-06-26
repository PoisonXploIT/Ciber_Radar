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
  // Use shared services passed from caller -- not new instances
  final ScannerService scannerService;
  final LanService lanService;
  final CellService cellService;
  final SensorService sensorService;

  ReportService({
    required this.scannerService,
    required this.lanService,
    required this.cellService,
    required this.sensorService,
  });

  Future<void> generateAndShareReport(Function(String) onStatus) async {
    // 1. WiFi -- use existing session data + trigger fresh scan
    onStatus("AUDITANDO ESPECTRO WIFI...");
    await scannerService.startWifiScan();
    await Future.delayed(const Duration(seconds: 3));
    final wifiList = scannerService.sessionWifiList;

    // 2. BLE -- use existing session data + trigger fresh scan
    onStatus("ESCANEANDO DISPOSITIVOS BLUETOOTH...");
    await scannerService.startBleScan();
    await Future.delayed(const Duration(seconds: 3));
    await scannerService.stopBleScan();
    final bleList = scannerService.sessionBleList;

    // 3. Sensor
    onStatus("LEYENDO SENSORES MAGNETICOS...");
    double magValue = 0.0;
    try {
       magValue = await sensorService.magneticField.first.timeout(const Duration(seconds: 1));
    } catch (e) {
       magValue = 0.0;
    }

    // 4. Cellular
    onStatus("INTERCEPTANDO TORRES CELULARES...");
    List<CellTowerModel> cellList = [];
    try {
       cellList = await cellService.getCells();
    } catch (e) {
       cellList = [];
    }

    // 5. LAN
    onStatus("ESCANANDO SUBRED LAN...");
    List<HostModel> lanHosts = [];
    try {
      String? ip = await lanService.getIp();
      if (ip != null) {
         String? subnet = lanService.getSubnet(ip);
         if (subnet != null) {
             final stream = lanService.scan(subnet);
             final List<HostModel> tempHosts = [];
             final sub = stream.listen((host) => tempHosts.add(host));
             await Future.delayed(const Duration(seconds: 3));
             await sub.cancel();
             lanHosts = tempHosts;
         }
      }
    } catch(e) { /* ignore */ }

    // 6. PDF Generation
    onStatus("COMPILANDO REPORTE PDF...");

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
            _buildSummary(wifiList, bleList, cellList, lanHosts, magValue),
            _buildSectionTitle("1. ESPECTRO WIRELESS (WiFi)"),
            _buildWifiTable(wifiList),
            pw.SizedBox(height: 15),
            _buildSectionTitle("2. DISPOSITIVOS BLUETOOTH"),
            _buildBleTable(bleList),
            pw.SizedBox(height: 15),
            _buildSectionTitle("3. INTERCEPTOR CELULAR"),
            _buildCellTable(cellList),
            pw.SizedBox(height: 15),
            _buildSectionTitle("4. SENSORES FISICOS"),
            _buildSensorRow(magValue),
            pw.SizedBox(height: 15),
            _buildSectionTitle("5. RED LOCAL (LAN)"),
            _buildLanTable(lanHosts),
            pw.Divider(thickness: 1, color: PdfColors.grey),
            _buildFooter(),
          ];
        },
      ),
    );

    // 7. Share
    onStatus("EXPORTANDO DOCUMENTO...");
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
             pw.Text("REPORTE DE AUDITORIA", style: pw.TextStyle(fontSize: 14, color: PdfColors.redAccent, fontWeight: pw.FontWeight.bold)),
          ]
        ),
        pw.SizedBox(height: 5),
        pw.Text("Fecha: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
      ]
    );
  }

  pw.Widget _buildSummary(List<WifiEntity> wifi, List<BluetoothEntity> ble,
      List<CellTowerModel> cells, List<HostModel> hosts, double mag) {
    final vulnWifi = wifi.where((w) => w.isVulnerable).length;
    final openWifi = wifi.where((w) => w.isOpen).length;
    final wepWifi = wifi.where((w) => w.isWep).length;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey300),
        color: PdfColors.blueGrey50,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem("WiFi", "${wifi.length}", vulnWifi > 0 ? "($vulnWifi vulnerables)" : ""),
          _summaryItem("BLE", "${ble.length}", ""),
          _summaryItem("Cell", "${cells.length}", ""),
          _summaryItem("LAN", "${hosts.length}", ""),
          _summaryItem("EMF", "${mag.toStringAsFixed(1)} uT", mag > 60 ? "ANOMALIA" : ""),
        ],
      ),
    );
  }

  pw.Widget _summaryItem(String label, String value, String note) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        if (note.isNotEmpty)
          pw.Text(note, style: pw.TextStyle(fontSize: 7, color: PdfColors.red)),
      ],
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
            pw.Text("CONFIDENCIAL", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            pw.Text("Generado por Ciber-Radar v2.0", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey))
         ]
       )
    );
  }

  pw.Widget _buildWifiTable(List<WifiEntity> list) {
    if (list.isEmpty) return pw.Paragraph(text: "No se detectaron redes WiFi");

    // Sort: Vulnerable first
    list.sort((a,b) {
       final aVuln = a.isVulnerable ? 1 : 0;
       final bVuln = b.isVulnerable ? 1 : 0;
       return bVuln.compareTo(aVuln);
    });

    final data = list.take(20).map((e) {
      final isVuln = e.isVulnerable;
      return [
        e.ssid.isEmpty ? "<OCULTA>" : e.ssid,
        e.bssid,
        e.securityType,
        "${e.rssi} dBm",
        pw.Text(
          isVuln ? "VULNERABLE" : "SEGURA",
          style: pw.TextStyle(color: isVuln ? PdfColors.red : PdfColors.green, fontWeight: pw.FontWeight.bold)
        )
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: ['SSID', 'BSSID', 'SEGURIDAD', 'SENAL', 'ESTADO'],
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
    if (list.isEmpty) return pw.Paragraph(text: "No se detectaron dispositivos Bluetooth");

    final data = list.take(15).map((e) {
      return [
        e.name.isEmpty ? "N/A" : e.name,
        e.mac,
        "${e.rssi} dBm",
        "BLE"
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: ['NOMBRE', 'MAC', 'RSSI', 'TIPO'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellStyle: const pw.TextStyle(fontSize: 10),
    );
  }

  pw.Widget _buildCellTable(List<CellTowerModel> list) {
     if (list.isEmpty) return pw.Paragraph(text: "No hay datos celulares disponibles");

     final data = list.map((e) {
       final isRisk = e.threatLevel == ThreatLevel.HIGH;
       return [
         e.type,
         e.cid.toString(),
         "${e.dbm} dBm",
         pw.Text(
           isRisk ? "AMENAZA (Downgrade)" : (e.threatLevel == ThreatLevel.WARN ? "ADVERTENCIA (3G)" : "SEGURA"),
           style: pw.TextStyle(color: isRisk ? PdfColors.red : (e.threatLevel == ThreatLevel.WARN ? PdfColors.orange : PdfColors.green), fontWeight: pw.FontWeight.bold)
         )
       ];
     }).toList();

     return pw.Table.fromTextArray(
      headers: ['RED', 'CELL ID', 'SENAL', 'ANALISIS'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellStyle: const pw.TextStyle(fontSize: 10),
    );
  }

  pw.Widget _buildLanTable(List<HostModel> list) {
    if (list.isEmpty) return pw.Paragraph(text: "No se descubrieron hosts LAN");

    return pw.Table.fromTextArray(
      headers: ['DIRECCION IP', 'HOSTNAME', 'ORIGEN'],
      data: list.map((e) => [
        e.ip,
        e.name ?? "Desconocido",
        e.source
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellStyle: const pw.TextStyle(fontSize: 10),
    );
  }

  pw.Widget _buildSensorRow(double mag) {
     final isHigh = mag > 100.0; // Raised threshold to reduce false positives
     return pw.Container(
       padding: const pw.EdgeInsets.all(10),
       decoration: pw.BoxDecoration(
         border: pw.Border.all(color: isHigh ? PdfColors.red : PdfColors.green),
         color: isHigh ? PdfColors.red50 : PdfColors.green50
       ),
       child: pw.Row(
         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
         children: [
           pw.Text("LECTURA MAGNETOMETRO (EMF)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
           pw.Text("$mag uT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
           pw.Text(isHigh ? "ANOMALIA DETECTADA" : "NORMAL", style: pw.TextStyle(color: isHigh ? PdfColors.red : PdfColors.green, fontWeight: pw.FontWeight.bold)),
         ]
       )
     );
  }
}