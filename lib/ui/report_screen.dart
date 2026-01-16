
import 'package:flutter/material.dart';
import 'theme.dart';
import '../services/report_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportService _reportService = ReportService();
  bool _scanning = false;
  String _status = "READY TO AUDIT";
  double _progress = 0.0;

  void _startAudit() async {
    setState(() {
      _scanning = true;
      _status = "INITIALIZING...";
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
         _status = "AUDIT COMPLETE";
         _progress = 1.0;
         _scanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF Generated & Exported Successfully"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() {
        _status = "ERROR: $e";
        _scanning = false;
        _progress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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
           // Header
           const Icon(Icons.security, size: 80, color: AppTheme.primary),
           const SizedBox(height: 16),
           const Text(
             "THE AUDITOR", 
             textAlign: TextAlign.center,
             style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textHigh)
           ),
           const Text(
             "UNIFIED SECURITY EVIDENCE", 
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
             child: Text(_scanning ? "AUDIT IN PROGRESS..." : "START FULL AUDIT"),
           ),
           
           const SizedBox(height: 16),
           const Text(
             "Generates a comprehensive PDF report including WiFi, BLE, Cellular, and LAN analysis.",
             textAlign: TextAlign.center,
             style: TextStyle(color: AppTheme.textDim, fontSize: 12)
           )
        ],
      ),
    );
  }
}
