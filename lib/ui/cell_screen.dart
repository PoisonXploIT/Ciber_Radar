
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
    // Reset state
    setState(() {
      _loading = true;
      _error = null;
    });

    _subscription = _cellService.startMonitoring().listen(
      (incomingCells) {
        if (!mounted) return;
        
        setState(() {
          _loading = false;
          // Pulse effect
          _blink = !_blink;
          
          // Sort: Connected first, then strongest
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
    setState(() {
      _cells.clear();
      _loading = true;
    });
    // Re-trigger helps, but stream will push next update automatically
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("LIST CLEARED"), backgroundColor: AppTheme.primary));
  }

  @override
  Widget build(BuildContext context) {
    // Registered ID
    final connected = _cells.cast<CellTowerModel?>().firstWhere(
        (c) => c?.isRegistered == true, 
        orElse: () => null
    );
    
    bool alarming = false;
    if (connected != null && connected.threatLevel == ThreatLevel.HIGH) {
       alarming = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          _buildHeader(),

          // EMPTY STATE (No Cells Found)
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
                       "NO CELL DATA FOUND", 
                       style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, color: AppTheme.textMedium)
                     ),
                     const SizedBox(height: 8),
                     const Text(
                       "1. Insert SIM Card\n2. Disable Airplane Mode\n3. Enable Location (GPS)", 
                       textAlign: TextAlign.center,
                       style: TextStyle(color: AppTheme.textDim, height: 1.5)
                     ),
                     const SizedBox(height: 20),
                     ElevatedButton.icon(
                        icon: const Icon(Icons.refresh), 
                        label: const Text("RETRY"),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                        onPressed: _startListening,
                     )
                   ],
                 ),
               ),
             ),

          // LOADING STATE
          if (_loading && _cells.isEmpty)
             const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppTheme.primary))),

          // ERROR
          if (_error != null)
             Card(
               color: Colors.red.withOpacity(0.1),
               child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
             ),

          // ALERT
          if (alarming)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                border: Border.all(color: Colors.redAccent, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.redAccent, blurRadius: 10)]
              ),
              child: Column(
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text("DOWNGRADE ATTACK DETECTED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("Force 2G (GSM) Connection Active!", style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

          // MAIN GAUGE DASHBOARD
          if (connected != null)
             _buildDashboard(connected),

          // NEIGHBORS
          if (_cells.where((c) => !c.isRegistered).isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.radar, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text("NEIGHBOR CELLS", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("${_cells.length - (connected!=null?1:0)} detected", style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            ..._cells.where((c) => !c.isRegistered).map((c) => _buildNeighbor(c)).toList(),
          ]
        ],
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
                const Text("CELLULAR MONITOR v2.0", style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, color: AppTheme.textHigh)),
                Row(
                  children: [
                    if (_blink)
                       Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    IconButton(
                        icon: const Icon(Icons.delete_sweep, color: AppTheme.accent),
                        tooltip: "Clear List",
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
     Color typeColor = cell.threatLevel == ThreatLevel.SAFE ? AppTheme.primary : (cell.threatLevel == ThreatLevel.WARN ? AppTheme.warning : Colors.redAccent);

     return Column(
       children: [
         // GAUGE CARD
         Card(
           color: AppTheme.secondary.withOpacity(0.1),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: signalColor.withOpacity(0.5), width: 1)),
           child: Padding(
             padding: const EdgeInsets.all(24.0),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 // Left: Network Type
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(cell.operator.toUpperCase(), style: const TextStyle(color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.2)),
                     const SizedBox(height: 4),
                     Text(cell.type, style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 36, fontWeight: FontWeight.bold, color: typeColor)),
                     if (cell.type == "NR")
                        const Text("5G NSA/SA", style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                     if (cell.type == "LTE")
                        const Text("4G LTE", style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                   ],
                 ),
                 // Right: Signal Gauge
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
         // DETAILS GRID
         Row(
           children: [
             Expanded(child: _buildDetailCard("CID", "${cell.cid}")),
             const SizedBox(width: 8),
             Expanded(child: _buildDetailCard("LAC", "${cell.lac}")),
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
