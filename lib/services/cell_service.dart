
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum ThreatLevel { SAFE, WARN, HIGH }

class CellTowerModel {
  final String type;
  final int cid;
  final int lac;
  final int dbm;
  final int asu; // New: ASU Level
  final String operator; // New: Network Operator
  final bool isRegistered;
  final ThreatLevel threatLevel;

  CellTowerModel({
    required this.type,
    required this.cid,
    required this.lac,
    required this.dbm,
    required this.asu,
    required this.operator,
    required this.isRegistered,
    required this.threatLevel,
  });
}

class CellService {
  static const methodChannel = MethodChannel('com.ciberradar/cell');
  static const eventChannel = EventChannel('com.ciberradar/cell_updates');

  Stream<List<CellTowerModel>> startMonitoring() {
      final controller = StreamController<List<CellTowerModel>>();

      // 1. Kickstart: Immediate Fetch
      _checkPermissions().then((_) async {
          try {
             final initialCells = await getCells();
             if (!controller.isClosed) controller.add(initialCells);
          } catch (e) {
             print("Kickstart Error: $e");
             if (!controller.isClosed) controller.add([]);
          }
      });

      // 2. Continuous Listener (EventChannel)
      final sub = eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (controller.isClosed) return;
          final List<dynamic> rawList = event;
          controller.add(_parseCells(rawList));
        },
        onError: (error) {
           print("EventChannel Error: $error");
           // Don't kill the stream, just log
        }
      );

      controller.onCancel = () {
        sub.cancel();
      };

      return controller.stream;
  }
  
  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.phone,
    ].request();
    
    if (statuses[Permission.location] != PermissionStatus.granted ||
        statuses[Permission.phone] != PermissionStatus.granted) {
       print("Permissions not granted");
    }
  }

  // Fallback / One-time fetch if needed
  Future<List<CellTowerModel>> getCells() async {
    try {
      final List<dynamic>? result = await methodChannel.invokeMethod('getCells');
      if (result == null) return [];
      return _parseCells(result);
    } on PlatformException catch (e) {
      print("CellService Error: ${e.message}");
      return [];
    }
  }

  List<CellTowerModel> _parseCells(List<dynamic> rawList) {
      final Map<int, CellTowerModel> uniqueCells = {};

      for (var data in rawList) {
        final map = Map<String, dynamic>.from(data);
        final type = map['type'] as String? ?? "UNKNOWN";
        final cid = _toInt(map['cid']);
        final lac = _toInt(map['lac']);
        final dbm = _toInt(map['dbm']);
        final asu = _toInt(map['asu']);
        final operator = map['operator'] as String? ?? "Unknown";
        final isRegistered = map['isRegistered'] == true;

        // Anomaly Logic
        ThreatLevel threat = ThreatLevel.WARN; 

        // 1. SAFE (Modern 4G/5G)
        if (type == "NR" || type == "LTE" || type == "IWLAN") {
           threat = ThreatLevel.SAFE;
        } 
        // 2. WARNING (3G)
        else if (type == "WCDMA" || type == "HSPA" || type == "HSPAP" || type == "UMTS" || type == "TD-SCDMA") {
           threat = ThreatLevel.WARN;
        }
        // 3. HIGH RISK (2G)
        else if (type == "GSM" || type == "GPRS" || type == "EDGE" || type == "CDMA" || type == "1xRTT" || type == "IDEN") {
           threat = ThreatLevel.HIGH;
        }

        final cell = CellTowerModel(
          type: type,
          cid: cid,
          lac: lac,
          dbm: dbm,
          asu: asu,
          operator: operator,
          isRegistered: isRegistered,
          threatLevel: threat,
        );

        // De-duplication: Prefer registered, then strongest signal
        if (cell.isRegistered) {
           uniqueCells[cell.cid] = cell;
        } else {
           if (uniqueCells.containsKey(cell.cid)) {
               if (cell.dbm > uniqueCells[cell.cid]!.dbm && !uniqueCells[cell.cid]!.isRegistered) {
                   uniqueCells[cell.cid] = cell;
               }
           } else {
               uniqueCells[cell.cid] = cell;
           }
        }
      }
      
      return uniqueCells.values.toList();
  }

  int _toInt(dynamic val) {
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? 0;
    if (val is double) return val.toInt();
    if (val is num) return val.toInt();
    return 0;
  }
}
