import 'dart:async';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/wifi_entity.dart';
import '../models/bluetooth_entity.dart';
import '../services/oui_service.dart';

class ScannerService {
  bool _isWifiScanning = false;
  DateTime? _lastWifiScanTime;
  static const Duration wifiScanInterval = Duration(seconds: 15);

  final Set<String> _uniqueWifiBssids = {};
  final Set<String> _uniqueBleMacs = {};

  final _wifiCountController = StreamController<int>.broadcast();
  final _bleCountController = StreamController<int>.broadcast();
  final _wifiResultsController = StreamController<List<WifiEntity>>.broadcast();
  final _bleResultsController = StreamController<List<BluetoothEntity>>.broadcast();

  final List<WifiEntity> _sessionWifiDevices = [];
  final List<BluetoothEntity> _sessionBleDevices = [];

  StreamSubscription? _wifiSub;
  StreamSubscription? _bleSub;

  ScannerService() {
    _initStreams();
  }

  void _initStreams() {
    _wifiSub = WiFiScan.instance.onScannedResultsAvailable.listen((results) async {
        final position = await _getCurrentLocation();

        final List<WifiEntity> entities = results.map((result) {
          return WifiEntity(
            ssid: result.ssid,
            bssid: result.bssid,
            rssi: result.level,
            frequency: result.frequency,
            capabilities: result.capabilities,
            manufacturer: OuiService.lookup(result.bssid),
            latitude: position?.latitude,
            longitude: position?.longitude,
            timestamp: DateTime.now(),
          );
        }).toList();

        for (var e in entities) {
           if (_uniqueWifiBssids.add(e.bssid)) {
              _sessionWifiDevices.add(e);
           }
        }
        _wifiCountController.add(_uniqueWifiBssids.length);
        _wifiResultsController.add(entities);
    });

    _bleSub = FlutterBluePlus.scanResults.listen((results) async {
       final position = await _getCurrentLocation();

       final List<BluetoothEntity> entities = results.map((r) {
         return BluetoothEntity(
           name: r.device.platformName.isNotEmpty ? r.device.platformName : "DESCONOCIDO",
           mac: r.device.remoteId.str,
           rssi: r.rssi,
           type: "BLE",
           manufacturer: OuiService.lookup(r.device.remoteId.str, deviceName: r.device.platformName.isNotEmpty ? r.device.platformName : null),
           latitude: position?.latitude,
           longitude: position?.longitude,
           timestamp: DateTime.now(),
         );
       }).toList();

       for (var e in entities) {
          if (_uniqueBleMacs.add(e.mac)) {
              _sessionBleDevices.add(e);
          }
       }
       _bleCountController.add(_uniqueBleMacs.length);
       _bleResultsController.add(entities);
    });
  }

  void clearSession() {
      _uniqueWifiBssids.clear();
      _uniqueBleMacs.clear();
      _sessionWifiDevices.clear();
      _sessionBleDevices.clear();
      _wifiCountController.add(0);
      _bleCountController.add(0);
      _wifiResultsController.add([]);
      _bleResultsController.add([]);
  }

  Stream<int> get wifiCountStream => _wifiCountController.stream;
  Stream<int> get bleCountStream => _bleCountController.stream;
  Stream<List<WifiEntity>> get wifiResultsStream => _wifiResultsController.stream;
  Stream<List<BluetoothEntity>> get bleResultsStream => _bleResultsController.stream;

  List<WifiEntity> get sessionWifiList => List.from(_sessionWifiDevices);
  List<BluetoothEntity> get sessionBleList => List.from(_sessionBleDevices);

  /// Get fresh GPS position (not stale getLastKnownPosition)
  Future<Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );
    } catch (e) {
      // Fallback to last known if fresh request fails
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // WiFi Methods

  Future<CanStartScan> startWifiScan() async {
    CanStartScan canStart = await WiFiScan.instance.canStartScan();
    if (canStart != CanStartScan.yes) {
      return canStart;
    }
    // Real throttle: skip if scanned recently
    if (_lastWifiScanTime != null) {
      final diff = DateTime.now().difference(_lastWifiScanTime!);
      if (diff < wifiScanInterval) {
        return CanStartScan.notYet;
      }
    }
    final result = await WiFiScan.instance.startScan();
    if (result) {
      _lastWifiScanTime = DateTime.now();
      _isWifiScanning = true;
    }
    return canStart;
  }

  void stopWifiScan() {
    _isWifiScanning = false;
  }

  // Bluetooth Methods
  Future<void> startBleScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
  }

  Future<void> stopBleScan() async {
    await FlutterBluePlus.stopScan();
  }

  Stream<bool> get isBleScanning => FlutterBluePlus.isScanning;

  /// Proper cleanup
  void dispose() {
    _wifiSub?.cancel();
    _bleSub?.cancel();
    _wifiCountController.close();
    _bleCountController.close();
    _wifiResultsController.close();
    _bleResultsController.close();
  }
}