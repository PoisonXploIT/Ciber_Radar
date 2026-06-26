import 'dart:async';
import 'package:flutter/material.dart';
import '../services/cell_service.dart';
import 'theme.dart';

class CellScreen extends StatefulWidget {
  const CellScreen({super.key});

  @override
  State<CellScreen> createState() => _CellScreenState();
}

class _CellScreenState extends State<CellScreen> {
  final CellService _cellService = CellService();

  List<CellTowerModel> _cells = [];
  StreamSubscription? _subscription;
  bool _loading = true;
  String? _error;
  bool _blink = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _loading = true;
      _error = null;
    });

    _subscription = _cellService.startMonitoring().listen(
      (incomingCells) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _blink = !_blink;

          incomingCells.sort((a, b) {
             if (a.isRegistered && !b.isRegistered) return -1;
             if (!a.isRegistered && b.isRegistered) return 1;
             return b.dbm.compareTo(a.dbm);
          });

          _cells = incomingCells;
        });
      },
      onError: (e) {
        if (mounted) setState(() { _loading = false; _error = e.toString(); });
      },
    );
  }

  void _clearList() {
    _cellService.clearAlerts();
    setState(() {
      _cells.clear();
      _loading = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("DATOS Y ALERTAS BORRADOS"), backgroundColor: AppTheme.primary));
  }

  @override
  Widget build(BuildContext context) {
    final connected = _cells.cast<CellTowerModel?>().firstWhere(
        (c) => c?.isRegistered == true,
        orElse: () => null
    );

    final alerts = _cellService.alerts;

    bool alarming = connected != null &&
        (connected.threatLevel == ThreatLevel.HIGH || connected.threatLevel == ThreatLevel.CRITICAL);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),

          // IMSI ALERTS
          if (alerts.isNotEmpty) ...[
            ...alerts.reversed.take(5).map((alert) => _buildAlertCard(alert)),
            const SizedBox(height: 12),
          ],

          // EMPTY STATE
          if (!_loading && _cells.isEmpty)
             Center(
               child: Padding(
                 padding: const EdgeInsets.all(32.0),
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.signal_cellular_off, size: 48, color: AppTheme.textDim),
                     const SizedBox(height: 16),
                     const Text(
                       "SIN DATOS CELULARES",
                       style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, color: AppTheme.textMedium)
                     ),
                     const SizedBox(height: 8),
                     const Text(
                       "1. Inserta tarjeta SIM\n2. Desactiva modo avion\n3. Activa ubicacion (GPS)",
                       textAlign: TextAlign.center,
                       style: TextStyle(color: AppTheme.textDim, height: 1.5)
                     ),
                     const SizedBox(height: 20),
                     ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("REINTENTAR"),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                        onPressed: _startListening,
                     )
                   ],
                 ),
               ),
             ),

          // LOADING
          if (_loading && _cells.isEmpty)
             const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppTheme.primary))),

          // ERROR
          if (_error != null)
             Card(
               color: Colors.red.withOpacity(0.1),
               child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
             ),

          // CRITICAL/HIGH ALERT BANNER
          if (alarming)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: connected!.threatLevel == ThreatLevel.CRITICAL ? Colors.purple.shade900 : Colors.red.shade900,
                border: Border.all(
                  color: connected.threatLevel == ThreatLevel.CRITICAL ? Colors.purpleAccent : Colors.redAccent,
                  width: 2
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: connected.threatLevel == ThreatLevel.CRITICAL ? Colors.purpleAccent : Colors.redAccent,
                    blurRadius: 10
                  )
                ]
              ),
              child: Column(
                children: [
                  Icon(
                    connected.threatLevel == ThreatLevel.CRITICAL ? Icons.dangerous : Icons.warning_amber_rounded,
                    size: 48, color: Colors.white
                  ),
                  const SizedBox(height: 8),
                  Text(
                    connected.threatLevel == ThreatLevel.CRITICAL ? "IMSI CATCHER DETECTADO" : "DOWNGRADE DETECTADO",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                  if (connected.threatReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(connected.threatReason!, style: const TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),

          // MAIN GAUGE
          if (connected != null)
             _buildDashboard(connected),

          // NEIGHBORS
          if (_cells.where((c) => !c.isRegistered).isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.radar, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text("CELDAS VECINAS", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("${_cells.length - (connected!=null?1:0)} detectadas", style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            ..._cells.where((c) => !c.isRegistered).map((c) => _buildNeighbor(c)).toList(),
          ]
        ],
      ),
    );
  }

  Widget _buildAlertCard(ImsiAlert alert) {
    Color color;
    IconData icon;
    switch (alert.type) {
      case "DOWNGRADE":
        color = Colors.redAccent;
        icon = Icons.dangerous;
        break;
      case "CELL_JUMP":
        color = Colors.orangeAccent;
        icon = Icons.swap_horiz;
        break;
      case "STRONG_2G":
        color = Colors.deepOrangeAccent;
        icon = Icons.signal_cellular_4_bar;
        break;
      case "JAMMING":
        color = Colors.purpleAccent;
        icon = Icons.block;
        break;
      default:
        color = Colors.amber;
        icon = Icons.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.message, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text("${alert.timestamp.hour}:${alert.timestamp.minute.toString().padLeft(2,'0')} - CID: ${alert.cellId} - ${alert.networkType}",
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: AppTheme.secondary.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("CELLULAR MONITOR v2.0", style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, color: AppTheme.textHigh)),
                    if (_cellService.alerts.isNotEmpty)
                      Text("${_cellService.alerts.length} alertas IMSI", style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                  ],
                ),
                Row(
                  children: [
                    if (_blink)
                       Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    IconButton(
                        icon: const Icon(Icons.delete_sweep, color: AppTheme.accent),
                        tooltip: "Limpiar",
                        onPressed: _clearList,
                    )
                  ],
                )
              ],
          ),
        )
    );
  }

  Widget _buildDashboard(CellTowerModel cell) {
     final strength = cell.dbm;
     Color signalColor = _getSignalColor(strength);
     Color typeColor = cell.threatLevel == ThreatLevel.SAFE ? AppTheme.primary
         : cell.threatLevel == ThreatLevel.WARN ? AppTheme.warning
         : cell.threatLevel == ThreatLevel.HIGH ? Colors.redAccent
         : Colors.purpleAccent;

     return Column(
       children: [
         Card(
           color: AppTheme.secondary.withOpacity(0.1),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: signalColor.withOpacity(0.5), width: 1)),
           child: Padding(
             padding: const EdgeInsets.all(24.0),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(cell.operator.toUpperCase(), style: const TextStyle(color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.2)),
                     const SizedBox(height: 4),
                     Text(cell.type, style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 36, fontWeight: FontWeight.bold, color: typeColor)),
                     if (cell.type == "NR")
                        const Text("5G NR", style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                     if (cell.type == "LTE")
                        const Text("4G LTE", style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                     if (cell.threatReason != null && cell.threatLevel != ThreatLevel.SAFE)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(cell.threatReason!, style: TextStyle(color: typeColor, fontSize: 10)),
                        ),
                   ],
                 ),
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     Text("${strength} dBm", style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 32, fontWeight: FontWeight.bold, color: signalColor)),
                     Text("ASU: ${cell.asu}", style: const TextStyle(color: AppTheme.textDim, fontSize: 14)),
                   ],
                 )
               ],
             ),
           ),
         ),
         const SizedBox(height: 12),
         Row(
           children: [
             Expanded(child: _buildDetailCard("CID", "${cell.cid}")),
             const SizedBox(width: 8),
             Expanded(child: _buildDetailCard("LAC/TAC", "${cell.lac}")),
           ],
         )
       ],
     );
  }

  Widget _buildDetailCard(String label, String value) {
    return Card(
      color: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textHigh)),
          ],
        ),
      ),
    );
  }

  Widget _buildNeighbor(CellTowerModel cell) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
       color: Colors.black12,
       child: ListTile(
         dense: true,
         leading: Icon(Icons.signal_cellular_alt, color: _getSignalColor(cell.dbm)),
         title: Text("${cell.type} - CID: ${cell.cid}", style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, color: AppTheme.textHigh)),
         subtitle: Text("LAC: ${cell.lac}", style: const TextStyle(fontSize: 10, color: AppTheme.textMedium)),
         trailing: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           crossAxisAlignment: CrossAxisAlignment.end,
           children: [
             Text("${cell.dbm} dBm", style: TextStyle(color: _getSignalColor(cell.dbm), fontWeight: FontWeight.bold)),
             Text("ASU: ${cell.asu}", style: const TextStyle(fontSize: 10, color: AppTheme.textDim)),
           ],
         ),
       ),
    );
  }

  Color _getSignalColor(int dbm) {
     if (dbm > -90) return Colors.greenAccent;
     if (dbm > -110) return Colors.yellowAccent;
     return Colors.redAccent;
  }
}