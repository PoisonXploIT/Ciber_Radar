
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/scanner_service.dart';
import '../services/location_service.dart';
import 'theme.dart';
import '../services/export_service.dart';

class DashboardScreen extends StatefulWidget {
  final ScannerService scannerService;
  final LocationService locationService;

  const DashboardScreen({super.key, required this.scannerService, required this.locationService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _wifiCount = 0;
  int _bleCount = 0;
  String _gpsAccuracy = "ESPERANDO...";
  bool _scanning = false;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    )..addListener(() { setState((){}); }); // Trigger rebuild for radar
    
    // Listeners
    widget.scannerService.wifiCountStream.listen((count) {
      if (mounted) setState(() => _wifiCount = count);
    });
    widget.scannerService.bleCountStream.listen((count) {
      if (mounted) setState(() => _bleCount = count);
    });
    widget.locationService.positionStream.listen((position) {
      if (mounted) {
         setState(() {
           _gpsAccuracy = "${position.accuracy.toStringAsFixed(1)} m";
         });
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _toggleScan() async {
    setState(() => _scanning = !_scanning);
    if (_scanning) {
        _radarController.repeat();
        // Start scans
        widget.scannerService.startWifiScan(); // Trigger one scan
        widget.scannerService.startBleScan(); // Trigger one scan
        // In a real app we might want a periodic timer here to re-trigger
        // But for MVP one-shot or manual re-trigger is basic.
        // User asked for "Scanning Status Indicator (handling throttling)".
        // We will assume the user presses button repeatedly or we implement a loop?
        // App requirements: "implement a visible countdown timer or progress bar showing when the next scan is available."
        // We will add a timer logic later. For now, basic toggle.
    } else {
        _radarController.stop();
        widget.scannerService.stopBleScan();
    }
  }

  void _exportData() async {
      final exportService = ExportService();
      String? path = await exportService.exportSession(
        widget.scannerService.sessionWifiList, 
        widget.scannerService.sessionBleList
      );
      
      if (mounted) {
         if (path != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("EXPORTADO A: $path", style: const TextStyle(color: AppTheme.background)), backgroundColor: AppTheme.primary));
         } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ERROR AL EXPORTAR"), backgroundColor: AppTheme.accent));
         }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // RADAR VISUALIZATION
          Stack(
            alignment: Alignment.center,
            children: [
               Container(
                 width: 250, height: 250,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   border: Border.all(color: AppTheme.secondary, width: 2),
                 ),
               ),
               Container(
                 width: 150, height: 150,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   border: Border.all(color: AppTheme.secondary.withOpacity(0.5), width: 1),
                 ),
               ),
               if (_scanning)
                 Transform.rotate(
                   angle: _radarController.value * 6.28,
                   child: Container(
                     width: 240, height: 240,
                     decoration: const BoxDecoration(
                       gradient: SweepGradient(
                         colors: [Colors.transparent, AppTheme.primary],
                         stops: [0.7, 1.0],
                       ),
                       shape: BoxShape.circle,
                     ),
                   ),
                 ),
               Column(
                 children: [
                   const Icon(Icons.radar, size: 50, color: AppTheme.primary),
                   Text(_scanning ? "ESCANENDO" : "INACTIVO", style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                 ],
               ),
            ],
          ),
          const SizedBox(height: 30),
          
          // STATS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard("WIFI", "$_wifiCount", Icons.wifi),
              _buildStatCard("BLE", "$_bleCount", Icons.bluetooth),
            ],
          ),
          const SizedBox(height: 10),
          Text("GPS: $_gpsAccuracy", style: Theme.of(context).textTheme.bodyMedium),
          
          const SizedBox(height: 30),
          
          // CONTROLS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleScan,
                icon: Icon(_scanning ? Icons.stop : Icons.play_arrow),
                label: Text(_scanning ? "DETENER" : "ESCANEAR"),
                style: ElevatedButton.styleFrom(
                   backgroundColor: _scanning ? AppTheme.accent : AppTheme.primary,
                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
              const SizedBox(width: 20),
              OutlinedButton.icon(
                onPressed: _exportData,
                icon: const Icon(Icons.download, color: AppTheme.primary),
                label: const Text("EXPORTAR A CSV", style: TextStyle(color: AppTheme.primary)),
                style: OutlinedButton.styleFrom(
                   side: const BorderSide(color: AppTheme.primary),
                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
     return Card(
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           children: [
             Icon(icon, color: AppTheme.primary),
             const SizedBox(height: 5),
             Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
             Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
           ],
         ),
       ),
     );
  }
}
