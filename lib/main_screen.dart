
import 'package:flutter/material.dart';
import 'ui/dashboard_screen.dart';
import 'ui/wifi_screen.dart';
import 'ui/bluetooth_screen.dart';
import 'services/permission_service.dart';
import 'services/scanner_service.dart';
import 'services/location_service.dart';
import 'ui/theme.dart';
import 'ui/magnetic_screen.dart';
import 'ui/lan_screen.dart';
import 'ui/cell_screen.dart';
import 'ui/report_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PermissionService _permissionService = PermissionService();
  final ScannerService _scannerService = ScannerService();
  final LocationService _locationService = LocationService();
  
  // Pages
  late final List<Widget> _pages;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(scannerService: _scannerService, locationService: _locationService),
      WifiScreen(scannerService: _scannerService),
      BluetoothScreen(scannerService: _scannerService),
      const MagneticScreen(),
      const LanScreen(),
      const CellScreen(),
      const ReportScreen(), // v3.0
    ];
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool granted = await _permissionService.requestAllPermissions();
    if (!granted) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("PERMISOS CRITICOS FALTANTES"), backgroundColor: AppTheme.accent)
         );
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("CIBER-RADAR"),
        actions: [
           IconButton(
             icon: const Icon(Icons.delete_forever, color: AppTheme.accent),
             onPressed: () {
               setState(() {
                  _scannerService.clearSession();
               });
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SESSION CLEARED")));
             },
           )
        ],
        bottom: PreferredSize(
           preferredSize: const Size.fromHeight(1.0),
           child: Container(color: AppTheme.secondary, height: 1.0),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.background,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textMedium,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: "RADAR"),
          BottomNavigationBarItem(icon: Icon(Icons.wifi), label: "WIFI"),
          BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: "BLUETOOTH"),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: "PHYSICAL"),
          BottomNavigationBarItem(icon: Icon(Icons.hub), label: "NETWORK"),
          BottomNavigationBarItem(icon: Icon(Icons.cell_tower), label: "CELL"),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: "REPORT"),
        ],
      ),
    );
  }
}
