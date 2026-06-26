import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum ThreatLevel { SAFE, WARN, HIGH, CRITICAL }

class CellTowerModel {
  final String type;
  final int cid;
  final int lac;
  final int dbm;
  final int asu;
  final String operator;
  final bool isRegistered;
  final ThreatLevel threatLevel;
  final String? threatReason;

  CellTowerModel({
    required this.type,
    required this.cid,
    required this.lac,
    required this.dbm,
    required this.asu,
    required this.operator,
    required this.isRegistered,
    required this.threatLevel,
    this.threatReason,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'cid': cid,
    'lac': lac,
    'dbm': dbm,
    'asu': asu,
    'operator': operator,
    'isRegistered': isRegistered,
    'threatLevel': threatLevel.name,
    'threatReason': threatReason,
  };
}

class ImsiAlert {
  final String type;
  final String message;
  final DateTime timestamp;
  final int? cellId;
  final String? networkType;

  ImsiAlert({
    required this.type,
    required this.message,
    required this.timestamp,
    this.cellId,
    this.networkType,
  });
}

class CellService {
  static const methodChannel = MethodChannel('com.ciberradar/cell');
  static const eventChannel = EventChannel('com.ciberradar/cell_updates');

  // IMSI catcher detection state
  int? _lastRegisteredCid;
  String? _lastNetworkType;
  int? _lastDbm;
  DateTime? _lastCellChangeTime;
  final List<ImsiAlert> _alerts = [];

  List<ImsiAlert> get alerts => List.unmodifiable(_alerts);

  Stream<List<CellTowerModel>> startMonitoring() {
      final controller = StreamController<List<CellTowerModel>>();

      _checkPermissions().then((_) async {
          try {
             final initialCells = await getCells();
             if (!controller.isClosed) controller.add(initialCells);
          } catch (e) {
             if (!controller.isClosed) controller.add([]);
          }
      });

      final sub = eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (controller.isClosed) return;
          final List<dynamic> rawList = event;
          final cells = _parseCells(rawList);
          _detectImsiAnomalies(cells);
          controller.add(cells);
        },
        onError: (error) {
           // Don't kill the stream, just log
        }
      );

      controller.onCancel = () {
        sub.cancel();
      };

      return controller.stream;
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.location,
      Permission.phone,
    ].request();
  }

  Future<List<CellTowerModel>> getCells() async {
    try {
      final List<dynamic>? result = await methodChannel.invokeMethod('getCells');
      if (result == null) return [];
      return _parseCells(result);
    } on PlatformException catch (e) {
      return [];
    }
  }

  /// Real IMSI catcher detection -- no root needed
  void _detectImsiAnomalies(List<CellTowerModel> cells) {
    final registered = cells.where((c) => c.isRegistered).toList();

    if (registered.isEmpty) return;

    final current = registered.first;

    // 1. Detect downgrade attack: 4G/5G -> 2G while stationary
    if (_lastNetworkType != null) {
      final wasModern = _lastNetworkType == "LTE" || _lastNetworkType == "NR";
      final is2G = current.type == "GSM" || current.type == "GPRS" || current.type == "EDGE";

      if (wasModern && is2G) {
        _alerts.add(ImsiAlert(
          type: "DOWNGRADE",
          message: "DOWNGRADE ATTACK: Red paso de $_lastNetworkType a ${current.type} (2G). Posible IMSI catcher.",
          timestamp: DateTime.now(),
          cellId: current.cid,
          networkType: current.type,
        ));
      }
    }

    // 2. Detect sudden Cell ID change (cell reselection while signal is strong = suspicious)
    if (_lastRegisteredCid != null && _lastRegisteredCid != current.cid) {
      // Cell changed -- check if it happened too fast (within 30 seconds)
      if (_lastCellChangeTime != null) {
        final timeSinceLastChange = DateTime.now().difference(_lastCellChangeTime!);
        if (timeSinceLastChange.inSeconds < 30 && current.dbm > -80) {
          _alerts.add(ImsiAlert(
            type: "CELL_JUMP",
            message: "CELL JUMP: Cambio rapido de celda ($_lastRegisteredCid -> ${current.cid}) en ${timeSinceLastChange.inSeconds}s con senal fuerte (${current.dbm} dBm).",
            timestamp: DateTime.now(),
            cellId: current.cid,
            networkType: current.type,
          ));
        }
      }
      _lastCellChangeTime = DateTime.now();
    }

    // 3. Detect abnormally strong signal from unknown cell (possible nearby fake tower)
    if (current.dbm > -50 && current.type == "GSM") {
      _alerts.add(ImsiAlert(
        type: "STRONG_2G",
        message: "STRONG 2G SIGNAL: Senal anormalmente fuerte (${current.dbm} dBm) en red 2G. Posible torre falsa proxima.",
        timestamp: DateTime.now(),
        cellId: current.cid,
        networkType: current.type,
      ));
    }

    // 4. Detect neighbor cells disappearing (jamming indicator)
    final neighborCount = cells.where((c) => !c.isRegistered).length;
    if (_lastDbm != null && neighborCount == 0 && cells.length <= 1 && current.dbm < _lastDbm! - 20) {
      _alerts.add(ImsiAlert(
        type: "JAMMING",
        message: "JAMMING INDICATOR: Vecinas desaparecieron y senal cayo ${_lastDbm! - current.dbm} dBm. Posible interferencia.",
        timestamp: DateTime.now(),
        cellId: current.cid,
        networkType: current.type,
      ));
    }

    // Update state
    _lastRegisteredCid = current.cid;
    _lastNetworkType = current.type;
    _lastDbm = current.dbm;
  }

  void clearAlerts() {
    _alerts.clear();
  }

  List<CellTowerModel> _parseCells(List<dynamic> rawList) {
      final Map<int, CellTowerModel> uniqueCells = {};

      for (var data in rawList) {
        final map = Map<String, dynamic>.from(data);
        final type = map['type'] as String? ?? "UNKNOWN";
        final cid = _toInt(map['cid'] ?? map['nci'] ?? 0);
        final lac = _toInt(map['lac'] ?? map['tac'] ?? 0);
        final dbm = _toInt(map['dbm']);
        final asu = _toInt(map['asu']);
        final operator = map['operator'] as String? ?? "Unknown";
        final isRegistered = map['isRegistered'] == true;

        ThreatLevel threat = ThreatLevel.WARN;
        String? reason;

        // 1. SAFE (Modern 4G/5G)
        if (type == "NR" || type == "LTE" || type == "IWLAN") {
           threat = ThreatLevel.SAFE;
        }
        // 2. WARNING (3G)
        else if (type == "WCDMA" || type == "HSPA" || type == "HSPAP" || type == "UMTS" || type == "TD-SCDMA") {
           threat = ThreatLevel.WARN;
           reason = "Red 3G -- encriptacion debil";
        }
        // 3. HIGH RISK (2G)
        else if (type == "GSM" || type == "GPRS" || type == "EDGE" || type == "CDMA" || type == "1xRTT" || type == "IDEN") {
           threat = ThreatLevel.HIGH;
           reason = "Red 2G -- vulnerable a interceptacion (IMSI catcher)";
        }

        // Check active IMSI alerts for this cell
        final cellAlerts = _alerts.where((a) => a.cellId == cid && a.type != "JAMMING");
        if (cellAlerts.isNotEmpty) {
           threat = ThreatLevel.CRITICAL;
           reason = cellAlerts.first.message;
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
          threatReason: reason,
        );

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