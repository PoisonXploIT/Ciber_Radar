import 'package:flutter/material.dart';
import 'theme.dart';
import '../services/report_service.dart';
import '../services/scanner_service.dart';
import '../services/lan_service.dart';
import '../services/cell_service.dart';
import '../services/sensor_service.dart';

class ReportScreen extends StatefulWidget {
  final ScannerService scannerService;

  const ReportScreen({super.key, required this.scannerService});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final ReportService _reportService;
  bool _scanning = false;
  String _status = "LISTO PARA AUDITAR";
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // Use shared scanner service -- not a new instance
    _reportService = ReportService(
      scannerService: widget.scannerService,
      lanService: LanService(),
      cellService: CellService(),
      sensorService: SensorService(),
    );
  }

  void _startAudit() async {
    setState(() {
      _scanning = true;
      _status = "INICIALIZANDO...";
      _progress = 0.1;
    });

    try {
      await _reportService.generateAndShareReport((status) {
         setState(() {
           _status = status;
           _progress += 0.15;
           if (_progress > 0.9) _progress = 0.9;
         });
      });
      setState(() {
         _status = "AUDITORIA COMPLETADA";
         _progress = 1.0;
         _scanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF generado y exportado"), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() {
        _status = "ERROR: $e";
        _scanning = false;
        _progress = 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           const SizedBox(height: 20),
           const Icon(Icons.security, size: 80, color: AppTheme.primary),
           const SizedBox(height: 16),
           const Text(
             "THE AUDITOR",
             textAlign: TextAlign.center,
             style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textHigh)
           ),
           const Text(
             "EVIDENCIA DE SEGURIDAD UNIFICADA",
             textAlign: TextAlign.center,
             style: TextStyle(fontSize: 12, color: AppTheme.textDim, letterSpacing: 2)
           ),

           const SizedBox(height: 48),

           // Status Circle
           Center(
             child: Stack(
               alignment: Alignment.center,
               children: [
                 SizedBox(
                   width: 200, height: 200,
                   child: CircularProgressIndicator(
                     value: _scanning ? _progress : 0,
                     backgroundColor: AppTheme.secondary.withOpacity(0.3),
                     color: AppTheme.accent,
                     strokeWidth: 12,
                   ),
                 ),
                 Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      Icon(_scanning ? Icons.radar : Icons.verified_user_outlined, size: 48, color: _scanning ? AppTheme.accent : AppTheme.textDim),
                      const SizedBox(height: 12),
                      Text(
                        _scanning ? "${(_progress * 100).toInt()}%" : "IDLE",
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 24, fontWeight: FontWeight.bold)
                      ),
                   ],
                 )
               ],
             ),
           ),

           const SizedBox(height: 32),

           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.black26,
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: AppTheme.primary.withOpacity(0.3))
             ),
             child: Text(
               _status,
               textAlign: TextAlign.center,
               style: const TextStyle(fontFamily: 'JetBrains Mono', color: AppTheme.primary)
             ),
           ),

           const SizedBox(height: 32),

           ElevatedButton(
             onPressed: _scanning ? null : _startAudit,
             style: ElevatedButton.styleFrom(
               backgroundColor: AppTheme.primary,
               foregroundColor: Colors.black,
               padding: const EdgeInsets.symmetric(vertical: 20),
               textStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 18, fontWeight: FontWeight.bold)
             ),
             child: Text(_scanning ? "AUDIT EN PROGRESO..." : "INICIAR AUDIT COMPLETO"),
           ),

           const SizedBox(height: 16),
           const Text(
             "Genera un reporte PDF completo con analisis de WiFi, BLE, redes celulares y LAN.",
             textAlign: TextAlign.center,
             style: TextStyle(color: AppTheme.textDim, fontSize: 12)
           )
        ],
      ),
    );
  }
}