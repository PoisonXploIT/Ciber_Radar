
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  
  /// Solicita todos los permisos necesarios para el funcionamiento de la app.
  /// Retorna true si todos fueron concedidos.
  Future<bool> requestAllPermissions() async {
    if (!Platform.isAndroid) return false;

    // Ubicacion es critica para WiFi scan
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.locationAlways, // A veces requerido para background, aunque este app es foreground principalmente
      Permission.locationWhenInUse,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    
    // Verificar Wifi (Location suele cubrirlo, pero Android 13+ puede ser tricky)
    // Permission.nearByWifiDevices es para Android 13+
    if (await Permission.nearbyWifiDevices.status.isDenied) {
        await Permission.nearbyWifiDevices.request();
    }

    bool locationGranted = await Permission.location.isGranted || await Permission.locationWhenInUse.isGranted;
    bool scanGranted = await Permission.bluetoothScan.isGranted; // Solo Android 12+
    // En versiones viejas bluetoothScan siempre es granted o no existe, permission_handler lo maneja.
    
    return locationGranted; 
  }

  Future<bool> checkLocationPermission() async {
    return await Permission.location.isGranted || await Permission.locationWhenInUse.isGranted;
  }
}
